// @vitest-environment jsdom
import { act, cleanup, fireEvent, render, screen, waitFor } from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { CARD, SLUG, TEA, err, live, mockApi, ok, open, renderGuest, router, tabWith } from "./setup";
import { TabScreen } from "@/components/tab-screen";
import { BillScreen } from "@/components/bill-screen";
import { MenuScreen } from "@/components/menu-screen";
import { LanguageScreen, QrError } from "@/components/entry-screens";
import { useGuest } from "@/components/guest-provider";

beforeEach(() => {
  localStorage.clear();
  sessionStorage.clear();
  router.push.mockClear();
  live.handlers = [];
});
afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
  vi.unstubAllEnvs();
  vi.useRealTimers();
});

describe("TabScreen", () => {
  it("shows the order, its status and the ticket total", async () => {
    mockApi(() => ok(tabWith("preparing")));
    await renderGuest(<TabScreen />, { tab: tabWith("preparing"), path: `/t/${SLUG}/tab` });
    expect(screen.getByRole("heading", { name: /^Order #?0*7$/ })).toBeInTheDocument();
    expect(screen.getByRole("list", { name: /Preparing/i })).toBeInTheDocument();
    expect(screen.getByText("Old dish")).toBeInTheDocument();
    expect(screen.getByText(/13\.000/)).toBeInTheDocument();
    expect(screen.getByRole("link", { name: /Table Bill/ })).toHaveAttribute("aria-current", "page");
  });

  it("refuses the bill until the order is served", async () => {
    const calls = mockApi(() => ok(tabWith("preparing")));
    await renderGuest(<TabScreen />, { tab: tabWith("preparing") });
    fireEvent.click(screen.getByRole("button", { name: "Request Bill" }));
    expect(await screen.findByText(/after the waiter marks/)).toBeInTheDocument();
    expect(calls.some((c) => c.url.includes("/bill"))).toBe(false);
  });

  it("asks for the bill once served and opens the bill page", async () => {
    const calls = mockApi((url) => (url.includes("/bill") ? ok({ ok: true }) : ok(tabWith("served"))));
    await renderGuest(<TabScreen />, { tab: tabWith("served") });
    fireEvent.click(screen.getByRole("button", { name: "Request Bill" }));
    await waitFor(() => expect(router.push).toHaveBeenCalledWith(`/t/${SLUG}/bill?lang=en`));
    expect(calls.find((c) => c.url.endsWith("/bill"))!.body).toEqual({ slug: SLUG });
  });

  it("calls the server, and says so when ordering is paused", async () => {
    const calls = mockApi((url) => (url.includes("call-staff") ? ok({ ok: true }) : ok(tabWith("served"))));
    await renderGuest(<TabScreen />, { tab: tabWith("served") });
    fireEvent.click(screen.getByRole("button", { name: "Call Server" }));
    expect(await screen.findByText("Request sent")).toBeInTheDocument();
    expect(calls.filter((c) => c.url.includes("call-staff"))).toHaveLength(1);
    cleanup();
    await renderGuest(<TabScreen />, { tab: tabWith("served"), status: { ...open, orderingOpen: false } });
    fireEvent.click(screen.getByRole("button", { name: "Call Server" }));
    fireEvent.click(screen.getByRole("button", { name: "Call Staff" }));
    expect(screen.getAllByText(/cashier/i).length).toBeGreaterThan(0);
    expect(calls.filter((c) => c.url.includes("call-staff"))).toHaveLength(1);
  });

  it("edits dishes not sent yet", async () => {
    localStorage.setItem(`tawla-cart:${SLUG}`, JSON.stringify({ [TEA]: 2 }));
    mockApi(() => ok(tabWith("served")));
    await renderGuest(<TabScreen />, { tab: tabWith("served") });
    expect(screen.getByText("New Additions")).toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: "Increase Mint Tea" }));
    expect(JSON.parse(localStorage.getItem(`tawla-cart:${SLUG}`)!)).toEqual({ [TEA]: 3 });
    fireEvent.click(screen.getByRole("button", { name: "Decrease Mint Tea" }));
    fireEvent.click(screen.getByRole("button", { name: "Decrease Mint Tea" }));
    fireEvent.click(screen.getByRole("button", { name: "Decrease Mint Tea" }));
    expect(localStorage.getItem(`tawla-cart:${SLUG}`)).toBeNull();
  });

  it("shows nothing to order yet, and the bill tab is disabled", async () => {
    mockApi(() => ok({ table: { number: "4", status: "free" }, order: null }));
    await renderGuest(<TabScreen />, { tab: { table: { number: "4", status: "free" }, order: null } });
    expect(screen.getByText("No active orders.")).toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: /Table Bill/ }));
    expect(screen.getByText("Place an order first.")).toBeInTheDocument();
  });

  it("confirms a refused dish", async () => {
    const refused = tabWith("served", { awaitingConfirmation: true, refusalNotice: "Mint Tea" });
    const calls = mockApi((url) => (url.includes("/refusal") ? err("cashier_offline") : ok(refused)));
    await renderGuest(<TabScreen />, { tab: refused });
    const alert = screen.getAllByRole("alert").find((a) => a.textContent?.includes("Item removed"))!;
    fireEvent.click(alert.querySelector("button")!);
    await waitFor(() => expect(calls.some((c) => c.url.endsWith("/refusal"))).toBe(true));
    expect(await screen.findByText(/cashier/i, { selector: "p" })).toBeInTheDocument();
  });
});

describe("BillScreen", () => {
  it("adds the service charge to the total", async () => {
    mockApi(() => ok(tabWith("served")));
    await renderGuest(<BillScreen />, { tab: tabWith("served"), path: `/t/${SLUG}/bill` });
    expect(screen.getByText("Service Charge (10%)")).toBeInTheDocument();
    expect(screen.getByText(/1\.300/)).toBeInTheDocument();
    expect(screen.getByText(/14\.300/)).toBeInTheDocument();
    expect(screen.getByText(/Ref/)).toBeInTheDocument();
  });

  it("needs a payment method, then sends it and asks for the bill", async () => {
    const calls = mockApi((url) =>
      url.includes("payment-type") || url.includes("/bill") ? ok({ ok: true }) : ok(tabWith("served", { paymentTypeId: CARD })),
    );
    await renderGuest(<BillScreen />, { tab: tabWith("served") });
    fireEvent.click(screen.getByRole("button", { name: "Confirm and request bill" }));
    expect(await screen.findByText("How will you pay?", { selector: "p" })).toBeInTheDocument();
    fireEvent.change(screen.getByLabelText("How will you pay?"), { target: { value: CARD } });
    await waitFor(() => expect((screen.getByLabelText("How will you pay?") as HTMLSelectElement).value).toBe(CARD));
    expect(calls.find((c) => c.url.endsWith("/payment-type"))!.body).toEqual({ slug: SLUG, typeId: CARD });
    fireEvent.click(screen.getByRole("button", { name: "Confirm and request bill" }));
    await waitFor(() => expect(calls.some((c) => c.url.endsWith("/bill"))).toBe(true));
  });

  it("refuses the bill before serving and reports a failed payment update", async () => {
    const calls = mockApi((url) => (url.includes("payment-type") ? err("rate_limited") : ok(tabWith("ready"))));
    await renderGuest(<BillScreen />, { tab: tabWith("ready") });
    fireEvent.click(screen.getByRole("button", { name: "Confirm and request bill" }));
    expect(await screen.findByText(/after the waiter marks/)).toBeInTheDocument();
    fireEvent.change(screen.getByLabelText("How will you pay?"), { target: { value: CARD } });
    expect(await screen.findByText(/Too many tries/)).toBeInTheDocument();
    expect(calls.some((c) => c.url.endsWith("/bill"))).toBe(false);
  });

  it("shows the paid view after the cashier settles", async () => {
    sessionStorage.setItem(`tawla-had-order:${SLUG}`, "1");
    const free = { table: { number: "4", status: "free" }, order: null };
    mockApi(() => ok(free));
    await renderGuest(<BillScreen />, { tab: free });
    expect(screen.getByText("PAID")).toBeInTheDocument();
    expect(screen.getByText(/Akakus Café/, { selector: "p.text-muted" })).toBeInTheDocument();
  });

  it("shows no orders when the table never ordered", async () => {
    const free = { table: { number: "4", status: "free" }, order: null };
    mockApi(() => ok(free));
    await renderGuest(<BillScreen />, { tab: free });
    expect(screen.getByText("No active orders.")).toBeInTheDocument();
  });
});

describe("live updates and refetching", () => {
  it("refreshes the tab on a table ping and the menu on a menu ping", async () => {
    vi.stubEnv("NEXT_PUBLIC_SUPABASE_URL", "https://x.supabase.co/");
    vi.stubEnv("NEXT_PUBLIC_SUPABASE_ANON_KEY", "sb_publishable_x");
    Object.defineProperty(window, "requestIdleCallback", { configurable: true, value: (cb: () => void) => setTimeout(cb, 0) });
    Object.defineProperty(window, "cancelIdleCallback", { configurable: true, value: (id: number) => clearTimeout(id) });
    const { menu } = await import("./setup");
    const renamed = menu();
    renamed.items[0].nameEn = "Green Tea";
    const calls = mockApi((url) =>
      url.includes("/menu") ? ok(renamed) : url.includes("/status") ? ok(open) : ok(tabWith("ready")),
    );
    const view = await renderGuest(<TabScreen />, { tab: tabWith("received") });
    await waitFor(() => expect(live.handlers.map((h) => h.topic).sort()).toEqual(["cafe:cafe-1", `guest:${SLUG}`]));
    const fire = (topic: string, table: string) => live.handlers.find((h) => h.topic === topic)!.cb({ payload: { table } });

    act(() => fire(`guest:${SLUG}`, "orders"));
    await screen.findByRole("list", { name: /Ready/i });

    act(() => fire("cafe:cafe-1", "shifts")); // not a menu table
    act(() => fire("cafe:cafe-1", "menu_items"));
    await screen.findByText("Green Tea");
    expect(calls.filter((c) => c.url.includes("/menu"))).toHaveLength(1);

    act(() => fire("cafe:cafe-1", "cashier_presence"));
    await waitFor(() => expect(calls.some((c) => c.url.includes("/status"))).toBe(true));
    view.unmount();
    expect(live.removed).toBeGreaterThan(0);
  });

  it("refetches when the page becomes visible again", async () => {
    const { menu } = await import("./setup");
    const calls = mockApi((url) => (url.includes("/status") ? ok(open) : url.includes("/menu") ? ok(menu()) : ok(tabWith("ready"))));
    await renderGuest(<TabScreen />, { tab: tabWith("received") });
    act(() => {
      document.dispatchEvent(new Event("visibilitychange"));
    });
    await screen.findByRole("list", { name: /Ready/i });
    expect(calls.map((c) => new URL(c.url, "http://x").pathname).sort()).toEqual(
      ["/api/guest/menu", "/api/guest/status", "/api/guest/tab"],
    );
  });

  it("polls status every 15 seconds", async () => {
    vi.useFakeTimers();
    const calls = mockApi((url) => (url.includes("/status") ? ok({ ...open, orderingOpen: false }) : ok(tabWith("ready"))));
    await renderGuest(<MenuScreen />);
    await act(async () => {
      await vi.advanceTimersByTimeAsync(15_000);
    });
    expect(calls.filter((c) => c.url.includes("/status"))).toHaveLength(1);
    expect(screen.getAllByText(/cashier/i).length).toBeGreaterThan(0);
  });
});

describe("entry screens", () => {
  it("lets the guest pick a language and opens the menu in it", () => {
    const assign = vi.fn();
    vi.stubGlobal("location", { ...window.location, assign });
    render(<LanguageScreen slug={SLUG} cafeName="Akakus Café" logoUrl="" tableNumber="4" initial="en" />);
    expect(screen.getByRole("main")).toHaveAttribute("dir", "ltr");
    fireEvent.click(screen.getByRole("button", { name: "العربية" }));
    expect(screen.getByRole("main")).toHaveAttribute("dir", "rtl");
    expect(screen.getByText("اختر لغتك")).toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: "افتح القائمة" }));
    expect(assign).toHaveBeenCalledWith(`/t/${SLUG}?lang=ar`);
  });

  it("explains a bad QR code, or too many tries", () => {
    const reload = vi.fn();
    vi.stubGlobal("location", { ...window.location, reload });
    render(<QrError lang="en" />);
    expect(screen.getByRole("heading", { name: /doesn't match a table/ })).toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: "Try again" }));
    expect(reload).toHaveBeenCalled();
    cleanup();
    render(<QrError lang="ar" rateLimited />);
    expect(screen.getByRole("heading", { name: /محاولات كثيرة/ })).toBeInTheDocument();
  });

  it("useGuest needs the provider", () => {
    const Probe = () => {
      useGuest();
      return null;
    };
    vi.spyOn(console, "error").mockImplementation(() => {});
    expect(() => render(<Probe />)).toThrow(/outside GuestProvider/);
  });
});
