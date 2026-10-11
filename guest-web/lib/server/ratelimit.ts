import { Ratelimit } from "@upstash/ratelimit";
import { Redis } from "@upstash/redis";

export type Endpoint =
  | "menu"
  | "status"
  | "location"
  | "order"
  | "tab"
  | "call-staff"
  | "bill"
  | "payment-type"
  | "refusal";

// Requests per minute. Guests on cafe Wi-Fi share one IP, so per-IP limits are generous and the
// tight limits are per table (docs/guest-migration/02_PLAN.md, "Rate limits").
export const LIMITS: Record<Endpoint, { ip: number; slug: number }> = {
  menu: { ip: 120, slug: 60 },
  status: { ip: 120, slug: 40 },
  location: { ip: 30, slug: 20 },
  order: { ip: 20, slug: 6 },
  tab: { ip: 120, slug: 60 },
  "call-staff": { ip: 10, slug: 3 },
  bill: { ip: 20, slug: 6 },
  "payment-type": { ip: 20, slug: 6 },
  refusal: { ip: 20, slug: 6 },
};

const WINDOW_MS = 60_000;

export type LimitResult = { success: boolean; retryAfter: number };

export interface Limiter {
  limit(key: string, max: number): Promise<LimitResult>;
}

// Sliding window kept in this process. Used when Upstash isn't configured (local dev, tests);
// on Vercel every instance would have its own window, which is why production needs Upstash.
export class MemoryLimiter implements Limiter {
  private hits = new Map<string, number[]>();

  constructor(private now: () => number = Date.now) {}

  async limit(key: string, max: number): Promise<LimitResult> {
    const now = this.now();
    const recent = (this.hits.get(key) ?? []).filter((t) => t > now - WINDOW_MS);
    if (recent.length >= max) {
      this.hits.set(key, recent);
      return { success: false, retryAfter: Math.max(1, Math.ceil((recent[0] + WINDOW_MS - now) / 1000)) };
    }
    recent.push(now);
    this.hits.set(key, recent);
    if (this.hits.size > 10_000) this.prune(now);
    return { success: true, retryAfter: 0 };
  }

  private prune(now: number) {
    for (const [key, times] of this.hits) {
      if (!times.some((t) => t > now - WINDOW_MS)) this.hits.delete(key);
    }
  }
}

class UpstashLimiter implements Limiter {
  private byMax = new Map<number, Ratelimit>();

  constructor(private redis: Redis) {}

  async limit(key: string, max: number): Promise<LimitResult> {
    let limiter = this.byMax.get(max);
    if (!limiter) {
      limiter = new Ratelimit({
        redis: this.redis,
        limiter: Ratelimit.slidingWindow(max, "1 m"),
        prefix: `guest:rl:${max}`,
      });
      this.byMax.set(max, limiter);
    }
    const result = await limiter.limit(key);
    return { success: result.success, retryAfter: Math.max(1, Math.ceil((result.reset - Date.now()) / 1000)) };
  }
}

export function upstashConfigured(): boolean {
  return Boolean(process.env.UPSTASH_REDIS_REST_URL && process.env.UPSTASH_REDIS_REST_TOKEN);
}

let shared: Limiter | null = null;

export function limiter(): Limiter {
  if (shared) return shared;
  if (upstashConfigured()) {
    shared = new UpstashLimiter(
      new Redis({ url: process.env.UPSTASH_REDIS_REST_URL!, token: process.env.UPSTASH_REDIS_REST_TOKEN! }),
    );
  } else {
    console.warn("Upstash is not configured: rate limits are kept in memory for this process only");
    shared = new MemoryLimiter();
  }
  return shared;
}

// For tests.
export function setLimiter(next: Limiter | null): void {
  shared = next;
}
