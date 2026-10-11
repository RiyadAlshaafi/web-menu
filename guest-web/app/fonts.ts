import localFont from "next/font/local";

// The same faces as the Flutter app (assets/fonts), subset to woff2.
export const jakarta = localFont({
  src: [
    { path: "./fonts/PlusJakartaSans-Regular.woff2", weight: "400" },
    { path: "./fonts/PlusJakartaSans-SemiBold.woff2", weight: "600" },
    { path: "./fonts/PlusJakartaSans-Bold.woff2", weight: "700" },
    { path: "./fonts/PlusJakartaSans-ExtraBold.woff2", weight: "800" },
  ],
  variable: "--font-jakarta",
  display: "swap",
});

export const naskh = localFont({
  src: [
    { path: "./fonts/NotoNaskhArabic-Regular.woff2", weight: "400" },
    { path: "./fonts/NotoNaskhArabic-Bold.woff2", weight: "700" },
  ],
  variable: "--font-naskh",
  // Only Arabic text uses it, so it is not preloaded. "optional": a slow first download shows
  // the phone's own Arabic font instead of re-laying out the page later. The language screen
  // already fetched it by the time the menu opens.
  display: "optional",
  preload: false,
});
