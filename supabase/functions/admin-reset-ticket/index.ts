// Signs a one-time offline admin reset ticket for the Windows setup (windows/installer/cafe_pos.iss),
// after the seller password check (public.check_dev_access, with its lockout). The Ed25519 private
// key lives only in this function's ADMIN_RESET_PRIVATE_KEY secret (PKCS#8, base64); the app checks
// tickets with the matching public key in lib/data/admin_reset.dart, so nothing in the public code
// or the installer can make a ticket.
//
// POST {"password": "...", "nonce": "<32-128 hex>"} -> {"nonce", "issued", "sig"}
// Deploy with JWT verification off: the setup only has the publishable key.

import { createClient } from "npm:@supabase/supabase-js@2.45.4";

/** Must match adminResetMessage in lib/data/admin_reset.dart. */
export function ticketMessage(nonce: string, issued: string): string {
  return `tawla-admin-reset-v2|${nonce}|${issued}`;
}

const NONCE = /^[0-9a-f]{32,128}$/;

function answer(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });
}

function bytesFromBase64(text: string): Uint8Array {
  return Uint8Array.from(atob(text.trim()), (c) => c.charCodeAt(0));
}

function hex(bytes: Uint8Array): string {
  return Array.from(bytes, (b) => b.toString(16).padStart(2, "0")).join("");
}

let signingKey: Promise<CryptoKey> | undefined;

function key(): Promise<CryptoKey> {
  const secret = Deno.env.get("ADMIN_RESET_PRIVATE_KEY");
  if (!secret) throw new Error("ADMIN_RESET_PRIVATE_KEY is not set");
  signingKey ??= crypto.subtle.importKey("pkcs8", bytesFromBase64(secret), { name: "Ed25519" }, false, ["sign"]);
  return signingKey;
}

export type PasswordCheck = (password: string) => Promise<boolean | null>;

/** Asks the database whether [password] is the seller password; null when it can't say. */
const checkWithDatabase: PasswordCheck = async (password) => {
  const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!, {
    auth: { persistSession: false },
  });
  const { data, error } = await supabase.rpc("check_dev_access", { p_password: password });
  if (error) {
    console.error("check_dev_access failed", error.message);
    return null;
  }
  return data === true;
};

export async function handle(request: Request, check: PasswordCheck = checkWithDatabase): Promise<Response> {
  if (request.method !== "POST") return answer(405, { error: "use POST" });
  let body: Record<string, unknown>;
  try {
    body = await request.json();
  } catch {
    return answer(400, { error: "bad request" });
  }
  const password = typeof body?.password === "string" ? body.password : "";
  const nonce = typeof body?.nonce === "string" ? body.nonce.toLowerCase() : "";
  if (password === "" || password.length > 200 || !NONCE.test(nonce)) return answer(400, { error: "bad request" });

  const accepted = await check(password);
  if (accepted === null) return answer(502, { error: "the password could not be checked" });
  if (!accepted) return answer(403, { error: "wrong password" });

  const issued = new Date().toISOString();
  const sig = await crypto.subtle.sign("Ed25519", await key(), new TextEncoder().encode(ticketMessage(nonce, issued)));
  return answer(200, { nonce, issued, sig: hex(new Uint8Array(sig)) });
}

if (import.meta.main) Deno.serve((request) => handle(request));
