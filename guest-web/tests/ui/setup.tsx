import { vi } from "vitest";
import type { ReactNode } from "react";
import type { Menu, Tab, GuestStatus } from "@/lib/types";

export const router = { push: vi.fn(), replace: vi.fn() };
export const nav = { path: "/t/abc123def456" };

vi.mock("next/navigation", () => ({
  useRouter: () => router,
  usePathname: () => nav.path,
}));
vi.mock("next/link", () => ({
  default: ({ href, children, ...rest }: { href: string; children: ReactNode }) => (
    <a href={href} {...rest}>
      {children}
    </a>
  ),
}));
vi.mock("next/image", () => ({
  // eslint-disable-next-line @next/next/no-img-element
  default: ({ src, alt }: { src: string; alt: string }) => <img src={src} alt={alt} />,
}));

export const live: { handlers: { topic: string; cb: (m: { payload?: { table?: string } }) => void }[]; removed: number } = {
  handlers: [],
  removed: 0,
};
vi.mock("@supabase/realtime-js", () => ({
  RealtimeClient: class {
    channel(topic: string) {
      const channel = {
        on: (_type: string, _filter: unknown, cb: (m: { payload?: { table?: string } }) => void) => {
          live.handlers.push({ topic, cb });
          return channel;
        },
        subscribe: () => channel,
      };
      return channel;
    }
    removeChannel() {
      live.removed++;
    }
    disconnect() {}
  },
}));

export const SLUG = "abc123def456";
export const TEA = "a0000000-0000-4000-8000-000000000101";
export const CAPPU = "a0000000-0000-4000-8000-000000000102";
export const JUICE = "a0000000-0000-4000-8000-000000000103";
export const CARD = "22222222-2222-4222-8222-222222222222";
// Cappuccino's choices: sugar comes in it, cinnamon can be added for a price, two extras.
export const SUGAR = "b0000000-0000-4000-8000-000000000201";
export const CINNAMON = "b0000000-0000-4000-8000-000000000202";
export const SHOT = "b0000000-0000-4000-8000-000000000203";
export const CREAM = "b0000000-0000-4000-8000-000000000204";

export const menu = (): Menu => ({
  cafe: {
    id: "cafe-1",
    name: "Akakus Café",
    locale: "ar",
    logoUrl: "",
    headerColor: "#1B3A4B",
    buttonColor: "#BA5333",
    backgroundColor: "",
    serviceChargeRate: 0.1,
  },
  table: { number: "4" },
  categories: [
    { id: "c1", nameEn: "Drinks", nameAr: "مشروبات" },
    { id: "c2", nameEn: "Food", nameAr: "طعام" },
  ],
  items: [
    { id: TEA, categoryId: "c1", nameEn: "Mint Tea", nameAr: "شاي", description: "Fresh mint.", price: 5, salePrice: 5, imageUrl: "https://x.supabase.co/storage/v1/object/public/a.jpg", available: true, featured: true, options: [] },
    {
      id: CAPPU, categoryId: "c1", nameEn: "Cappuccino", nameAr: "كابتشينو", description: "", price: 8, salePrice: 6, imageUrl: "", available: true, featured: false,
      options: [
        { id: SUGAR, kind: "ingredient", nameEn: "Sugar", nameAr: "سكر", price: 0, defaultOn: true },
        { id: CINNAMON, kind: "ingredient", nameEn: "Cinnamon", nameAr: "قرفة", price: 0.5, defaultOn: false },
        { id: SHOT, kind: "topping", nameEn: "Extra shot", nameAr: "جرعة إضافية", price: 1.5, defaultOn: false },
        { id: CREAM, kind: "topping", nameEn: "Cream", nameAr: "كريمة", price: 0, defaultOn: false },
      ],
    },
    { id: JUICE, categoryId: "c2", nameEn: "Juice", nameAr: "عصير", description: "", price: 6.5, salePrice: 6.5, imageUrl: "data:image/png;base64,AAAA", available: false, featured: false, options: [] },
  ],
  paymentTypes: [{ id: CARD, nameEn: "Card", nameAr: "بطاقة" }],
});

export const open: GuestStatus = { orderingOpen: true, location: { enabled: false, radiusM: 100 } };

export const tabWith = (status: string, extra: Partial<NonNullable<Tab["order"]>> = {}): Tab => ({
  table: { number: "4", status: "dining" },
  order: {
    id: "o1",
    status,
    createdAt: "2026-10-11T08:00:00Z",
    orderNumber: 7,
    awaitingConfirmation: false,
    refusalNotice: "",
    paymentTypeId: null,
    lines: [
      { id: "l1", menuItemId: TEA, name: "Mint Tea", qty: 2, unitPrice: 5, listUnitPrice: 5, round: 1, choices: [] },
      { id: "l2", menuItemId: null, name: "Old dish", qty: 1, unitPrice: 3, listUnitPrice: null, round: 2, choices: [] },
    ],
    ...extra,
  },
});

export type Call = { url: string; method: string; body: unknown };
type Responder = (url: string, method: string, body: unknown) => unknown;

// Fake /api/guest/*: `respond` returns the JSON body (an ApiResponse) for a call.
export function mockApi(respond: Responder) {
  const calls: Call[] = [];
  vi.stubGlobal(
    "fetch",
    vi.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
      const url = String(input);
      const method = init?.method ?? "GET";
      const body = init?.body ? JSON.parse(String(init.body)) : undefined;
      calls.push({ url, method, body });
      const result = respond(url, method, body);
      if (result instanceof Error) throw result;
      return new Response(JSON.stringify(result), { headers: { "Content-Type": "application/json" } });
    }),
  );
  return calls;
}

// The stored cart as { line key: qty }.
export function storedQty(): Record<string, number> {
  const raw = localStorage.getItem(`tawla-cart:${SLUG}`);
  const cart = raw ? (JSON.parse(raw) as Record<string, { qty: number }>) : {};
  return Object.fromEntries(Object.entries(cart).map(([key, line]) => [key, line.qty]));
}

export const ok = <T,>(data: T) => ({ ok: true, data, error: null });
export const err = (code: string, items?: string[]) => ({ ok: false, data: null, error: { code, message: "x", items } });

// Renders `ui` inside a GuestProvider with the fixtures above.
export async function renderGuest(
  ui: ReactNode,
  { status = open, tab = null, lang = "en", path = `/t/${SLUG}` }: { status?: GuestStatus | null; tab?: Tab | null; lang?: "en" | "ar"; path?: string } = {},
) {
  const { render } = await import("@testing-library/react");
  const { GuestProvider } = await import("@/components/guest-provider");
  nav.path = path;
  return render(
    <GuestProvider slug={SLUG} lang={lang} initialMenu={menu()} initialStatus={status} initialTab={tab}>
      {ui}
    </GuestProvider>,
  );
}
