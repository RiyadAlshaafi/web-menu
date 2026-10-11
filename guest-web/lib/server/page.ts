import "server-only";
import { headers } from "next/headers";
import { cache } from "react";
import { ipFromHeaders } from "./client-ip";
import { guest } from "./guest";
import { limiter, LIMITS } from "./ratelimit";
import { slug as slugSchema } from "./schemas";
import type { GuestStatus, Menu, Tab } from "../types";

export type TableLoad = { kind: "ok"; menu: Menu } | { kind: "not_found" } | { kind: "rate_limited" } | { kind: "error" };

// The table's menu for a server-rendered page: same checks as GET /api/guest/menu (slug format,
// per-IP and per-table limits, one RPC), run once per request however many components ask.
export const loadTable = cache(async (rawSlug: string): Promise<TableLoad> => {
  const parsed = slugSchema.safeParse(rawSlug);
  if (!parsed.success) return { kind: "not_found" };
  const slug = parsed.data;
  const ip = ipFromHeaders(await headers());
  try {
    const rl = limiter();
    if (!(await rl.limit(`page:ip:${ip}`, LIMITS.menu.ip)).success) return { kind: "rate_limited" };
    if (!(await rl.limit(`page:slug:${slug}`, LIMITS.menu.slug)).success) return { kind: "rate_limited" };
    const result = await guest.menu(slug);
    if (result.ok) return { kind: "ok", menu: result.data };
    return result.code === "table_not_found" ? { kind: "not_found" } : { kind: "error" };
  } catch (error) {
    console.error("guest page load failed", error);
    return { kind: "error" };
  }
});

export async function pageLang(): Promise<"en" | "ar" | null> {
  const value = (await headers()).get("x-guest-lang");
  return value === "en" || value === "ar" ? value : null;
}

// Ordering status and the open order, so the first HTML already shows the right banner and tab.
// Called only after loadTable succeeded (which applied the page rate limits).
export async function loadTableState(slug: string): Promise<{ status: GuestStatus | null; tab: Tab | null }> {
  try {
    const [status, tab] = await Promise.all([guest.status(slug), guest.tab(slug)]);
    return { status: status.ok ? status.data : null, tab: tab.ok ? tab.data : null };
  } catch (error) {
    console.error("guest page state failed", error);
    return { status: null, tab: null };
  }
}
