import { guest } from "@/lib/server/guest";
import { guestRoute } from "@/lib/server/handler";
import { slugBody } from "@/lib/server/schemas";

export const POST = guestRoute({
  endpoint: "call-staff",
  method: "POST",
  schema: slugBody,
  run: ({ slug }) => guest.callStaff(slug),
});
