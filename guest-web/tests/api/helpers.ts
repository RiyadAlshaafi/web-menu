import { vi } from "vitest";
import { MemoryLimiter, setLimiter } from "@/lib/server/ratelimit";

export const SLUG = "abc123def456";
export const ITEM = "11111111-1111-4111-8111-111111111111";
export const TYPE = "22222222-2222-4222-8222-222222222222";

export type RpcCall = { name: string; args: Record<string, unknown>; headers: Headers };
type Reply = { status?: number; body: unknown } | "network-error";

// Stands in for PostgREST: records every RPC call and answers with `reply`.
export function mockSupabase(reply: (name: string, args: Record<string, unknown>) => Reply) {
  const calls: RpcCall[] = [];
  const fetchMock = vi.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
    const url = String(input);
    const name = url.split("/rest/v1/rpc/")[1];
    const args = JSON.parse(String(init?.body ?? "{}")) as Record<string, unknown>;
    calls.push({ name, args, headers: new Headers(init?.headers) });
    const r = reply(name, args);
    if (r === "network-error") throw new TypeError("fetch failed");
    return new Response(JSON.stringify(r.body), { status: r.status ?? 200, headers: { "Content-Type": "application/json" } });
  });
  vi.stubGlobal("fetch", fetchMock);
  return calls;
}

export function freshLimits() {
  setLimiter(new MemoryLimiter());
}

export function get(path: string, ip = "10.0.0.1") {
  return new Request(`http://localhost${path}`, { headers: { "x-forwarded-for": `${ip}, 10.9.9.9` } });
}

export function post(path: string, body: unknown, ip = "10.0.0.1") {
  return new Request(`http://localhost${path}`, {
    method: "POST",
    headers: { "Content-Type": "application/json", "x-forwarded-for": ip },
    body: typeof body === "string" ? body : JSON.stringify(body),
  });
}

export async function json(response: Response) {
  return (await response.json()) as { ok: boolean; data: unknown; error: { code: string; message: string; items?: string[] } | null };
}

export function setEnv() {
  vi.stubEnv("SUPABASE_URL", "https://example.supabase.co/");
  vi.stubEnv("SUPABASE_ANON_KEY", "sb_publishable_test");
  vi.stubEnv("UPSTASH_REDIS_REST_URL", "");
  vi.stubEnv("UPSTASH_REDIS_REST_TOKEN", "");
}
