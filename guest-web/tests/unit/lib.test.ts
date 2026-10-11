import { describe, expect, it } from "vitest";
import { add, cartCount, cartLines, cartTotal, loadCart, prune, saveCart, setQty } from "@/lib/cart";
import { accessibleFill, brand, contrastOn, contrastRatio, parseHex, readableOn, INK, PAPER, PAGE } from "@/lib/color";
import { categoryName, dishName, hasDiscount, lineTotal, money, orderNumber, paymentTypeName, tripoliTime } from "@/lib/format";
import { dir, isLang, t } from "@/lib/i18n";
import type { MenuItem } from "@/lib/types";

const A = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa";
const B = "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb";
const item = (id: string, salePrice: number, extra: Partial<MenuItem> = {}): MenuItem => ({
  id,
  categoryId: "c",
  nameEn: "Tea",
  nameAr: "شاي",
  description: "",
  price: salePrice,
  salePrice,
  imageUrl: "",
  available: true,
  featured: false,
  ...extra,
});

describe("money and numbers", () => {
  it("formats like the Flutter app", () => {
    expect(money(1234.5, "en")).toBe("1,234.500 LYD");
    expect(money(0, "ar")).toBe("0.000 د.ل");
    expect(orderNumber(7)).toBe("#007");
    expect(orderNumber(1234)).toBe("#1234");
    expect(orderNumber(null)).toBe("—");
    expect(lineTotal(4.5, 3)).toBe(13.5);
    expect(lineTotal(0.1, 3)).toBe(0.3);
  });

  it("shows Tripoli time (UTC+2)", () => {
    expect(tripoliTime("2026-10-11T22:05:00Z")).toBe("00:05");
    expect(tripoliTime("2026-10-11T08:00:00+00:00")).toBe("10:00");
    expect(tripoliTime("nonsense")).toBe("");
  });
});

describe("names", () => {
  it("uses the Arabic name in Arabic, falling back to English", () => {
    expect(dishName({ nameEn: "Tea", nameAr: "شاي" }, "ar")).toBe("شاي");
    expect(dishName({ nameEn: "Tea", nameAr: "" }, "ar")).toBe("Tea");
    expect(dishName({ nameEn: "", nameAr: "شاي" }, "en")).toBe("شاي");
    expect(categoryName({ id: "c", nameEn: "Hot", nameAr: "ساخن" }, "ar")).toBe("ساخن");
    expect(paymentTypeName({ id: "p", nameEn: "Card", nameAr: "" }, "ar")).toBe("Card");
    expect(hasDiscount({ price: 10, salePrice: 9 })).toBe(true);
    expect(hasDiscount({ price: 10, salePrice: 10 })).toBe(false);
  });
});

describe("texts", () => {
  it("fills placeholders in both languages", () => {
    expect(t("en", "guestTableNumber", { number: 4 })).toBe("Table 4");
    expect(t("ar", "guestTableNumber", { number: 4 })).toBe("طاولة 4");
    expect(t("en", "guestItemRemoved")).toBe("Item removed: {name} — currently unavailable.");
    expect(dir("ar")).toBe("rtl");
    expect(dir("en")).toBe("ltr");
    expect(isLang("ar")).toBe(true);
    expect(isLang("fr")).toBe(false);
  });
});

describe("brand colours", () => {
  it("parses owner colours and falls back on junk", () => {
    expect(parseHex("#1b3a4b", "#000000")).toBe("#1B3A4B");
    expect(parseHex("FF112233", "#000000")).toBe("#112233");
    expect(parseHex("", "#BA5333")).toBe("#BA5333");
    expect(parseHex("red", "#BA5333")).toBe("#BA5333");
  });

  it("picks black or white text for AA contrast", () => {
    expect(contrastOn("#1B3A4B")).toBe(PAPER);
    expect(contrastOn("#FFE066")).toBe(INK);
    for (const owner of ["#1B3A4B", "#BA5333", "#FFE066", "#00A86B", "#777777", "#FF0000", "#3399FF"]) {
      const fill = accessibleFill(owner);
      expect(contrastRatio(fill, contrastOn(fill)), owner).toBeGreaterThanOrEqual(4.5);
    }
    // Colours that already work are kept exactly.
    expect(accessibleFill("#BA5333")).toBe("#BA5333");
    expect(accessibleFill("#FF0000")).not.toBe("#FF0000");
  });

  it("darkens a light button colour until it reads as text", () => {
    const ink = readableOn("#FFE066", [PAPER, PAGE]);
    expect(contrastRatio(ink, PAPER)).toBeGreaterThanOrEqual(4.5);
    expect(contrastRatio(ink, PAGE)).toBeGreaterThanOrEqual(4.5);
    expect(readableOn("#1B3A4B", [PAPER])).toBe("#1B3A4B");
    expect(brand("", "")).toMatchObject({ header: "#1B3A4B", button: "#BA5333", onHeader: PAPER });
  });
});

describe("cart", () => {
  it("adds, caps at 99 and removes at zero", () => {
    let cart = add({}, A);
    cart = add(cart, A, 2);
    expect(cart).toEqual({ [A]: 3 });
    expect(setQty(cart, A, 500)).toEqual({ [A]: 99 });
    expect(setQty(cart, A, 0)).toEqual({});
    expect(setQty(cart, A, -3)).toEqual({});
  });

  it("prices lines from the menu, never from storage", () => {
    const items = [item(A, 4.5), item(B, 2, { available: false })];
    const lines = cartLines({ [B]: 1, [A]: 2, gone: 5 }, items);
    expect(lines.map((l) => l.item.id)).toEqual([A, B]);
    expect(cartCount(lines)).toBe(3);
    expect(cartTotal(lines)).toBe(11);
    expect(prune({ [A]: 1, gone: 2 }, items)).toEqual({ [A]: 1 });
  });

  it("survives broken or hostile storage", () => {
    const store = new Map<string, string>();
    const storage = {
      getItem: (k: string) => store.get(k) ?? null,
      setItem: (k: string, v: string) => void store.set(k, v),
      removeItem: (k: string) => void store.delete(k),
    };
    saveCart(storage, "s", { [A]: 2 });
    expect(loadCart(storage, "s")).toEqual({ [A]: 2 });
    store.set("tawla-cart:s", JSON.stringify({ [A]: 1000, "<script>": 1, [B]: "2" }));
    expect(loadCart(storage, "s")).toEqual({ [A]: 99 });
    store.set("tawla-cart:s", "{oops");
    expect(loadCart(storage, "s")).toEqual({});
    store.set("tawla-cart:s", "[1]");
    expect(loadCart(storage, "s")).toEqual({});
    saveCart(storage, "s", {});
    expect(store.has("tawla-cart:s")).toBe(false);
    expect(loadCart(null, "s")).toEqual({});
    const throwing = { setItem: () => { throw new Error("quota"); }, removeItem: () => {} };
    expect(() => saveCart(throwing, "s", { [A]: 1 })).not.toThrow();
  });
});
