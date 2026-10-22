"use client";

import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState, type ReactNode } from "react";
import { cartCount, cartKey, cartLines, cartTotal, loadCart, prune, setQty as setCartQty, add as addToCart, type Cart, type CartLine } from "@/lib/cart";
import { api } from "@/lib/client/api";
import { isFresh, pingStamp } from "@/lib/client/freshness";
import { MENU_TABLES, subscribeLive } from "@/lib/client/live";
import { errorText } from "@/lib/client/messages";
import { readRaw, useStoredRaw, writeRaw } from "@/lib/client/stored";
import { recordVisit } from "@/lib/client/visit";
import { t, type Lang, type TextKey } from "@/lib/i18n";
import type { GuestStatus, Menu, MenuItem, Tab } from "@/lib/types";

export type LocationState = "off" | "checking" | "allowed" | "tooFar" | "denied" | "unavailable";

type Point = { lat: number; lng: number; accuracy: number; until: number };

type Guest = {
  slug: string;
  lang: Lang;
  menu: Menu;
  status: GuestStatus | null;
  tab: Tab | null;
  cart: Cart;
  lines: CartLine[];
  count: number;
  total: number;
  location: LocationState;
  canPlaceOrder: boolean;
  blockedMessage: string | null;
  hadOrder: boolean;
  text: (key: TextKey, vars?: Record<string, string | number>) => string;
  href: (path?: string) => string;
  // `on` defaults to the dish as it comes.
  add: (item: MenuItem, on?: string[], qty?: number) => void;
  // By cart line key (lib/cart lineKey).
  setQty: (key: string, qty: number) => void;
  checkLocation: (force?: boolean) => Promise<void>;
  sendOrder: (lines: OrderLine[]) => Promise<boolean>;
  callStaff: () => Promise<void>;
  requestBill: () => Promise<boolean>;
  setPaymentType: (typeId: string) => Promise<void>;
  confirmRefusal: () => Promise<void>;
  refreshTab: () => Promise<void>;
  toast: string | null;
  showToast: (message: string) => void;
};

export type OrderLine = { menuItemId: string; qty: number; on?: string[] };

const GuestContext = createContext<Guest | null>(null);

export function useGuest(): Guest {
  const value = useContext(GuestContext);
  if (!value) throw new Error("useGuest outside GuestProvider");
  return value;
}

const STATUS_POLL_MS = 30_000;
const SAFETY_NET_MS = 180_000;
// The menu changes rarely and a ping reloads it at once, so timers and tab switches reuse it.
const MENU_FRESH_MS = 5 * 60_000;
const PING_DEBOUNCE_MS = 300;
const POINT_TTL_MS = 10 * 60_000;

function readPosition(): Promise<GeolocationPosition> {
  return new Promise((resolve, reject) => {
    if (!("geolocation" in navigator)) {
      reject({ code: 2 });
      return;
    }
    navigator.geolocation.getCurrentPosition(resolve, reject, { enableHighAccuracy: true, timeout: 20_000, maximumAge: 0 });
  });
}

export function GuestProvider({
  slug,
  lang,
  initialMenu,
  initialStatus,
  initialTab,
  children,
}: {
  slug: string;
  lang: Lang;
  initialMenu: Menu;
  initialStatus: GuestStatus | null;
  initialTab: Tab | null;
  children: ReactNode;
}) {
  const [menu, setMenu] = useState(initialMenu);
  const [status, setStatus] = useState<GuestStatus | null>(initialStatus);
  const [tab, setTab] = useState<Tab | null>(initialTab);
  const [checked, setLocation] = useState<LocationState>("off");
  const [toast, setToast] = useState<string | null>(null);
  const cartRaw = useStoredRaw("local", cartKey(slug));
  const hadOrderKey = `tawla-had-order:${slug}`;
  const hadOrder = useStoredRaw("session", hadOrderKey) === "1" || Boolean(tab?.order);
  const point = useRef<Point | null>(null);
  const locationBusy = useRef<Promise<void> | null>(null);
  // Outcome of the last check, read by sendOrder right after it awaits one.
  const lastCheck = useRef<LocationState>("off");
  const toastTimer = useRef<ReturnType<typeof setTimeout> | undefined>(undefined);

  const text = useCallback((key: TextKey, vars?: Record<string, string | number>) => t(lang, key, vars), [lang]);
  const href = useCallback((path = "") => `/t/${slug}${path}?lang=${lang}`, [slug, lang]);

  // Counts this browser once as a visitor of the cafe (no personal data; see lib/client/visit).
  useEffect(() => {
    recordVisit(slug);
  }, [slug]);

  const showToast = useCallback((message: string) => {
    clearTimeout(toastTimer.current);
    setToast(message);
    toastTimer.current = setTimeout(() => setToast(null), 4000);
  }, []);

  // ---------------------------------------------------------------- cart (this phone only)
  const storageArea = useMemo(() => ({ getItem: (key: string) => readRaw("local", key) }), []);
  const cart = useMemo<Cart>(
    () => (cartRaw === null ? {} : loadCart(storageArea, slug, menu.items)),
    [cartRaw, storageArea, slug, menu.items],
  );

  const updateCart = useCallback(
    (next: (current: Cart) => Cart) => {
      // Dishes no longer on the menu are dropped on every change.
      const value = prune(next(loadCart(storageArea, slug, menu.items)), menu.items);
      writeRaw("local", cartKey(slug), Object.keys(value).length ? JSON.stringify(value) : null);
    },
    [menu.items, slug, storageArea],
  );

  const lines = useMemo(() => cartLines(cart, menu.items), [cart, menu.items]);

  // ---------------------------------------------------------------- server state
  // The server rendered the menu just now. A ping forces a reload under a shared edge-cache key;
  // timers and tab switches reuse the menu while it is fresh and otherwise use the plain edge copy.
  const menuAt = useRef(0);
  useEffect(() => {
    menuAt.current = Date.now();
  }, []);
  const refreshMenu = useCallback(
    async (force = false) => {
      if (!force && isFresh(menuAt.current, MENU_FRESH_MS)) return;
      const result = await api.menu(slug, force ? pingStamp() : undefined);
      if (!result.ok) return;
      menuAt.current = Date.now();
      setMenu(result.data);
    },
    [slug],
  );

  const refreshStatus = useCallback(async () => {
    const result = await api.status(slug);
    if (result.ok) setStatus(result.data);
  }, [slug]);

  // The first phone at a table owns it and may order; the others only look. Unknown (null) until
  // the first answer, and when the answer fails: the server refuses a non-owner's order anyway.
  const [role, setRole] = useState<"owner" | "viewer" | null>(null);
  const roleRef = useRef(role);
  useEffect(() => {
    roleRef.current = role;
  }, [role]);
  // A free table is only taken by a phone at the cafe, so the checked position goes along when
  // there is one. "none" (too far, not checked yet) leaves ordering to the location rules.
  const claimPoint = useRef<{ lat: number; lng: number; accuracy: number } | null>(null);
  const claimTable = useCallback(async () => {
    const result = await api.claim(slug, claimPoint.current ?? undefined);
    if (!result.ok) return;
    if (result.data.role === "owner" || result.data.role === "viewer") setRole(result.data.role);
    else if (result.data.role === "none") setRole(null);
  }, [slug]);

  const refreshTab = useCallback(async () => {
    const result = await api.tab(slug);
    if (!result.ok) return;
    setTab(result.data);
    if (result.data.order && readRaw("session", hadOrderKey) !== "1") writeRaw("session", hadOrderKey, "1");
  }, [slug, hadOrderKey]);

  useEffect(() => {
    // A hidden tab needs nothing: coming back refreshes at once (onVisible below).
    const poll = setInterval(() => {
      if (document.visibilityState !== "visible") return;
      void refreshStatus();
      // A viewer keeps asking: the owner's claim may have run out.
      if (roleRef.current === "viewer") void claimTable();
    }, STATUS_POLL_MS);
    const net = setInterval(() => {
      if (document.visibilityState !== "visible") return;
      void refreshMenu();
      void refreshTab();
    }, SAFETY_NET_MS);
    const onVisible = () => {
      if (document.visibilityState !== "visible") return;
      void refreshStatus();
      void refreshMenu();
      void refreshTab();
      void claimTable();
    };
    // On opening the page, so the phone knows at once whether it may order.
    const first = setTimeout(() => void claimTable(), 0);
    document.addEventListener("visibilitychange", onVisible);
    window.addEventListener("pageshow", onVisible);
    return () => {
      clearTimeout(first);
      clearInterval(poll);
      clearInterval(net);
      document.removeEventListener("visibilitychange", onVisible);
      window.removeEventListener("pageshow", onVisible);
    };
  }, [claimTable, refreshMenu, refreshStatus, refreshTab]);

  // Live pings: the guest's own table, and menu changes in the cafe.
  useEffect(() => {
    const timers: Record<string, ReturnType<typeof setTimeout>> = {};
    const debounce = (key: string, run: () => void) => {
      clearTimeout(timers[key]);
      timers[key] = setTimeout(run, PING_DEBOUNCE_MS);
    };
    let unsubscribe = () => {};
    const start = () => {
      unsubscribe = subscribeLive([`guest:${slug}`, `cafe:${menu.cafe.id}`], (ping) => {
        if (ping.topic.startsWith("guest:")) {
          debounce("tab", () => void refreshTab());
          // The table was paid or cleared: a phone that could only look may own it now.
          if (roleRef.current === "viewer") debounce("claim", () => void claimTable());
        } else if (MENU_TABLES.has(ping.table)) debounce("menu", () => void refreshMenu(true));
        if (ping.table === "restaurants" || ping.table === "cashier_presence") debounce("status", () => void refreshStatus());
      });
    };
    // After first paint and idle, so Realtime stays out of the critical path.
    const idle = typeof window.requestIdleCallback === "function"
      ? window.requestIdleCallback(start, { timeout: 2000 })
      : window.setTimeout(start, 1000);
    return () => {
      if (typeof window.cancelIdleCallback === "function") window.cancelIdleCallback(idle as number);
      clearTimeout(idle as number);
      Object.values(timers).forEach(clearTimeout);
      unsubscribe();
    };
  }, [slug, menu.cafe.id, claimTable, refreshMenu, refreshStatus, refreshTab]);

  // ---------------------------------------------------------------- location (inventory §2.9)
  const locationEnabled = status?.location.enabled ?? false;

  const checkLocation = useCallback(
    async (force = false) => {
      if (!locationEnabled) {
        setLocation("off");
        return;
      }
      const fresh = point.current && point.current.until > Date.now();
      if (!force && fresh) return;
      if (locationBusy.current) return locationBusy.current;
      const run = (async () => {
        setLocation("checking");
        const settle = (state: LocationState) => {
          lastCheck.current = state;
          setLocation(state);
        };
        try {
          const position = await readPosition();
          const { latitude: lat, longitude: lng, accuracy } = position.coords;
          const result = await api.location(slug, lat, lng, Math.min(accuracy, 10_000));
          if (result.ok && result.data.status === "allowed") {
            point.current = { lat, lng, accuracy: Math.min(accuracy, 10_000), until: Date.now() + POINT_TTL_MS };
            claimPoint.current = { lat, lng, accuracy: Math.min(accuracy, 10_000) };
            settle("allowed");
            // At the cafe now: this phone may take the table if it is still free.
            void claimTable();
          } else if (result.ok && result.data.status === "too_far") {
            point.current = null;
            claimPoint.current = null;
            settle("tooFar");
          } else if (result.ok && !result.data.enabled) {
            // Staff switched the check off since the last status: pick that up now.
            point.current = null;
            claimPoint.current = null;
            settle("off");
            await refreshStatus();
          } else {
            point.current = null;
            claimPoint.current = null;
            settle("unavailable");
          }
        } catch (error) {
          point.current = null;
          claimPoint.current = null;
          const code = (error as { code?: number })?.code;
          settle(code === 1 ? "denied" : "unavailable");
        } finally {
          locationBusy.current = null;
        }
      })();
      locationBusy.current = run;
      return run;
    },
    [claimTable, locationEnabled, refreshStatus, slug],
  );

  // The check only applies while the cafe has it switched on.
  const location: LocationState = locationEnabled ? checked : "off";

  const orderingOpen = status?.orderingOpen ?? true;
  const locationOk = location === "off" || location === "allowed";
  const viewOnly = role === "viewer";
  const canPlaceOrder = !viewOnly && orderingOpen && locationOk && !(locationEnabled && location === "off");

  const blockedMessage = useMemo(() => {
    if (viewOnly) return t(lang, "guestViewOnly");
    if (!orderingOpen) return t(lang, "guestOrderingPaused");
    switch (location) {
      case "tooFar":
        return t(lang, "guestLocationTooFar");
      case "denied":
        return t(lang, "guestLocationDenied");
      case "unavailable":
        return t(lang, "guestLocationUnavailable");
      case "checking":
        return t(lang, "guestLocationChecking");
      case "off":
        return locationEnabled ? t(lang, "guestLocationChecking") : null;
      default:
        return null;
    }
  }, [lang, location, locationEnabled, orderingOpen, viewOnly]);

  // ---------------------------------------------------------------- actions
  const fail = useCallback(
    (error: { code: string; items?: string[] }) => {
      if (error.code === "cashier_offline") setStatus((s) => (s ? { ...s, orderingOpen: false } : s));
      if (error.code === "not_table_owner") setRole("viewer");
      if (error.code === "too_far") setLocation("tooFar");
      if (error.code === "location_required") setLocation("denied");
      showToast(errorText(lang, error, menu.items));
    },
    [lang, menu.items, showToast],
  );

  const sendOrder = useCallback(
    async (send: OrderLine[]) => {
      if (send.length === 0) return false;
      if (locationEnabled) {
        await checkLocation(!(point.current && point.current.until > Date.now()));
        // "off" here means staff just switched the check off: send without a position.
        if (!point.current && lastCheck.current !== "off") {
          // The banner already says why; repeat it where the guest is looking.
          const why: Record<string, TextKey> = { tooFar: "guestLocationTooFar", denied: "guestLocationDenied" };
          showToast(t(lang, why[lastCheck.current] ?? "guestLocationUnavailable"));
          return false;
        }
      }
      const p = point.current;
      const result = await api.order(slug, send, p ? { lat: p.lat, lng: p.lng, accuracy: p.accuracy } : undefined);
      if (!result.ok) {
        fail(result.error);
        return false;
      }
      updateCart(() => ({}));
      await refreshTab();
      return true;
    },
    [checkLocation, fail, lang, locationEnabled, refreshTab, showToast, slug, updateCart],
  );

  const callStaff = useCallback(async () => {
    if (!orderingOpen) {
      showToast(t(lang, "guestOrderingPaused"));
      return;
    }
    const result = await api.callStaff(slug);
    if (result.ok) showToast(t(lang, "guestRequestSent"));
    else fail(result.error);
  }, [fail, lang, orderingOpen, showToast, slug]);

  const requestBill = useCallback(async () => {
    const result = await api.bill(slug);
    if (!result.ok) {
      fail(result.error);
      return false;
    }
    await refreshTab();
    return true;
  }, [fail, refreshTab, slug]);

  const setPaymentType = useCallback(
    async (typeId: string) => {
      const result = await api.paymentType(slug, typeId);
      if (!result.ok) fail(result.error);
      await refreshTab();
    },
    [fail, refreshTab, slug],
  );

  const confirmRefusal = useCallback(async () => {
    const result = await api.refusal(slug);
    if (!result.ok) fail(result.error);
    await refreshTab();
  }, [fail, refreshTab, slug]);

  const value: Guest = {
    slug,
    lang,
    menu,
    status,
    tab,
    cart,
    lines,
    count: cartCount(lines),
    total: cartTotal(lines),
    location,
    canPlaceOrder,
    blockedMessage,
    hadOrder,
    text,
    href,
    add: (item, on, qty = 1) => updateCart((c) => addToCart(c, item, on, qty)),
    setQty: (key, qty) => updateCart((c) => setCartQty(c, key, qty)),
    checkLocation,
    sendOrder,
    callStaff,
    requestBill,
    setPaymentType,
    confirmRefusal,
    refreshTab,
    toast,
    showToast,
  };

  return <GuestContext.Provider value={value}>{children}</GuestContext.Provider>;
}
