import { guest } from "@/lib/server/guest";
import { guestRoute } from "@/lib/server/handler";
import { slugQuery } from "@/lib/server/schemas";

export const GET = guestRoute({
  endpoint: "status",
  method: "GET",
  schema: slugQuery,
  run: ({ slug }) => guest.status(slug),
});
