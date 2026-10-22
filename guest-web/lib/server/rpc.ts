import { supabaseEnv } from "./env";

// The guest functions this app may call. Anything else is a type error.
export type RpcName =
  | "guest_menu"
  | "guest_status"
  | "guest_location_rule"
  | "send_table_cart"
  | "guest_tab"
  | "guest_call_staff"
  | "request_bill"
  | "set_table_payment_type"
  | "guest_confirm_refusal"
  | "guest_record_visit"
  | "guest_claim_table";

export type RpcResult =
  | { kind: "ok"; body: unknown }
  // A raised Postgres exception (for example cashier_offline from a trigger). `message` is for
  // mapping and logs only; it is never sent to the browser.
  | { kind: "db_error"; message: string }
  | { kind: "unreachable" };

const TIMEOUT_MS = 8000;

// One PostgREST call with the anon key: every guest function takes the QR slug as an argument,
// so nothing else identifies the table. `visitor` is the guest browser's own random id; the
// database reads it from x-guest-visitor to tell the phone that owns the table from the others.
export async function callRpc(name: RpcName, args: Record<string, unknown>, visitor?: string): Promise<RpcResult> {
  const { url, key } = supabaseEnv();
  const headers: Record<string, string> = {
    apikey: key,
    "Content-Type": "application/json",
    Accept: "application/json",
  };
  if (visitor) headers["x-guest-visitor"] = visitor;
  // Legacy anon keys are JWTs and go in Authorization too; publishable keys only in apikey.
  if (key.split(".").length === 3) headers.Authorization = `Bearer ${key}`;
  let response: Response;
  try {
    response = await fetch(`${url}/rest/v1/rpc/${name}`, {
      method: "POST",
      headers,
      body: JSON.stringify(args),
      cache: "no-store",
      signal: AbortSignal.timeout(TIMEOUT_MS),
    });
  } catch (error) {
    console.error(`rpc ${name} unreachable`, error);
    return { kind: "unreachable" };
  }
  const text = await response.text();
  let body: unknown = null;
  try {
    body = text ? JSON.parse(text) : null;
  } catch {
    body = null;
  }
  if (response.ok) return { kind: "ok", body };
  const message =
    body && typeof body === "object" && "message" in body && typeof body.message === "string" ? body.message : "";
  console.error(`rpc ${name} failed with ${response.status}`, message);
  return { kind: "db_error", message };
}
