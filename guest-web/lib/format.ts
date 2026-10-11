import type { Lang } from "./i18n";
import type { Category, MenuItem, PaymentType } from "./types";

const digits = new Intl.NumberFormat("en-US", { minimumFractionDigits: 3, maximumFractionDigits: 3 });

// `#,##0.000 LYD`, or `د.ل` in Arabic, as the Flutter app shows money (lib/core/money.dart).
export function money(value: number, lang: Lang): string {
  const amount = digits.format(value);
  return lang === "ar" ? `${amount} د.ل` : `${amount} LYD`;
}

// Tripoli is UTC+2 all year (lib/core/money.dart toTripoli). HH:mm.
export function tripoliTime(iso: string): string {
  const instant = new Date(iso);
  if (Number.isNaN(instant.getTime())) return "";
  const local = new Date(instant.getTime() + 2 * 60 * 60 * 1000);
  return `${String(local.getUTCHours()).padStart(2, "0")}:${String(local.getUTCMinutes()).padStart(2, "0")}`;
}

// `#012`: the spoken daily number, at least three digits (lib/core/money.dart formatOrderNumber).
export function orderNumber(sequence: number | null): string {
  if (sequence === null) return "—";
  const text = String(sequence);
  return `#${text.length >= 3 ? text : text.padStart(3, "0")}`;
}

// Arabic name lives in name_it (lib/models/models.dart displayName).
export function dishName(item: Pick<MenuItem, "nameEn" | "nameAr">, lang: Lang): string {
  if (lang === "en" || !item.nameAr) return item.nameEn || item.nameAr;
  return item.nameAr;
}

export function categoryName(category: Category, lang: Lang): string {
  return lang === "ar" ? category.nameAr : category.nameEn;
}

export function paymentTypeName(type: PaymentType, lang: Lang): string {
  return lang === "ar" && type.nameAr ? type.nameAr : type.nameEn;
}

export function hasDiscount(item: Pick<MenuItem, "price" | "salePrice">): boolean {
  return item.salePrice < item.price;
}

// Same rounding as the bill on the cashier: three decimals for display, sums in fils.
export function lineTotal(unitPrice: number, qty: number): number {
  return Math.round(unitPrice * qty * 1000) / 1000;
}
