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
import * as visit from "@/app/api/guest/visit/route";
import * as claim from "@/app/api/guest/claim/route";
import { freshLimits, get, ITEM, json, mockSupabase, post, setEnv, SLUG, TYPE } from "./helpers";

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

const ITEM2 = "c0000000-0000-4000-8000-000000000002";
const OPT = "d0000000-0000-4000-8000-000000000001";
const OPT2 = "d0000000-0000-4000-8000-000000000002";

const CASHIER_OFFLINE = { status: 400, body: { code: "P0001", message: "cashier_offline", details: null, hint: null } };

const menuRow = {
  ok: true,
  cafe: {
    id: "r1",
    name: "Akakus",
    locale: "ar",
    logo_url: "",
    header_color: "#1B3A4B",
    button_color: "",
    background_color: null,
    service_charge_rate: 0.1,
  },
  table: { number: "4" },
  categories: [{ id: "c1", name_en: "Drinks", name_ar: "مشروبات", sort_order: 1 }],
  items: [
    {
      id: ITEM,
      category_id: "c1",
      name_en: "Tea",
      name_ar: "شاي",
      description: "",
      price: 5,
      sale_price: 4.5,
      image_url: "",
      available: true,
      featured: false,
      sort_order: 1,
    },
    {
      id: ITEM2,
      category_id: "c1",
      name_en: "Burger",
      name_ar: "برغر",
      description: null,
      price: 12,
      sale_price: 10,
      image_url: null,
      available: true,
      featured: false,
      options: [
        { id: OPT, kind: "ingredient", nameAr: "بصل", nameEn: "Onion", price: 0, defaultOn: true },
        { id: OPT2, kind: "topping", nameAr: "جبنة", price: 1.5, defaultOn: false },
      ],
    },
  ],
  payment_types: [{ id: TYPE, name_en: "Card", name_ar: "بطاقة" }],
};

describe("GET /api/guest/menu", () => {
  it("returns the cafe, table and menu in camelCase, cached briefly at the edge", async () => {
    const calls = mockSupabase(() => ({ body: menuRow }));
    const res = await menu.GET(get(`/api/guest/menu?slug=${SLUG}`));
    expect(res.status).toBe(200);
    expect(res.headers.get("Cache-Control")).toBe("public, s-maxage=60, stale-while-revalidate=300");
    const body = await json(res);
    expect(body.ok).toBe(true);
    expect(body.data).toMatchObject({
      // No menu_layout from a database before that migration: the default list.
      cafe: { name: "Akakus", headerColor: "#1B3A4B", backgroundColor: "", serviceChargeRate: 0.1, menuLayout: "list" },
      table: { number: "4" },
      categories: [{ id: "c1", nameEn: "Drinks", nameAr: "مشروبات" }],
      items: [
        { id: ITEM, nameAr: "شاي", price: 5, salePrice: 4.5, available: true, options: [] },
        {
          id: ITEM2,
          description: "",
          options: [
            { id: OPT, kind: "ingredient", nameAr: "بصل", nameEn: "Onion", price: 0, defaultOn: true },
            { id: OPT2, kind: "topping", nameAr: "جبنة", nameEn: "", price: 1.5, defaultOn: false },
          ],
        },
      ],
      paymentTypes: [{ id: TYPE, nameEn: "Card" }],
    });
    expect(calls).toEqual([expect.objectContaining({ name: "guest_menu", args: { p_qr_slug: SLUG } })]);
  });

  it("passes the cafe's menu design through, and treats an unknown one as the list", async () => {
    for (const [sent, got] of [["grid", "grid"], ["list", "list"], ["carousel", "list"]]) {
      mockSupabase(() => ({ body: { ...menuRow, cafe: { ...menuRow.cafe, menu_layout: sent } } }));
      const body = await json(await menu.GET(get(`/api/guest/menu?slug=${SLUG}`)));
      expect(body.data).toMatchObject({ cafe: { menuLayout: got } });
    }
  });

  it("refuses an option of an unknown kind instead of guessing", async () => {
    const odd = { ...menuRow, items: [{ ...menuRow.items[1], options: [{ id: OPT, kind: "sauce", nameEn: "X", price: 0, defaultOn: false }] }] };
    mockSupabase(() => ({ body: odd }));
    expect((await menu.GET(get(`/api/guest/menu?slug=${SLUG}`))).status).toBe(500);
  });

  it("accepts a numeric cache stamp and nothing else", async () => {
    mockSupabase(() => ({ body: menuRow }));
    expect((await menu.GET(get(`/api/guest/menu?slug=${SLUG}&v=1728640000000`))).status).toBe(200);
    expect((await menu.GET(get(`/api/guest/menu?slug=${SLUG}&v=abc`))).status).toBe(400);
    expect((await menu.GET(get(`/api/guest/menu?slug=${SLUG}&restaurant_id=x`))).status).toBe(400);
  });

  it("failures are never cached", async () => {
    mockSupabase(() => ({ body: { ok: false, error: "table not found" } }));
    const res = await menu.GET(get(`/api/guest/menu?slug=${SLUG}`));
    expect(res.headers.get("Cache-Control")).toBe("no-store");
  });
});

describe("GET /api/guest/status", () => {
  it("reports ordering open and the location rule", async () => {
    mockSupabase(() => ({ body: { ok: true, ordering_open: false, location: { enabled: true, radius_m: 30 } } }));
    const res = await status.GET(get(`/api/guest/status?slug=${SLUG}`));
    expect(res.headers.get("Cache-Control")).toBe("no-store");
    expect((await json(res)).data).toEqual({ orderingOpen: false, location: { enabled: true, radiusM: 30 } });
  });
});

describe("POST /api/guest/location", () => {
  it("passes the position and returns the verdict", async () => {
    const calls = mockSupabase(() => ({ body: { enabled: true, radius_m: 30, status: "too_far" } }));
    const res = await location.POST(post("/api/guest/location", { slug: SLUG, lat: 32.9, lng: 13.18, accuracy: 12 }));
    expect((await json(res)).data).toEqual({ enabled: true, radiusM: 30, status: "too_far" });
    expect(calls[0]).toMatchObject({
      name: "guest_location_rule",
      args: { p_qr_slug: SLUG, p_lat: 32.9, p_lng: 13.18, p_accuracy_m: 12 },
    });
  });

  it("returns no verdict when the cafe has no location check", async () => {
    mockSupabase(() => ({ body: { enabled: false, radius_m: 100 } }));
    const res = await location.POST(post("/api/guest/location", { slug: SLUG, lat: 1, lng: 2 }));
    expect((await json(res)).data).toEqual({ enabled: false, radiusM: 100, status: null });
  });

  it("refuses impossible coordinates", async () => {
    const calls = mockSupabase(() => ({ body: {} }));
    for (const body of [
      { slug: SLUG, lat: 91, lng: 0 },
      { slug: SLUG, lat: 0, lng: -181 },
      { slug: SLUG, lat: "32", lng: 13 },
      { slug: SLUG, lat: 0, lng: 0, accuracy: -1 },
      { slug: SLUG },
    ]) {
      expect((await location.POST(post("/api/guest/location", body))).status).toBe(400);
    }
    expect(calls).toHaveLength(0);
  });
});

describe("POST /api/guest/order", () => {
  const body = (extra: Record<string, unknown> = {}) => ({ slug: SLUG, lines: [{ menuItemId: ITEM, qty: 2 }], ...extra });

  it("sends dish ids and quantities only, always as dine-in", async () => {
    const calls = mockSupabase(() => ({ body: { ok: true, order_id: "o1", round: 2, service_type: "dine_in" } }));
    const res = await order.POST(post("/api/guest/order", body({ lat: 32.9, lng: 13.18, accuracy: 20 })));
    expect(res.status).toBe(200);
    expect((await json(res)).data).toEqual({ orderId: "o1", round: 2 });
    expect(calls).toHaveLength(1);
    expect(calls[0]).toMatchObject({
      name: "send_table_cart",
      args: {
        p_qr_slug: SLUG,
        p_lines: [{ menu_item_id: ITEM, qty: 2 }],
        p_service_type: "dine_in",
        p_lat: 32.9,
        p_lng: 13.18,
        p_accuracy_m: 20,
      },
    });
  });

  it("passes the options that are on through to the database", async () => {
    const calls = mockSupabase(() => ({ body: { ok: true, order_id: "o1", round: 1 } }));
    const lines = [
      { menuItemId: ITEM2, qty: 1, on: [OPT2] },
      { menuItemId: ITEM2, qty: 2, on: [] },
      { menuItemId: ITEM, qty: 1 },
    ];
    expect((await order.POST(post("/api/guest/order", { slug: SLUG, lines }))).status).toBe(200);
    expect(calls[0].args).toMatchObject({
      p_lines: [
        { menu_item_id: ITEM2, qty: 1, on: [OPT2] },
        { menu_item_id: ITEM2, qty: 2, on: [] },
        { menu_item_id: ITEM, qty: 1 },
      ],
    });
    expect((calls[0].args as { p_lines: unknown[] }).p_lines[2]).not.toHaveProperty("on");
  });

  it("refuses bad option lists before the database", async () => {
    const calls = mockSupabase(() => ({ body: {} }));
    for (const on of [["not-a-uuid"], [OPT, OPT], OPT, [1], Array.from({ length: 41 }, (_, i) => `00000000-0000-4000-8000-${String(i).padStart(12, "0")}`)]) {
      expect((await order.POST(post("/api/guest/order", { slug: SLUG, lines: [{ menuItemId: ITEM2, qty: 1, on }] }))).status).toBe(400);
    }
    expect(calls).toHaveLength(0);
  });

  it("refuses a price, total or service type sent by the phone (price tampering)", async () => {
    const calls = mockSupabase(() => ({ body: { ok: true, order_id: "o1", round: 1 } }));
    for (const tampered of [
      { slug: SLUG, lines: [{ menuItemId: ITEM, qty: 1, unitPrice: 0.001 }] },
      { slug: SLUG, lines: [{ menuItemId: ITEM, qty: 1, price: 0 }] },
      { slug: SLUG, lines: [{ menuItemId: ITEM, qty: 1, on: [OPT], extras: [{ id: OPT, price: 0 }] }] },
      body({ total: 0 }),
      body({ serviceType: "takeout" }),
      body({ restaurantId: "other-cafe" }),
    ]) {
      const res = await order.POST(post("/api/guest/order", tampered));
      expect(res.status).toBe(400);
    }
    expect(calls).toHaveLength(0);
  });

  it("refuses bad quantities and line counts before the database", async () => {
    const calls = mockSupabase(() => ({ body: {} }));
    const lines = (n: number) => Array.from({ length: n }, () => ({ menuItemId: ITEM, qty: 1 }));
    for (const bad of [
      { slug: SLUG, lines: [] },
      { slug: SLUG, lines: lines(101) },
      { slug: SLUG, lines: [{ menuItemId: ITEM, qty: 0 }] },
      { slug: SLUG, lines: [{ menuItemId: ITEM, qty: 100 }] },
      { slug: SLUG, lines: [{ menuItemId: ITEM, qty: 1.5 }] },
      { slug: SLUG, lines: [{ menuItemId: "not-a-uuid", qty: 1 }] },
      body({ lat: 32.9 }),
    ]) {
      expect((await order.POST(post("/api/guest/order", bad))).status).toBe(400);
    }
    expect(calls).toHaveLength(0);
    mockSupabase(() => ({ body: { ok: true, order_id: "o1", round: 1 } }));
    expect((await order.POST(post("/api/guest/order", { slug: SLUG, lines: lines(100) }))).status).toBe(200);
  });

  it("names sold-out or switched-off dishes", async () => {
    mockSupabase(() => ({ body: { ok: false, error: "items_unavailable", items: ["Tea", "Cake"] } }));
    const res = await order.POST(post("/api/guest/order", body()));
    expect(res.status).toBe(409);
    expect((await json(res)).error).toEqual({
      code: "items_unavailable",
      message: "Some dishes are no longer available.",
      items: ["Tea", "Cake"],
    });
  });

  it("answers cashier_offline when the cafe needs a cashier and none is online", async () => {
    mockSupabase(() => CASHIER_OFFLINE);
    const res = await order.POST(post("/api/guest/order", body()));
    expect(res.status).toBe(409);
    expect((await json(res)).error?.code).toBe("cashier_offline");
  });

  it("answers location_required or too_far outside the cafe", async () => {
    mockSupabase(() => ({ body: { ok: false, error: "location_required" } }));
    let res = await order.POST(post("/api/guest/order", body()));
    expect(res.status).toBe(403);
    expect((await json(res)).error?.code).toBe("location_required");
    mockSupabase(() => ({ body: { ok: false, error: "too_far" } }));
    res = await order.POST(post("/api/guest/order", body({ lat: 0, lng: 0 })));
    expect((await json(res)).error?.code).toBe("too_far");
  });

  it("a dish from another cafe is dropped by the database, so the order is empty", async () => {
    mockSupabase(() => ({ body: { ok: false, error: "cart is empty" } }));
    const res = await order.POST(post("/api/guest/order", body()));
    expect(res.status).toBe(400);
    expect((await json(res)).error?.code).toBe("cart_empty");
  });

  it("maps the database's own quantity and line limits", async () => {
    mockSupabase(() => ({ body: { ok: false, error: "qty_too_large" } }));
    expect((await json(await order.POST(post("/api/guest/order", body())))).error?.code).toBe("qty_too_large");
    mockSupabase(() => ({ body: { ok: false, error: "too_many_lines" } }));
    expect((await json(await order.POST(post("/api/guest/order", body())))).error?.code).toBe("bad_request");
  });
});

describe("GET /api/guest/tab", () => {
  it("returns the open order with its lines", async () => {
    mockSupabase(() => ({
      body: {
        ok: true,
        table: { number: "4", status: "dining" },
        order: {
          id: "o1",
          status: "preparing",
          created_at: "2026-10-11T08:00:00+00:00",
          order_number: 12,
          service_type: "dine_in",
          awaiting_confirmation: false,
          refusal_notice: "",
          payment_type_id: null,
          lines: [
            { id: "l1", menu_item_id: ITEM, name: "Tea", qty: 2, unit_price: 4.5, list_unit_price: 5, round: 1 },
            {
              id: "l2",
              menu_item_id: ITEM2,
              name: "Burger",
              qty: 1,
              unit_price: 11.5,
              list_unit_price: 13.5,
              round: 1,
              choices: [
                { id: OPT, nameAr: "بصل", nameEn: "Onion", on: false, price: 0 },
                { id: OPT2, nameAr: "جبنة", nameEn: null, on: true, price: "1.5" },
              ],
            },
          ],
        },
      },
    }));
    const res = await tab.GET(get(`/api/guest/tab?slug=${SLUG}`));
    expect((await json(res)).data).toEqual({
      table: { number: "4", status: "dining" },
      order: {
        id: "o1",
        status: "preparing",
        createdAt: "2026-10-11T08:00:00+00:00",
        orderNumber: 12,
        awaitingConfirmation: false,
        refusalNotice: "",
        paymentTypeId: null,
        lines: [
          { id: "l1", menuItemId: ITEM, name: "Tea", qty: 2, unitPrice: 4.5, listUnitPrice: 5, round: 1, choices: [] },
          {
            id: "l2",
            menuItemId: ITEM2,
            name: "Burger",
            qty: 1,
            unitPrice: 11.5,
            listUnitPrice: 13.5,
            round: 1,
            choices: [
              { id: OPT, nameAr: "بصل", nameEn: "Onion", on: false, price: 0 },
              { id: OPT2, nameAr: "جبنة", nameEn: "", on: true, price: 1.5 },
            ],
          },
        ],
      },
    });
  });

  it("returns a null order when nothing is open", async () => {
    mockSupabase(() => ({ body: { ok: true, table: { number: "4", status: "free" }, order: null } }));
    expect((await json(await tab.GET(get(`/api/guest/tab?slug=${SLUG}`)))).data).toEqual({
      table: { number: "4", status: "free" },
      order: null,
    });
  });
});

describe("POST /api/guest/call-staff", () => {
  it("confirms the call (a repeat tap re-uses the open one)", async () => {
    const calls = mockSupabase(() => ({ body: { ok: true, reused: true } }));
    const res = await callStaff.POST(post("/api/guest/call-staff", { slug: SLUG }));
    expect((await json(res)).data).toEqual({ done: true });
    expect(calls[0].name).toBe("guest_call_staff");
  });

  it("answers cashier_offline", async () => {
    mockSupabase(() => ({ body: { ok: false, error: "cashier_offline" } }));
    expect((await json(await callStaff.POST(post("/api/guest/call-staff", { slug: SLUG })))).error?.code).toBe(
      "cashier_offline",
    );
  });
});

describe("POST /api/guest/bill", () => {
  it("asks for the bill", async () => {
    const calls = mockSupabase(() => ({ body: { ok: true } }));
    expect((await bill.POST(post("/api/guest/bill", { slug: SLUG }))).status).toBe(200);
    expect(calls[0]).toMatchObject({ name: "request_bill", args: { p_qr_slug: SLUG, p_table_id: null } });
  });

  it("answers no_open_bill and cashier_offline", async () => {
    mockSupabase(() => ({ body: { ok: false, error: "no open bill" } }));
    expect((await json(await bill.POST(post("/api/guest/bill", { slug: SLUG })))).error?.code).toBe("no_open_bill");
    mockSupabase(() => CASHIER_OFFLINE);
    expect((await json(await bill.POST(post("/api/guest/bill", { slug: SLUG })))).error?.code).toBe("cashier_offline");
  });

  it("answers not_served and payment_type_required", async () => {
    mockSupabase(() => ({ body: { ok: false, error: "not served" } }));
    expect((await json(await bill.POST(post("/api/guest/bill", { slug: SLUG })))).error?.code).toBe("not_served");
    mockSupabase(() => ({ body: { ok: false, error: "payment type required" } }));
    expect((await json(await bill.POST(post("/api/guest/bill", { slug: SLUG })))).error?.code).toBe(
      "payment_type_required",
    );
  });
});

describe("POST /api/guest/payment-type", () => {
  it("sets the payment method", async () => {
    const calls = mockSupabase(() => ({ body: { ok: true } }));
    expect((await paymentType.POST(post("/api/guest/payment-type", { slug: SLUG, typeId: TYPE }))).status).toBe(200);
    expect(calls[0]).toMatchObject({ name: "set_table_payment_type", args: { p_qr_slug: SLUG, p_type_id: TYPE } });
  });

  it("refuses another cafe's or a disabled payment type", async () => {
    mockSupabase(() => ({ body: { ok: false, error: "unknown payment type" } }));
    const res = await paymentType.POST(post("/api/guest/payment-type", { slug: SLUG, typeId: TYPE }));
    expect(res.status).toBe(400);
    expect((await json(res)).error?.code).toBe("bad_request");
  });

  it("refuses a malformed id", async () => {
    const calls = mockSupabase(() => ({ body: { ok: true } }));
    expect((await paymentType.POST(post("/api/guest/payment-type", { slug: SLUG, typeId: "1" }))).status).toBe(400);
    expect(calls).toHaveLength(0);
  });
});

describe("POST /api/guest/refusal", () => {
  it("clears the refusal notice in one call", async () => {
    const calls = mockSupabase(() => ({ body: { ok: true } }));
    expect((await refusal.POST(post("/api/guest/refusal", { slug: SLUG }))).status).toBe(200);
    expect(calls.map((c) => c.name)).toEqual(["guest_confirm_refusal"]);
  });

  it("answers cashier_offline and no_open_bill", async () => {
    mockSupabase(() => ({ body: { ok: false, error: "cashier_offline" } }));
    expect((await json(await refusal.POST(post("/api/guest/refusal", { slug: SLUG })))).error?.code).toBe(
      "cashier_offline",
    );
    mockSupabase(() => ({ body: { ok: false, error: "no open bill" } }));
    expect((await json(await refusal.POST(post("/api/guest/refusal", { slug: SLUG })))).error?.code).toBe(
      "no_open_bill",
    );
  });
});

describe("POST /api/guest/visit", () => {
  const VISITOR = "0b1f4c52-6a1e-4d0b-9c5e-3f7a2d9e8c11";

  it("counts the visit with the slug and the browser's random id, and nothing else", async () => {
    const calls = mockSupabase(() => ({ body: { ok: true } }));
    const res = await visit.POST(post("/api/guest/visit", { slug: SLUG, visitor: VISITOR }));
    expect(res.status).toBe(200);
    expect((await json(res)).data).toEqual({ done: true });
    expect(calls).toEqual([
      expect.objectContaining({ name: "guest_record_visit", args: { p_qr_slug: SLUG, p_visitor: VISITOR } }),
    ]);
  });

  it("never passes the visitor's IP or user agent to the database", async () => {
    const calls = mockSupabase(() => ({ body: { ok: true } }));
    await visit.POST(post("/api/guest/visit", { slug: SLUG, visitor: VISITOR }, "203.0.113.9"));
    expect(JSON.stringify(calls[0].args)).not.toContain("203.0.113.9");
    expect(Object.keys(calls[0].args).sort()).toEqual(["p_qr_slug", "p_visitor"]);
  });

  it("refuses a visitor id that is missing, too short, too long or has other characters", async () => {
    const calls = mockSupabase(() => ({ body: { ok: true } }));
    for (const bad of [undefined, "", "short", "x".repeat(65), "has spaces in it 12345", "semi;colon-0123456789"]) {
      const res = await visit.POST(post("/api/guest/visit", { slug: SLUG, visitor: bad }));
      expect(res.status, String(bad)).toBe(400);
    }
    expect(calls).toHaveLength(0);
  });
});

describe("POST /api/guest/claim", () => {
  const VISITOR = "0b1f4c52-6a1e-4d0b-9c5e-3f7a2d9e8c11";

  it("asks the database whether this phone owns the table and returns only the role", async () => {
    const calls = mockSupabase(() => ({ body: { ok: true, role: "viewer", extra: "never shown" } }));
    const res = await claim.POST(post("/api/guest/claim", { slug: SLUG, visitor: VISITOR }));
    expect(res.status).toBe(200);
    expect((await json(res)).data).toEqual({ role: "viewer" });
    expect(calls).toEqual([
      expect.objectContaining({ name: "guest_claim_table", args: { p_qr_slug: SLUG, p_visitor: VISITOR, p_lat: null, p_lng: null, p_accuracy_m: null } }),
    ]);
  });

  it("refuses a visitor id that is missing or malformed without calling the database", async () => {
    const calls = mockSupabase(() => ({ body: { ok: true, role: "owner" } }));
    for (const bad of [undefined, "", "short", "has spaces in it 12345"]) {
      const res = await claim.POST(post("/api/guest/claim", { slug: SLUG, visitor: bad }));
      expect(res.status, String(bad)).toBe(400);
    }
    expect(calls).toHaveLength(0);
  });
});

describe("POST /api/guest/order with a table owner", () => {
  const VISITOR = "0b1f4c52-6a1e-4d0b-9c5e-3f7a2d9e8c11";
  const lines = [{ menuItemId: ITEM, qty: 1 }];

  it("tells the database which phone is ordering through the x-guest-visitor header, not an argument", async () => {
    const calls = mockSupabase(() => ({ body: { ok: true, order_id: "o1", round: 1 } }));
    const res = await order.POST(post("/api/guest/order", { slug: SLUG, lines, visitor: VISITOR }));
    expect(res.status).toBe(200);
    expect(calls[0].headers.get("x-guest-visitor")).toBe(VISITOR);
    expect(JSON.stringify(calls[0].args)).not.toContain(VISITOR);
  });

  it("sends no header when the phone gave no id", async () => {
    const calls = mockSupabase(() => ({ body: { ok: true, order_id: "o1", round: 1 } }));
    await order.POST(post("/api/guest/order", { slug: SLUG, lines }));
    expect(calls[0].headers.get("x-guest-visitor")).toBeNull();
  });

  it("answers 403 not_table_owner when the database says another phone owns the table", async () => {
    mockSupabase(() => ({ status: 400, body: { message: "not_table_owner" } }));
    const res = await order.POST(post("/api/guest/order", { slug: SLUG, lines, visitor: VISITOR }));
    expect(res.status).toBe(403);
    expect((await json(res)).error?.code).toBe("not_table_owner");
  });

  it("refuses a malformed visitor id", async () => {
    const calls = mockSupabase(() => ({ body: { ok: true, order_id: "o1", round: 1 } }));
    const res = await order.POST(post("/api/guest/order", { slug: SLUG, lines, visitor: "bad id!" }));
    expect(res.status).toBe(400);
    expect(calls).toHaveLength(0);
  });
});
