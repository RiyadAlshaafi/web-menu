import "@testing-library/jest-dom/vitest";

// jsdom has no matchMedia. Report reduced motion, so sheets close at once instead of waiting
// for an exit animation that jsdom never plays.
if (typeof window !== "undefined" && !window.matchMedia) {
  window.matchMedia = (query: string) =>
    ({
      matches: query.includes("prefers-reduced-motion: reduce"),
      media: query,
      onchange: null,
      addEventListener: () => {},
      removeEventListener: () => {},
      addListener: () => {},
      removeListener: () => {},
      dispatchEvent: () => false,
    }) as MediaQueryList;
}
