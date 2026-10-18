// The guest's own cart (decision Q2: per phone), kept in this browser only. Only dish ids, the
// options that are on and quantities are stored; prices always come from the latest menu.
import type { DishOption, LineChoice, MenuItem } from "./types";

export const MAX_QTY = 99;
const MAX_LINES = 100;
const MAX_OPTIONS = 40;
const UUID = /^[0-9a-f-]{36}$/i;

// One line of the cart: a dish with one set of choices. `on` is the full set of option ids that
// are on, in the dish's option order.
export type CartEntry = { itemId: string; on: string[]; qty: number };

// Keyed by lineKey(): the same dish with different choices is a separate line.
export type Cart = Record<string, CartEntry>;

export function cartKey(slug: string): string {
  return `tawla-cart:${slug}`;
}

export function defaultOn(item: Pick<MenuItem, "options">): string[] {
  return item.options.filter((o) => o.defaultOn).map((o) => o.id);
}

// Only option ids the dish has, once each, in the dish's own order.
export function normalizeOn(item: Pick<MenuItem, "options">, on: readonly string[]): string[] {
  const chosen = new Set(on);
  return item.options.filter((o) => chosen.has(o.id)).map((o) => o.id);
}

// The options whose state differs from the dish defaults.
function changed(item: Pick<MenuItem, "options">, on: readonly string[]): DishOption[] {
  const chosen = new Set(on);
  return item.options.filter((o) => o.defaultOn !== chosen.has(o.id));
}

// The dish id for a dish as it comes, else the dish id plus the sorted ids that differ.
export function lineKey(item: Pick<MenuItem, "id" | "options">, on: readonly string[]): string {
  const diff = changed(item, on).map((o) => o.id).sort();
  return diff.length === 0 ? item.id : `${item.id}|${diff.join(",")}`;
}

// Only an option that is off by default and turned on is charged; the dish discount never
// applies to it.
export function linePrice(item: Pick<MenuItem, "salePrice" | "options">, on: readonly string[]): number {
  const chosen = new Set(on);
  const extra = item.options.filter((o) => !o.defaultOn && chosen.has(o.id)).reduce((sum, o) => sum + o.price, 0);
  return Math.round((item.salePrice + extra) * 1000) / 1000;
}

// What a line changes, for "– No onion" / "+ Cheese 0.500" under the dish; price is what it adds.
export function lineChoices(item: Pick<MenuItem, "options">, on: readonly string[]): LineChoice[] {
  return changed(item, on).map((o) => ({
    id: o.id,
    nameEn: o.nameEn,
    nameAr: o.nameAr,
    on: !o.defaultOn,
    price: o.defaultOn ? 0 : o.price,
  }));
}

export function setQty(cart: Cart, key: string, qty: number): Cart {
  const entry = cart[key];
  if (!entry) return cart;
  const next = { ...cart };
  const clamped = Math.min(MAX_QTY, Math.max(0, Math.floor(qty)));
  if (clamped === 0) delete next[key];
  else next[key] = { ...entry, qty: clamped };
  return next;
}

// Adds to the line with the same choices, or starts a new one.
export function add(cart: Cart, item: Pick<MenuItem, "id" | "options">, on: readonly string[] = defaultOn(item), qty = 1): Cart {
  const chosen = normalizeOn(item, on);
  const key = lineKey(item, chosen);
  const current = cart[key]?.qty ?? 0;
  const clamped = Math.min(MAX_QTY, Math.max(0, Math.floor(current + qty)));
  const next = { ...cart };
  if (clamped === 0) delete next[key];
  else next[key] = { itemId: item.id, on: chosen, qty: clamped };
  return next;
}

// How many of a dish are in the cart, whatever the choices.
export function dishQty(cart: Cart, itemId: string): number {
  return Object.values(cart).reduce((sum, entry) => sum + (entry.itemId === itemId ? entry.qty : 0), 0);
}

export type CartLine = { key: string; item: MenuItem; on: string[]; qty: number };

// Lines for dishes that are still on the menu, in menu order. Dishes that disappeared are
// dropped; unavailable ones are kept so the guest sees why the send is refused.
export function cartLines(cart: Cart, items: MenuItem[]): CartLine[] {
  const entries = Object.entries(cart);
  return items.flatMap((item) =>
    entries
      .filter(([, entry]) => entry.itemId === item.id && entry.qty > 0)
      .map(([key, entry]) => ({ key, item, on: normalizeOn(item, entry.on), qty: entry.qty })),
  );
}

export function cartCount(lines: CartLine[]): number {
  return lines.reduce((sum, line) => sum + line.qty, 0);
}

export function cartTotal(lines: CartLine[]): number {
  return Math.round(lines.reduce((sum, line) => sum + linePrice(line.item, line.on) * line.qty, 0) * 1000) / 1000;
}

// Rebuilds the cart against the menu: drops dishes that disappeared and option ids the dish no
// longer has, and merges lines that became the same.
function rebuild(entries: CartEntry[], items: MenuItem[]): Cart {
  const byId = new Map(items.map((i) => [i.id, i]));
  let cart: Cart = {};
  for (const entry of entries) {
    const item = byId.get(entry.itemId);
    if (item && entry.qty > 0) cart = add(cart, item, entry.on, entry.qty);
  }
  return cart;
}

export function prune(cart: Cart, items: MenuItem[]): Cart {
  return rebuild(Object.values(cart), items);
}

function readEntry(key: string, value: unknown, items: MenuItem[]): CartEntry | null {
  // Before dish choices the cart was { dishId: qty }: those are dishes as they come.
  if (typeof value === "number") {
    const item = UUID.test(key) ? items.find((i) => i.id === key) : undefined;
    return item ? { itemId: key, on: defaultOn(item), qty: value } : null;
  }
  if (!value || typeof value !== "object" || Array.isArray(value)) return null;
  const { itemId, on, qty } = value as Record<string, unknown>;
  if (typeof itemId !== "string" || !UUID.test(itemId) || typeof qty !== "number") return null;
  if (!Array.isArray(on) || on.length > MAX_OPTIONS || !on.every((id) => typeof id === "string")) return null;
  return { itemId, on: on as string[], qty };
}

// Needs the menu to read the stored cart: an old-format line takes the dish defaults, and
// anything the menu does not know is dropped.
export function loadCart(storage: Pick<Storage, "getItem"> | null, slug: string, items: MenuItem[]): Cart {
  try {
    const raw = storage?.getItem(cartKey(slug));
    if (!raw) return {};
    const parsed: unknown = JSON.parse(raw);
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) return {};
    const entries = Object.entries(parsed)
      .slice(0, MAX_LINES)
      .map(([key, value]) => readEntry(key, value, items))
      .filter((entry): entry is CartEntry => entry !== null);
    return rebuild(entries, items);
  } catch {
    return {};
  }
}

export function saveCart(storage: Pick<Storage, "setItem" | "removeItem"> | null, slug: string, cart: Cart): void {
  try {
    if (Object.keys(cart).length === 0) storage?.removeItem(cartKey(slug));
    else storage?.setItem(cartKey(slug), JSON.stringify(cart));
  } catch {
    // Private mode or full storage: the cart still works for this page view.
  }
}
