import type { Metadata, Viewport } from "next";
import { headers } from "next/headers";
import { jakarta, naskh } from "./fonts";
import "./globals.css";

export const metadata: Metadata = {
  title: "Tawla",
  description: "Order from your table",
  robots: { index: false, follow: false },
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  themeColor: "#FDF9F2",
};

export default async function RootLayout({ children }: LayoutProps<"/">) {
  const lang = (await headers()).get("x-guest-lang") === "ar" ? "ar" : "en";
  return (
    <html lang={lang} dir={lang === "ar" ? "rtl" : "ltr"} className={`${jakarta.variable} ${naskh.variable} antialiased`}>
      <body className="min-h-dvh">{children}</body>
    </html>
  );
}
