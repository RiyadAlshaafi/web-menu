import { z } from "zod";
import { codeForDbError } from "./errors";
import type { Outcome } from "./handler";
import { callRpc, type RpcName } from "./rpc";
import type { Done, GuestStatus, LocationVerdict, Menu, OrderSent, Tab } from "../types";

// One function per endpoint. Each makes exactly one RPC call and maps its result; RPC output is
// checked against a schema so a database change can't leak unexpected fields to the browser.

const failure = z.object({ ok: z.literal(false), error: z.string(), items: z.array(z.string()).optional() });

async function call<T>(name: RpcName, args: Record<string, unknown>, success: z.ZodType<T>): Promise<Outcome<T>> {
  const result = await callRpc(name, args);
  if (result.kind === "unreachable") return { ok: false, code: "server_error" };
  if (result.kind === "db_error") return { ok: false, code: codeForDbError(result.message) };
  const refused = failure.safeParse(result.body);
  if (refused.success) {
    const code = codeForDbError(refused.data.error);
    if (code === "server_error") console.error(`rpc ${name} refused`, refused.data.error);
    return code === "items_unavailable"
      ? { ok: false, code, items: refused.data.items ?? [] }
      : { ok: false, code };
  }
  const parsed = success.safeParse(result.body);
  if (!parsed.success) {
    console.error(`rpc ${name} returned an unexpected shape`, parsed.error.issues.slice(0, 3));
    return { ok: false, code: "server_error" };
  }
  return { ok: true, data: parsed.data };
}

const text = z.string().nullable().transform((v) => v ?? "");
const money = z.coerce.number();
const optionalText = z.string().nullish().transform((v) => v ?? "");
// Older databases have no options or choices: a missing list means "dish as it comes".
const list = <T extends z.ZodType>(entry: T) => z.array(entry).nullish().transform((v) => v ?? []);

const dishOption = z.object({
  id: z.string(),
  kind: z.enum(["ingredient", "topping"]),
  nameAr: optionalText,
  nameEn: optionalText,
  price: money,
  defaultOn: z.boolean(),
});

const lineChoice = z.object({
  id: z.string(),
  nameAr: optionalText,
  nameEn: optionalText,
  on: z.boolean(),
  price: money,
});

const menuSchema = z
  .object({
    ok: z.literal(true),
    cafe: z.object({
      id: z.string(),
      name: text,
      locale: text,
      logo_url: text,
      header_color: text,
      button_color: text,
      background_color: text,
      service_charge_rate: money,
    }),
    table: z.object({ number: text }),
    categories: z.array(z.object({ id: z.string(), name_en: text, name_ar: text })),
    items: z.array(
      z.object({
        id: z.string(),
        category_id: z.string(),
        name_en: text,
        name_ar: text,
        description: text,
        price: money,
        sale_price: money,
        image_url: text,
        available: z.boolean(),
        featured: z.boolean(),
        options: list(dishOption),
      }),
    ),
    payment_types: z.array(z.object({ id: z.string(), name_en: text, name_ar: text })),
  })
  .transform(
    (m): Menu => ({
      cafe: {
        id: m.cafe.id,
        name: m.cafe.name,
        locale: m.cafe.locale,
        logoUrl: m.cafe.logo_url,
        headerColor: m.cafe.header_color,
        buttonColor: m.cafe.button_color,
        backgroundColor: m.cafe.background_color,
        serviceChargeRate: m.cafe.service_charge_rate,
      },
      table: { number: m.table.number },
      categories: m.categories.map((c) => ({ id: c.id, nameEn: c.name_en, nameAr: c.name_ar })),
      items: m.items.map((i) => ({
        id: i.id,
        categoryId: i.category_id,
        nameEn: i.name_en,
        nameAr: i.name_ar,
        description: i.description,
        price: i.price,
        salePrice: i.sale_price,
        imageUrl: i.image_url,
        available: i.available,
        featured: i.featured,
        options: i.options,
      })),
      paymentTypes: m.payment_types.map((p) => ({ id: p.id, nameEn: p.name_en, nameAr: p.name_ar })),
    }),
  );

const statusSchema = z
  .object({
    ok: z.literal(true),
    ordering_open: z.boolean(),
    location: z.object({ enabled: z.boolean(), radius_m: z.number() }),
  })
  .transform((s): GuestStatus => ({ orderingOpen: s.ordering_open, location: { enabled: s.location.enabled, radiusM: s.location.radius_m } }));

const locationSchema = z
  .object({
    enabled: z.boolean(),
    radius_m: z.number(),
    status: z.enum(["allowed", "too_far", "location_required"]).optional(),
  })
  .transform((l): LocationVerdict => ({ enabled: l.enabled, radiusM: l.radius_m, status: l.status ?? null }));

const orderSchema = z
  .object({ ok: z.literal(true), order_id: z.string(), round: z.number() })
  .transform((o): OrderSent => ({ orderId: o.order_id, round: o.round }));

const tabSchema = z
  .object({
    ok: z.literal(true),
    table: z.object({ number: text, status: text }),
    order: z
      .object({
        id: z.string(),
        status: z.string(),
        created_at: z.string(),
        order_number: z.number().nullable(),
        awaiting_confirmation: z.boolean(),
        refusal_notice: text,
        payment_type_id: z.string().nullable(),
        lines: z.array(
          z.object({
            id: z.string(),
            menu_item_id: z.string().nullable(),
            name: text,
            qty: z.number(),
            unit_price: money,
            list_unit_price: money.nullable(),
            round: z.number(),
            choices: list(lineChoice),
          }),
        ),
      })
      .nullable(),
  })
  .transform(
    (t): Tab => ({
      table: t.table,
      order: t.order && {
        id: t.order.id,
        status: t.order.status,
        createdAt: t.order.created_at,
        orderNumber: t.order.order_number,
        awaitingConfirmation: t.order.awaiting_confirmation,
        refusalNotice: t.order.refusal_notice,
        paymentTypeId: t.order.payment_type_id,
        lines: t.order.lines.map((l) => ({
          id: l.id,
          menuItemId: l.menu_item_id,
          name: l.name,
          qty: l.qty,
          unitPrice: l.unit_price,
          listUnitPrice: l.list_unit_price,
          round: l.round,
          choices: l.choices,
        })),
      },
    }),
  );

const doneSchema = z.object({ ok: z.literal(true) }).transform((): Done => ({ done: true }));

export const guest = {
  menu: (slug: string) => call("guest_menu", { p_qr_slug: slug }, menuSchema),
  status: (slug: string) => call("guest_status", { p_qr_slug: slug }, statusSchema),
  location: (slug: string, lat: number, lng: number, accuracy?: number) =>
    call(
      "guest_location_rule",
      { p_qr_slug: slug, p_lat: lat, p_lng: lng, p_accuracy_m: accuracy ?? null },
      locationSchema,
    ),
  order: (
    slug: string,
    lines: { menuItemId: string; qty: number; on?: string[] }[],
    position: { lat?: number; lng?: number; accuracy?: number },
  ) =>
    call(
      "send_table_cart",
      {
        p_qr_slug: slug,
        // `on` is the full set of option ids that are on; left out, the dish comes as it is.
        p_lines: lines.map((l) => ({ menu_item_id: l.menuItemId, qty: l.qty, ...(l.on ? { on: l.on } : {}) })),
        p_service_type: "dine_in",
        p_lat: position.lat ?? null,
        p_lng: position.lng ?? null,
        p_accuracy_m: position.accuracy ?? null,
      },
      orderSchema,
    ),
  tab: (slug: string) => call("guest_tab", { p_qr_slug: slug }, tabSchema),
  callStaff: (slug: string) => call("guest_call_staff", { p_qr_slug: slug }, doneSchema),
  bill: (slug: string) => call("request_bill", { p_qr_slug: slug, p_table_id: null }, doneSchema),
  paymentType: (slug: string, typeId: string) =>
    call("set_table_payment_type", { p_qr_slug: slug, p_type_id: typeId }, doneSchema),
  refusal: (slug: string) => call("guest_confirm_refusal", { p_qr_slug: slug }, doneSchema),
};
