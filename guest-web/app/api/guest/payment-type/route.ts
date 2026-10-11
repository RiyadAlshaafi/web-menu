import { guest } from "@/lib/server/guest";
import { guestRoute } from "@/lib/server/handler";
import { paymentTypeBody } from "@/lib/server/schemas";

export const POST = guestRoute({
  endpoint: "payment-type",
  method: "POST",
  schema: paymentTypeBody,
  run: ({ slug, typeId }) => guest.paymentType(slug, typeId),
});
