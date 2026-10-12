// Words for the public sales page, in English (/) and Arabic (/ar).
// The mock screens inside the hero are product pictures and stay in English.

export type Tone = "coral" | "amber" | "teal";
export type LandingLang = "en" | "ar";

export interface LandingCopy {
  metaTitle: string;
  metaDescription: string;
  homeLabel: string;
  featuresLabel: string;
  switchLabel: string;
  switchHref: string;
  heroWords: readonly [string, string, string];
  heroSub: string;
  demoCta: string;
  sceneLabel: string;
  stats: readonly { value: string; label: string; tone: Tone }[];
  howTitle: string;
  howSteps: readonly { title: string; text: string }[];
  audienceTitle: string;
  audience: readonly { title: string; text: string; tone: Tone; icon: "guest" | "cashier" | "owner" }[];
  pills: readonly string[];
  bandTitle: string;
  bandCta: string;
  whatsappText: string;
  footer: string;
}

export const landingCopy: Record<LandingLang, LandingCopy> = {
  en: {
    metaTitle: "Tawla: QR ordering and a cashier system for cafés",
    metaDescription:
      "Guests scan a QR code and order from their phone. Your cashier sees the order in seconds, even offline. In Arabic and English.",
    homeLabel: "Tawla home",
    featuresLabel: "Features",
    switchLabel: "العربية",
    switchHref: "/ar",
    heroWords: ["Tap.", "Order.", "It's already at the counter."],
    heroSub: "QR ordering and a cashier system for cafés, in Arabic and English.",
    demoCta: "Try a live menu",
    sceneLabel: "A guest sends an order from their phone and it appears on the cashier's floor screen.",
    stats: [
      { value: "3 s", label: "order to cashier", tone: "coral" },
      { value: "2", label: "languages", tone: "amber" },
      { value: "0", label: "apps for guests to install", tone: "teal" },
    ],
    howTitle: "How it works",
    howSteps: [
      { title: "1 · Scan", text: "QR code on every table." },
      { title: "2 · Order", text: "Photos, prices, both languages." },
      { title: "3 · Pay", text: "Cashier settles and prints." },
    ],
    audienceTitle: "Made for everyone",
    audience: [
      { title: "Guests", text: "Order, call staff, ask for the bill.", tone: "coral", icon: "guest" },
      { title: "Cashiers", text: "Live floor, takeout, shifts. Works offline.", tone: "amber", icon: "cashier" },
      { title: "Owners", text: "Menu, prices, staff and reports.", tone: "teal", icon: "owner" },
    ],
    pills: ["Works offline", "Arabic and English", "Prints receipts", "Windows or web", "Daily reports"],
    bandTitle: "Want it in your café?",
    bandCta: "Message us on WhatsApp",
    whatsappText: "Hi, I'd like to see Tawla in my café.",
    footer: "© Tawla",
  },
  ar: {
    metaTitle: "Tawla: نظام طلب بالـ QR وكاشير للمقاهي",
    metaDescription:
      "الزبون يمسح رمز QR ويطلب من هاتفه، والكاشير يرى الطلب في ثوانٍ حتى بدون إنترنت. بالعربية والإنجليزية.",
    homeLabel: "الصفحة الرئيسية لـ Tawla",
    featuresLabel: "المزايا",
    switchLabel: "English",
    switchHref: "/",
    heroWords: ["امسح.", "اطلب.", "وطلبك جاهز عند الكاشير."],
    heroSub: "نظام طلب عبر QR وكاشير للمقاهي، بالعربية والإنجليزية.",
    demoCta: "جرّب قائمة حقيقية",
    sceneLabel: "زبون يرسل طلبه من هاتفه فيظهر مباشرة على شاشة الصالة عند الكاشير.",
    stats: [
      { value: "3 ث", label: "من الطلب إلى الكاشير", tone: "coral" },
      { value: "2", label: "لغتان", tone: "amber" },
      { value: "0", label: "تطبيقات يحمّلها الزبون", tone: "teal" },
    ],
    howTitle: "كيف يعمل",
    howSteps: [
      { title: "1 · امسح", text: "رمز QR على كل طاولة." },
      { title: "2 · اطلب", text: "صور وأسعار بالعربية والإنجليزية." },
      { title: "3 · ادفع", text: "الكاشير يحاسب ويطبع الفاتورة." },
    ],
    audienceTitle: "مصمم للجميع",
    audience: [
      { title: "الزبائن", text: "اطلب، نادِ الموظف، واطلب الفاتورة.", tone: "coral", icon: "guest" },
      { title: "الكاشير", text: "الصالة مباشرة، الطلبات الخارجية، الورديات. يعمل بدون إنترنت.", tone: "amber", icon: "cashier" },
      { title: "أصحاب المقاهي", text: "القائمة والأسعار والموظفون والتقارير.", tone: "teal", icon: "owner" },
    ],
    pills: ["يعمل بدون إنترنت", "عربي وإنجليزي", "يطبع الفواتير", "ويندوز أو ويب", "تقارير يومية"],
    bandTitle: "تريد Tawla في مقهاك؟",
    bandCta: "راسلنا على واتساب",
    whatsappText: "مرحباً، أريد تجربة Tawla في مقهاي.",
    footer: "© Tawla",
  },
};
