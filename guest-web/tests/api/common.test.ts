import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import * as menu from "@/app/api/guest/menu/route";
import * as status from "@/app/api/guest/status/route";
import * as tab from "@/app/api/guest/tab/route";
import * as callStaff from "@/app/api/guest/call-staff/route";
import * as bill from "@/app/api/guest/bill/route";
import * as refusal from "@/app/api/guest/refusal/route";
import * as location from "@/app/api/guest/location/route";
import * as order from "@/app/api/guest/order/route";
import * as paymentType from "@/app/api/guest/payment-type/route";
import { LIMITS } from "@/lib/server/ratelimit";
import { freshLimits, get, ITEM, json, mockSupabase, post, setEnv, SLUG, TYPE } from "./helpers";

type Case = {
  name: keyof typeof LIMITS;
  call: (slug: string, ip?: string) => Promise<Response>;
};

const cases: Case[] = [
  { name: "menu", call: (s, ip) => menu.GET(get(`/api/guest/menu?slug=${s}`, ip)) },
  { name: "status", call: (s, ip) => status.GET(get(`/api/guest/status?slug=${s}`, ip)) },
  { name: "tab", call: (s, ip) => tab.GET(get(`/api/guest/tab?slug=${s}`, ip)) },
  { name: "call-staff", call: (s, ip) => callStaff.POST(post("/api/guest/call-staff", { slug: s }, ip)) },
  { name: "bill", call: (s, ip) => bill.POST(post("/api/guest/bill", { slug: s }, ip)) },
  { name: "refusal", call: (s, ip) => refusal.POST(post("/api/guest/refusal", { slug: s }, ip)) },
  { name: "location", call: (s, ip) => location.POST(post("/api/guest/location", { slug: s, lat: 32.9, lng: 13.18 }, ip)) },
  {
    name: "order",
    call: (s, ip) => order.POST(post("/api/guest/order", { slug: s, lines: [{ menuItemId: ITEM, qty: 1 }] }, ip)),
  },
  { name: "payment-type", call: (s, ip) => paymentType.POST(post("/api/guest/payment-type", { slug: s, typeId: TYPE }, ip)) },
];

beforeEach(() => {
  setEnv();
  freshLimits();
  vi.spyOn(console, "error").mockImplementation(() => {});
  vi.spyOn(console, "warn").mockImplementation(() => {});
});
afterEach(() => {
  vi.unstubAllGlobals();
  vi.unstubAllEnvs();
  vi.restoreAllMocks();
});

describe.each(cases)("$name: shared rules", ({ name, call }) => {
  it("refuses a malformed slug without calling the database", async () => {
    const calls = mockSupabase(() => ({ body: { ok: true } }));
    for (const bad of ["", "ab", "UPPER-case-slug", "a b c d e f", "x".repeat(65), "slug';drop"]) {
      const res = await call(encodeURIComponent(bad));
      expect(res.status, bad).toBe(400);
      expect((await json(res)).error?.code).toBe("bad_request");
    }
    expect(calls).toHaveLength(0);
  });

  it("answers table_not_found for an unknown or archived table (another cafe's slug is just unknown)", async () => {
    mockSupabase(() => ({ body: { ok: false, error: "table not found" } }));
    const res = await call(SLUG);
    expect(res.status).toBe(404);
    expect(await json(res)).toEqual({
      ok: false,
      data: null,
      error: { code: "table_not_found", message: "This QR code doesn't match a table." },
    });
  });

  it("limits each table, then answers 429 with Retry-After", async () => {
    const calls = mockSupabase(() => ({ body: { ok: false, error: "table not found" } }));
    const max = LIMITS[name].slug;
    for (let i = 0; i < max; i++) await call(SLUG, `10.0.1.${i}`);
    const res = await call(SLUG, "10.0.2.1");
    expect(res.status).toBe(429);
    expect(res.headers.get("Retry-After")).toMatch(/^\d+$/);
    expect((await json(res)).error?.code).toBe("rate_limited");
    expect(calls).toHaveLength(max);
    // Another table is not affected.
    expect((await call("otherslug123", "10.0.2.1")).status).toBe(404);
  });

  it("limits each IP across tables", async () => {
    mockSupabase(() => ({ body: { ok: false, error: "table not found" } }));
    const max = LIMITS[name].ip;
    for (let i = 0; i < max; i++) await call(`slug${String(i).padStart(4, "0")}`, "10.0.3.3");
    const res = await call("lastslug999", "10.0.3.3");
    expect(res.status).toBe(429);
    expect((await call("lastslug999", "10.0.3.4")).status).toBe(404);
  });

  it("never passes a database error text to the guest", async () => {
    mockSupabase(() => ({ status: 400, body: { code: "42501", message: 'permission denied for table "orders"' } }));
    const res = await call(SLUG);
    const body = await json(res);
    expect(res.status).toBe(500);
    expect(body.error).toEqual({ code: "server_error", message: "Something went wrong." });
    expect(JSON.stringify(body)).not.toContain("permission");
  });

  it("answers server_error when Supabase can't be reached", async () => {
    mockSupabase(() => "network-error");
    const res = await call(SLUG);
    expect(res.status).toBe(500);
    expect((await json(res)).error?.code).toBe("server_error");
  });

  it("answers server_error for an unexpected result shape", async () => {
    mockSupabase(() => ({ body: { ok: true, surprise: "column" } }));
    const res = await call(SLUG);
    // Endpoints that only confirm (call-staff, bill, ...) accept { ok: true }.
    if (["call-staff", "bill", "refusal", "payment-type"].includes(name)) {
      expect(res.status).toBe(200);
      expect((await json(res)).data).toEqual({ done: true });
    } else {
      expect(res.status).toBe(500);
    }
  });

  it("calls Supabase with only the public key and no guest header", async () => {
    const calls = mockSupabase(() => ({ body: { ok: false, error: "table not found" } }));
    await call(SLUG);
    expect(calls).toHaveLength(1);
    expect(calls[0].headers.get("apikey")).toBe("sb_publishable_test");
    expect(calls[0].headers.get("authorization")).toBeNull();
    expect(calls[0].headers.get("x-qr-slug")).toBeNull();
    expect(calls[0].args.p_qr_slug).toBe(SLUG);
  });
});

describe.each(cases.filter((c) => !["menu", "status", "tab"].includes(c.name)))("$name: request body", ({ name }) => {
  const path = `/api/guest/${name}`;
  const handler = { "call-staff": callStaff, bill, refusal, location, order, "payment-type": paymentType }[
    name as "call-staff"
  ];

  it("refuses unknown fields, bad JSON, wrong content type and oversized bodies", async () => {
    const calls = mockSupabase(() => ({ body: { ok: true } }));
    const bad = [
      post(path, { slug: SLUG, extra: 1 }),
      post(path, "{not json"),
      new Request(`http://localhost${path}`, { method: "POST", body: JSON.stringify({ slug: SLUG }) }),
      post(path, JSON.stringify({ slug: SLUG, pad: "x".repeat(20_000) })),
    ];
    for (const request of bad) {
      const res = await handler.POST(request);
      expect(res.status).toBe(400);
    }
    expect(calls).toHaveLength(0);
  });
});
