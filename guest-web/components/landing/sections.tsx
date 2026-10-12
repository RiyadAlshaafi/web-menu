// The static parts of the sales page. Nothing here needs JavaScript in the browser.

import { Icon } from "@/components/icons";
import type { LandingCopy, Tone } from "@/lib/landing-copy";

const AUDIENCE_ICONS = { guest: "restaurant", cashier: "receipt", owner: "menu" } as const;

export function Stats({ stats }: { stats: LandingCopy["stats"] }) {
  return (
    <ul className="lp-stats">
      {stats.map((stat) => (
        <li key={stat.label} className="lp-stat" data-tone={stat.tone}>
          <b>{stat.value}</b>
          <span>{stat.label}</span>
        </li>
      ))}
    </ul>
  );
}

export function Audience({ title, items }: { title: string; items: LandingCopy["audience"] }) {
  return (
    <section className="lp-aud" aria-labelledby="lp-aud-title">
      <h2 id="lp-aud-title">{title}</h2>
      <ul>
        {items.map((item) => (
          <li key={item.title} className="lp-aud-card" data-tone={item.tone}>
            <Icon name={AUDIENCE_ICONS[item.icon]} size={26} />
            <div>
              <b>{item.title}</b>
              <p>{item.text}</p>
            </div>
          </li>
        ))}
      </ul>
    </section>
  );
}

const PILL_TONES: readonly Tone[] = ["teal", "coral", "amber", "teal", "coral"];

// The track slides left by half its width and starts over, so each half must be wider than the
// widest screen (1120px) or an empty gap shows at the end. One row of pills is about 530px, so
// three rows per half is enough; only the first row is read aloud.
const PILL_ROWS = 6;

export function Pills({ pills }: { pills: readonly string[] }) {
  return (
    <div className="lp-pills">
      <div className="lp-pill-track">
        {Array.from({ length: PILL_ROWS }, (_, copy) => (
          <ul key={copy} className="lp-pill-row" aria-hidden={copy > 0 || undefined}>
            {pills.map((pill, i) => (
              <li key={pill} className="lp-pill" data-tone={PILL_TONES[i % PILL_TONES.length]}>
                {pill}
              </li>
            ))}
          </ul>
        ))}
      </div>
    </div>
  );
}

export function WhatsAppIcon({ size = 22 }: { size?: number }) {
  return (
    <svg viewBox="0 0 24 24" width={size} height={size} aria-hidden="true" focusable="false" fill="currentColor">
      <path d="M12.04 2a9.9 9.9 0 0 0-8.47 15.03L2 22l5.1-1.34A9.9 9.9 0 1 0 12.04 2Zm0 18.1a8.2 8.2 0 0 1-4.18-1.14l-.3-.18-3.03.8.81-2.95-.2-.31a8.2 8.2 0 1 1 6.9 3.78Zm4.5-6.14c-.25-.12-1.46-.72-1.69-.8-.23-.08-.39-.12-.56.12-.16.25-.64.8-.78.97-.14.16-.29.18-.54.06a6.7 6.7 0 0 1-1.97-1.22 7.4 7.4 0 0 1-1.36-1.69c-.14-.25 0-.38.1-.5.11-.11.25-.29.37-.43.12-.14.16-.25.25-.41.08-.17.04-.31-.02-.43-.06-.12-.56-1.34-.76-1.84-.2-.48-.4-.41-.56-.42h-.47c-.16 0-.43.06-.65.31-.23.25-.86.84-.86 2.05s.88 2.38 1 2.55c.12.16 1.73 2.64 4.2 3.7.59.26 1.05.41 1.4.52.59.19 1.13.16 1.55.1.47-.07 1.46-.6 1.66-1.17.2-.58.2-1.07.14-1.17-.06-.1-.23-.16-.48-.29Z" />
    </svg>
  );
}
