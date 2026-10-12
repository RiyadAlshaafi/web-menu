// @vitest-environment jsdom
import { act, cleanup, fireEvent, screen, waitFor, within } from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { CAPPU, SLUG, TEA, err, mockApi, ok, open, renderGuest, router, tabWith } from "./setup";
import { MenuScreen } from "@/components/menu-screen";

const tabEmpty = { table: { number: "4", status: "free" }, order: null };

beforeEach(() => {
  localStorage.clear();
  sessionStorage.clear();
  router.push.mockClear();
});
afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
  vi.useRealTimers();
});

const addButton = (name: RegExp) => screen.getByRole("button", { name });

describe("MenuScreen", () => {
  it("titles the menu with the cafe's own name in English and Arabic", async () => {
    mockApi(() => ok(tabEmpty));
    await renderGuest(<MenuScreen />);
    expect(screen.getByRole("heading", { name: "Akakus Café Menu" })).toBeInTheDocument();
    expect(screen.queryByText(/Mezzogiorno/)).toBeNull();
    cleanup();

    await renderGuest(<MenuScreen />, { lang: "ar" });
    expect(screen.getByRole("heading", { name: "قائمة Akakus Café" })).toBeInTheDocument();
    expect(screen.queryByText("قائمة الغداء")).toBeNull();
  });

  it("lists dishes, filters by chip and shows the spotlight", async () => {
    mockApi(() => ok(tabEmpty));
    await renderGuest(<MenuScreen />);
    expect(screen.getByText("3 items")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Mint Tea" })).toBeInTheDocument(); // spotlight
    expect(screen.getByRole("heading", { name: "Drinks" })).toBeInTheDocument();

    fireEvent.click(screen.getByRole("button", { name: "Food" }));
    expect(screen.getByText("1 items")).toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "Mint Tea" })).toBeNull();

    fireEvent.click(screen.getByRole("button", { name: "Chef's Specials" }));
    expect(screen.getByText("1 items")).toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: "All" }));
    expect(screen.getByText("3 items")).toBeInTheDocument();
    expect(addButton(/^Add Juice/)).toBeDisabled();
  });

  it("adds to the cart, reviews and sends the order, then opens the tab", async () => {
    const calls = mockApi((url) =>
      url.includes("/order") ? ok({ orderId: "o1", round: 1 }) : ok(tabWith("received")),
    );
    await renderGuest(<MenuScreen />);
    fireEvent.click(addButton(/^Add Mint Tea/));
    fireEvent.click(addButton(/^Add Mint Tea/));
    fireEvent.click(addButton(/^Add Cappuccino/));
    expect(screen.getByLabelText("2 in your order")).toBeInTheDocument();
    expect(JSON.parse(localStorage.getItem(`tawla-cart:${SLUG}`)!)).toEqual({ [TEA]: 2, [CAPPU]: 1 });

    fireEvent.click(screen.getByRole("button", { name: /3 items • Cart/ }));
    const sheet = screen.getByRole("dialog");
    // Drop the cappuccino in the review sheet.
    fireEvent.click(within(within(sheet).getByRole("group", { name: "Cappuccino" })).getByRole("button", { name: "Decrease" }));
    fireEvent.click(within(sheet).getByRole("button", { name: /Confirm & Send to Kitchen/ }));

    await waitFor(() => expect(router.push).toHaveBeenCalledWith(`/t/${SLUG}/tab?lang=en`));
    const order = calls.find((c) => c.url.endsWith("/api/guest/order"))!;
    expect(order.method).toBe("POST");
    expect(order.body).toEqual({ slug: SLUG, lines: [{ menuItemId: TEA, qty: 2 }] });
    expect(localStorage.getItem(`tawla-cart:${SLUG}`)).toBeNull();
    expect(sessionStorage.getItem(`tawla-had-order:${SLUG}`)).toBe("1");
  });

  it("opens the dish sheet and adds the chosen quantity", async () => {
    mockApi(() => ok(tabEmpty));
    await renderGuest(<MenuScreen />);
    fireEvent.click(screen.getAllByRole("button", { name: /^Cappuccino/ })[0]);
    const sheet = screen.getByRole("dialog", { name: "Cappuccino" });
    expect(within(sheet).getByText("كابتشينو")).toBeInTheDocument();
    fireEvent.click(within(sheet).getByRole("button", { name: "Increase" }));
    fireEvent.click(within(sheet).getByRole("button", { name: /Add to Order/ }));
    expect(screen.queryByRole("dialog")).toBeNull();
    expect(JSON.parse(localStorage.getItem(`tawla-cart:${SLUG}`)!)).toEqual({ [CAPPU]: 2 });

    fireEvent.click(screen.getByRole("button", { name: "Mint Tea" }));
    fireEvent.keyDown(document, { key: "Escape" });
    expect(screen.queryByRole("dialog")).toBeNull();
  });

  it("names the sold-out dishes in the guest's language when the order is refused", async () => {
    localStorage.setItem(`tawla-cart:${SLUG}`, JSON.stringify({ [TEA]: 1 }));
    mockApi((url) => (url.includes("/order") ? err("items_unavailable", ["Mint Tea"]) : ok(tabEmpty)));
    await renderGuest(<MenuScreen />, { lang: "ar" });
    fireEvent.click(screen.getByRole("button", { name: /السلة/ }));
    fireEvent.click(screen.getByRole("button", { name: /تأكيد وإرسال للمطبخ/ }));
    await screen.findByText(/هذه الأطباق لم تعد متوفرة: شاي/);
    expect(router.push).not.toHaveBeenCalled();
  });

  it("pauses ordering when the cashier goes offline", async () => {
    localStorage.setItem(`tawla-cart:${SLUG}`, JSON.stringify({ [TEA]: 1 }));
    mockApi((url) => (url.includes("/order") ? err("cashier_offline") : ok(tabEmpty)));
    await renderGuest(<MenuScreen />);
    fireEvent.click(screen.getByRole("button", { name: /1 items • Cart/ }));
    fireEvent.click(screen.getByRole("button", { name: /Confirm & Send/ }));
    await waitFor(() => expect(screen.getAllByText(/cashier/i).length).toBeGreaterThan(0));
    // Now blocked: the add button only repeats why.
    fireEvent.click(addButton(/^Add Mint Tea/));
    expect(JSON.parse(localStorage.getItem(`tawla-cart:${SLUG}`)!)).toEqual({ [TEA]: 1 });
  });

  it("blocks adding while ordering is paused from the start", async () => {
    mockApi(() => ok(tabEmpty));
    await renderGuest(<MenuScreen />, { status: { ...open, orderingOpen: false } });
    fireEvent.click(addButton(/^Add Mint Tea/));
    expect(localStorage.getItem(`tawla-cart:${SLUG}`)).toBeNull();
    expect(screen.getAllByText(/cashier/i).length).toBeGreaterThan(0);
  });

  it("shows the empty menu hint", async () => {
    mockApi(() => ok(tabEmpty));
    const { GuestProvider } = await import("@/components/guest-provider");
    const { render } = await import("@testing-library/react");
    const { menu } = await import("./setup");
    render(
      <GuestProvider slug={SLUG} lang="en" initialMenu={{ ...menu(), items: [], categories: [] }} initialStatus={open} initialTab={null}>
        <MenuScreen />
      </GuestProvider>,
    );
    expect(screen.getByText(/menu/i, { selector: "p" })).toBeInTheDocument();
  });
});

describe("location check", () => {
  const located = { ...open, location: { enabled: true, radiusM: 50 } };
  const geo = (impl: (ok: PositionCallback, fail: PositionErrorCallback) => void) =>
    Object.defineProperty(navigator, "geolocation", { configurable: true, value: { getCurrentPosition: impl } });

  it("sends the checked position with the order", async () => {
    geo((ok) => ok({ coords: { latitude: 32.9, longitude: 13.18, accuracy: 12 } } as GeolocationPosition));
    localStorage.setItem(`tawla-cart:${SLUG}`, JSON.stringify({ [TEA]: 1 }));
    const calls = mockApi((url) =>
      url.includes("/location")
        ? ok({ enabled: true, status: "allowed" })
        : url.includes("/order")
          ? ok({ orderId: "o1", round: 1 })
          : ok(tabWith("received")),
    );
    await renderGuest(<MenuScreen />, { status: located });
    await waitFor(() => expect(calls.some((c) => c.url.includes("/location"))).toBe(true));
    await waitFor(() => expect(screen.queryByText(/Checking your location/)).toBeNull());
    fireEvent.click(screen.getByRole("button", { name: /1 items • Cart/ }));
    fireEvent.click(screen.getByRole("button", { name: /Confirm & Send/ }));
    await waitFor(() => expect(router.push).toHaveBeenCalled());
    const order = calls.find((c) => c.url.endsWith("/order"))!;
    expect(order.body).toMatchObject({ lat: 32.9, lng: 13.18, accuracy: 12 });
    expect(calls.filter((c) => c.url.includes("/location"))).toHaveLength(1); // cached point reused
  });

  it("says too far and lets the guest retry", async () => {
    geo((ok) => ok({ coords: { latitude: 1, longitude: 1, accuracy: 5 } } as GeolocationPosition));
    const calls = mockApi((url) => (url.includes("/location") ? ok({ enabled: true, status: "too_far" }) : ok(tabEmpty)));
    await renderGuest(<MenuScreen />, { status: located });
    await screen.findByText(/too far from the cafe/);
    fireEvent.click(screen.getByRole("button", { name: "Retry" }));
    await waitFor(() => expect(calls.filter((c) => c.url.includes("/location"))).toHaveLength(2));
  });

  it("explains a denied permission with the iPhone hint", async () => {
    geo((_ok, fail) => fail({ code: 1 } as GeolocationPositionError));
    mockApi(() => ok(tabEmpty));
    await renderGuest(<MenuScreen />, { status: located });
    await screen.findByText(/Location is needed/);
    expect(screen.getByText(/On iPhone/)).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Allow location" })).toBeInTheDocument();
  });

  it("treats a failed check as unavailable, and picks up a check staff switched off", async () => {
    geo((ok) => ok({ coords: { latitude: 1, longitude: 1, accuracy: 5 } } as GeolocationPosition));
    let verdict: unknown = err("server_error");
    let status = located;
    mockApi((url) => (url.includes("/location") ? verdict : url.includes("/status") ? ok(status) : ok(tabEmpty)));
    await renderGuest(<MenuScreen />, { status: located });
    await screen.findByText(/Couldn't|location/i, { selector: "p.font-bold" });
    verdict = ok({ enabled: false, radiusM: 0, status: null });
    status = open;
    await act(async () => fireEvent.click(screen.getByRole("button", { name: "Retry" })));
    await waitFor(() => expect(screen.queryByRole("button", { name: "Retry" })).toBeNull());
    fireEvent.click(addButton(/^Add Mint Tea/));
    expect(JSON.parse(localStorage.getItem(`tawla-cart:${SLUG}`)!)).toEqual({ [TEA]: 1 });
  });

  it("re-checks an expired position at send: sends without one if staff switched the check off, explains a refusal", async () => {
    geo((ok) => ok({ coords: { latitude: 1, longitude: 1, accuracy: 5 } } as GeolocationPosition));
    let verdict: unknown = ok({ enabled: true, radiusM: 50, status: "allowed" });
    const calls = mockApi((url) =>
      url.includes("/location")
        ? verdict
        : url.includes("/status")
          ? ok(located)
          : url.includes("/order")
            ? ok({ orderId: "o1", round: 1 })
            : ok(tabWith("received")),
    );
    vi.useFakeTimers({ toFake: ["Date"] });
    localStorage.setItem(`tawla-cart:${SLUG}`, JSON.stringify({ [TEA]: 1 }));
    const send = async () => {
      await screen.findByRole("button", { name: /1 items • Cart/ });
      vi.setSystemTime(Date.now() + 11 * 60_000); // the checked position has expired
      fireEvent.click(screen.getByRole("button", { name: /1 items • Cart/ }));
      fireEvent.click(screen.getByRole("button", { name: /Confirm & Send/ }));
    };
    await renderGuest(<MenuScreen />, { status: located });
    await waitFor(() => expect(screen.queryByText(/Checking your location/)).toBeNull());

    verdict = ok({ enabled: false, radiusM: 0, status: null });
    await send();
    await waitFor(() => expect(router.push).toHaveBeenCalled());
    const order = calls.find((c) => c.url.endsWith("/order"))!;
    expect(order.body).toEqual({ slug: SLUG, lines: [{ menuItemId: TEA, qty: 1 }] });

    cleanup();
    localStorage.setItem(`tawla-cart:${SLUG}`, JSON.stringify({ [TEA]: 1 }));
    verdict = ok({ enabled: true, radiusM: 50, status: "allowed" });
    await renderGuest(<MenuScreen />, { status: located });
    await waitFor(() => expect(screen.queryByText(/Checking your location/)).toBeNull());
    verdict = ok({ enabled: true, radiusM: 50, status: "too_far" });
    await send();
    await waitFor(() => expect(screen.getAllByText(/too far from the cafe/).length).toBe(2)); // banner and toast
    expect(calls.filter((c) => c.url.endsWith("/order"))).toHaveLength(1);
  });
});

