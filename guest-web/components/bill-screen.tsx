"use client";

import { useState } from "react";
import { lineTotal, money, orderNumber, paymentTypeName } from "@/lib/format";
import { BottomNav, Header, Toast } from "./chrome";
import { useGuest } from "./guest-provider";
import { Icon } from "./icons";
import { EmptyHint, Eyebrow, GuestCard, PrimaryButton, TicketLine } from "./parts";
import { subtotalOf, useLineName } from "./tab-screen";

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex py-[3px] text-sm">
      <span className="flex-1 text-muted">{label}</span>
      <span className="font-bold text-ink">{value}</span>
    </div>
  );
}

// Final bill: lines, service charge, total, payment method, request bill, paid view.
export function BillScreen() {
  const { tab, menu, lines, lang, text, showToast, requestBill, setPaymentType, hadOrder } = useGuest();
  const lineName = useLineName();
  const [busy, setBusy] = useState(false);
  const order = tab?.order ?? null;
  const subtotal = subtotalOf(order?.lines ?? []);
  const rate = menu.cafe.serviceChargeRate;
  const service = Math.round(subtotal * rate * 1000) / 1000;
  const total = subtotal + service;
  const paid = tab !== null && !order && lines.length === 0 && tab.table.status === "free" && hadOrder;
  const canBill = order?.status === "served" && lines.length === 0;
  const types = menu.paymentTypes;

  return (
    <div className="mx-auto flex min-h-dvh max-w-[430px] flex-col bg-page">
      <Header />
      <main className="flex-1 space-y-3.5 px-4 pt-[18px] pb-6">
        <GuestCard>
          <div className="flex items-start">
            <div className="flex-1">
              <Eyebrow>{text("guestFinalTab")}</Eyebrow>
              <h2 className="mt-0.5 text-xl font-extrabold">{text("guestOrderSummary")}</h2>
            </div>
            {order?.orderNumber != null && (
              <p className="text-[13px] text-muted">{text("guestRefNumber", { id: orderNumber(order.orderNumber).replace("#", "") })}</p>
            )}
          </div>
          <div className="mt-2">
            {paid ? (
              <div className="flex flex-col items-center py-3 text-center">
                <Icon name="checkCircle" size={48} className="text-success" />
                <p className="mt-2 font-extrabold tracking-[0.1em] text-success">{text("guestPaid")}</p>
                <p className="text-lg font-bold">{text("guestPaymentSuccessful")}</p>
                <p className="text-muted">{text("guestThankYou", { cafe: menu.cafe.name })}</p>
              </div>
            ) : tab === null ? null : !order ? (
              <EmptyHint>{text("noOrders")}</EmptyHint>
            ) : (
              <>
                {order.lines.map((line) => (
                  <TicketLine key={line.id} qty={line.qty} name={lineName(line)} amount={money(lineTotal(line.unitPrice, line.qty), lang)} />
                ))}
                <div className="mt-0.5 mb-2 border-t border-dashed border-step-idle" />
                <Row label={text("guestSubtotal")} value={money(subtotal, lang)} />
                <Row label={text("guestServiceCharge", { percent: Math.round(rate * 100) })} value={money(service, lang)} />
                <Row label={text("guestVatIncluded")} value="—" />
                <div className="mt-1 flex items-baseline">
                  <span className="flex-1 text-base font-extrabold">{text("guestTotalDue")}</span>
                  <span className="text-2xl font-extrabold text-brand-header">{money(total, lang)}</span>
                </div>
              </>
            )}
          </div>
        </GuestCard>
        {order && types.length > 0 && (
          <div>
            <label htmlFor="pay" className="text-[15px] font-extrabold">
              {text("payChoose")}
            </label>
            <div className="relative mt-2.5">
              <select
                id="pay"
                value={types.some((t) => t.id === order.paymentTypeId) ? (order.paymentTypeId ?? "") : ""}
                onChange={(event) => event.target.value && void setPaymentType(event.target.value)}
                className="min-h-[56px] w-full appearance-none rounded-[14px] border-2 border-border bg-white ps-4 pe-10 text-base font-bold text-ink focus:border-brand-ink"
              >
                <option value="" disabled>
                  {text("guestPayLabel")}
                </option>
                {types.map((type) => (
                  <option key={type.id} value={type.id}>
                    {paymentTypeName(type, lang)}
                  </option>
                ))}
              </select>
              <Icon name="down" size={22} className="pointer-events-none absolute end-3 top-1/2 -translate-y-1/2 text-muted" />
            </div>
          </div>
        )}
        {order && (
          <PrimaryButton
            busy={busy}
            onClick={async () => {
              if (!canBill) {
                showToast(text("guestBillAfterServed"));
                return;
              }
              if (types.length > 0 && !order.paymentTypeId) {
                showToast(text("payChoose"));
                return;
              }
              setBusy(true);
              await requestBill();
              setBusy(false);
            }}
          >
            {text("guestConfirmRequestBill")}
          </PrimaryButton>
        )}
      </main>
      <BottomNav />
      <Toast />
    </div>
  );
}
