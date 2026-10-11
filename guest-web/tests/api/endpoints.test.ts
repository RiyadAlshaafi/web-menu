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
  ],
  payment_types: [{ id: TYPE, name_en: "Card", name_ar: "بطاقة" }],
};

describe("GET /api/guest/menu", () => {
  it("returns the cafe, table and menu in camelCase, cached briefly at the edge", async () => {
    const calls = mockSupabase(() => ({ body: menuRow }));
    const res = await menu.GET(get(`/api/guest/menu?slug=${SLUG}`));
    expect(res.status).toBe(200);
    expect(res.headers.get("Cache-Control")).toBe("public, s-maxage=5, stale-while-revalidate=30");
    const body = await json(res);
    expect(body.ok).toBe(true);
    expect(body.data).toMatchObject({
      cafe: { name: "Akakus", headerColor: "#1B3A4B", backgroundColor: "", serviceChargeRate: 0.1 },
      table: { number: "4" },
      categories: [{ id: "c1", nameEn: "Drinks", nameAr: "مشروبات" }],
      items: [{ id: ITEM, nameAr: "شاي", price: 5, salePrice: 4.5, available: true }],
      paymentTypes: [{ id: TYPE, nameEn: "Card" }],
    });
    expect(calls).toEqual([expect.objectContaining({ name: "guest_menu", args: { p_qr_slug: SLUG } })]);
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

  it("refuses a price, total or service type sent by the phone (price tampering)", async () => {
    const calls = mockSupabase(() => ({ body: { ok: true, order_id: "o1", round: 1 } }));
    for (const tampered of [
      { slug: SLUG, lines: [{ menuItemId: ITEM, qty: 1, unitPrice: 0.001 }] },
      { slug: SLUG, lines: [{ menuItemId: ITEM, qty: 1, price: 0 }] },
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
          lines: [{ id: "l1", menu_item_id: ITEM, name: "Tea", qty: 2, unit_price: 4.5, list_unit_price: 5, round: 1 }],
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
        lines: [{ id: "l1", menuItemId: ITEM, name: "Tea", qty: 2, unitPrice: 4.5, listUnitPrice: 5, round: 1 }],
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
  it("confirms the refusal and asks for the bill in one call", async () => {
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
