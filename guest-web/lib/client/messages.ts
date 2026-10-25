import { dishName } from "../format";
import { t, type Lang } from "../i18n";
import type { MenuItem } from "../types";

// The guest-facing text for an API error code. Unknown codes get the generic text, never the
// server's message (inventory §2.14).
export function errorText(
  lang: Lang,
  error: { code: string; items?: string[] },
  items: MenuItem[] = [],
  online = typeof navigator === "undefined" ? true : navigator.onLine,
): string {
  switch (error.code) {
    case "cashier_offline":
      return t(lang, "guestOrderingPaused");
    case "too_far":
      return t(lang, "guestLocationTooFar");
    case "location_required":
      return t(lang, "guestLocationDenied");
    case "items_unavailable": {
      const names = (error.items ?? []).map((name) => {
        const match = items.find((i) => i.nameEn === name || i.nameAr === name);
        return match ? dishName(match, lang) : name;
      });
      return t(lang, "guestItemsUnavailable", { items: names.join(lang === "ar" ? "، " : ", ") });
    }
    case "qty_too_large":
      return t(lang, "guestQtyTooLarge");
    case "rate_limited":
      return t(lang, "errRateLimited");
    case "table_not_found":
      return t(lang, "guestQrInvalid");
    case "no_open_bill":
      return t(lang, "noOrders");
    case "not_served":
      return t(lang, "guestBillAfterServed");
    case "payment_type_required":
      return t(lang, "payChoose");
    case "not_table_owner":
      return t(lang, "guestViewOnly");
    case "network":
      return online ? t(lang, "errGeneric") : t(lang, "errOffline");
    default:
      return t(lang, "errGeneric");
  }
}
