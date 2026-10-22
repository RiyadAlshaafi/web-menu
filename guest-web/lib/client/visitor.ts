import { readRaw, writeRaw } from "./stored";

const VISITOR_KEY = "tawla-visitor";

// A random id made once in this browser and kept in its own storage. The server only ever sees
// hashes of it: to count a visit once a day, and to tell which phone owns a table. Null when the
// browser gives no storage or crypto, in which case the page simply cannot claim a table.
export function visitorId(): string | null {
  try {
    const saved = readRaw("local", VISITOR_KEY);
    if (saved && /^[A-Za-z0-9-]{16,64}$/.test(saved)) return saved;
    const made = crypto.randomUUID();
    writeRaw("local", VISITOR_KEY, made);
    return made;
  } catch {
    return null;
  }
}
