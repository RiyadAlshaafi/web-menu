"use client";

import { useState } from "react";
import { t, type Lang } from "@/lib/i18n";
import { Icon } from "./icons";
import { CafeBadge, PoweredBy, PrimaryButton } from "./parts";

// Language choice on every fresh visit, like today (lib/screens/customer/loading.dart).
export function LanguageScreen({
  slug,
  cafeName,
  logoUrl,
  tableNumber,
  initial,
}: {
  slug: string;
  cafeName: string;
  logoUrl: string;
  tableNumber: string;
  initial: Lang;
}) {
  const [lang, setLang] = useState<Lang>(initial);
  const option = (value: Lang, label: string) => (
    <button
      type="button"
      lang={value}
      aria-pressed={lang === value}
      onClick={() => setLang(value)}
      className={`min-h-14 flex-1 rounded-[14px] border-2 text-[17px] font-bold text-ink ${
        lang === value ? "border-brand-ink bg-soft-accent" : "border-border bg-white"
      }`}
    >
      {label}
    </button>
  );
  return (
    <main dir={lang === "ar" ? "rtl" : "ltr"} lang={lang} className="mx-auto flex min-h-dvh max-w-[430px] flex-col px-6 pt-10 pb-6">
      <CafeBadge name={cafeName} logoUrl={logoUrl} size={76} className="mx-auto bg-brand-header text-on-header" />
      <h1 className="mt-2.5 text-center text-[26px] font-extrabold tracking-tight">{cafeName}</h1>
      <p className="mx-auto mt-2.5 rounded-[15px] border border-line bg-white px-3.5 py-1.5 text-[13px] font-bold">
        {t(lang, "guestTableNumber", { number: tableNumber })}
      </p>
      <h2 className="mt-6 text-[15px] font-extrabold">{t(lang, "guestChooseLanguage")}</h2>
      <div className="mt-2.5 flex gap-2.5">
        {option("en", "English")}
        {option("ar", "العربية")}
      </div>
      <div className="flex-1" />
      <PrimaryButton
        onClick={() => {
          // A full load, so the page comes back with the right language and direction.
          // eslint-disable-next-line @next/next/no-location-assign-relative-destination -- needs new <html lang dir>
          window.location.assign(`/t/${encodeURIComponent(slug)}?lang=${lang}`);
        }}
      >
        {t(lang, "guestOpenMenu")}
      </PrimaryButton>
      <div className="mt-4">
        <PoweredBy label={t(lang, "guestPoweredBy")} />
      </div>
    </main>
  );
}

export function QrError({ lang, rateLimited = false }: { lang: Lang; rateLimited?: boolean }) {
  return (
    <main className="mx-auto flex min-h-dvh max-w-[430px] flex-col px-6 py-6">
      <div className="flex flex-1 flex-col items-center justify-center text-center">
        <Icon name="qr" size={48} className="text-brand-ink" />
        <h1 className="mt-3 text-[22px] font-extrabold">{rateLimited ? t(lang, "errRateLimited") : t(lang, "guestQrInvalid")}</h1>
        {!rateLimited && <p className="mt-2 text-muted">{t(lang, "guestQrInvalidHint")}</p>}
        <div className="mt-5 w-full">
          <PrimaryButton onClick={() => window.location.reload()}>{t(lang, "guestRetry")}</PrimaryButton>
        </div>
      </div>
      <PoweredBy label={t(lang, "guestPoweredBy")} />
    </main>
  );
}
