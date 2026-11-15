import { GuestProvider } from "@/components/guest-provider";
import { QrError } from "@/components/entry-screens";
import { loadTable, loadTableState, pageLang } from "@/lib/server/page";

export default async function TableLayout({ children, params }: LayoutProps<"/t/[slug]">) {
  const { slug } = await params;
  const [load, chosen] = await Promise.all([loadTable(slug), pageLang()]);
  const lang = chosen ?? "en";
  if (load.kind !== "ok") return <QrError lang={lang} rateLimited={load.kind === "rate_limited"} />;
  const { status, tab } = await loadTableState(slug);
  return (
    <GuestProvider slug={slug} lang={lang} initialMenu={load.menu} initialStatus={status} initialTab={tab}>
      {children}
    </GuestProvider>
  );
}
