import { readdirSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";

// The guest app must never hold a privileged Supabase key (brief: anon key only, RLS enforcing).
const root = join(__dirname, "..", "..");
// .open-next and .wrangler are generated bundles of dependency code, not the guest app's own source.
const skip = new Set(["node_modules", ".git", "coverage", "playwright-report", "test-results", ".open-next", ".wrangler"]);
const forbidden = [["service", "role"].join("_"), ["SUPABASE", "SERVICE", "ROLE"].join("_"), "sb_secret_"];

function files(dir: string, skipBuild = true): string[] {
  return readdirSync(dir).flatMap((name) => {
    if (skip.has(name) || (skipBuild && name === ".next")) return [];
    const path = join(dir, name);
    if (statSync(path).isDirectory()) return files(path, skipBuild);
    return /\.(ts|tsx|js|mjs|cjs|json|css|html|sql|sh|md)$/.test(name) || name.startsWith(".env") ? [path] : [];
  });
}

describe("no privileged Supabase key", () => {
  it("appears in the guest app's source, config or build output", () => {
    const offenders = files(root)
      .filter((path) => !path.endsWith("no-secrets.test.ts") && !path.endsWith("package-lock.json"))
      .filter((path) => {
        const text = readFileSync(path, "utf8");
        return forbidden.some((word) => text.includes(word));
      });
    expect(offenders).toEqual([]);
  });

  it("is embedded in the build output (run after `next build`)", () => {
    const build = join(root, ".next");
    let outputs: string[] = [];
    try {
      outputs = files(build, false).filter((p) => /\.(js|json|html)$/.test(p));
    } catch {
      return; // not built yet
    }
    const jwt = /eyJ[A-Za-z0-9_-]{10,}\.([A-Za-z0-9_-]{10,})\.[A-Za-z0-9_-]{10,}/g;
    const secretKey = new RegExp(`${["sb", "secret"].join("_")}_[A-Za-z0-9]`);
    const offenders = outputs.filter((path) => {
      const text = readFileSync(path, "utf8");
      if (text.includes(forbidden[1]) || secretKey.test(text)) return true;
      for (const match of text.matchAll(jwt)) {
        try {
          const role = JSON.parse(Buffer.from(match[1], "base64url").toString("utf8")).role;
          if (role && role !== "anon") return true;
        } catch {
          // not a JWT
        }
      }
      return false;
    });
    expect(offenders).toEqual([]);
  });
});
