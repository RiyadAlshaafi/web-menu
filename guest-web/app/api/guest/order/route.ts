import { guest } from "@/lib/server/guest";
import { guestRoute } from "@/lib/server/handler";
import { orderBody } from "@/lib/server/schemas";

export const POST = guestRoute({
  endpoint: "order",
  method: "POST",
  schema: orderBody,
  run: ({ slug, lines, lat, lng, accuracy, visitor }) => guest.order(slug, lines, { lat, lng, accuracy }, visitor),
});
