// Where the sales page's two buttons lead. Both come from build settings so no number or demo
// address is ever invented: when a setting is missing, its button is simply not shown.

const WHATSAPP_DIGITS = /^\d{8,15}$/;
const DEMO_PATH = /^\/t\/[a-z0-9-]{4,64}$/;

/** wa.me link with the message already typed, or null when no number is set. */
export function whatsappLink(message: string, raw = process.env.NEXT_PUBLIC_WHATSAPP_NUMBER): string | null {
  const digits = (raw ?? "").replace(/[\s+()-]/g, "");
  if (!WHATSAPP_DIGITS.test(digits)) return null;
  return `https://wa.me/${digits}?text=${encodeURIComponent(message)}`;
}

/** The demo cafe's menu, as a path on this site ("/t/<slug>"), or null when not set. */
export function demoMenuHref(raw = process.env.NEXT_PUBLIC_DEMO_MENU_PATH): string | null {
  const path = (raw ?? "").trim();
  return DEMO_PATH.test(path) ? path : null;
}
