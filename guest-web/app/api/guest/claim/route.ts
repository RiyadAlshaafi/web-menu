import { guest } from "@/lib/server/guest";
import { guestRoute } from "@/lib/server/handler";
import { claimBody } from "@/lib/server/schemas";

export const POST = guestRoute({
  endpoint: "claim",
  method: "POST",
  schema: claimBody,
  run: ({ slug, visitor, lat, lng, accuracy }) => guest.claim(slug, visitor, { lat, lng, accuracy }),
});
