"use client";

import { useRouter } from "next/navigation";
import { lineChoices, linePrice } from "@/lib/cart";
import { dishName, lineTotal, money, orderNumber, tripoliTime } from "@/lib/format";
import type { TabLine } from "@/lib/types";
import { BottomNav, Header, RefusalNotice, Toast } from "./chrome";
import { useGuest } from "./guest-provider";
import { Icon } from "./icons";
import { ChoiceNotes, EmptyHint, Eyebrow, GuestCard, OutlineButton, PrimaryButton, TicketLine } from "./parts";

const STEPS = ["received", "preparing", "ready", "served"] as const;

export function useLineName() {
  const { menu, lang } = useGuest();
  return (line: Pick<TabLine, "menuItemId" | "name">) => {
    const item = menu.items.find((i) => i.id === line.menuItemId);
    return item ? dishName(item, lang) : line.name;
  };
}

export function subtotalOf(lines: TabLine[]): number {
  return Math.round(lines.reduce((sum, l) => sum + l.unitPrice * l.qty, 0) * 1000) / 1000;
}

function StatusSteps({ status }: { status: string }) {
  const { text } = useGuest();
  const labels = [text("guestStatusReceived"), text("guestStatusPreparing"), text("guestStatusReady"), text("guestStatusServed")];
  const current = Math.max(0, Math.min(3, STEPS.indexOf(status as (typeof STEPS)[number])));
  return (
    <ol className="flex items-start" aria-label={labels[current]}>
      {labels.map((label, index) => {
        const reached = index <= current;
        const done = index < current;
        return (
          <li key={label} className="flex flex-1 flex-col items-center" aria-current={index === current ? "step" : undefined}>
            <div className="relative flex h-9 w-full items-center">
              <span className={`h-[3px] flex-1 motion-safe:transition-colors motion-safe:duration-300 ${index === 0 ? "bg-transparent" : reached ? "bg-brand" : "bg-border"}`} />
              <span className={`h-[3px] flex-1 motion-safe:transition-colors motion-safe:duration-300 ${index === 3 ? "bg-transparent" : index < current ? "bg-brand" : "bg-border"}`} />
              <span
                className={`absolute start-1/2 grid motion-safe:transition-colors motion-safe:duration-300 h-7 w-7 -translate-x-1/2 rtl:translate-x-1/2 place-items-center rounded-full text-xs font-extrabold ${
                  reached ? "bg-brand text-on-brand" : "bg-step-idle text-ink"
                } ${index === current && !done ? "ring-4 ring-brand/20" : ""}`}
                aria-hidden="true"
              >
                {done ? <Icon name="check" size={15} /> : index + 1}
              </span>
            </div>
            <span className={`mt-1 text-center text-xs font-bold ${reached ? "text-ink" : "text-[#5f6d75]"}`}>{label}</span>
          </li>
        );
      })}
    </ol>
  );
}

// The live tab (today's /t/<slug>/cart): order status, this phone's unsent dishes, totals.
export function TabScreen() {
  const { tab, lines, lang, text, setQty, canPlaceOrder, blockedMessage, showToast, callStaff, href, status } = useGuest();
  const router = useRouter();
  const lineName = useLineName();
  const order = tab?.order ?? null;
  const canBill = order?.status === "served" && lines.length === 0;
  const total = subtotalOf(order?.lines ?? []) + lines.reduce((s, l) => s + linePrice(l.item, l.on) * l.qty, 0);

  return (
    <div className="mx-auto flex min-h-dvh max-w-[430px] flex-col bg-page">
      <Header />
      <RefusalNotice />
      <main className="flex-1 space-y-3.5 px-4 pt-[18px] pb-6">
        {tab === null ? null : !order && lines.length === 0 ? (
          <div className="pt-12">
            <EmptyHint>{text("noOrders")}</EmptyHint>
          </div>
        ) : (
          <>
            {order && (
              <GuestCard>
                <div className="flex items-center gap-2">
                  <Eyebrow>{text("guestLiveTab")}</Eyebrow>
                  <p className="flex-1 truncate text-end text-[13px] text-muted">
                    {text("guestSentToKitchenAt", { time: tripoliTime(order.createdAt) })}
                  </p>
                </div>
                <h2 className="mt-0.5 text-[22px] font-extrabold">{text("guestOrderNumber", { id: orderNumber(order.orderNumber) })}</h2>
                <div className="mt-4">
                  <StatusSteps status={order.status} />
                </div>
                {(order.status === "received" || order.status === "preparing") && (
                  <p className="mt-3.5 rounded-xl bg-soft-accent px-3.5 py-3 text-sm leading-relaxed font-bold whitespace-pre-line text-terracotta-dark">
                    {text("guestKitchenPreparing")}
                  </p>
                )}
              </GuestCard>
            )}
            {lines.length > 0 && (
              <GuestCard className="!pb-2.5">
                <h3 className="text-[13px] font-extrabold text-muted">{text("guestNewAdditions")}</h3>
                <ul className="mt-1.5">
                  {lines.map(({ key, item, on, qty }) => (
                    <li key={key} className="flex items-center border-t border-hairline py-1">
                      <span className="min-w-0 flex-1 text-[15px] font-bold">
                        {dishName(item, lang)}
                        <ChoiceNotes choices={lineChoices(item, on)} lang={lang} />
                      </span>
                      {[
                        { icon: "remove" as const, label: text("decrease"), next: qty - 1 },
                        { icon: "add" as const, label: text("increase"), next: qty + 1 },
                      ].map((b, i) => (
                        <span key={b.icon} className="contents">
                          {i === 1 && <span className="text-[15px] font-extrabold">{qty}</span>}
                          <button
                            type="button"
                            aria-label={`${b.label} ${dishName(item, lang)}`}
                            onClick={() => (canPlaceOrder ? setQty(key, b.next) : blockedMessage && showToast(blockedMessage))}
                            className={`press grid h-11 w-11 place-items-center ${canPlaceOrder ? "text-brand-ink" : "text-muted"}`}
                          >
                            <Icon name={b.icon} size={18} />
                          </button>
                        </span>
                      ))}
                      <span className="ms-1 text-[15px] font-bold whitespace-nowrap">{money(lineTotal(linePrice(item, on), qty), lang)}</span>
                    </li>
                  ))}
                </ul>
              </GuestCard>
            )}
            <GuestCard>
              <h3 className="pb-1.5 text-[13px] font-extrabold text-muted">{text("guestTicketSummary")}</h3>
              {order?.lines.map((line) => (
                <TicketLine
                  key={line.id}
                  qty={line.qty}
                  name={lineName(line)}
                  choices={line.choices}
                  lang={lang}
                  amount={money(lineTotal(line.unitPrice, line.qty), lang)}
                />
              ))}
              {lines.map(({ key, item, on, qty }) => (
                <TicketLine
                  key={`new-${key}`}
                  qty={qty}
                  name={dishName(item, lang)}
                  choices={lineChoices(item, on)}
                  lang={lang}
                  amount={money(lineTotal(linePrice(item, on), qty), lang)}
                />
              ))}
              <div className="flex border-t border-line pt-2.5">
                <span className="flex-1 text-[15px] font-bold">{text("guestKitchenTicketTotal")}</span>
                <span className="text-[15px] font-extrabold text-brand-header">{money(total, lang)}</span>
              </div>
            </GuestCard>
            <div className="flex gap-2.5">
              <div className="flex-1">
                <OutlineButton
                  onClick={() => {
                    if (status && !status.orderingOpen) showToast(text("guestOrderingPaused"));
                    else void callStaff();
                  }}
                >
                  {text("guestCallServer")}
                </OutlineButton>
              </div>
              <div className="flex-1">
                <PrimaryButton
                  height={52}
                  onClick={async () => {
                    if (!canBill) {
                      showToast(text("guestBillAfterServed"));
                      return;
                    }
                    // The bill screen sends the request, once a payment type is picked.
                    router.push(href("/bill"));
                  }}
                >
                  {text("guestRequestBill")}
                </PrimaryButton>
              </div>
            </div>
          </>
        )}
      </main>
      <BottomNav />
      <Toast />
    </div>
  );
}
