import type { Metadata } from "next";
import { LandingPage } from "@/components/landing/landing-page";
import { landingCopy } from "@/lib/landing-copy";

const copy = landingCopy.ar;

export const metadata: Metadata = {
  metadataBase: new URL("https://tawla.ly"),
  title: copy.metaTitle,
  description: copy.metaDescription,
  robots: { index: true, follow: true },
  alternates: { canonical: "/ar", languages: { en: "/", ar: "/ar" } },
  openGraph: { title: copy.metaTitle, description: copy.metaDescription, url: "/ar", siteName: "Tawla", type: "website", locale: "ar" },
};

export default function HomeArabic() {
  return <LandingPage lang="ar" />;
}
