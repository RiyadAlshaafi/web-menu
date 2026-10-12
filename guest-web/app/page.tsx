import type { Metadata } from "next";
import { LandingPage } from "@/components/landing/landing-page";
import { landingCopy } from "@/lib/landing-copy";

const copy = landingCopy.en;

export const metadata: Metadata = {
  metadataBase: new URL("https://tawla.ly"),
  title: copy.metaTitle,
  description: copy.metaDescription,
  robots: { index: true, follow: true },
  alternates: { canonical: "/", languages: { en: "/", ar: "/ar" } },
  openGraph: { title: copy.metaTitle, description: copy.metaDescription, url: "/", siteName: "Tawla", type: "website" },
};

// Old table QR codes were /#/t/<slug>[/cart|/bill]. The hash never reaches the server, so a tiny
// script forwards them to the guest menu before the page paints.
const forward = `(function(){var m=location.hash.match(/^#\\/t\\/([a-z0-9-]{4,64})(\\/(cart|bill))?\\/?(\\?.*)?$/);if(m){location.replace('/t/'+m[1]+(m[3]==='bill'?'/bill':m[3]==='cart'?'/tab':''));}})();`;

export default function Home() {
  return (
    <>
      <script dangerouslySetInnerHTML={{ __html: forward }} />
      <LandingPage lang="en" />
    </>
  );
}
