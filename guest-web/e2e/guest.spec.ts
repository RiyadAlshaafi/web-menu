import AxeBuilder from "@axe-core/playwright";
import { expect, test, type BrowserContextOptions, type Page, type TestInfo } from "@playwright/test";
import { db, resetDemo, SHIM } from "./db";

// Extra browser contexts (a second phone, a set location) keep the project's device profile.
function phone(testInfo: TestInfo): BrowserContextOptions {
  const { viewport, userAgent, deviceScaleFactor, isMobile, hasTouch, locale, baseURL } = testInfo.project.use;
  return { viewport, userAgent, deviceScaleFactor, isMobile, hasTouch, locale, baseURL };
}

const TABLE = "demotable0001";

async function openMenu(page: Page, lang: "en" | "ar" = "en", slug = TABLE) {
  await page.goto(`/t/${slug}?lang=${lang}`);
  await expect(page.locator("main")).toBeVisible();
}

test.describe.configure({ mode: "serial" });

// Each phone profile starts from empty tables.
test.beforeAll(() => resetDemo());

test("language choice opens the menu in Arabic, right to left", async ({ page }) => {
  await page.goto(`/t/${TABLE}`);
  await expect(page.getByRole("heading", { name: "Akakus Café" })).toBeVisible();
  // The cafe's locale is Arabic, so Arabic is preselected.
  await expect(page.getByRole("button", { name: "العربية" })).toHaveAttribute("aria-pressed", "true");
  await page.getByRole("button", { name: "English" }).click();
  await page.getByRole("button", { name: "العربية" }).click();
  await page.getByRole("button", { name: "افتح القائمة" }).click();
  await expect(page).toHaveURL(/lang=ar/);
  await expect(page.locator("html")).toHaveAttribute("dir", "rtl");
  await expect(page.locator("html")).toHaveAttribute("lang", "ar");
  await expect(page.getByText("شاي بالنعناع").first()).toBeVisible();
  await expect(page.getByText("6.000 د.ل").first()).toBeVisible();
});

test("browse, order a round, then a second round lands on the same order", async ({ page }) => {
  await openMenu(page);
  await expect(page.getByRole("heading", { name: "Mezzogiorno Menu" })).toBeVisible();
  // Sold-out and switched-off dishes can't be added.
  await expect(page.getByRole("button", { name: "Add Cheesecake" })).toBeDisabled();
  await expect(page.getByRole("button", { name: "Add Orange Juice" })).toBeDisabled();
  // Discounted: list price struck through, sale price shown.
  await expect(page.locator("del", { hasText: "8.000 LYD" }).first()).toBeVisible();

  await page.getByRole("button", { name: "Add Club Sandwich" }).click();
  await page.getByRole("button", { name: "Add Club Sandwich" }).click();
  await page.getByRole("button", { name: "Drinks" }).click();
  await page.getByRole("button", { name: /^Cappuccino/ }).click();
  const sheet = page.getByRole("dialog", { name: "Cappuccino" });
  await sheet.getByRole("button", { name: "Increase" }).click();
  await sheet.getByRole("button", { name: /Add to Order • 12.000 LYD/ }).click();
  await expect(page.getByText("4 items • Cart · 42.000 LYD")).toBeVisible();

  await page.getByRole("button", { name: /View Order/ }).click();
  const verify = page.getByRole("dialog", { name: "Verify Your Order" });
  await expect(verify.getByText("Items in order (4)")).toBeVisible();
  await verify.getByRole("group", { name: "Club Sandwich" }).getByRole("button", { name: "Decrease" }).click();
  await expect(verify.getByText("27.000 LYD").first()).toBeVisible();
  await verify.getByRole("button", { name: "Confirm & Send to Kitchen" }).click();

  await expect(page).toHaveURL(/\/tab\?lang=en/);
  await expect(page.getByText("Live Tab")).toBeVisible();
  await expect(page.getByText("Kitchen Ticket Total")).toBeVisible();
  await expect(page.getByText("27.000 LYD")).toBeVisible();
  // Prices came from the database, not the phone.
  expect(db(`select string_agg(name || ':' || qty || ':' || unit_price, ',' order by name) from order_lines l join orders o on o.id = l.order_id join dining_tables t on t.id = o.table_id where t.qr_slug = '${TABLE}'`)).toBe(
    "Cappuccino:2:6.00,Club Sandwich:1:15.00",
  );

  await page.getByRole("link", { name: "Menu" }).click();
  await page.getByRole("button", { name: "Add Mint Tea" }).click();
  await page.getByRole("button", { name: /View Order/ }).click();
  await page.getByRole("button", { name: "Confirm & Send to Kitchen" }).click();
  await expect(page).toHaveURL(/\/tab/);
  expect(db(`select count(distinct o.id) || '/' || max(l.round) from order_lines l join orders o on o.id = l.order_id join dining_tables t on t.id = o.table_id where t.qr_slug = '${TABLE}'`)).toBe("1/2");
});

test("the cashier's status changes show on the tab, and the bill opens once served", async ({ page }) => {
  await page.goto(`/t/${TABLE}/tab?lang=en`);
  await page.getByRole("button", { name: "Request Bill" }).click();
  await expect(page.getByRole("status").filter({ hasText: "after the waiter marks your order served" })).toBeVisible();

  db(`update orders set status = 'served' where table_id = (select id from dining_tables where qr_slug = '${TABLE}') and status <> 'paid'`);
  // No Realtime locally: coming back to the tab refetches it.
  await page.reload();
  await expect(page.locator("[aria-current=step]")).toContainText("Served");
  await page.getByRole("button", { name: "Request Bill" }).click();
  await expect(page).toHaveURL(/\/bill/);
  await expect(page.getByText("Service Charge (10%)")).toBeVisible();
  await expect(page.getByText("3.200 LYD")).toBeVisible();
  await expect(page.getByText("35.200 LYD")).toBeVisible();
  await page.getByLabel("How will you pay?").selectOption({ label: "Card" });
  await expect
    .poll(() => db(`select p.name_en from orders o join payment_types p on p.id = o.payment_type_id join dining_tables t on t.id = o.table_id where t.qr_slug = '${TABLE}' and o.status <> 'paid'`))
    .toBe("Card");
  expect(db(`select status from dining_tables where qr_slug = '${TABLE}'`)).toBe("billRequested");
});

test("an item refused by the cashier is confirmed by the guest", async ({ page }) => {
  db(`update orders set awaiting_customer_confirmation = true, refusal_notice = 'Mint Tea' where table_id = (select id from dining_tables where qr_slug = '${TABLE}') and status <> 'paid'`);
  await openMenu(page);
  const alert = page.getByRole("alert").filter({ hasText: "Item removed" });
  await expect(alert).toContainText("Item removed: Mint Tea — currently unavailable.");
  await alert.getByRole("button", { name: "Confirm and request bill" }).click();
  await expect(alert).toBeHidden();
  expect(db(`select awaiting_customer_confirmation from orders where table_id = (select id from dining_tables where qr_slug = '${TABLE}') and status <> 'paid'`)).toBe("f");
});

test("each phone keeps its own cart", async ({ browser }, testInfo) => {
  const one = await browser.newContext(phone(testInfo));
  const two = await browser.newContext(phone(testInfo));
  const a = await one.newPage();
  const b = await two.newPage();
  await openMenu(a, "en", "demotable0002");
  await openMenu(b, "en", "demotable0002");
  await a.getByRole("button", { name: "Add Mint Tea" }).click();
  await expect(a.getByText(/1 items • Cart/)).toBeVisible();
  await b.reload();
  await expect(b.getByText(/items • Cart/)).toHaveCount(0);
  // The cart survives a reload on the same phone.
  await a.reload();
  await expect(a.getByText(/1 items • Cart/)).toBeVisible();
  await one.close();
  await two.close();
});

test("ordering pauses while the cashier is offline; browsing still works", async ({ page }) => {
  await openMenu(page, "en", "offlinetable1");
  await expect(page.getByText(/Ordering is paused right now because the cashier is offline/)).toBeVisible();
  await expect(page.getByText("Espresso")).toBeVisible();
  const add = page.getByRole("button", { name: "Add Espresso" });
  await expect(add).toHaveAttribute("aria-disabled", "true");
  await add.click({ force: true });
  await expect(page.getByRole("status").filter({ hasText: "Ordering is paused" }).last()).toBeVisible();
  await expect(page.getByText(/1 items • Cart/)).toHaveCount(0);
  await page.getByRole("button", { name: "Call Staff" }).click();
  expect(db(`select count(*) from staff_calls c join dining_tables t on t.id = c.table_id where t.qr_slug = 'offlinetable1'`)).toBe("0");
});

test("outside the cafe's radius the guest can browse but not order", async ({ browser }, testInfo) => {
  const far = await browser.newContext({ ...phone(testInfo), geolocation: { latitude: 32.9, longitude: 13.3, accuracy: 10 }, permissions: ["geolocation"] });
  const page = await far.newPage();
  await openMenu(page, "en", "squaretable01");
  await expect(page.getByText(/You're too far from the cafe to order/)).toBeVisible();
  await expect(page.getByRole("button", { name: "Retry" })).toBeVisible();
  await far.close();

  const near = await browser.newContext({ ...phone(testInfo), geolocation: { latitude: 32.8955, longitude: 13.181, accuracy: 15 }, permissions: ["geolocation"] });
  const ok = await near.newPage();
  await openMenu(ok, "en", "squaretable01");
  await ok.getByRole("button", { name: "Add Latte" }).click();
  await ok.getByRole("button", { name: /View Order/ }).click();
  await ok.getByRole("button", { name: "Confirm & Send to Kitchen" }).click();
  await expect(ok).toHaveURL(/\/tab/);
  await near.close();
});

test("location refused: the guest is told how to allow it", async ({ browser }, testInfo) => {
  const context = await browser.newContext({ ...phone(testInfo), permissions: [] });
  const page = await context.newPage();
  await openMenu(page, "en", "squaretable01");
  await expect(page.getByText(/Location is needed to place an order/)).toBeVisible();
  await expect(page.getByRole("button", { name: "Allow location" })).toBeVisible();
  await context.close();
});

test("an unknown QR code shows the retry page", async ({ page }) => {
  await page.goto("/t/nosuchtable99?lang=en");
  await expect(page.getByRole("heading", { name: "This QR code doesn't match a table." })).toBeVisible();
  await page.goto("/t/BAD%20slug");
  await expect(page.getByRole("heading", { name: "This QR code doesn't match a table." })).toBeVisible();
});

test("old Flutter links are forwarded", async ({ page }) => {
  await page.goto(`/#/t/${TABLE}/cart`);
  await expect(page).toHaveURL(new RegExp(`/t/${TABLE}/tab`));
  await page.goto(`/t/${TABLE}/cart?lang=ar`);
  await expect(page).toHaveURL(new RegExp(`/t/${TABLE}/tab\\?lang=ar`));
});

test("tap targets are at least 44 px and there are no accessibility violations", async ({ page }) => {
  for (const [path, name] of [
    [`/t/${TABLE}`, "language"],
    [`/t/${TABLE}?lang=en`, "menu en"],
    [`/t/${TABLE}?lang=ar`, "menu ar"],
    [`/t/${TABLE}/tab?lang=en`, "tab"],
    [`/t/${TABLE}/bill?lang=ar`, "bill"],
  ]) {
    await page.goto(path);
    await page.waitForLoadState("networkidle");
    const small = await page.$$eval("button, a, select", (nodes) =>
      nodes
        .filter((n) => n.getClientRects().length > 0 && getComputedStyle(n).visibility !== "hidden")
        .map((n) => ({ text: (n.getAttribute("aria-label") ?? n.textContent ?? "").trim().slice(0, 30), r: n.getBoundingClientRect() }))
        .filter(({ r }) => r.width < 44 || r.height < 44)
        .map(({ text, r }) => `${text} ${Math.round(r.width)}x${Math.round(r.height)}`),
    );
    expect(small, name).toEqual([]);
    const results = await new AxeBuilder({ page }).withTags(["wcag2a", "wcag2aa", "wcag21aa"]).analyze();
    expect(results.violations.map((v) => `${v.id}: ${v.nodes.map((n) => n.target.join(" ")).join(", ")}`), name).toEqual([]);
  }
});

test("as a guest, Supabase gives no direct table access (RLS)", async ({ request }) => {
  for (const table of ["orders", "order_lines", "restaurants", "menu_items", "dining_tables", "staff_calls", "payments", "shifts", "shift_expenses", "cashiers", "cashier_sessions", "profiles", "carts", "cart_lines", "payment_types"]) {
    const res = await request.get(`${SHIM}/rest/v1/${table}?select=*`, { headers: { apikey: "sb_publishable_local_only", "x-qr-slug": TABLE } });
    // Either no grant at all (401/403), or rows hidden by RLS (200 and an empty list).
    expect([200, 401, 403], `${table} status`).toContain(res.status());
    if (res.status() === 200) expect(await res.json(), table).toEqual([]);
  }
  const insert = await request.post(`${SHIM}/rest/v1/staff_calls`, {
    headers: { apikey: "sb_publishable_local_only", "x-qr-slug": TABLE, "content-type": "application/json" },
    data: { restaurant_id: "a0000000-0000-4000-8000-000000000001", table_id: "a0000000-0000-4000-8000-0000000000a1" },
  });
  expect(insert.ok()).toBe(false);
});
