"use client";

import { useRouter } from "next/navigation";
import { useEffect, useMemo, useState } from "react";
import { MAX_QTY, defaultOn, dishQty, lineChoices, lineKey, linePrice, normalizeOn } from "@/lib/cart";
import { categoryName, dishName, hasDiscount, money } from "@/lib/format";
import type { DishOption, MenuItem } from "@/lib/types";
import { BottomNav, Header, RefusalNotice, Sheet, Toast } from "./chrome";
import { useGuest } from "./guest-provider";
import { Icon } from "./icons";
import { useReducedMotion } from "./landing/use-motion";
import { ChoiceNotes, DishPhoto, EmptyHint, PoweredBy, PrimaryButton, Spinner } from "./parts";

type Filter = { kind: "all" } | { kind: "chef" } | { kind: "category"; id: string };

export function MenuScreen() {
  const guest = useGuest();
  const { menu, lang, text, checkLocation, status } = guest;
  const [filter, setFilter] = useState<Filter>({ kind: "all" });
  const [dish, setDish] = useState<MenuItem | null>(null);
  const [verifying, setVerifying] = useState(false);
  const reduced = useReducedMotion();
  const grid = menu.cafe.menuLayout === "grid";

  const locationEnabled = status?.location.enabled ?? false;
  useEffect(() => {
    if (locationEnabled) void checkLocation();
  }, [locationEnabled, checkLocation]);

  const items = useMemo(
    () =>
      menu.items.filter((item) =>
        filter.kind === "chef" ? item.featured : filter.kind === "category" ? item.categoryId === filter.id : true,
      ),
    [menu.items, filter],
  );
  const featured = menu.items.find((item) => item.featured);
  const sections = menu.categories
    .map((category) => ({ category, dishes: items.filter((item) => item.categoryId === category.id) }))
    .filter((section) => section.dishes.length > 0);
  const showHeadings = sections.length > 1;
  // Picking a filter: centre its chip, bring the list's top back under the pinned chips, and
  // let the new list settle in, so the swap reads as one change rather than a jump.
  // Nodes are found from the chip itself, as this only runs on a tap.
  const pick = (next: Filter, chipNode: HTMLElement) => {
    setFilter(next);
    const behavior = reduced ? "auto" : "smooth";
    chipNode.scrollIntoView?.({ behavior, inline: "center", block: "nearest" });
    const main = chipNode.closest("main");
    const title = main?.querySelector("h2");
    if (title) {
      const listTop = title.getBoundingClientRect().bottom + window.scrollY;
      if (window.scrollY > listTop) window.scrollTo({ top: listTop, behavior: "auto" });
    }
    if (!reduced) {
      main?.querySelector<HTMLElement>("[data-menu-list]")?.animate?.(
        [{ opacity: 0, transform: "translateY(6px)" }, { opacity: 1, transform: "none" }],
        { duration: 220, easing: "cubic-bezier(0.23, 1, 0.32, 1)" },
      );
    }
  };
  const chip = (label: string, selected: boolean, next: Filter) => (
    <FilterChip
      key={label + (next.kind === "category" ? next.id : next.kind)}
      label={label}
      selected={selected}
      onPick={(node) => pick(next, node)}
    />
  );

  return (
    <div className="mx-auto flex min-h-dvh max-w-[430px] flex-col bg-page">
      <Header />
      <LocationBanner />
      <RefusalNotice />
      <main className="flex-1">
        <h2 className="px-4 pt-[18px] text-[21px] font-extrabold tracking-tight min-[360px]:text-2xl">{text("guestMenuTitle", { name: menu.cafe.name })}</h2>
        <div
          className="no-scrollbar sticky top-0 z-10 flex gap-2 overflow-x-auto bg-page/95 px-4 py-2.5 backdrop-blur-sm"
          role="group"
          aria-label={text("guestMenuTitle", { name: menu.cafe.name })}
        >
          {menu.categories.length > 0 && chip(text("guestCategoryAll"), filter.kind === "all", { kind: "all" })}
          {chip(text("guestChefsSpecials"), filter.kind === "chef", { kind: "chef" })}
          {menu.categories.map((category) =>
            chip(categoryName(category, lang), filter.kind === "category" && filter.id === category.id, {
              kind: "category",
              id: category.id,
            }),
          )}
        </div>
        {menu.items.length === 0 ? (
          <EmptyHint>{text("noMenu")}</EmptyHint>
        ) : (
          <div data-menu-list>
            {featured && filter.kind !== "category" && (
              <div className="px-4 pt-0.5 pb-1">
                <Spotlight item={featured} onOpen={() => setDish(featured)} />
              </div>
            )}
            <p className="px-4 pt-3 pb-2.5 text-[13px] font-bold text-muted">{text("guestItemCount", { count: items.length })}</p>
            {sections.map(({ category, dishes }) => (
              <section key={category.id} aria-labelledby={showHeadings ? `cat-${category.id}` : undefined}>
                {showHeadings && (
                  <h3 id={`cat-${category.id}`} className="px-4 pt-1.5 pb-2.5 text-base font-extrabold">
                    {categoryName(category, lang)}
                  </h3>
                )}
                {grid ? (
                  <ul className="mb-2.5 grid grid-cols-2 gap-2.5 px-4">
                    {dishes.map((item, index) => (
                      <DishCard key={item.id} item={item} priority={index < 4} onOpen={() => setDish(item)} />
                    ))}
                  </ul>
                ) : (
                  <ul className="px-4">
                    {dishes.map((item, index) => (
                      <DishRow key={item.id} item={item} priority={index < 4} onOpen={() => setDish(item)} />
                    ))}
                  </ul>
                )}
              </section>
            ))}
            <div className="px-4 pt-2.5 pb-6">
              <PoweredBy label={text("guestPoweredBy")} />
            </div>
          </div>
        )}
      </main>
      <CartBar onOpen={() => setVerifying(true)} />
      <BottomNav />
      <Toast />
      {dish && <DishSheet item={dish} onClose={() => setDish(null)} />}
      {verifying && <VerifySheet onClose={() => setVerifying(false)} />}
    </div>
  );
}

function FilterChip({ label, selected, onPick }: { label: string; selected: boolean; onPick: (node: HTMLElement) => void }) {
  return (
    <button
      type="button"
      aria-pressed={selected}
      onClick={(event) => onPick(event.currentTarget)}
      className={`press min-h-[44px] shrink-0 rounded-[20px] border-[1.5px] px-4 text-sm font-bold whitespace-nowrap ${
        selected ? "border-brand bg-brand text-on-brand" : "border-border bg-white text-ink"
      }`}
    >
      {label}
    </button>
  );
}

function Price({ item, size }: { item: MenuItem; size: number }) {
  const { lang } = useGuest();
  if (!hasDiscount(item)) {
    return (
      <span className="font-extrabold whitespace-nowrap text-brand-header" style={{ fontSize: size }}>
        {money(item.salePrice, lang)}
      </span>
    );
  }
  return (
    <span className="inline-flex flex-wrap items-center gap-x-1.5">
      <del className="font-semibold whitespace-nowrap text-muted" style={{ fontSize: size * 0.85 }}>
        {money(item.price, lang)}
      </del>
      <span className="font-extrabold whitespace-nowrap text-brand-ink" style={{ fontSize: size }}>
        {money(item.salePrice, lang)}
      </span>
    </span>
  );
}

function Badge({ children }: { children: string }) {
  return (
    <span className="inline-flex h-6 items-center rounded-xl bg-brand px-2.5 text-[11px] font-extrabold tracking-[0.1em] text-on-brand uppercase">
      {children}
    </span>
  );
}

function Spotlight({ item, onOpen }: { item: MenuItem; onOpen: () => void }) {
  const { menu, lang, text } = useGuest();
  const category = menu.categories.find((c) => c.id === item.categoryId);
  const name = dishName(item, lang);
  return (
    <button
      type="button"
      onClick={onOpen}
      disabled={!item.available}
      aria-label={name}
      className="press block w-full overflow-hidden rounded-[18px] bg-white text-start shadow-[0_2px_10px_rgba(27,58,75,0.08)]"
    >
      <div className="relative">
        <DishPhoto url={item.imageUrl} size={150} width={430} radius={0} priority />
        <span className="absolute start-3 top-3">
          <Badge>{text("guestSpotlight")}</Badge>
        </span>
      </div>
      <div className="flex items-center gap-2.5 px-4 py-3.5">
        <div className="min-w-0 flex-1">
          <p className={`truncate text-lg font-extrabold ${item.available ? "text-ink" : "text-muted line-through"}`}>{name}</p>
          <p className={`text-[13px] ${item.available ? "text-muted" : "font-bold text-brand-ink"}`}>
            {item.available ? (category ? categoryName(category, lang) : text("guestChefsSpecials")) : text("cashierNotAvailable")}
          </p>
        </div>
        <Price item={item} size={16} />
      </div>
    </button>
  );
}

function DishRow({ item, onOpen, priority }: { item: MenuItem; onOpen: () => void; priority: boolean }) {
  const { lang, text } = useGuest();
  const name = dishName(item, lang);
  return (
    <li className="mb-2.5 flex items-center rounded-2xl bg-white p-2.5">
      <button
        type="button"
        onClick={onOpen}
        disabled={!item.available}
        className="flex min-w-0 flex-1 items-center gap-3 text-start"
      >
        <DishPhoto url={item.imageUrl} size={68} radius={12} priority={priority} />
        <span className="min-w-0 flex-1">
          <span className={`line-clamp-2 text-base font-bold ${item.available ? "text-ink" : "text-muted line-through"}`}>{name}</span>
          <span className="mt-[3px] block">
            {item.available ? (
              <Price item={item} size={15} />
            ) : (
              <span className="text-xs font-extrabold text-brand-ink">{text("cashierNotAvailable")}</span>
            )}
          </span>
        </span>
      </button>
      <InCartBadge item={item} className="ms-2" />
      <AddButton item={item} className="ms-3" />
    </li>
  );
}

// The photo grid (the cafe's "Photo grid" menu design): two cards per row, the photo on top and
// the add button sitting on its corner.
function DishCard({ item, onOpen, priority }: { item: MenuItem; onOpen: () => void; priority: boolean }) {
  const { lang, text } = useGuest();
  const name = dishName(item, lang);
  return (
    <li className="relative flex flex-col overflow-hidden rounded-2xl bg-white">
      <button type="button" onClick={onOpen} disabled={!item.available} className="press flex flex-1 flex-col text-start">
        <span className={`block w-full ${item.available ? "" : "opacity-50"}`}>
          <DishPhoto url={item.imageUrl} size={128} width={215} radius={0} priority={priority} />
        </span>
        <span className="flex flex-1 flex-col px-3 pt-2.5 pb-3 pe-14">
          <span className={`line-clamp-2 text-[15px] leading-snug font-bold ${item.available ? "text-ink" : "text-muted line-through"}`}>{name}</span>
          <span className="mt-auto block pt-1">
            {item.available ? (
              <Price item={item} size={14} />
            ) : (
              <span className="text-xs font-extrabold text-brand-ink">{text("cashierNotAvailable")}</span>
            )}
          </span>
        </span>
      </button>
      <InCartBadge item={item} className="absolute end-2 top-2" />
      <AddButton item={item} className="absolute end-2.5 bottom-2.5" />
    </li>
  );
}

function InCartBadge({ item, className }: { item: MenuItem; className: string }) {
  const { text, cart } = useGuest();
  const inCart = dishQty(cart, item.id);
  if (inCart === 0) return null;
  return (
    <span
      key={inCart}
      className={`pop-in grid h-[26px] min-w-[26px] place-items-center rounded-[13px] bg-brand-header px-1.5 text-xs font-extrabold text-on-header ${className}`}
      aria-label={text("inCart", { count: inCart })}
    >
      {inCart}
    </span>
  );
}

function AddButton({ item, className }: { item: MenuItem; className: string }) {
  const { lang, text, add, canPlaceOrder, blockedMessage, showToast } = useGuest();
  return (
    <button
      type="button"
      aria-label={text("addDish", { name: dishName(item, lang) })}
      disabled={!item.available}
      aria-disabled={item.available && !canPlaceOrder ? true : undefined}
      onClick={() => {
        if (!canPlaceOrder) {
          if (blockedMessage) showToast(blockedMessage);
          return;
        }
        // The dish as it comes; choices are made in the sheet.
        add(item);
      }}
      className={`press grid h-11 w-11 shrink-0 place-items-center rounded-full ${
        item.available && canPlaceOrder ? "bg-brand text-on-brand" : "bg-ink/10 text-ink/40"
      } ${className}`}
    >
      <Icon name="add" size={22} />
    </button>
  );
}

function LocationBanner() {
  const { blockedMessage, location, text, checkLocation, status } = useGuest();
  if (!blockedMessage) return null;
  const orderingOpen = status?.orderingOpen ?? true;
  const retry = orderingOpen && (location === "denied" || location === "unavailable" || location === "tooFar");
  return (
    <div className="px-4 pt-3">
      <div role="status" className="rounded-xl bg-soft-accent px-3.5 py-3">
        <p className="leading-snug font-bold text-terracotta-dark">{blockedMessage}</p>
        {orderingOpen && location === "denied" && <p className="mt-1 text-xs leading-tight text-muted">{text("guestLocationIosHint")}</p>}
        {retry && (
          <button type="button" onClick={() => void checkLocation(true)} className="mt-1.5 min-h-[44px] font-extrabold text-brand-ink">
            {location === "denied" ? text("guestLocationAllow") : text("guestLocationRetry")}
          </button>
        )}
      </div>
    </div>
  );
}

function CartBar({ onOpen }: { onOpen: () => void }) {
  const { count, total, lang, text, canPlaceOrder, blockedMessage, showToast } = useGuest();
  if (count === 0) return null;
  return (
    <div className="rise-in sticky bottom-[68px] z-10 px-3 pt-2 pb-3">
      <button
        type="button"
        onClick={() => {
          if (!canPlaceOrder) {
            if (blockedMessage) showToast(blockedMessage);
            return;
          }
          onOpen();
        }}
        aria-disabled={!canPlaceOrder || undefined}
        className={`press flex min-h-[60px] w-full items-center gap-2.5 rounded-2xl px-[18px] shadow-[0_4px_12px_rgba(0,0,0,0.16)] ${
          canPlaceOrder ? "bg-brand text-on-brand" : "bg-[#e9e7e3] text-ink/60"
        }`}
      >
        <span className="min-w-0 flex-1 truncate text-start text-sm font-bold">
          {text("guestCartItemCount", { count })} · {money(total, lang)}
        </span>
        <span className="text-[15px] font-extrabold">{text("guestViewOrder")}</span>
        <Icon name="chevron" size={22} />
      </button>
    </div>
  );
}

function Stepper({ value, onChange, min = 1, label }: { value: number; onChange: (v: number) => void; min?: number; label: string }) {
  const { text } = useGuest();
  return (
    <div className="flex items-center" role="group" aria-label={label}>
      <button
        type="button"
        aria-label={text("decrease")}
        disabled={value <= min}
        onClick={() => onChange(Math.max(min, value - 1))}
        className="press grid h-11 w-11 place-items-center rounded-full border-[1.5px] border-brand-ink text-brand-ink disabled:opacity-40"
      >
        <Icon name="remove" size={20} />
      </button>
      <span className="w-[38px] text-center text-lg font-extrabold" aria-live="polite">
        {value}
      </span>
      <button
        type="button"
        aria-label={text("increase")}
        disabled={value >= MAX_QTY}
        onClick={() => onChange(Math.min(MAX_QTY, value + 1))}
        className="press grid h-11 w-11 place-items-center rounded-full bg-brand text-on-brand disabled:opacity-40"
      >
        <Icon name="add" size={20} />
      </button>
    </div>
  );
}

// Ingredients the guest can remove or add, or extras they can add. A price shows only on an
// option that is off by default, because only turning one of those on is charged.
function OptionGroup({ title, options, on, onToggle }: { title: string; options: DishOption[]; on: string[]; onToggle: (id: string) => void }) {
  const { lang } = useGuest();
  if (options.length === 0) return null;
  return (
    <fieldset className="mt-3.5 rounded-[14px] bg-white px-3.5 pt-3 pb-1">
      <legend className="float-start w-full text-xs font-extrabold tracking-[0.12em] text-muted">{title}</legend>
      {options.map((option) => (
        <label key={option.id} className="flex min-h-[44px] items-center gap-3 border-t border-hairline first-of-type:border-0">
          <input
            type="checkbox"
            checked={on.includes(option.id)}
            onChange={() => onToggle(option.id)}
            className="h-5 w-5 shrink-0 accent-brand"
          />
          <span className="min-w-0 flex-1 text-[15px] font-bold">{dishName(option, lang)}</span>
          {!option.defaultOn && option.price > 0 && (
            <span className="text-sm font-bold whitespace-nowrap text-muted">+{money(option.price, lang)}</span>
          )}
        </label>
      ))}
    </fieldset>
  );
}

function DishSheet({ item, onClose }: { item: MenuItem; onClose: () => void }) {
  const { lang, text, add, canPlaceOrder, blockedMessage, showToast, cart } = useGuest();
  const [qty, setQty] = useState(1);
  const [on, setOn] = useState<string[]>(() => defaultOn(item));
  const name = dishName(item, lang);
  const otherName = dishName(item, lang === "ar" ? "en" : "ar");
  const room = MAX_QTY - (cart[lineKey(item, on)]?.qty ?? 0);
  const unitPrice = linePrice(item, on);
  const toggle = (id: string) =>
    setOn((current) => normalizeOn(item, current.includes(id) ? current.filter((x) => x !== id) : [...current, id]));
  return (
    <Sheet label={name} onClose={onClose}>
      {(close) => (
        <>
          <div className="relative">
            <DishPhoto url={item.imageUrl} size={200} width={430} radius={0} />
            <button
              type="button"
              onClick={close}
              aria-label={text("close")}
              className="press absolute end-3 top-3 grid h-11 w-11 place-items-center rounded-full bg-white/90 text-ink shadow-sm"
            >
              <Icon name="close" size={20} />
            </button>
            {item.featured && (
              <span className="absolute start-3.5 bottom-3.5">
                <Badge>{text("guestChefsPick")}</Badge>
              </span>
            )}
          </div>
          <div className="px-[18px] pt-[18px] pb-6">
            <div className="flex items-start gap-2.5">
              <div className="min-w-0 flex-1">
                <h2 className="text-[22px] font-extrabold">{name}</h2>
                {otherName !== name && <p className="mt-0.5 text-[15px] text-muted">{otherName}</p>}
              </div>
              <div className="pt-1">
                <Price item={item} size={18} />
              </div>
            </div>
            {item.description && <p className="mt-2.5 leading-relaxed text-muted">{item.description}</p>}
            <OptionGroup
              title={text("guestIngredients")}
              options={item.options.filter((o) => o.kind === "ingredient")}
              on={on}
              onToggle={toggle}
            />
            <OptionGroup
              title={text("guestExtras")}
              options={item.options.filter((o) => o.kind === "topping")}
              on={on}
              onToggle={toggle}
            />
            <div className="mt-3.5 flex items-center rounded-[14px] bg-white px-3.5 py-3">
              <div className="flex-1">
                <p className="text-xs font-extrabold tracking-[0.12em] text-muted">{text("guestQuantity")}</p>
                <p className="mt-0.5 text-[13px] text-muted">{text("guestPortionServing")}</p>
              </div>
              <Stepper value={qty} onChange={(v) => setQty(Math.min(v, Math.max(1, room)))} label={text("guestQuantity")} />
            </div>
            <div className="mt-3.5">
              <PrimaryButton
                height={58}
                disabled={room <= 0}
                onClick={() => {
                  if (!canPlaceOrder) {
                    if (blockedMessage) showToast(blockedMessage);
                    return;
                  }
                  add(item, on, qty);
                  close();
                }}
                className={canPlaceOrder ? "" : "!bg-ink/10 !text-ink/40"}
              >
                {text("guestAddToOrder", { amount: money(unitPrice * qty, lang) })}
              </PrimaryButton>
            </div>
          </div>
        </>
      )}
    </Sheet>
  );
}

// "Verify Your Order": last look at this phone's cart before it goes to the kitchen.
function VerifySheet({ onClose }: { onClose: () => void }) {
  const { lines, lang, text, menu, setQty, sendOrder, href } = useGuest();
  const router = useRouter();
  // Quantities by cart line key: the same dish with other choices is its own row.
  const [draft, setDraft] = useState<Record<string, number>>(() =>
    Object.fromEntries(lines.map((line) => [line.key, line.qty])),
  );
  const [sending, setSending] = useState(false);
  const visible = lines.filter((line) => (draft[line.key] ?? 0) > 0);
  const count = visible.reduce((sum, line) => sum + draft[line.key], 0);
  const subtotal = visible.reduce((sum, line) => sum + linePrice(line.item, line.on) * draft[line.key], 0);

  const send = async () => {
    if (sending) return;
    setSending(true);
    for (const line of lines) setQty(line.key, draft[line.key] ?? 0);
    // `on` only for dishes that have options, so a plain dish is sent exactly as before.
    const send = visible.map((line) => ({
      menuItemId: line.item.id,
      qty: draft[line.key],
      ...(line.item.options.length > 0 ? { on: line.on } : {}),
    }));
    if (send.length === 0) {
      onClose();
      return;
    }
    const ok = await sendOrder(send);
    setSending(false);
    if (ok) {
      onClose();
      router.push(href("/tab"));
    }
  };

  return (
    <Sheet label={text("guestConfirmOrderTitle")} onClose={onClose} locked={sending} floating>
      {(close) => (
        <>
          <div className="mx-auto mt-2.5 h-1 w-10 rounded bg-line" aria-hidden="true" />
          <div className="flex items-start px-4 pt-3 pb-2">
            <div className="min-w-0 flex-1">
              <div className="flex items-center gap-2">
                <span className="rounded-full bg-peach px-2 py-[3px] text-xs font-bold text-terracotta-dark">
                  {text("guestTableNumber", { number: menu.table.number })}
                </span>
                <span className="truncate text-xs text-ink-muted">{text("guestDineInOrder")}</span>
              </div>
              <h2 className="mt-1.5 text-[26px] font-extrabold">{text("guestConfirmOrderTitle")}</h2>
            </div>
            <button
              type="button"
              onClick={close}
              disabled={sending}
              aria-label={text("guestCloseReview")}
              className="grid h-11 w-11 place-items-center rounded-full text-ink"
            >
              <Icon name="close" size={18} />
            </button>
          </div>
          <div className="px-4 pb-2">
            <p className="font-bold tracking-wide text-ink-muted">{text("guestItemsInOrder", { count })}</p>
            <ul className="mt-2">
              {visible.map(({ key, item, on }) => {
                const qty = draft[key];
                const name = dishName(item, lang);
                return (
                  <li key={key} className="mb-2 flex items-center rounded-2xl bg-key p-3">
                    <div className="min-w-0 flex-1">
                      <p className="font-bold">{name}</p>
                      <ChoiceNotes choices={lineChoices(item, on)} lang={lang} />
                      <p className="font-extrabold">{money(linePrice(item, on) * qty, lang)}</p>
                    </div>
                    <div className="flex items-center rounded-full bg-white" role="group" aria-label={name}>
                      <button
                        type="button"
                        aria-label={text("decrease")}
                        disabled={sending}
                        onClick={() => setDraft((d) => ({ ...d, [key]: qty - 1 }))}
                        className="grid h-11 w-11 place-items-center"
                      >
                        <Icon name="remove" size={16} />
                      </button>
                      <span className="min-w-4 text-center font-extrabold">{qty}</span>
                      <button
                        type="button"
                        aria-label={text("increase")}
                        disabled={sending || qty >= MAX_QTY}
                        onClick={() => setDraft((d) => ({ ...d, [key]: Math.min(MAX_QTY, qty + 1) }))}
                        className="grid h-11 w-11 place-items-center disabled:opacity-40"
                      >
                        <Icon name="add" size={16} />
                      </button>
                    </div>
                  </li>
                );
              })}
            </ul>
            <div className="rounded-2xl bg-cream-dark p-3.5">
              <div className="flex">
                <span className="flex-1 text-ink-muted">{text("guestSubtotal")}</span>
                <span className="font-bold">{money(subtotal, lang)}</span>
              </div>
              <div className="mt-2 flex items-center">
                <div className="flex-1">
                  <p className="font-extrabold">{text("guestTotalDue")}</p>
                  <p className="text-xs text-ink-muted">{text("guestBilledToTable", { table: menu.table.number })}</p>
                </div>
                <span className="text-xl font-extrabold text-terracotta-dark">{money(subtotal, lang)}</span>
              </div>
            </div>
          </div>
          <div className="px-4 pt-2 pb-3">
            <button
              type="button"
              onClick={() => void send()}
              disabled={sending || count === 0}
              className="flex min-h-[52px] w-full items-center justify-center gap-2 rounded-xl bg-brand text-base font-extrabold text-on-brand disabled:opacity-60"
            >
              {sending ? <Spinner className="h-[18px] w-[18px]" /> : <Icon name="restaurant" size={18} />}
              {sending ? text("guestSendingOrder") : text("guestConfirmSendKitchen")}
            </button>
            <button
              type="button"
              onClick={close}
              disabled={sending}
              className="mt-1 flex min-h-[44px] w-full items-center justify-center gap-1.5 text-sm font-bold text-brand-ink"
            >
              <Icon name="back" size={16} />
              {text("guestModifyOrder")}
            </button>
          </div>
        </>
      )}
    </Sheet>
  );
}
