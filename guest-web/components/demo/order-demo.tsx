"use client";

import { useEffect, useRef, useState, type FormEvent } from "react";
import { DishPhoto, GuestCard, GuestHeader, OutlineButton, PrimaryButton, TawlaMark, TicketLine } from "@/components/parts";
import { dishName, lineTotal, money, orderNumber } from "@/lib/format";
import { t, type Lang } from "@/lib/i18n";
import { demoCopy, sampleCafe, sampleMenu, sampleTable } from "./sample-order";

type DishId = (typeof sampleMenu)[number]["id"];
type Stage = "browse" | "review" | "sent";

const stages: Stage[] = ["browse", "review", "sent"];
const quantityButton = "press grid size-11 shrink-0 place-items-center rounded-xl bg-key text-lg font-extrabold text-brand-ink disabled:opacity-40";

export function OrderDemo({ initialLang }: { initialLang: Lang }) {
  const [lang, setLang] = useState(initialLang);
  const [stage, setStage] = useState<Stage>("browse");
  const [quantities, setQuantities] = useState<Partial<Record<DishId, number>>>({});
  const [note, setNote] = useState("");
  const heading = useRef<HTMLHeadingElement>(null);
  const focusHeading = useRef(false);
  const copy = demoCopy[lang];
  const rows = sampleMenu.flatMap((dish) => {
    const qty = quantities[dish.id] ?? 0;
    return qty ? [{ dish, qty, amount: lineTotal(dish.price, qty) }] : [];
  });
  const count = rows.reduce((sum, row) => sum + row.qty, 0);
  const total = rows.reduce((sum, row) => sum + row.amount, 0);

  useEffect(() => {
    const html = document.documentElement;
    const previous = { lang: html.lang, dir: html.dir };
    html.lang = lang;
    html.dir = lang === "ar" ? "rtl" : "ltr";
    return () => {
      html.lang = previous.lang;
      html.dir = previous.dir;
    };
  }, [lang]);

  useEffect(() => {
    if (focusHeading.current) {
      focusHeading.current = false;
      heading.current?.focus();
      heading.current?.scrollIntoView({ block: "nearest" });
    }
  }, [stage]);

  function goTo(next: Stage) {
    if (next === stage) return;
    focusHeading.current = true;
    setStage(next);
  }

  function switchLanguage() {
    const next = lang === "en" ? "ar" : "en";
    setLang(next);
    const url = new URL(window.location.href);
    if (next === "ar") url.searchParams.set("lang", "ar");
    else url.searchParams.delete("lang");
    window.history.replaceState(null, "", url);
  }

  function changeQuantity(id: DishId, delta: number) {
    setQuantities((previous) => ({
      ...previous,
      [id]: Math.max(0, Math.min(99, (previous[id] ?? 0) + delta)),
    }));
  }

  function reset() {
    setQuantities({});
    setNote("");
    goTo("browse");
  }

  function sendOrder(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (stage === "review" && count > 0) goTo("sent");
  }

  const ticket = (
    <GuestCard>
      <h3 className="mb-3 font-extrabold">{t(lang, "guestItemsInOrder", { count })}</h3>
      {rows.map(({ dish, qty, amount }) => (
        <TicketLine key={dish.id} qty={qty} name={dishName(dish, lang)} amount={money(amount, lang)} lang={lang} />
      ))}
      <div className="flex items-center justify-between gap-3 border-t border-hairline pt-3 font-extrabold">
        <span>{t(lang, "guestKitchenTicketTotal")}</span>
        <span className="whitespace-nowrap">{money(total, lang)}</span>
      </div>
    </GuestCard>
  );

  return (
    <div lang={lang} dir={lang === "ar" ? "rtl" : "ltr"} className="flex min-h-dvh flex-col">
      <header className="sticky top-0 z-20 border-b border-line bg-page">
        <div className="mx-auto flex min-h-14 max-w-5xl flex-wrap items-center justify-between gap-x-2 px-3 py-1 sm:px-6">
          <div className="flex items-center gap-2">
            <TawlaMark size={22} />
            <span className="rounded-full bg-peach px-2.5 py-1 text-xs font-extrabold text-terracotta-dark">{copy.label}</span>
          </div>
          <div className="flex items-center gap-1 text-xs font-extrabold text-brand-header sm:gap-3">
            <button type="button" onClick={switchLanguage} lang={lang === "en" ? "ar" : "en"} className="min-h-11 rounded-lg px-2 hover:bg-key">
              {lang === "en" ? "العربية" : "English"}
            </button>
            <button type="button" onClick={reset} className="min-h-11 rounded-lg px-2 hover:bg-key">{copy.reset}</button>
          </div>
        </div>
      </header>

      <main className="mx-auto w-full max-w-5xl flex-1 px-3 pt-4 pb-6 sm:px-6 sm:pt-6">
        <div className="overflow-hidden rounded-[18px]">
          <GuestHeader cafeName={sampleCafe[lang]} logoUrl="" subtitle={t(lang, "guestTableDineIn", { number: sampleTable })} />
        </div>

        <ol aria-label={copy.progress} className="my-4 grid grid-cols-3 gap-1 rounded-xl bg-key p-1 text-center text-xs font-extrabold sm:text-sm">
          {stages.map((step) => (
            <li key={step} aria-current={step === stage ? "step" : undefined}
              className={step === stage ? "rounded-lg bg-brand-header px-1 py-2 text-on-header" : "px-1 py-2 text-muted"}>
              {copy[step]}
            </li>
          ))}
        </ol>

        <div className={stage === "browse" ? "" : "mx-auto max-w-xl"}>
          <h2 ref={heading} tabIndex={-1} className="scroll-mt-28 rounded text-2xl font-extrabold text-brand-header">
            {copy[stage]}
          </h2>
          <p className="mt-1 mb-4 text-sm leading-relaxed text-muted">
            {stage === "browse" ? copy.browseHint : stage === "review" ? copy.reviewHint : copy.sentHint}
          </p>

          {stage === "browse" && (
            <ul className="grid gap-3 sm:grid-cols-2">
              {sampleMenu.map((dish) => {
                const qty = quantities[dish.id] ?? 0;
                const name = dishName(dish, lang);
                return (
                  <li key={dish.id} className="flex [&>section]:flex [&>section]:flex-col">
                    <GuestCard className="border border-line">
                      <div className="flex flex-1 items-start gap-3">
                        <DishPhoto url="" size={54} radius={12} />
                        <div className="min-w-0">
                          <h3 className="font-extrabold">{name}</h3>
                          <p className="mt-0.5 text-sm leading-relaxed text-muted">{dish.description[lang]}</p>
                        </div>
                      </div>
                      <div className="mt-3 flex items-center justify-between gap-2">
                        <span className="font-extrabold whitespace-nowrap text-brand-header">{money(dish.price, lang)}</span>
                        <div className="flex items-center gap-2">
                          {qty > 0 && (
                            <>
                              <button type="button" className={quantityButton} aria-label={`${t(lang, "decrease")} · ${name}`}
                                onClick={() => changeQuantity(dish.id, -1)}>−</button>
                              <span className="min-w-5 text-center text-sm font-extrabold tabular-nums">{qty}</span>
                            </>
                          )}
                          <button type="button" className={quantityButton} aria-label={t(lang, "addDish", { name })}
                            disabled={qty === 99} onClick={() => changeQuantity(dish.id, 1)}>+</button>
                        </div>
                      </div>
                    </GuestCard>
                  </li>
                );
              })}
            </ul>
          )}

          {stage === "review" && (
            <form onSubmit={sendOrder} className="space-y-3">
              {ticket}
              <GuestCard>
                <label htmlFor="demo-note" className="block text-sm font-extrabold">{copy.note}</label>
                <textarea id="demo-note" value={note} onChange={(event) => setNote(event.target.value)} maxLength={160}
                  placeholder={copy.notePlaceholder} rows={2} dir="auto"
                  className="mt-2 w-full resize-y rounded-xl border border-border bg-page px-3 py-2 text-base" />
              </GuestCard>
              <PrimaryButton type="submit">{t(lang, "guestConfirmSendKitchen")}</PrimaryButton>
              <OutlineButton onClick={() => goTo("browse")}>{t(lang, "guestModifyOrder")}</OutlineButton>
            </form>
          )}

          {stage === "sent" && (
            <div className="space-y-3">
              <div role="status" className="flex flex-wrap items-center justify-between gap-2 rounded-xl bg-brand-header px-4 py-3 font-extrabold text-on-header">
                <span>{t(lang, "guestOrderNumber", { id: orderNumber(12) })}</span>
                <span>{t(lang, "guestStatusReceived")}</span>
              </div>
              {ticket}
              {note.trim() && (
                <GuestCard>
                  <h3 className="text-sm font-extrabold">{copy.note}</h3>
                  <p dir="auto" className="mt-1 wrap-anywhere whitespace-pre-wrap text-sm text-muted">{note.trim()}</p>
                </GuestCard>
              )}
              <OutlineButton onClick={reset}>{copy.done}</OutlineButton>
            </div>
          )}
        </div>
      </main>

      {stage === "browse" && (
        <footer className="sticky bottom-0 z-10 border-t border-line bg-white pb-[env(safe-area-inset-bottom)]">
          <div className="mx-auto flex max-w-5xl items-center justify-between gap-2 px-3 py-2.5 sm:px-6">
            <div role="status" className="text-xs text-muted sm:text-sm">
              <p>{count > 0 ? t(lang, "guestItemsInOrder", { count }) : copy.empty}</p>
              <p className="font-extrabold whitespace-nowrap text-brand-header">{money(total, lang)}</p>
            </div>
            <PrimaryButton height={46} className="max-w-44 sm:max-w-56" disabled={count === 0} onClick={() => goTo("review")}>
              {copy.review}
            </PrimaryButton>
          </div>
        </footer>
      )}
    </div>
  );
}
