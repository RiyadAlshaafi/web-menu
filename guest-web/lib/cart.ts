// The guest's own cart (decision Q2: per phone), kept in this browser only. Only dish ids and
// quantities are stored; prices always come from the latest menu.
import type { MenuItem } from "./types";

export const MAX_QTY = 99;
export type Cart = Record<string, number>;

export function cartKey(slug: string): string {
  return `tawla-cart:${slug}`;
}

export function setQty(cart: Cart, itemId: string, qty: number): Cart {
  const next = { ...cart };
  const clamped = Math.min(MAX_QTY, Math.max(0, Math.floor(qty)));
  if (clamped === 0) delete next[itemId];
  else next[itemId] = clamped;
  return next;
}

export function add(cart: Cart, itemId: string, qty = 1): Cart {
  return setQty(cart, itemId, (cart[itemId] ?? 0) + qty);
}

export type CartLine = { item: MenuItem; qty: number };

// Lines for dishes that are still on the menu, in menu order. Dishes that disappeared are
// dropped; unavailable ones are kept so the guest sees why the send is refused.
export function cartLines(cart: Cart, items: MenuItem[]): CartLine[] {
  return items.filter((item) => (cart[item.id] ?? 0) > 0).map((item) => ({ item, qty: cart[item.id] }));
}

export function cartCount(lines: CartLine[]): number {
  return lines.reduce((sum, line) => sum + line.qty, 0);
}

export function cartTotal(lines: CartLine[]): number {
  return Math.round(lines.reduce((sum, line) => sum + line.item.salePrice * line.qty, 0) * 1000) / 1000;
}

export function prune(cart: Cart, items: MenuItem[]): Cart {
  const ids = new Set(items.map((i) => i.id));
  return Object.fromEntries(Object.entries(cart).filter(([id, qty]) => ids.has(id) && qty > 0));
}

export function loadCart(storage: Pick<Storage, "getItem"> | null, slug: string): Cart {
  try {
    const raw = storage?.getItem(cartKey(slug));
    if (!raw) return {};
    const parsed: unknown = JSON.parse(raw);
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) return {};
    let cart: Cart = {};
    for (const [id, qty] of Object.entries(parsed)) {
      if (typeof qty === "number" && /^[0-9a-f-]{36}$/i.test(id)) cart = setQty(cart, id, qty);
    }
    return cart;
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
