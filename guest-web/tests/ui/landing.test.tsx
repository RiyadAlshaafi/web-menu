// @vitest-environment jsdom
import { cleanup, fireEvent, render, screen, within } from "@testing-library/react";
import { afterEach, beforeAll, describe, expect, it, vi } from "vitest";
import "./setup";
import { LandingPage } from "@/components/landing/landing-page";
import { demoMenuHref, whatsappLink } from "@/lib/landing-config";
import { landingCopy } from "@/lib/landing-copy";

beforeAll(() => {
  vi.stubGlobal(
    "IntersectionObserver",
    class {
      observe() {}
      disconnect() {}
    },
  );
  vi.stubGlobal(
    "ResizeObserver",
    class {
      observe() {}
      disconnect() {}
    },
  );
  vi.stubGlobal("matchMedia", (query: string) => ({
    matches: false,
    media: query,
    addEventListener() {},
    removeEventListener() {},
  }));
});

afterEach(() => {
  cleanup();
  vi.unstubAllEnvs();
});

const squash = (text: string | null | undefined) => (text ?? "").replace(/\s/g, "");
const hrefs = () => [...document.querySelectorAll("a")].map((a) => a.getAttribute("href") ?? "");

describe("LandingPage", () => {
  it("opens with the English headline and the Arabic switch", () => {
    render(<LandingPage lang="en" />);
    const heading = screen.getByRole("heading", { level: 1 });
    expect(squash(heading.textContent)).toBe(squash(landingCopy.en.heroWords.join("")));
    const switcher = screen.getByRole("link", { name: "العربية" });
    expect(switcher).toHaveAttribute("href", "/ar");
    expect(switcher).toHaveAttribute("hreflang", "ar");
  });

  it("shows the Arabic words and a link back to English", () => {
    render(<LandingPage lang="ar" />);
    expect(squash(screen.getByRole("heading", { level: 1 }).textContent)).toBe(squash(landingCopy.ar.heroWords.join("")));
    expect(screen.getByRole("link", { name: "English" })).toHaveAttribute("href", "/");
  });

  it("never links to the admin or cashier site", () => {
    vi.stubEnv("NEXT_PUBLIC_WHATSAPP_NUMBER", "218910000000");
    vi.stubEnv("NEXT_PUBLIC_DEMO_MENU_PATH", "/t/demotable0001");
    for (const lang of ["en", "ar"] as const) {
      render(<LandingPage lang={lang} />);
      const bad = hrefs().filter((href) => /admin|login|pos|staff|\/c\//i.test(href));
      expect(bad).toEqual([]);
      cleanup();
    }
  });

  it("hides the two buttons when their settings are missing instead of inventing a link", () => {
    vi.stubEnv("NEXT_PUBLIC_WHATSAPP_NUMBER", "");
    vi.stubEnv("NEXT_PUBLIC_DEMO_MENU_PATH", "");
    render(<LandingPage lang="en" />);
    expect(screen.queryByRole("link", { name: /live menu/i })).toBeNull();
    expect(screen.queryByRole("link", { name: /whatsapp/i })).toBeNull();
  });

  it("links the demo menu and WhatsApp when configured", () => {
    vi.stubEnv("NEXT_PUBLIC_WHATSAPP_NUMBER", "+218 91 000 0000");
    vi.stubEnv("NEXT_PUBLIC_DEMO_MENU_PATH", "/t/demotable0001");
    render(<LandingPage lang="en" />);
    expect(screen.getByRole("link", { name: /live menu/i })).toHaveAttribute("href", "/t/demotable0001");
    const chat = screen.getAllByRole("link", { name: /whatsapp/i });
    expect(chat.length).toBeGreaterThan(0);
    for (const link of chat) {
      expect(link.getAttribute("href")).toMatch(/^https:\/\/wa\.me\/218910000000\?text=/);
      expect(link).toHaveAttribute("rel", "noopener noreferrer");
    }
  });

  it("lets a visitor pick a How it works step", () => {
    render(<LandingPage lang="en" />);
    const how = screen.getByRole("region", { name: "How it works" });
    const steps = within(how).getAllByRole("button");
    expect(steps[0]).toHaveAttribute("aria-pressed", "true");
    fireEvent.click(steps[2]);
    expect(steps[2]).toHaveAttribute("aria-pressed", "true");
    expect(steps[0]).toHaveAttribute("aria-pressed", "false");
  });

  it("keeps the repeated feature pills out of the accessibility tree", () => {
    render(<LandingPage lang="en" />);
    expect(screen.getAllByText("Works offline")).toHaveLength(2);
    expect(screen.getAllByText("Works offline").filter((el) => el.closest("[aria-hidden='true']"))).toHaveLength(1);
  });
});

describe("landing config", () => {
  it("accepts only a plain digit phone number", () => {
    expect(whatsappLink("hi", "")).toBeNull();
    expect(whatsappLink("hi", "12345")).toBeNull();
    expect(whatsappLink("hi", "abc12345678")).toBeNull();
    expect(whatsappLink("hi there", "+218 (91) 000-0000")).toBe("https://wa.me/218910000000?text=hi%20there");
  });

  it("accepts only a /t/<slug> path for the demo menu", () => {
    expect(demoMenuHref("/t/demotable0001")).toBe("/t/demotable0001");
    expect(demoMenuHref("https://evil.example/t/demotable0001")).toBeNull();
    expect(demoMenuHref("/admin")).toBeNull();
    expect(demoMenuHref("//evil.example")).toBeNull();
    expect(demoMenuHref(undefined)).toBeNull();
  });
});
