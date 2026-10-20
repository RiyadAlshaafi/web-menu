import { guest } from "@/lib/server/guest";
import { guestRoute } from "@/lib/server/handler";
import { visitBody } from "@/lib/server/schemas";

export const POST = guestRoute({
  endpoint: "visit",
  method: "POST",
  schema: visitBody,
  run: ({ slug, visitor }) => guest.visit(slug, visitor),
});
