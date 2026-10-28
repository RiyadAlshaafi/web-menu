// The cafe's header and button colours with black or white text, whichever reads better
// (lib/theme/cafe_theme.dart CafeColors.contrastOn / readableOn).
export const INK = "#1C1C18";
export const PAPER = "#FFFFFF";
export const PAGE = "#FDF9F2";
const DEFAULT_HEADER = "#1B3A4B";
const DEFAULT_BUTTON = "#BA5333";

type Rgb = [number, number, number];

export function parseHex(value: string | null | undefined, fallback: string): string {
  const raw = (value ?? "").trim().replace(/^#/, "");
  if (!/^[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$/.test(raw)) return fallback;
  // 8 digits are ARGB in the Flutter app; the alpha is dropped.
  const rgb = raw.length === 8 ? raw.slice(2) : raw;
  return `#${rgb.toUpperCase()}`;
}

function rgb(hex: string): Rgb {
  const n = parseInt(hex.slice(1), 16);
  return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
}

function luminance(hex: string): number {
  const [r, g, b] = rgb(hex).map((c) => {
    const s = c / 255;
    return s <= 0.03928 ? s / 12.92 : ((s + 0.055) / 1.055) ** 2.4;
  });
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

export function contrastRatio(a: string, b: string): number {
  const x = luminance(a);
  const y = luminance(b);
  return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05);
}

export function contrastOn(color: string): string {
  return contrastRatio(color, INK) >= contrastRatio(color, PAPER) ? INK : PAPER;
}

function toHsl([r, g, b]: Rgb): [number, number, number] {
  const [R, G, B] = [r / 255, g / 255, b / 255];
  const max = Math.max(R, G, B);
  const min = Math.min(R, G, B);
  const l = (max + min) / 2;
  if (max === min) return [0, 0, l];
  const d = max - min;
  const s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
  const h = max === R ? (G - B) / d + (G < B ? 6 : 0) : max === G ? (B - R) / d + 2 : (R - G) / d + 4;
  return [h * 60, s, l];
}

function fromHsl(h: number, s: number, l: number): string {
  const c = (1 - Math.abs(2 * l - 1)) * s;
  const x = c * (1 - Math.abs(((h / 60) % 2) - 1));
  const m = l - c / 2;
  const [r, g, b] =
    h < 60 ? [c, x, 0] : h < 120 ? [x, c, 0] : h < 180 ? [0, c, x] : h < 240 ? [0, x, c] : h < 300 ? [x, 0, c] : [c, 0, x];
  const hex = (v: number) => Math.round((v + m) * 255).toString(16).padStart(2, "0");
  return `#${hex(r)}${hex(g)}${hex(b)}`.toUpperCase();
}

// `color` darkened just enough to read as text on every surface (4.5:1).
export function readableOn(color: string, surfaces: string[], minRatio = 4.5): string {
  const reads = (c: string) => surfaces.every((s) => contrastRatio(c, s) >= minRatio);
  if (reads(color)) return color;
  const [h, s, l] = toHsl(rgb(color));
  for (let next = l - 0.02; next > 0; next -= 0.02) {
    const candidate = fromHsl(h, s, next);
    if (reads(candidate)) return candidate;
  }
  return INK;
}

// A fill colour that black or white text can read on at 4.5:1. The owner's colour is kept when
// it already works (almost always); a few mid-tones are darkened just enough for white text.
export function accessibleFill(color: string): string {
  if (contrastRatio(color, contrastOn(color)) >= 4.5) return color;
  return readableOn(color, [PAPER]);
}

export type Brand = { header: string; onHeader: string; button: string; onButton: string; buttonInk: string };

export function brand(headerColor: string, buttonColor: string): Brand {
  const header = accessibleFill(parseHex(headerColor, DEFAULT_HEADER));
  const button = accessibleFill(parseHex(buttonColor, DEFAULT_BUTTON));
  return {
    header,
    onHeader: contrastOn(header),
    button,
    onButton: contrastOn(button),
    buttonInk: readableOn(button, [PAPER, PAGE]),
  };
}

export function brandStyle(b: Brand): Record<string, string> {
  return {
    "--brand-header": b.header,
    "--brand-on-header": b.onHeader,
    "--brand-button": b.button,
    "--brand-on-button": b.onButton,
    "--brand-button-ink": b.buttonInk,
  };
}
