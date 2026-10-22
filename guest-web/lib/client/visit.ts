import { api } from "./api";
import { readRaw, writeRaw } from "./stored";
import { visitorId } from "./visitor";

const VISIT_SENT_PREFIX = "tawla-visit:";

// Counts this browser as a visitor of the table's cafe, once per tab session. Never throws and
// never makes the page wait: a failed count is simply lost.
export function recordVisit(slug: string): void {
  try {
    const sentKey = `${VISIT_SENT_PREFIX}${slug}`;
    if (readRaw("session", sentKey) === "1") return;
    writeRaw("session", sentKey, "1");
    const visitor = visitorId();
    if (visitor) void api.visit(slug, visitor);
  } catch {
    // Storage or crypto unavailable: skip counting.
  }
}
