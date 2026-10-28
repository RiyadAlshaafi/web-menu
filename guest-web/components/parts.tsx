import Image from "next/image";
import type { ReactNode } from "react";
import { dishName, money } from "@/lib/format";
import { t, type Lang } from "@/lib/i18n";
import type { LineChoice } from "@/lib/types";
import { Icon } from "./icons";

// Shared pieces of the guest pages (lib/screens/customer/guest_parts.dart).

function cafeInitials(name: string): string {
  const words = name.trim().split(/\s+/).filter(Boolean);
  return words
    .slice(0, 2)
    .map((w) => Array.from(w)[0] ?? "")
    .join("")
    .toUpperCase();
}

export function CafeBadge({ name, logoUrl, size, className = "" }: { name: string; logoUrl: string; size: number; className?: string }) {
  const logo = logoUrl.trim();
  return (
    <div
      className={`grid shrink-0 place-items-center overflow-hidden rounded-full font-extrabold ${className}`}
      style={{ width: size, height: size, fontSize: size * 0.33 }}
    >
      {logo.startsWith("https://") ? (
        <Image src={logo} alt="" width={size} height={size} className="h-full w-full object-cover" priority />
      ) : (
        <span aria-hidden="true">{cafeInitials(name)}</span>
      )}
    </div>
  );
}

export function GuestHeader({ cafeName, logoUrl, subtitle }: { cafeName: string; logoUrl: string; subtitle: string }) {
  return (
    <header className="flex items-center gap-3 bg-brand-header px-[18px] pt-4 pb-3.5 text-on-header">
      <CafeBadge name={cafeName} logoUrl={logoUrl} size={42} className="bg-on-header/15" />
      <div className="min-w-0 flex-1">
        <h1 className="truncate text-lg font-extrabold">{cafeName}</h1>
        <p className="mt-0.5 text-[13px] opacity-80">{subtitle}</p>
      </div>
    </header>
  );
}

export function GuestCard({ children, className = "" }: { children: ReactNode; className?: string }) {
  return <section className={`w-full rounded-[18px] bg-white p-[18px] ${className}`}>{children}</section>;
}

export function Eyebrow({ children }: { children: ReactNode }) {
  return <p className="text-xs font-extrabold tracking-[0.13em] text-brand-ink uppercase">{children}</p>;
}

export function TicketLine({ qty, name, amount, choices = [], lang }: { qty: number; name: string; amount: string; choices?: LineChoice[]; lang: Lang }) {
  return (
    <div className="flex items-center gap-2 border-t border-hairline py-[9px] text-[15px]">
      <span className="w-[34px] shrink-0 self-start font-extrabold">{qty}×</span>
      <span className="min-w-0 flex-1">
        {name}
        <ChoiceNotes choices={choices} lang={lang} />
      </span>
      <span className="self-start font-bold whitespace-nowrap">{amount}</span>
    </div>
  );
}

// Small lines under a dish for the choices that differ from how it comes: "– No onion",
// "+ Cheese 0.500 LYD". Nothing for a dish as it comes. Spans, so it fits inside inline text.
export function ChoiceNotes({ choices, lang }: { choices: LineChoice[]; lang: Lang }) {
  if (choices.length === 0) return null;
  return (
    <span className="mt-0.5 block text-[13px] leading-snug font-normal text-muted">
      {choices.map((choice) => (
        <span key={choice.id} className="block">
          {t(lang, choice.on ? "guestChoiceWith" : "guestChoiceWithout", { name: dishName(choice, lang) })}
          {choice.on && choice.price > 0 && <span className="ms-1.5 whitespace-nowrap">{money(choice.price, lang)}</span>}
        </span>
      ))}
    </span>
  );
}

function TawlaMark({ size = 18 }: { size?: number }) {
  const simple = size < 24;
  const corners = [
    [8, 8],
    [76, 8],
    [8, 76],
  ];
  return (
    <svg viewBox="0 0 120 120" width={size} height={size} aria-hidden="true">
      {corners.map(([x, y]) => (
        <g key={`${x}-${y}`}>
          <rect x={x} y={y} width="36" height="36" rx="10" fill="none" stroke="#1B3A4B" strokeWidth={simple ? 12 : 9} />
          {!simple && <rect x={x + 11} y={y + 11} width="14" height="14" rx="4" fill="#1B3A4B" />}
        </g>
      ))}
      {simple ? (
        <circle cx="90" cy="90" r="16" fill="#BA5333" />
      ) : (
        <>
          <rect x="55" y="55" width="10" height="10" rx="3" fill="#1B3A4B" />
          <circle cx="90" cy="90" r="17" fill="none" stroke="#1B3A4B" strokeWidth="9" />
          <circle cx="90" cy="90" r="8" fill="#BA5333" />
          <line x1="103" y1="103" x2="110" y2="110" stroke="#1B3A4B" strokeWidth="9" strokeLinecap="round" />
        </>
      )}
    </svg>
  );
}

export function PoweredBy({ label }: { label: string }) {
  return (
    <div className="flex items-center justify-center gap-1.5 text-xs text-muted">
      <span>{label}</span>
      <span dir="ltr" className="flex items-center gap-[7px]" role="img" aria-label="Tawla">
        <TawlaMark size={18} />
        <span aria-hidden="true" className="font-[family-name:var(--font-jakarta)] text-xs font-extrabold tracking-[-0.05em] text-[#1B3A4B]">
          Tawla
        </span>
      </span>
    </div>
  );
}

export function PrimaryButton({
  children,
  onClick,
  disabled,
  busy,
  height = 56,
  type = "button",
  className = "",
}: {
  children: ReactNode;
  onClick?: () => void;
  disabled?: boolean;
  busy?: boolean;
  height?: number;
  type?: "button" | "submit";
  className?: string;
}) {
  return (
    <button
      type={type}
      onClick={onClick}
      disabled={disabled || busy}
      aria-busy={busy || undefined}
      style={{ minHeight: height }}
      className={`flex w-full items-center justify-center gap-2 rounded-[14px] bg-brand px-4 text-base font-extrabold text-on-brand transition-opacity disabled:bg-ink/10 disabled:text-ink/40 ${className}`}
    >
      {busy ? <Spinner /> : children}
    </button>
  );
}

export function OutlineButton({ children, onClick, height = 52 }: { children: ReactNode; onClick?: () => void; height?: number }) {
  return (
    <button
      type="button"
      onClick={onClick}
      style={{ minHeight: height }}
      className="flex w-full items-center justify-center rounded-xl border border-brand-ink px-3 text-[15px] font-extrabold text-brand-ink"
    >
      {children}
    </button>
  );
}

export function Spinner({ className = "" }: { className?: string }) {
  return (
    <span
      aria-hidden="true"
      className={`inline-block h-5 w-5 animate-spin rounded-full border-[2.2px] border-current border-t-transparent ${className}`}
    />
  );
}

export function EmptyHint({ children }: { children: ReactNode }) {
  return <p className="px-6 py-12 text-center text-muted">{children}</p>;
}

export function DishPhoto({ url, size, width, radius, priority }: { url: string; size: number; width?: number; radius: number; priority?: boolean }) {
  const value = url.trim();
  const w = width ?? size;
  const style = { height: size, borderRadius: radius, width: width ? "100%" : w };
  if (value.startsWith("https://")) {
    return (
      <div className="relative shrink-0 overflow-hidden bg-peach" style={style}>
        <Image
          src={value}
          alt=""
          fill
          sizes={width ? "(max-width: 430px) 100vw, 430px" : `${w}px`}
          className="object-cover"
          priority={priority}
        />
      </div>
    );
  }
  if (value.startsWith("data:image/")) {
    return (
      // eslint-disable-next-line @next/next/no-img-element -- photos saved inline by older app versions
      <img src={value} alt="" className="shrink-0 object-cover" style={style} />
    );
  }
  return (
    <div className="grid shrink-0 place-items-center bg-peach text-terracotta" style={style}>
      <Icon name="restaurant" size={Math.min(28, size / 2.5)} />
    </div>
  );
}
