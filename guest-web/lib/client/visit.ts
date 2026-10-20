import { api } from "./api";
import { readRaw, writeRaw } from "./stored";

const VISITOR_KEY = "tawla-visitor";
const VISIT_SENT_PREFIX = "tawla-visit:";

// A random id made once in this browser and kept in its own storage. It is never sent anywhere
// except to be hashed with the day by the database, so it only answers "was this browser
// already counted today".
function visitorId(): string {
  const saved = readRaw("local", VISITOR_KEY);
  if (saved && /^[A-Za-z0-9-]{16,64}$/.test(saved)) return saved;
  const made = crypto.randomUUID();
  writeRaw("local", VISITOR_KEY, made);
  return made;
}

// Counts this browser as a visitor of the table's cafe, once per tab session. Never throws and
// never makes the page wait: a failed count is simply lost.
export function recordVisit(slug: string): void {
  try {
    const sentKey = `${VISIT_SENT_PREFIX}${slug}`;
    if (readRaw("session", sentKey) === "1") return;
    writeRaw("session", sentKey, "1");
    void api.visit(slug, visitorId());
  } catch {
    // Storage or crypto unavailable: skip counting.
  }
}
