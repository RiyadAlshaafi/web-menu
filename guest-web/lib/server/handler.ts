import type { z } from "zod";
import { clientIp } from "./client-ip";
import type { ErrorCode } from "./errors";
import { limiter, LIMITS, type Endpoint } from "./ratelimit";
import { fail, ok } from "./respond";

export type Outcome<T> = { ok: true; data: T } | { ok: false; code: ErrorCode; items?: string[] };

type RouteOptions<S extends z.ZodType<{ slug: string }>, T> = {
  endpoint: Endpoint;
  method: "GET" | "POST";
  schema: S;
  run: (input: z.infer<S>) => Promise<Outcome<T>>;
  cacheControl?: string;
};

const MAX_BODY_BYTES = 16 * 1024;

async function readInput(request: Request, method: "GET" | "POST"): Promise<unknown> {
  if (method === "GET") {
    return Object.fromEntries(new URL(request.url).searchParams.entries());
  }
  const type = request.headers.get("content-type") ?? "";
  if (!type.toLowerCase().startsWith("application/json")) return undefined;
  const text = await request.text();
  if (new TextEncoder().encode(text).length > MAX_BODY_BYTES) return undefined;
  try {
    return JSON.parse(text);
  } catch {
    return undefined;
  }
}

// Every guest endpoint: per-IP limit, strict input, per-table limit, exactly one RPC (inside
// `run`), and the { ok, data, error } envelope. Never throws to the framework.
export function guestRoute<S extends z.ZodType<{ slug: string }>, T>(options: RouteOptions<S, T>) {
  const limits = LIMITS[options.endpoint];
  return async function handle(request: Request): Promise<Response> {
    try {
      const rl = limiter();
      const byIp = await rl.limit(`${options.endpoint}:ip:${clientIp(request)}`, limits.ip);
      if (!byIp.success) return fail("rate_limited", { retryAfter: byIp.retryAfter });

      const parsed = options.schema.safeParse(await readInput(request, options.method));
      if (!parsed.success) return fail("bad_request");

      const bySlug = await rl.limit(`${options.endpoint}:slug:${parsed.data.slug}`, limits.slug);
      if (!bySlug.success) return fail("rate_limited", { retryAfter: bySlug.retryAfter });

      const outcome = await options.run(parsed.data);
      if (!outcome.ok) return fail(outcome.code, { items: outcome.items });
      return ok(outcome.data, options.cacheControl);
    } catch (error) {
      console.error(`guest ${options.endpoint} failed`, error);
      return fail("server_error");
    }
  };
}
