import { useState, type FormEvent, type ReactNode } from "react";
import { GuestCard, OutlineButton, PrimaryButton } from "@/components/parts";
import { money, orderNumber } from "@/lib/format";
import { t, type Lang } from "@/lib/i18n";
import { sampleTable } from "./sample-order";

export const demoOrderNumber = 12;

export type OrderStatus = "received" | "preparing" | "ready" | "served" | "paid";
export type PaymentMethod = "cash" | "card";

const statusKeys = {
  received: "guestStatusReceived",
  preparing: "guestStatusPreparing",
  ready: "guestStatusReady",
  served: "guestStatusServed",
  paid: "guestPaid",
} as const;

const nextStatus = { received: "preparing", preparing: "ready", ready: "served" } as const;

export function orderStatusLabel(lang: Lang, status: OrderStatus) {
  return t(lang, statusKeys[status]);
}

export const cashierCopy = {
  en: {
    guest: "Guest",
    cashier: "Cashier",
    view: "Demo view",
    floor: "Floor overview",
    empty: "No open orders",
    emptyHint: "Send an order from the guest menu or load a sample ticket to try the cashier.",
    draftHint: "Send your order from the guest menu to see it here.",
    sample: "Load sample order",
    guestMenu: "Go to guest menu",
    handoff: "View in cashier",
    billRequested: "Bill requested",
    settle: "Settle & close bill",
    closed: "Bill settled",
    closedHint: "The payment is recorded and the table is available again.",
    actions: { received: "Accept order", preparing: "Ready to serve", ready: "Mark served" },
    payment: { cash: "Cash", card: "Card" },
  },
  ar: {
    guest: "الضيف",
    cashier: "الكاشير",
    view: "واجهة العرض التجريبي",
    floor: "صالة المطعم",
    empty: "لا توجد طلبات مفتوحة",
    emptyHint: "أرسل طلبًا من قائمة الضيف أو حمّل طلبًا نموذجيًا لتجربة الكاشير.",
    draftHint: "أرسل طلبك من قائمة الضيف ليظهر هنا.",
    sample: "حمّل طلبًا نموذجيًا",
    guestMenu: "انتقل إلى قائمة الضيف",
    handoff: "عرض الطلب في الكاشير",
    billRequested: "تم طلب الفاتورة",
    settle: "تسوية وإغلاق الفاتورة",
    closed: "تمت تسوية الفاتورة",
    closedHint: "تم تسجيل الدفع وأصبحت الطاولة متاحة من جديد.",
    actions: { received: "قبول الطلب", preparing: "جاهز للتقديم", ready: "تم التقديم" },
    payment: { cash: "نقدًا", card: "بطاقة" },
  },
} as const;

export function CashierDemo({
  lang,
  status,
  billRequested,
  payment,
  total,
  details,
  loadSample,
  openGuest,
  onStatus,
  onPayment,
  onSettle,
}: {
  lang: Lang;
  status: OrderStatus | null;
  billRequested: boolean;
  payment: PaymentMethod;
  total: number;
  details: ReactNode;
  loadSample?: () => void;
  openGuest: () => void;
  onStatus: (status: OrderStatus) => void;
  onPayment: (payment: PaymentMethod) => void;
  onSettle: () => void;
}) {
  const copy = cashierCopy[lang];
  const [showPayment, setShowPayment] = useState(false);
  const action = status === "received" || status === "preparing" || status === "ready"
    ? { label: copy.actions[status], next: nextStatus[status] }
    : null;

  function settle(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (status === "served") onSettle();
  }

  if (!status) {
    return (
      <GuestCard className="mt-4 space-y-3 border border-line">
        <h3 className="font-extrabold">{copy.empty}</h3>
        <p className="text-sm text-muted">{loadSample ? copy.emptyHint : copy.draftHint}</p>
        <div className="grid gap-2 sm:max-w-md sm:grid-cols-2">
          {loadSample && <PrimaryButton height={48} onClick={loadSample}>{copy.sample}</PrimaryButton>}
          <OutlineButton height={48} onClick={openGuest}>{copy.guestMenu}</OutlineButton>
        </div>
      </GuestCard>
    );
  }

  return (
    <div className="mt-4 grid items-start gap-3 md:grid-cols-[minmax(0,1fr)_minmax(0,320px)]">
      <div className="space-y-3">{details}</div>
      <GuestCard className="space-y-4 border border-line">
        <div>
          <h3 className="font-extrabold text-brand-header">{t(lang, "guestTableNumber", { number: sampleTable })}</h3>
          <p className="text-sm text-muted">{t(lang, "guestOrderNumber", { id: orderNumber(demoOrderNumber) })}</p>
        </div>
        <div role="status">
          <p className="font-extrabold text-brand-header">{status === "paid" ? copy.closed : orderStatusLabel(lang, status)}</p>
          {status === "paid" && <p className="mt-1 text-sm text-muted">{copy.closedHint}</p>}
          {billRequested && status === "served" && <p className="mt-1 text-sm font-bold text-terracotta-dark">{copy.billRequested}</p>}
        </div>
        {action && <PrimaryButton onClick={() => onStatus(action.next)}>{action.label}</PrimaryButton>}
        {status === "served" && !showPayment && (
          <PrimaryButton onClick={() => setShowPayment(true)}>{copy.settle}</PrimaryButton>
        )}
        {status === "served" && showPayment && (
          <form onSubmit={settle} className="space-y-3">
            <fieldset>
              <legend className="mb-1 text-sm font-extrabold">{t(lang, "guestPayLabel")}</legend>
              <div className="grid grid-cols-2 gap-2">
                {(["cash", "card"] as const).map((method) => (
                  <label key={method} className="flex min-h-11 cursor-pointer items-center gap-2 rounded-xl border border-line bg-key px-3 text-sm font-bold">
                    <input type="radio" name="demo-payment" checked={payment === method} onChange={() => onPayment(method)} className="accent-brand" />
                    {copy.payment[method]}
                  </label>
                ))}
              </div>
            </fieldset>
            <PrimaryButton type="submit">{copy.settle} · {money(total, lang)}</PrimaryButton>
          </form>
        )}
        {status === "paid" && (
          <p className="flex flex-wrap justify-between gap-2 border-t border-hairline pt-3 text-sm font-extrabold">
            <span>{copy.payment[payment]}</span>
            <span>{money(total, lang)}</span>
          </p>
        )}
      </GuestCard>
    </div>
  );
}
