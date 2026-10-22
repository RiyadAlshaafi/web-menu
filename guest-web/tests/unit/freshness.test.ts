import { describe, expect, it } from "vitest";
import { isFresh, PING_BUCKET_MS, pingStamp } from "@/lib/client/freshness";

describe("isFresh", () => {
  it("is true while the fetch is younger than the max age", () => {
    expect(isFresh(1_000, 300_000, 1_000 + 299_999)).toBe(true);
  });

  it("is false once the max age has passed", () => {
    expect(isFresh(1_000, 300_000, 1_000 + 300_000)).toBe(false);
  });
});

describe("pingStamp", () => {
  it("gives guests pinged within the same bucket the same cache key", () => {
    const start = 10 * PING_BUCKET_MS;
    expect(pingStamp(start + 1)).toBe(pingStamp(start + PING_BUCKET_MS - 1));
  });

  it("changes in the next bucket so a later change is not served from an older copy", () => {
    const start = 10 * PING_BUCKET_MS;
    expect(pingStamp(start + PING_BUCKET_MS)).toBeGreaterThan(pingStamp(start));
  });
});
