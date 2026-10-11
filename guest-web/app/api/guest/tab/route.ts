import { guest } from "@/lib/server/guest";
import { guestRoute } from "@/lib/server/handler";
import { slugQuery } from "@/lib/server/schemas";

export const GET = guestRoute({
  endpoint: "tab",
  method: "GET",
  schema: slugQuery,
  run: ({ slug }) => guest.tab(slug),
});
