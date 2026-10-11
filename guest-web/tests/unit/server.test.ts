import { afterEach, describe, expect, it, vi } from "vitest";
import { assertPublicKey, supabaseEnv } from "@/lib/server/env";
import { MemoryLimiter } from "@/lib/server/ratelimit";
import { clientIp } from "@/lib/server/client-ip";
import { codeForDbError } from "@/lib/server/errors";

const jwt = (role: string) =>
  ["e30", Buffer.from(JSON.stringify({ role })).toString("base64url"), "sig"].join(".");

afterEach(() => vi.unstubAllEnvs());

describe("supabase settings", () => {
  it("accepts the anon or publishable key only", () => {
    expect(() => assertPublicKey(jwt("anon"))).not.toThrow();
    expect(() => assertPublicKey("sb_publishable_abc")).not.toThrow();
    expect(() => assertPublicKey(jwt(["service", "role"].join("_")))).toThrow(/anon/);
    expect(() => assertPublicKey(["sb", "secret", "abc"].join("_"))).toThrow(/secret/);
  });

  it("falls back to the NEXT_PUBLIC names and trims the URL", () => {
    vi.stubEnv("SUPABASE_URL", "");
    vi.stubEnv("SUPABASE_ANON_KEY", "");
    vi.stubEnv("NEXT_PUBLIC_SUPABASE_URL", "https://x.supabase.co//");
    vi.stubEnv("NEXT_PUBLIC_SUPABASE_ANON_KEY", "sb_publishable_x");
    expect(supabaseEnv()).toEqual({ url: "https://x.supabase.co", key: "sb_publishable_x" });
  });

  it("fails when not configured", () => {
    vi.stubEnv("SUPABASE_URL", "");
    vi.stubEnv("NEXT_PUBLIC_SUPABASE_URL", "");
    expect(() => supabaseEnv()).toThrow(/not configured/);
  });
});

describe("memory rate limiter", () => {
  it("allows max per minute, then frees up as the window slides", async () => {
    let now = 0;
    const rl = new MemoryLimiter(() => now);
    for (let i = 0; i < 3; i++) expect((await rl.limit("k", 3)).success).toBe(true);
    const blocked = await rl.limit("k", 3);
    expect(blocked).toEqual({ success: false, retryAfter: 60 });
    now = 30_000;
    expect((await rl.limit("k", 3)).retryAfter).toBe(30);
    now = 60_001;
    expect((await rl.limit("k", 3)).success).toBe(true);
    expect((await rl.limit("other", 3)).success).toBe(true);
  });
});

describe("client ip", () => {
  it("uses the first forwarded hop, then x-real-ip", () => {
    expect(clientIp(new Request("http://x", { headers: { "x-forwarded-for": " 1.2.3.4 , 5.6.7.8" } }))).toBe("1.2.3.4");
    expect(clientIp(new Request("http://x", { headers: { "x-real-ip": "9.9.9.9" } }))).toBe("9.9.9.9");
    expect(clientIp(new Request("http://x"))).toBe("unknown");
    // Cloudflare's own header wins over a forged x-forwarded-for.
    expect(
      clientIp(new Request("http://x", { headers: { "cf-connecting-ip": "7.7.7.7", "x-forwarded-for": "6.6.6.6" } })),
    ).toBe("7.7.7.7");
  });
});

describe("database error mapping", () => {
  it("maps known texts and nothing else", () => {
    expect(codeForDbError("table not found")).toBe("table_not_found");
    expect(codeForDbError("cart is empty")).toBe("cart_empty");
    expect(codeForDbError("duplicate key value violates unique constraint")).toBe("server_error");
    expect(codeForDbError(undefined)).toBe("server_error");
  });
});
