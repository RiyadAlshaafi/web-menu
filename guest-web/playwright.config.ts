import { defineConfig, devices } from "@playwright/test";

// Browser tests against a running app (npm start) backed by the local stack in e2e/ (see
// README). Phone profiles run in Chromium; the iPhone profile keeps Safari's viewport, touch
// and user agent.
export default defineConfig({
  testDir: "e2e",
  globalSetup: "./e2e/global-setup.ts",
  fullyParallel: false,
  workers: 1,
  retries: 0,
  reporter: [["list"]],
  use: {
    baseURL: process.env.E2E_BASE_URL ?? "http://localhost:3100",
    trace: "retain-on-failure",
    launchOptions: process.env.CHROMIUM_PATH ? { executablePath: process.env.CHROMIUM_PATH } : undefined,
  },
  // A fresh server per run, so in-memory rate limits start empty.
  webServer: process.env.E2E_BASE_URL
    ? undefined
    : { command: "npm run start -- -p 3100", url: "http://localhost:3100/", reuseExistingServer: false, timeout: 60_000 },
  projects: [
    { name: "iphone", use: { ...devices["iPhone 13"], browserName: "chromium" } },
    { name: "android", use: { ...devices["Pixel 7"] } },
  ],
});
