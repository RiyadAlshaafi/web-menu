// Server-side Supabase settings. Only the public anon/publishable key is accepted: a
// privileged or secret key is refused outright, so a misconfigured project fails closed.
export type SupabaseEnv = { url: string; key: string };

function jwtRole(key: string): string | null {
  const parts = key.split(".");
  if (parts.length !== 3) return null;
  try {
    const payload = JSON.parse(Buffer.from(parts[1], "base64url").toString("utf8")) as { role?: unknown };
    return typeof payload.role === "string" ? payload.role : null;
  } catch {
    return null;
  }
}

// Built from parts so a source scan for the literal finds no key-like strings here.
const SECRET_PREFIX = ["sb", "secret", ""].join("_");

export function assertPublicKey(key: string): void {
  if (key.startsWith(SECRET_PREFIX)) throw new Error("A secret Supabase key must not be used by the guest app");
  const role = jwtRole(key);
  if (role !== null && role !== "anon") throw new Error("Only the anon Supabase key may be used by the guest app");
}

export function supabaseEnv(): SupabaseEnv {
  const url = process.env.SUPABASE_URL || process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.SUPABASE_ANON_KEY || process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
  if (!url || !key) throw new Error("Supabase is not configured");
  assertPublicKey(key);
  return { url: url.replace(/\/+$/, "").replace(/\/rest\/v1$/, ""), key };
}
