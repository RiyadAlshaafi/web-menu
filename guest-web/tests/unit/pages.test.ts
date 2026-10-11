import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { ITEM, SLUG, freshLimits, mockSupabase, setEnv } from "../api/helpers";
import { errorText } from "@/lib/client/messages";
import { setLimiter } from "@/lib/server/ratelimit";

vi.mock("server-only", () => ({}));
const requestHeaders = { value: new Headers() };
vi.mock("next/headers", () => ({ headers: async () => requestHeaders.value }));
vi.mock("@upstash/redis", () => ({ Redis: class { constructor(public opts: unknown) {} } }));
const upstash = vi.hoisted(() => ({ success: true, reset: 0, keys: [] as string[], windows: [] as unknown[] }));
vi.mock("@upstash/ratelimit", () => ({
  Ratelimit: Object.assign(
    class {
      constructor(public opts: { prefix: string; limiter: unknown }) {
        upstash.windows.push(opts.limiter);
      }
      async limit(key: string) {
        upstash.keys.push(`${this.opts.prefix}:${key}`);
        return { success: upstash.success, reset: upstash.reset };
      }
    },
    { slidingWindow: (max: number, window: string) => ({ max, window }) },
  ),
}));

const menuRow = {
  ok: true,
  cafe: { id: "c", name: "Akakus", locale: "ar", logo_url: "", header_color: "", button_color: "", background_color: "", service_charge_rate: 0 },
  table: { number: "4" },
  categories: [],
  items: [],
  payment_types: [],
};

beforeEach(() => {
  setEnv();
  freshLimits();
  requestHeaders.value = new Headers({ "x-forwarded-for": "9.9.9.9, 10.0.0.1" });
  vi.spyOn(console, "error").mockImplementation(() => {});
});
afterEach(() => {
  Object.assign(upstash, { success: true, reset: 0, keys: [], windows: [] });
  vi.unstubAllGlobals();
  vi.unstubAllEnvs();
  vi.restoreAllMocks();
});

describe("server page loaders", () => {
  it("loads the table's menu, and maps a missing table and a failure", async () => {
    const { loadTable } = await import("@/lib/server/page");
    let reply: unknown = menuRow;
    const calls = mockSupabase(() => (reply === "throw" ? "network-error" : { body: reply }));
    expect(await loadTable(SLUG)).toMatchObject({ kind: "ok", menu: { cafe: { name: "Akakus" } } });
    expect(calls[0]).toMatchObject({ name: "guest_menu", args: { p_qr_slug: SLUG } });
    reply = { ok: false, error: "table not found" };
    expect(await loadTable("other-slug-1")).toEqual({ kind: "not_found" });
    reply = "throw";
    expect(await loadTable("third-slug-1")).toEqual({ kind: "error" });
    expect(await loadTable("BAD SLUG!")).toEqual({ kind: "not_found" });
  });

  it("applies the page rate limits per phone and per table", async () => {
    const { loadTable } = await import("@/lib/server/page");
    mockSupabase(() => ({ body: menuRow }));
    const keys: string[] = [];
    setLimiter({ limit: async (key) => (keys.push(key), { success: !key.startsWith("page:slug"), retryAfter: 5 }) });
    expect(await loadTable("limited-slug")).toEqual({ kind: "rate_limited" });
    expect(keys).toEqual(["page:ip:9.9.9.9", "page:slug:limited-slug"]);
    setLimiter({ limit: async () => ({ success: false, retryAfter: 5 }) });
    expect(await loadTable("limited-slug-2")).toEqual({ kind: "rate_limited" });
  });

  it("reads the chosen language and the table state", async () => {
    const { loadTableState, pageLang } = await import("@/lib/server/page");
    requestHeaders.value = new Headers({ "x-guest-lang": "ar" });
    expect(await pageLang()).toBe("ar");
    requestHeaders.value = new Headers({ "x-guest-lang": "fr" });
    expect(await pageLang()).toBeNull();

    mockSupabase((name) =>
      name === "guest_status"
        ? { body: { ok: true, ordering_open: true, location: { enabled: false, radius_m: 30 } } }
        : { body: { ok: false, error: "table not found" } },
    );
    expect(await loadTableState(SLUG)).toEqual({ status: { orderingOpen: true, location: { enabled: false, radiusM: 30 } }, tab: null });
    mockSupabase(() => "network-error");
    expect(await loadTableState(SLUG)).toEqual({ status: null, tab: null });
  });
});

describe("old cart links", () => {
  it("forward to the live tab, keeping a valid language", async () => {
    const { GET } = await import("@/app/t/[slug]/cart/route");
    let res = await GET(new Request(`https://g.test/t/${SLUG}/cart?lang=ar`), { params: Promise.resolve({ slug: SLUG }) });
    expect(res.status).toBe(308);
    expect(res.headers.get("location")).toBe(`https://g.test/t/${SLUG}/tab?lang=ar`);
    res = await GET(new Request(`https://g.test/t/${SLUG}/cart?lang=x`), { params: Promise.resolve({ slug: SLUG }) });
    expect(res.headers.get("location")).toBe(`https://g.test/t/${SLUG}/tab`);
  });
});

describe("Upstash limiter", () => {
  it("is used when configured, with one sliding window per limit", async () => {
    vi.stubEnv("UPSTASH_REDIS_REST_URL", "https://redis.test");
    vi.stubEnv("UPSTASH_REDIS_REST_TOKEN", "t");
    const { limiter, upstashConfigured } = await import("@/lib/server/ratelimit");
    setLimiter(null);
    expect(upstashConfigured()).toBe(true);
    const rl = limiter();
    expect(limiter()).toBe(rl);
    upstash.reset = Date.now() + 30_000;
    expect(await rl.limit("ip:1", 60)).toEqual({ success: true, retryAfter: 30 });
    upstash.success = false;
    upstash.reset = Date.now() - 1;
    expect(await rl.limit("ip:1", 60)).toEqual({ success: false, retryAfter: 1 });
    await rl.limit("slug:x", 20);
    expect(upstash.keys).toEqual(["guest:rl:60:ip:1", "guest:rl:60:ip:1", "guest:rl:20:slug:x"]);
    expect(upstash.windows).toEqual([{ max: 60, window: "1 m" }, { max: 20, window: "1 m" }]);
    setLimiter(null);
  });

  it("falls back to memory with a warning when not configured", async () => {
    const warn = vi.spyOn(console, "warn").mockImplementation(() => {});
    const { limiter, MemoryLimiter } = await import("@/lib/server/ratelimit");
    setLimiter(null);
    expect(limiter()).toBeInstanceOf(MemoryLimiter);
    expect(warn).toHaveBeenCalled();
    setLimiter(null);
  });

  it("memory limiter forgets idle keys once it holds many", async () => {
    const { MemoryLimiter } = await import("@/lib/server/ratelimit");
    let now = 0;
    const rl = new MemoryLimiter(() => now);
    for (let i = 0; i <= 10_000; i++) await rl.limit(`k${i}`, 5);
    now = 120_000;
    await rl.limit("fresh-1", 5);
    await rl.limit("fresh-2", 5);
    expect((rl as unknown as { hits: Map<string, number[]> }).hits.size).toBe(2);
  });
});

describe("error text", () => {
  it("covers every guest error code in both languages", () => {
    const items = [{ id: ITEM, categoryId: "c", nameEn: "Tea", nameAr: "شاي", description: "", price: 1, salePrice: 1, imageUrl: "", available: false, featured: false }];
    expect(errorText("ar", { code: "items_unavailable", items: ["Tea", "Cake"] }, items)).toContain("شاي، Cake");
    expect(errorText("en", { code: "items_unavailable", items: ["شاي"] }, items)).toContain("Tea");
    const codes = ["cashier_offline", "too_far", "location_required", "qty_too_large", "rate_limited", "table_not_found", "no_open_bill", "not_served", "server_error"];
    const seen = new Set(codes.map((code) => errorText("en", { code })));
    expect(seen.size).toBe(codes.length);
    expect(errorText("en", { code: "network" }, [], true)).toMatch(/went wrong/);
    expect(errorText("en", { code: "network" }, [], false)).toMatch(/offline/);
    expect(errorText("ar", { code: "network" }, [], false)).toMatch(/اتصال/);
  });
});
