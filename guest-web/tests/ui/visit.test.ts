// @vitest-environment jsdom
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { recordVisit } from "@/lib/client/visit";

const SLUG = "abc123def456";

function stubFetch() {
  const fetchMock = vi.fn(async () => new Response(JSON.stringify({ ok: true, data: { done: true }, error: null })));
  vi.stubGlobal("fetch", fetchMock);
  return fetchMock;
}

beforeEach(() => {
  localStorage.clear();
  sessionStorage.clear();
});
afterEach(() => {
  vi.unstubAllGlobals();
});

describe("recordVisit", () => {
  it("sends the slug and a random id once per tab session", async () => {
    const fetchMock = stubFetch();
    recordVisit(SLUG);
    recordVisit(SLUG);
    recordVisit(SLUG);
    expect(fetchMock).toHaveBeenCalledTimes(1);
    const [url, init] = fetchMock.mock.calls[0] as unknown as [string, RequestInit];
    expect(url).toBe("/api/guest/visit");
    const body = JSON.parse(String(init.body)) as { slug: string; visitor: string };
    expect(body.slug).toBe(SLUG);
    expect(body.visitor).toMatch(/^[A-Za-z0-9-]{16,64}$/);
  });

  it("keeps the same id across tab sessions and another id for another browser", () => {
    const fetchMock = stubFetch();
    recordVisit(SLUG);
    sessionStorage.clear();
    recordVisit(SLUG);
    const ids = fetchMock.mock.calls.map((c) => JSON.parse(String((c as unknown as [string, RequestInit])[1].body)).visitor);
    expect(ids).toHaveLength(2);
    expect(ids[0]).toBe(ids[1]);

    localStorage.clear();
    sessionStorage.clear();
    recordVisit(SLUG);
    const third = JSON.parse(String((fetchMock.mock.calls[2] as unknown as [string, RequestInit])[1].body)).visitor;
    expect(third).not.toBe(ids[0]);
  });

  it("counts each table's cafe separately within one tab session", () => {
    const fetchMock = stubFetch();
    recordVisit(SLUG);
    recordVisit("other-slug-123");
    expect(fetchMock).toHaveBeenCalledTimes(2);
  });

  it("never throws when the count fails", () => {
    vi.stubGlobal("fetch", vi.fn(async () => { throw new TypeError("offline"); }));
    expect(() => recordVisit(SLUG)).not.toThrow();
  });
});
