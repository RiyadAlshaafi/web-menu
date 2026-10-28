// The two mock screens in the hero, drawn from the real ones: the guest menu on a phone
// (components/menu-screen.tsx) and the cashier's floor view on a tablet (lib/screens/cashier).
// They are pictures, so they stay English and left-to-right.

import { Icon } from "@/components/icons";
import { LandingMark } from "./logo";

type TableStatus = "free" | "dining" | "bill" | "call" | "new";

const STATUS: Record<TableStatus, { chip: string; label: string; badge: string; badgeText: string; line: string; lineColor: string }> = {
  free: { chip: "#F1EDE7", label: "FREE", badge: "#EAF3DE", badgeText: "#4F7A45", line: "Clean, ready", lineColor: "#56423C" },
  dining: { chip: "#2F6F8F", label: "DINING", badge: "#E6F1FB", badgeText: "#2F6F8F", line: "24 LYD", lineColor: "#2F6F8F" },
  bill: { chip: "#95600F", label: "BILL", badge: "#FAEEDA", badgeText: "#95600F", line: "41 LYD", lineColor: "#95600F" },
  call: { chip: "#BA5333", label: "CALL", badge: "#FFDBD1", badgeText: "#9A3C1D", line: "Needs staff", lineColor: "#9A3C1D" },
  new: { chip: "#2F6F8F", label: "NEW", badge: "#FFDBD1", badgeText: "#9A3C1D", line: "30 LYD · 3 items", lineColor: "#2F6F8F" },
};

function TableCard({ number, status, pop = false }: { number: number; status: TableStatus; pop?: boolean }) {
  const s = STATUS[status];
  const free = status === "free";
  return (
    <div className={`lp-tc${pop ? " lp-pop" : ""}`}>
      <div className="lp-tc-top">
        <span className="lp-num" style={{ background: s.chip, color: free ? "#56423C" : "#fff" }}>
          T{number}
        </span>
        <span className="lp-bdg" style={{ background: s.badge, color: s.badgeText }}>
          {s.label}
        </span>
      </div>
      <b>Table {number}</b>
      <span style={{ color: s.lineColor, fontWeight: free ? 400 : 800 }}>{s.line}</span>
    </div>
  );
}

function Dish({ name, price, tint, height }: { name: string; price: number; tint: string; height: number }) {
  return (
    <div className="lp-dish">
      <div style={{ height, background: tint }} />
      <div className="lp-dish-row">
        <div>
          <div className="lp-dish-name">{name}</div>
          <div className="lp-dish-price">{price} LYD</div>
        </div>
        <span className="lp-plus">+</span>
      </div>
    </div>
  );
}

export function GuestPhone({ sent }: { sent: boolean }) {
  return (
    <div className="lp-phone">
      <div className="lp-phone-head">
        <small>TABLE 4</small>
        <b>Menu</b>
      </div>
      <div className="lp-chips">
        <span className="lp-chip lp-chip-on">Coffee</span>
        <span className="lp-chip">Bakery</span>
        <span className="lp-chip">Juice</span>
      </div>
      <div className="lp-phone-body">
        <Dish name="Espresso" price={6} tint="#C9A27A" height={46} />
        <Dish name="Croissant" price={8} tint="#E8C99B" height={34} />
      </div>
      <div className="lp-bar" data-sent={sent}>
        <span>{sent ? "Sent ✓" : "Send order · 3"}</span>
        <span>30 LYD</span>
      </div>
    </div>
  );
}

export function CashierTablet({ arrived }: { arrived: boolean }) {
  return (
    <div className="lp-tablet">
      <div className="lp-side">
        <LandingMark size={22} className="lp-side-mark" />
        <span className="lp-side-dot lp-side-on" />
        <span className="lp-side-dot" />
        <span className="lp-side-dot" />
      </div>
      <div className="lp-floor">
        <div className="lp-floor-head">
          <b>Floor</b>
          <span className="lp-bell" data-ring={arrived}>
            <Icon name="bell" size={13} />
          </span>
        </div>
        <div className="lp-chips">
          <span className="lp-chip lp-chip-navy">All 6</span>
          <span className="lp-chip">Occupied {arrived ? 3 : 2}</span>
          <span className="lp-chip">Bill due 1</span>
        </div>
        <div className="lp-grid">
          <TableCard number={1} status="dining" />
          <TableCard number={2} status="bill" />
          <TableCard number={3} status="free" />
          <TableCard key={arrived ? "new" : "free"} number={4} status={arrived ? "new" : "free"} pop={arrived} />
          <TableCard number={5} status="call" />
          <TableCard number={6} status="free" />
        </div>
      </div>
    </div>
  );
}
