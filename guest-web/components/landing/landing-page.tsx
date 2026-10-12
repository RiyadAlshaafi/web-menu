import Link from "next/link";
import { demoMenuHref, whatsappLink } from "@/lib/landing-config";
import { landingCopy, type LandingLang } from "@/lib/landing-copy";
import { HeroScene } from "./hero-scene";
import { HowItWorks } from "./how-it-works";
import { LandingLockup } from "./logo";
import { Audience, Pills, Stats, WhatsAppIcon } from "./sections";
import "./landing.css";

/** Words are split so each one can arrive on its own; the whole line is still one heading. */
function Headline({ words }: { words: readonly [string, string, string] }) {
  return (
    <h1 className="lp-h1">
      <span style={{ "--i": 0 } as React.CSSProperties}>{words[0]}</span> <span style={{ "--i": 1 } as React.CSSProperties}>{words[1]}</span>
      <br />
      <span className="lp-h1-accent" style={{ "--i": 2 } as React.CSSProperties}>
        {words[2]}
      </span>
    </h1>
  );
}

export function LandingPage({ lang }: { lang: LandingLang }) {
  const copy = landingCopy[lang];
  const demo = demoMenuHref();
  const chat = whatsappLink(copy.whatsappText);

  return (
    <div className="lp">
      <header className="lp-header">
        <Link href={lang === "ar" ? "/ar" : "/"} className="lp-home" aria-label={copy.homeLabel}>
          <LandingLockup size={30} spin />
        </Link>
        <nav aria-label="Tawla" className="lp-nav">
          <a href="#how" className="lp-nav-link lp-nav-features">
            {copy.featuresLabel}
          </a>
          <Link href={copy.switchHref} className="lp-nav-link" lang={lang === "ar" ? "en" : "ar"} hrefLang={lang === "ar" ? "en" : "ar"}>
            {copy.switchLabel}
          </Link>
        </nav>
      </header>

      <main>
        <section className="lp-hero">
          <span className="lp-glow lp-glow-a" aria-hidden="true" />
          <span className="lp-glow lp-glow-b" aria-hidden="true" />
          <Headline words={copy.heroWords} />
          <p className="lp-sub">{copy.heroSub}</p>
          <HeroScene label={copy.sceneLabel} />
          {demo && (
            <a href={demo} className="lp-cta">
              <svg viewBox="0 0 24 24" width="20" height="20" aria-hidden="true" fill="currentColor">
                <path d="M3 3h8v8H3zm2 2v4h4V5zm8-2h8v8h-8zm2 2v4h4V5zM3 13h8v8H3zm2 2v4h4v-4zm13-2h3v3h-3zm-5 0h3v3h-3zm3 3h3v3h-3zm-3 3h3v2h-3zm5 0h3v2h-3z" />
              </svg>
              {copy.demoCta}
            </a>
          )}
        </section>

        <Stats stats={copy.stats} />
        <HowItWorks id="how" title={copy.howTitle} steps={copy.howSteps} />
        <Audience title={copy.audienceTitle} items={copy.audience} />
        <Pills pills={copy.pills} />

        <section className="lp-band">
          <span className="lp-glow lp-glow-c" aria-hidden="true" />
          <h2>{copy.bandTitle}</h2>
          {chat && (
            <a href={chat} className="lp-cta lp-cta-still" target="_blank" rel="noopener noreferrer">
              <WhatsAppIcon />
              {copy.bandCta}
            </a>
          )}
        </section>
      </main>

      <footer className="lp-footer">
        <LandingLockup size={20} />
        <span>{copy.footer}</span>
      </footer>

      {chat && (
        <a href={chat} className="lp-fab" target="_blank" rel="noopener noreferrer" aria-label={copy.bandCta}>
          <WhatsAppIcon size={28} />
        </a>
      )}
    </div>
  );
}
