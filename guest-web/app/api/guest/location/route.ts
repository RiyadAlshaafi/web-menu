import { guest } from "@/lib/server/guest";
import { guestRoute } from "@/lib/server/handler";
import { locationBody } from "@/lib/server/schemas";

export const POST = guestRoute({
  endpoint: "location",
  method: "POST",
  schema: locationBody,
  run: ({ slug, lat, lng, accuracy }) => guest.location(slug, lat, lng, accuracy),
});
