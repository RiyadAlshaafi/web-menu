import type { Metadata } from "next";
import { LanguageScreen } from "@/components/entry-screens";
import { MenuScreen } from "@/components/menu-screen";
import { loadTable, pageLang } from "@/lib/server/page";

export async function generateMetadata({ params }: PageProps<"/t/[slug]">): Promise<Metadata> {
  const load = await loadTable((await params).slug);
  return { title: load.kind === "ok" ? load.menu.cafe.name || "Tawla" : "Tawla" };
}

export default async function TablePage({ params }: PageProps<"/t/[slug]">) {
  const { slug } = await params;
  const [load, lang] = await Promise.all([loadTable(slug), pageLang()]);
  if (load.kind !== "ok") return null; // the layout shows the error
  if (!lang) {
    const { cafe, table } = load.menu;
    return (
      <LanguageScreen
        slug={slug}
        cafeName={cafe.name}
        logoUrl={cafe.logoUrl}
        tableNumber={table.number}
        initial={cafe.locale === "ar" ? "ar" : "en"}
      />
    );
  }
  return <MenuScreen />;
}
