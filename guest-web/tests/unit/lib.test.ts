import { describe, expect, it } from "vitest";
import { add, cartCount, cartLines, cartTotal, defaultOn, dishQty, lineChoices, lineKey, linePrice, loadCart, prune, saveCart, setQty } from "@/lib/cart";
import { accessibleFill, brand, contrastOn, contrastRatio, parseHex, readableOn, INK, PAPER, PAGE } from "@/lib/color";
import { categoryName, dishName, hasDiscount, lineTotal, money, orderNumber, paymentTypeName, tripoliTime } from "@/lib/format";
import { dir, isLang, t } from "@/lib/i18n";
import type { DishOption, MenuItem } from "@/lib/types";

const A = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa";
const B = "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb";
const ONION = "11111111-1111-4111-8111-111111111111";
const EGG = "22222222-2222-4222-8222-222222222222";
const CHEESE = "33333333-3333-4333-8333-333333333333";
const option = (id: string, kind: DishOption["kind"], defaultOn: boolean, price: number): DishOption => ({
  id,
  kind,
  nameEn: { [ONION]: "Onion", [EGG]: "Egg", [CHEESE]: "Cheese" }[id] ?? "?",
  nameAr: "",
  price,
  defaultOn,
});
// A discounted burger: onion comes in it (removing it is free), egg can be added, cheese is extra.
const burgerOptions = [option(ONION, "ingredient", true, 0.25), option(EGG, "ingredient", false, 1), option(CHEESE, "topping", false, 0.5)];
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
  options: [],
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
  const tea = item(A, 4.5);
  const burger = item(B, 10, { price: 12, options: burgerOptions });
  const plain = (id: string, qty: number) => ({ itemId: id, on: [], qty });

  it("adds, caps at 99 and removes at zero", () => {
    let cart = add({}, tea);
    cart = add(cart, tea, undefined, 2);
    expect(cart).toEqual({ [A]: plain(A, 3) });
    expect(setQty(cart, A, 500)).toEqual({ [A]: plain(A, 99) });
    expect(setQty(cart, A, 0)).toEqual({});
    expect(setQty(cart, A, -3)).toEqual({});
    expect(setQty(cart, "unknown", 2)).toBe(cart);
  });

  it("keys a dish as it comes by its id, and other choices by the ids that differ", () => {
    expect(defaultOn(burger)).toEqual([ONION]);
    expect(lineKey(burger, [ONION])).toBe(B);
    expect(lineKey(burger, [])).toBe(`${B}|${ONION}`);
    expect(lineKey(burger, [CHEESE, EGG, ONION])).toBe(`${B}|${[CHEESE, EGG].sort().join(",")}`);
    expect(lineKey(tea, [])).toBe(A);
  });

  it("merges identical lines and keeps different choices apart", () => {
    let cart = add({}, burger);
    cart = add(cart, burger, [ONION]);
    cart = add(cart, burger, [CHEESE, ONION, CHEESE, "not-an-option"]);
    cart = add(cart, burger, [ONION, CHEESE], 2);
    expect(cart).toEqual({
      [B]: { itemId: B, on: [ONION], qty: 2 },
      [`${B}|${CHEESE}`]: { itemId: B, on: [ONION, CHEESE], qty: 3 },
    });
    expect(dishQty(cart, B)).toBe(5);
    expect(dishQty(cart, A)).toBe(0);
  });

  it("charges only options that are off by default and turned on; the discount skips them", () => {
    expect(linePrice(burger, [ONION])).toBe(10);
    expect(linePrice(burger, [])).toBe(10); // no onion: free, no refund
    expect(linePrice(burger, [ONION, EGG, CHEESE])).toBe(11.5); // sale price 10 + full 1 + 0.5
    expect(linePrice(tea, [])).toBe(4.5);
    expect(lineChoices(burger, [EGG, CHEESE])).toEqual([
      { id: ONION, nameEn: "Onion", nameAr: "", on: false, price: 0 },
      { id: EGG, nameEn: "Egg", nameAr: "", on: true, price: 1 },
      { id: CHEESE, nameEn: "Cheese", nameAr: "", on: true, price: 0.5 },
    ]);
    expect(lineChoices(burger, [ONION])).toEqual([]);
  });

  it("prices lines from the menu, never from storage", () => {
    const items = [tea, item(B, 2, { available: false })];
    const lines = cartLines({ [B]: plain(B, 1), [A]: plain(A, 2), gone: plain("gone", 5) }, items);
    expect(lines.map((l) => l.item.id)).toEqual([A, B]);
    expect(cartCount(lines)).toBe(3);
    expect(cartTotal(lines)).toBe(11);
    const withChoices = cartLines(add(add({}, burger, [ONION, CHEESE], 2), burger), [burger]);
    expect(withChoices.map((l) => l.key)).toEqual([`${B}|${CHEESE}`, B]);
    expect(cartTotal(withChoices)).toBe(31);
  });

  it("prunes dishes that disappeared and options the dish no longer has", () => {
    const cart = { [A]: plain(A, 1), gone: plain("gone", 2), [`${B}|${EGG}`]: { itemId: B, on: [ONION, EGG], qty: 1 } };
    const withoutEgg = { ...burger, options: burgerOptions.filter((o) => o.id !== EGG) };
    // The egg line becomes the plain burger line.
    expect(prune(cart, [tea, withoutEgg])).toEqual({ [A]: plain(A, 1), [B]: { itemId: B, on: [ONION], qty: 1 } });
  });

  it("reads a cart stored before dish choices as dishes as they come", () => {
    const storage = { getItem: () => JSON.stringify({ [A]: 2, [B]: 1 }) };
    expect(loadCart(storage, "s", [tea, burger])).toEqual({
      [A]: plain(A, 2),
      [B]: { itemId: B, on: [ONION], qty: 1 },
    });
  });

  it("survives broken or hostile storage", () => {
    const store = new Map<string, string>();
    const storage = {
      getItem: (k: string) => store.get(k) ?? null,
      setItem: (k: string, v: string) => void store.set(k, v),
      removeItem: (k: string) => void store.delete(k),
    };
    const items = [tea, burger];
    saveCart(storage, "s", { [A]: plain(A, 2) });
    expect(loadCart(storage, "s", items)).toEqual({ [A]: plain(A, 2) });
    store.set("tawla-cart:s", JSON.stringify({ [A]: 1000, "<script>": 1, [B]: "2" }));
    expect(loadCart(storage, "s", items)).toEqual({ [A]: plain(A, 99) });
    // A forged key is rebuilt from the line itself.
    store.set("tawla-cart:s", JSON.stringify({ forged: { itemId: B, on: [CHEESE, ONION], qty: 1 } }));
    expect(Object.keys(loadCart(storage, "s", items))).toEqual([`${B}|${CHEESE}`]);
    for (const bad of [{ itemId: B, on: "x", qty: 1 }, { itemId: B, on: [1], qty: 1 }, { itemId: "<b>", on: [], qty: 1 }, { itemId: B, on: [], qty: "1" }, [B]]) {
      store.set("tawla-cart:s", JSON.stringify({ k: bad }));
      expect(loadCart(storage, "s", items)).toEqual({});
    }
    store.set("tawla-cart:s", JSON.stringify({ k: { itemId: B, on: Array(41).fill(ONION), qty: 1 } }));
    expect(loadCart(storage, "s", items)).toEqual({});
    store.set("tawla-cart:s", "{oops");
    expect(loadCart(storage, "s", items)).toEqual({});
    store.set("tawla-cart:s", "[1]");
    expect(loadCart(storage, "s", items)).toEqual({});
    saveCart(storage, "s", {});
    expect(store.has("tawla-cart:s")).toBe(false);
    expect(loadCart(null, "s", items)).toEqual({});
    const throwing = { setItem: () => { throw new Error("quota"); }, removeItem: () => {} };
    expect(() => saveCart(throwing, "s", { [A]: plain(A, 1) })).not.toThrow();
  });
});
