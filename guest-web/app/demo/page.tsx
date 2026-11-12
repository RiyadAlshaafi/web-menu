import type { Metadata } from "next";
import { OrderDemo } from "@/components/demo/order-demo";

export const metadata: Metadata = {
  title: "Interactive demo | Tawla",
  description: "Try ordering from a Tawla QR menu with sample data.",
  alternates: { canonical: "https://tawla.ly/demo" },
  robots: { index: true, follow: true },
};

export default async function DemoPage({ searchParams }: PageProps<"/demo">) {
  const { lang } = await searchParams;
  return <OrderDemo initialLang={lang === "ar" ? "ar" : "en"} />;
}
