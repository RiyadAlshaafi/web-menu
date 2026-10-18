import type { ApiResponse } from "../server/respond";
import type { Done, GuestStatus, LocationVerdict, Menu, OrderSent, Tab } from "../types";

// Browser side of /api/guest/*. Never throws: a network failure comes back as `network`.
export type Result<T> = ApiResponse<T> | { ok: false; data: null; error: { code: "network"; message: string } };

async function request<T>(path: string, init?: RequestInit): Promise<Result<T>> {
  try {
    const response = await fetch(path, { ...init, cache: "no-store" });
    const body = (await response.json()) as ApiResponse<T>;
    if (body && typeof body === "object" && "ok" in body) return body;
  } catch {
    // fall through
  }
  return { ok: false, data: null, error: { code: "network", message: "" } };
}

const post = <T>(path: string, body: unknown) =>
  request<T>(path, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(body) });

const q = (slug: string) => `slug=${encodeURIComponent(slug)}`;

export const api = {
  menu: (slug: string, stamp?: number) =>
    request<Menu>(`/api/guest/menu?${q(slug)}${stamp ? `&v=${stamp}` : ""}`),
  status: (slug: string) => request<GuestStatus>(`/api/guest/status?${q(slug)}`),
  tab: (slug: string) => request<Tab>(`/api/guest/tab?${q(slug)}`),
  location: (slug: string, lat: number, lng: number, accuracy?: number) =>
    post<LocationVerdict>("/api/guest/location", { slug, lat, lng, accuracy }),
  order: (
    slug: string,
    lines: { menuItemId: string; qty: number; on?: string[] }[],
    point?: { lat: number; lng: number; accuracy?: number },
  ) => post<OrderSent>("/api/guest/order", { slug, lines, ...point }),
  callStaff: (slug: string) => post<Done>("/api/guest/call-staff", { slug }),
  bill: (slug: string) => post<Done>("/api/guest/bill", { slug }),
  paymentType: (slug: string, typeId: string) => post<Done>("/api/guest/payment-type", { slug, typeId }),
  refusal: (slug: string) => post<Done>("/api/guest/refusal", { slug }),
};
