"use client";

import { useEffect, useRef, useState } from "react";
import { Icon } from "@/components/icons";
import { useOnScreen, useReducedMotion } from "./use-motion";

const STEP_MS = 3200;
const ICONS = ["qr", "menu", "receipt"] as const;
const TINTS = ["teal", "amber", "coral"] as const;

interface Step {
  title: string;
  text: string;
}

/** A step is on while it is hovered, focused or tapped; otherwise the three take turns. */
function useActiveStep(count: number, running: boolean): { active: number; held: boolean; select: (i: number) => void; hold: (held: boolean) => void } {
  const [active, setActive] = useState(0);
  const [held, setHeld] = useState(false);
  useEffect(() => {
    if (!running || held) return;
    const id = window.setInterval(() => setActive((i) => (i + 1) % count), STEP_MS);
    return () => window.clearInterval(id);
  }, [count, running, held, active]);
  return { active, held, select: setActive, hold: setHeld };
}

/** The table scene on the left changes with the step; the photo goes under the layers. */
function TableScene({ active }: { active: number }) {
  return (
    <div className="lp-table" aria-hidden="true" data-step={active}>
      <div className="lp-table-wood" />
      <div className="lp-cup-saucer">
        <span />
      </div>
      <span className="lp-steam" />
      <div className="lp-qr-stand">
        <Icon name="qr" size={44} />
        <small>Scan to order</small>
      </div>
      <div className="lp-layer lp-layer-scan">
        <div className="lp-cam">
          <span className="lp-scanline" />
          <span className="lp-ok">
            <Icon name="check" size={24} />
          </span>
        </div>
      </div>
      <div className="lp-layer lp-layer-order">
        <span className="lp-bub lp-bub-1">Espresso ×2</span>
        <span className="lp-bub lp-bub-2">Croissant</span>
        <span className="lp-bub lp-bub-3">Fresh juice</span>
        <span className="lp-bub lp-bub-4">Sent · 30 LYD</span>
      </div>
      <div className="lp-layer lp-layer-pay">
        <span className="lp-printer" />
        <div className="lp-receipt">
          <div>Table 4</div>
          <p>Espresso ×2 …… 12</p>
          <p>Croissant …… 8</p>
          <p>Fresh juice …… 10</p>
          <p className="lp-total">Total …… 30 LYD</p>
          <span className="lp-paid">PAID</span>
        </div>
      </div>
    </div>
  );
}

export function HowItWorks({ id, title, steps }: { id: string; title: string; steps: readonly Step[] }) {
  const box = useRef<HTMLDivElement>(null);
  const reduced = useReducedMotion();
  const onScreen = useOnScreen(box);
  const { active, held, select, hold } = useActiveStep(steps.length, onScreen && !reduced);

  return (
    <section id={id} ref={box} className="lp-how" aria-labelledby={`${id}-title`}>
      <h2 id={`${id}-title`}>{title}</h2>
      <div className="lp-how-grid">
        <TableScene active={active} />
        <div
          className="lp-steps"
          data-held={held || reduced}
          onPointerEnter={() => hold(true)}
          onPointerLeave={() => hold(false)}
          onFocus={() => hold(true)}
          onBlur={() => hold(false)}
        >
          {steps.map((step, i) => (
            <button
              key={step.title}
              type="button"
              className="lp-step"
              data-on={active === i}
              data-tint={TINTS[i]}
              aria-pressed={active === i}
              onPointerEnter={() => select(i)}
              onFocus={() => select(i)}
              onClick={() => select(i)}
            >
              <span className="lp-step-icon">
                <Icon name={ICONS[i]} size={22} />
              </span>
              <span className="lp-step-text">
                <b>{step.title}</b>
                <span>{step.text}</span>
                <i className="lp-step-bar" key={active === i ? `run-${active}` : "idle"} />
              </span>
            </button>
          ))}
        </div>
      </div>
    </section>
  );
}
