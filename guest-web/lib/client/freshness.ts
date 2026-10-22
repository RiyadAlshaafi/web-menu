// How recent a fetch must be before the page skips asking the server again.
export function isFresh(fetchedAt: number, maxAgeMs: number, now: number = Date.now()): boolean {
  return now - fetchedAt < maxAgeMs;
}

// Guests whose menu reload comes from the same ping share one edge-cache key per bucket, so a
// menu change costs the database one read instead of one per guest.
export const PING_BUCKET_MS = 5_000;

export function pingStamp(now: number = Date.now()): number {
  return Math.floor(now / PING_BUCKET_MS) * PING_BUCKET_MS;
}
