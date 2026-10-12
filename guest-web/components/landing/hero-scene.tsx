"use client";

import { useEffect, useRef, useState, type PointerEvent } from "react";
import { CashierTablet, GuestPhone } from "./scene-parts";
import { useOnScreen, useReducedMotion } from "./use-motion";

const STAGE_W = 680;
const STAGE_H = 360;
const FLIGHT_MS = 1300;
const HOLD_MS = 3300;
const FIRST_DELAY_MS = 1800;
const TICKET_HALF_W = 50;
const TICKET_HALF_H = 16;

type Phase = "idle" | "flying" | "arrived";

const easeInOut = (p: number): number => (p < 0.5 ? 2 * p * p : 1 - Math.pow(-2 * p + 2, 2) / 2);

/** Fits the fixed-size stage into whatever width the page gives it. */
function useStageScale(ref: React.RefObject<HTMLDivElement | null>): number {
  const [scale, setScale] = useState(1);
  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    const observer = new ResizeObserver(([entry]) => setScale(Math.min(1, entry.contentRect.width / STAGE_W)));
    observer.observe(el);
    return () => observer.disconnect();
  }, [ref]);
  return scale;
}

/** Sends an order along the path again and again while the scene is on screen. */
function useOrderFlight(active: boolean, path: React.RefObject<SVGPathElement | null>, ticket: React.RefObject<HTMLDivElement | null>): Phase {
  const [phase, setPhase] = useState<Phase>("idle");
  useEffect(() => {
    if (!active) return;
    const timers: number[] = [];
    let frame = 0;
    const fly = () => {
      const pathEl = path.current;
      const ticketEl = ticket.current;
      if (!pathEl || !ticketEl) return;
      setPhase("flying");
      const length = pathEl.getTotalLength();
      let start = 0;
      const step = (now: number) => {
        start ||= now;
        const p = Math.min((now - start) / FLIGHT_MS, 1);
        const point = pathEl.getPointAtLength(easeInOut(p) * length);
        const grow = 1 + Math.sin(p * Math.PI) * 0.25;
        ticketEl.style.transform = `translate(${point.x - TICKET_HALF_W}px, ${point.y - TICKET_HALF_H}px) scale(${grow}) rotate(${(p - 0.5) * 20}deg)`;
        if (p < 1) {
          frame = requestAnimationFrame(step);
          return;
        }
        setPhase("arrived");
        timers.push(window.setTimeout(fly, HOLD_MS));
      };
      frame = requestAnimationFrame(step);
    };
    timers.push(window.setTimeout(fly, FIRST_DELAY_MS));
    return () => {
      timers.forEach(window.clearTimeout);
      cancelAnimationFrame(frame);
    };
  }, [active, path, ticket]);
  return phase;
}

export function HeroScene({ label }: { label: string }) {
  const box = useRef<HTMLDivElement>(null);
  const tilt = useRef<HTMLDivElement>(null);
  const path = useRef<SVGPathElement>(null);
  const ticket = useRef<HTMLDivElement>(null);
  const reduced = useReducedMotion();
  const onScreen = useOnScreen(box);
  const scale = useStageScale(box);
  const phase = useOrderFlight(onScreen && !reduced, path, ticket);

  const arrived = reduced || phase === "arrived";
  const flying = !reduced && phase === "flying";

  const handleMove = (event: PointerEvent<HTMLDivElement>) => {
    if (event.pointerType !== "mouse" || reduced || !tilt.current) return;
    const rect = event.currentTarget.getBoundingClientRect();
    const x = (event.clientX - rect.left) / rect.width - 0.5;
    const y = (event.clientY - rect.top) / rect.height - 0.5;
    tilt.current.style.transform = `rotateY(${x * 10}deg) rotateX(${-y * 8}deg)`;
  };
  const handleLeave = () => {
    if (tilt.current) tilt.current.style.transform = "none";
  };

  return (
    <div ref={box} className="lp-scene" style={{ height: STAGE_H * scale }} onPointerMove={handleMove} onPointerLeave={handleLeave}>
      <div role="img" aria-label={label} dir="ltr" className="lp-stage" style={{ transform: `scale(${scale})` }}>
        <div ref={tilt} className="lp-tilt">
          <svg className="lp-path" width={STAGE_W} height={STAGE_H} aria-hidden="true">
            <path ref={path} d="M170 290 C 280 120, 380 110, 470 170" />
          </svg>
          <GuestPhone sent={arrived} />
          <CashierTablet arrived={arrived} />
        </div>
        <div ref={ticket} className="lp-ticket" data-flying={flying} aria-hidden="true">
          Table 4 · 3 items
        </div>
      </div>
    </div>
  );
}
