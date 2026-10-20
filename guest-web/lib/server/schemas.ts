import { z } from "zod";

// Today's QR slugs are 12 lowercase letters and digits; older or test tables may differ a little.
export const slug = z
  .string()
  .trim()
  .regex(/^[a-z0-9][a-z0-9-]{3,63}$/);

const lat = z.number().finite().min(-90).max(90);
const lng = z.number().finite().min(-180).max(180);
const accuracy = z.number().finite().min(0).max(10_000);

export const slugQuery = z.object({ slug }).strict();

// `v` is a cache-busting stamp the page adds after a live ping; it is otherwise ignored.
export const menuQuery = z.object({ slug, v: z.string().regex(/^\d{1,16}$/).optional() }).strict();

export const slugBody = z.object({ slug }).strict();

// A random id the guest's own browser made (a UUID). The database keeps only a per-day hash of it.
export const visitBody = z.object({ slug, visitor: z.string().regex(/^[A-Za-z0-9-]{16,64}$/) }).strict();

export const locationBody =z.object({ slug, lat, lng, accuracy: accuracy.optional() }).strict();

// A dish never has more options than the database allows (valid_dish_options).
const MAX_OPTIONS = 40;

// Only dish id, quantity and the options that are on: prices, names and totals are decided by
// the database.
export const orderBody = z
  .object({
    slug,
    lines: z
      .array(
        z
          .object({
            menuItemId: z.uuid(),
            qty: z.number().int().min(1).max(99),
            on: z
              .array(z.uuid())
              .max(MAX_OPTIONS)
              .refine((ids) => new Set(ids).size === ids.length, { message: "option ids repeat" })
              .optional(),
          })
          .strict(),
      )
      .min(1)
      .max(100),
    lat: lat.optional(),
    lng: lng.optional(),
    accuracy: accuracy.optional(),
  })
  .strict()
  .refine((body) => (body.lat === undefined) === (body.lng === undefined), { message: "lat and lng go together" });

export const paymentTypeBody = z.object({ slug, typeId: z.uuid() }).strict();
