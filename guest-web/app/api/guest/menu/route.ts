import { guest } from "@/lib/server/guest";
import { guestRoute } from "@/lib/server/handler";
import { menuQuery } from "@/lib/server/schemas";

// A minute at the edge keeps most scans off the database. After a live ping the page adds a
// fresh `v` stamp, which makes a new cache key, so staff changes still show at once.
export const GET = guestRoute({
  endpoint: "menu",
  method: "GET",
  schema: menuQuery,
  cacheControl: "public, s-maxage=60, stale-while-revalidate=300",
  run: ({ slug }) => guest.menu(slug),
});
