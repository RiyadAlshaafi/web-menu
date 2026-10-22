// The only error codes a guest can receive. Database texts never reach the browser: each RPC
// result is mapped onto one of these, and anything unexpected becomes server_error.
export const ERROR_CODES = [
  "bad_request",
  "rate_limited",
  "table_not_found",
  "cashier_offline",
  "location_required",
  "too_far",
  "items_unavailable",
  "qty_too_large",
  "cart_empty",
  "no_open_bill",
  "not_served",
  "not_table_owner",
  "server_error",
] as const;

export type ErrorCode = (typeof ERROR_CODES)[number];

export const ERROR_STATUS: Record<ErrorCode, number> = {
  bad_request: 400,
  rate_limited: 429,
  table_not_found: 404,
  cashier_offline: 409,
  location_required: 403,
  too_far: 403,
  items_unavailable: 409,
  qty_too_large: 400,
  cart_empty: 400,
  no_open_bill: 409,
  not_served: 409,
  not_table_owner: 403,
  server_error: 500,
};

// Plain English, for logs and API clients. The page shows its own translated text per code.
export const ERROR_MESSAGE: Record<ErrorCode, string> = {
  bad_request: "The request was not valid.",
  rate_limited: "Too many requests. Try again shortly.",
  table_not_found: "This QR code doesn't match a table.",
  cashier_offline: "Ordering is paused until a cashier is online.",
  location_required: "Location is needed to order from this table.",
  too_far: "You need to be at the cafe to order.",
  items_unavailable: "Some dishes are no longer available.",
  qty_too_large: "Too many of one dish.",
  cart_empty: "The order is empty.",
  no_open_bill: "There is no open bill for this table.",
  not_served: "The bill can be requested once the order is served.",
  not_table_owner: "Another guest at this table is ordering.",
  server_error: "Something went wrong.",
};

// Error strings the guest RPCs return in { ok: false, error } or raise, mapped to a code.
const DB_ERRORS: Record<string, ErrorCode> = {
  "table not found": "table_not_found",
  cashier_offline: "cashier_offline",
  location_required: "location_required",
  too_far: "too_far",
  items_unavailable: "items_unavailable",
  qty_too_large: "qty_too_large",
  too_many_lines: "bad_request",
  "cart is empty": "cart_empty",
  "no open bill": "no_open_bill",
  not_table_owner: "not_table_owner",
  "unknown payment type": "bad_request",
};

export function codeForDbError(text: unknown): ErrorCode {
  return (typeof text === "string" && DB_ERRORS[text]) || "server_error";
}
