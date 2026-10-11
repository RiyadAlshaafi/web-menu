"use client";

import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState, type ReactNode } from "react";
import { cartCount, cartKey, cartLines, cartTotal, loadCart, prune, setQty as setCartQty, add as addToCart, type Cart, type CartLine } from "@/lib/cart";
import { api } from "@/lib/client/api";
import { MENU_TABLES, subscribeLive } from "@/lib/client/live";
import { errorText } from "@/lib/client/messages";
import { readRaw, useStoredRaw, writeRaw } from "@/lib/client/stored";
import { t, type Lang, type TextKey } from "@/lib/i18n";
import type { GuestStatus, Menu, Tab } from "@/lib/types";

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
  add: (itemId: string, qty?: number) => void;
  setQty: (itemId: string, qty: number) => void;
  checkLocation: (force?: boolean) => Promise<void>;
  sendOrder: (lines: { menuItemId: string; qty: number }[]) => Promise<boolean>;
  callStaff: () => Promise<void>;
  requestBill: () => Promise<boolean>;
  setPaymentType: (typeId: string) => Promise<void>;
  confirmRefusal: () => Promise<void>;
  refreshTab: () => Promise<void>;
  toast: string | null;
  showToast: (message: string) => void;
};

const GuestContext = createContext<Guest | null>(null);

export function useGuest(): Guest {
  const value = useContext(GuestContext);
  if (!value) throw new Error("useGuest outside GuestProvider");
  return value;
}

const STATUS_POLL_MS = 15_000;
const SAFETY_NET_MS = 90_000;
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
  const toastTimer = useRef<ReturnType<typeof setTimeout> | undefined>(undefined);

  const text = useCallback((key: TextKey, vars?: Record<string, string | number>) => t(lang, key, vars), [lang]);
  const href = useCallback((path = "") => `/t/${slug}${path}?lang=${lang}`, [slug, lang]);

  const showToast = useCallback((message: string) => {
    clearTimeout(toastTimer.current);
    setToast(message);
    toastTimer.current = setTimeout(() => setToast(null), 4000);
  }, []);

  // ---------------------------------------------------------------- cart (this phone only)
  const storageArea = useMemo(() => ({ getItem: (key: string) => readRaw("local", key) }), []);
  const cart = useMemo<Cart>(() => (cartRaw === null ? {} : loadCart(storageArea, slug)), [cartRaw, storageArea, slug]);

  const updateCart = useCallback(
    (next: (current: Cart) => Cart) => {
      // Dishes no longer on the menu are dropped on every change.
      const value = prune(next(loadCart(storageArea, slug)), menu.items);
      writeRaw("local", cartKey(slug), Object.keys(value).length ? JSON.stringify(value) : null);
    },
    [menu.items, slug, storageArea],
  );

  const lines = useMemo(() => cartLines(cart, menu.items), [cart, menu.items]);

  // ---------------------------------------------------------------- server state
  const refreshMenu = useCallback(async () => {
    const result = await api.menu(slug, Date.now());
    if (result.ok) setMenu(result.data);
  }, [slug]);

  const refreshStatus = useCallback(async () => {
    const result = await api.status(slug);
    if (result.ok) setStatus(result.data);
  }, [slug]);

  const refreshTab = useCallback(async () => {
    const result = await api.tab(slug);
    if (!result.ok) return;
    setTab(result.data);
    if (result.data.order && readRaw("session", hadOrderKey) !== "1") writeRaw("session", hadOrderKey, "1");
  }, [slug, hadOrderKey]);

  useEffect(() => {
    const poll = setInterval(() => void refreshStatus(), STATUS_POLL_MS);
    const net = setInterval(() => {
      void refreshMenu();
      void refreshTab();
    }, SAFETY_NET_MS);
    const onVisible = () => {
      if (document.visibilityState !== "visible") return;
      void refreshStatus();
      void refreshMenu();
      void refreshTab();
    };
    document.addEventListener("visibilitychange", onVisible);
    window.addEventListener("pageshow", onVisible);
    return () => {
      clearInterval(poll);
      clearInterval(net);
      document.removeEventListener("visibilitychange", onVisible);
      window.removeEventListener("pageshow", onVisible);
    };
  }, [refreshMenu, refreshStatus, refreshTab]);

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
        if (ping.topic.startsWith("guest:")) debounce("tab", () => void refreshTab());
        else if (MENU_TABLES.has(ping.table)) debounce("menu", () => void refreshMenu());
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
  }, [slug, menu.cafe.id, refreshMenu, refreshStatus, refreshTab]);

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
        try {
          const position = await readPosition();
          const { latitude: lat, longitude: lng, accuracy } = position.coords;
          const result = await api.location(slug, lat, lng, Math.min(accuracy, 10_000));
          if (result.ok && result.data.status === "allowed") {
            point.current = { lat, lng, accuracy: Math.min(accuracy, 10_000), until: Date.now() + POINT_TTL_MS };
            setLocation("allowed");
          } else if (result.ok && result.data.status === "too_far") {
            point.current = null;
            setLocation("tooFar");
          } else if (result.ok && !result.data.enabled) {
            // Staff switched the check off since the last status: pick that up now.
            point.current = null;
            setLocation("off");
            void refreshStatus();
          } else {
            point.current = null;
            setLocation("unavailable");
          }
        } catch (error) {
          point.current = null;
          const code = (error as { code?: number })?.code;
          setLocation(code === 1 ? "denied" : "unavailable");
        } finally {
          locationBusy.current = null;
        }
      })();
      locationBusy.current = run;
      return run;
    },
    [locationEnabled, refreshStatus, slug],
  );

  // The check only applies while the cafe has it switched on.
  const location: LocationState = locationEnabled ? checked : "off";

  const orderingOpen = status?.orderingOpen ?? true;
  const locationOk = location === "off" || location === "allowed";
  const canPlaceOrder = orderingOpen && locationOk && !(locationEnabled && location === "off");

  const blockedMessage = useMemo(() => {
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
  }, [lang, location, locationEnabled, orderingOpen]);

  // ---------------------------------------------------------------- actions
  const fail = useCallback(
    (error: { code: string; items?: string[] }) => {
      if (error.code === "cashier_offline") setStatus((s) => (s ? { ...s, orderingOpen: false } : s));
      if (error.code === "too_far") setLocation("tooFar");
      if (error.code === "location_required") setLocation("denied");
      showToast(errorText(lang, error, menu.items));
    },
    [lang, menu.items, showToast],
  );

  const sendOrder = useCallback(
    async (send: { menuItemId: string; qty: number }[]) => {
      if (send.length === 0) return false;
      if (locationEnabled) {
        await checkLocation(!(point.current && point.current.until > Date.now()));
        if (!point.current) {
          // The banner already says why; repeat it where the guest is looking.
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
    [checkLocation, fail, locationEnabled, refreshTab, slug, updateCart],
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
    add: (itemId, qty = 1) => updateCart((c) => addToCart(c, itemId, qty)),
    setQty: (itemId, qty) => updateCart((c) => setCartQty(c, itemId, qty)),
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
