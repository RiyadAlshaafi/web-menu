import { PoweredBy } from "@/components/parts";
import { Icon } from "@/components/icons";

// Old QR links were /#/t/<slug>[/cart|/bill]; the hash never reaches the server, so a tiny
// script forwards them. Anyone else is asked to scan their table's code.
const forward = `(function(){var m=location.hash.match(/^#\\/t\\/([a-z0-9-]{4,64})(\\/(cart|bill))?\\/?(\\?.*)?$/);if(m){location.replace('/t/'+m[1]+(m[3]==='bill'?'/bill':m[3]==='cart'?'/tab':''));}})();`;

export default function Home() {
  return (
    <main className="mx-auto flex min-h-dvh max-w-[430px] flex-col px-6 py-6">
      <script dangerouslySetInnerHTML={{ __html: forward }} />
      <div className="flex flex-1 flex-col items-center justify-center text-center">
        <Icon name="qr" size={48} className="text-terracotta" />
        <h1 className="mt-3 text-[22px] font-extrabold">Scan the QR code on your table</h1>
        <p className="mt-2 text-muted" lang="ar" dir="rtl">
          امسح رمز QR الموجود على طاولتك
        </p>
      </div>
      <PoweredBy label="Powered by" />
    </main>
  );
}
