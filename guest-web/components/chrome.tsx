"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useCallback, useEffect, useRef, useState, type ReactNode } from "react";
import { useGuest } from "./guest-provider";
import { Icon, type IconName } from "./icons";
import { useReducedMotion } from "./landing/use-motion";
import { GuestHeader } from "./parts";

export function Header() {
  const { menu, text } = useGuest();
  return (
    <GuestHeader
      cafeName={menu.cafe.name}
      logoUrl={menu.cafe.logoUrl}
      subtitle={text("guestTableDineIn", { number: menu.table.number })}
    />
  );
}

// Menu · Table Bill · Call Staff (lib/screens/customer/call_staff.dart CustomerShell.nav).
export function BottomNav() {
  const { href, tab, text, showToast, callStaff } = useGuest();
  const path = usePathname();
  const hasOrder = Boolean(tab?.order);
  const onMenu = !path.endsWith("/tab") && !path.endsWith("/bill");
  const onTab = path.endsWith("/tab") || path.endsWith("/bill");

  const item = (icon: IconName, label: string, active: boolean, enabled = true) => {
    const color = !enabled ? "text-muted/50" : active ? "text-brand-ink" : "text-muted";
    return (
      <>
        <Icon name={icon} size={22} className={color} />
        <span className={`mt-1 text-xs font-bold ${color}`}>{label}</span>
      </>
    );
  };
  const cell = "flex min-h-[44px] flex-1 flex-col items-center justify-center";

  return (
    <nav aria-label={text("guestNavMenu")} className="sticky bottom-0 z-20 flex h-[68px] border-t border-line bg-white pb-[env(safe-area-inset-bottom)]">
      <Link href={href()} className={cell} aria-current={onMenu ? "page" : undefined}>
        {item("menu", text("guestNavMenu"), onMenu)}
      </Link>
      {hasOrder ? (
        <Link href={href("/tab")} className={cell} aria-current={onTab ? "page" : undefined}>
          {item("receipt", text("guestTableBill"), onTab)}
        </Link>
      ) : (
        <button type="button" className={cell} aria-disabled="true" onClick={() => showToast(text("guestOrderFirst"))}>
          {item("receipt", text("guestTableBill"), false, false)}
        </button>
      )}
      <button type="button" className={cell} onClick={() => void callStaff()}>
        {item("bell", text("guestCallStaff"), false)}
      </button>
    </nav>
  );
}

export function Toast() {
  const { toast } = useGuest();
  // Keep the last message on screen while it fades out, so it leaves the way it came.
  const [last, setLast] = useState(toast);
  if (toast && toast !== last) setLast(toast);
  const shown = Boolean(toast);
  return (
    <div role="status" aria-live="polite" className="pointer-events-none fixed inset-x-0 bottom-24 z-50 flex justify-center px-4">
      {last && (
        <p
          aria-hidden={!shown || undefined}
          className={`toast max-w-[400px] rounded-xl bg-ink px-4 py-3 text-sm leading-snug text-white shadow-lg ${
            shown ? "fade-in pointer-events-auto" : "translate-y-2 opacity-0"
          }`}
        >
          {last}
        </p>
      )}
    </div>
  );
}

// "Item removed" bar while the cashier refused a dish and waits for the guest.
export function RefusalNotice() {
  const { tab, text, confirmRefusal } = useGuest();
  const order = tab?.order;
  if (!order?.awaitingConfirmation) return null;
  return (
    <div role="alert" className="bg-brand/10 px-4 py-2.5">
      <p className="font-extrabold text-brand-ink">{text("guestItemRemoved", { name: order.refusalNotice })}</p>
      <button
        type="button"
        onClick={() => void confirmRefusal()}
        className="mt-2 min-h-[44px] rounded-full bg-brand px-5 text-sm font-bold text-on-brand"
      >
        {text("guestRefusalOk")}
      </button>
    </div>
  );
}

// The exit animation is 180ms (globals.css .sheet-out); this is the latest it may take.
const EXIT_FALLBACK_MS = 320;

// A bottom sheet: modal, closes on Escape or the backdrop, keeps focus inside while open.
// Children given as a function get `close`, which plays the exit before onClose unmounts it.
export function Sheet({
  label,
  onClose,
  children,
  floating = false,
  locked = false,
}: {
  label: string;
  onClose: () => void;
  children: ReactNode | ((close: () => void) => ReactNode);
  floating?: boolean;
  /** Ignores Escape, the backdrop and `close` (e.g. while an order is sending). */
  locked?: boolean;
}) {
  const panel = useRef<HTMLDivElement>(null);
  const reduced = useReducedMotion();
  const [leaving, setLeaving] = useState(false);
  const close = useCallback(() => {
    if (locked) return;
    if (reduced) onClose();
    else setLeaving(true);
  }, [locked, reduced, onClose]);
  // The latest handlers, so the focus trap below is set up once, not again on every new onClose.
  const onCloseRef = useRef(onClose);
  const closeRef = useRef(close);
  useEffect(() => {
    onCloseRef.current = onClose;
    closeRef.current = close;
  }, [onClose, close]);
  // A background tab can skip animationend; never leave an invisible sheet holding the page.
  useEffect(() => {
    if (!leaving) return;
    const timer = setTimeout(() => onCloseRef.current(), EXIT_FALLBACK_MS);
    return () => clearTimeout(timer);
  }, [leaving]);

  useEffect(() => {
    const previous = document.activeElement as HTMLElement | null;
    const node = panel.current;
    node?.focus();
    const onKey = (event: KeyboardEvent) => {
      if (event.key === "Escape") closeRef.current();
      if (event.key !== "Tab" || !node) return;
      const focusable = node.querySelectorAll<HTMLElement>("button:not([disabled]), input:not([disabled]), [href], select, [tabindex='0']");
      if (focusable.length === 0) return;
      const first = focusable[0];
      const last = focusable[focusable.length - 1];
      if (event.shiftKey && document.activeElement === first) {
        event.preventDefault();
        last.focus();
      } else if (!event.shiftKey && document.activeElement === last) {
        event.preventDefault();
        first.focus();
      }
    };
    document.addEventListener("keydown", onKey);
    const overflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => {
      document.removeEventListener("keydown", onKey);
      document.body.style.overflow = overflow;
      previous?.focus?.();
    };
  }, []);

  return (
    <div className={`fixed inset-0 z-40 flex items-end justify-center ${leaving ? "pointer-events-none" : ""}`}>
      <div className={`${leaving ? "fade-out" : "fade-in"} absolute inset-0 bg-black/40`} onClick={close} aria-hidden="true" />
      <div
        ref={panel}
        role="dialog"
        aria-modal="true"
        aria-label={label}
        tabIndex={-1}
        onAnimationEnd={(event) => {
          if (leaving && event.target === event.currentTarget) onCloseRef.current();
        }}
        className={`${leaving ? "sheet-out" : "sheet-in"} relative max-h-[88dvh] w-full max-w-[430px] overflow-y-auto outline-none ${
          floating ? "mx-3 mb-4 max-w-[420px] rounded-[20px] bg-white shadow-2xl" : "rounded-t-3xl bg-page"
        }`}
      >
        {typeof children === "function" ? children(close) : children}
      </div>
    </div>
  );
}
