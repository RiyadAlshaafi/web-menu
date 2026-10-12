# Hide the staff site from tawla.ly

Today `tawla.ly/` is the public sales page, and the staff site (admin and cashier) answers on
`staff.tawla.ly`. It also still answers on `tawla.ly/login`, `tawla.ly/admin/...` and so on, so
old bookmarks keep working. This runbook removes that last overlap. Do it only after every
cashier and admin uses `staff.tawla.ly`.

## Before you start

1. Open `https://staff.tawla.ly/login` and sign in as an admin and as a cashier.
2. Supabase dashboard, Authentication, URL configuration: add `https://staff.tawla.ly/**` to the
   redirect URLs. Password-reset emails link back to the staff site.
3. Re-link each device once: open `https://staff.tawla.ly/c/<cafe-slug>`.
4. Print a table QR code from the staff site and check it reads `https://tawla.ly/t/<slug>`.

## Cut over (in this order)

1. In `wrangler.jsonc`, delete the `tawla.ly` custom domain line and keep `staff.tawla.ly`. Push to
   `main`; the "Web deploy" workflow runs. Confirm in the Cloudflare dashboard that `tawla.ly` no
   longer belongs to `tawla-web`.
2. In `guest-web/wrangler.jsonc`, replace the `routes` list with
   `[{ "pattern": "tawla.ly", "custom_domain": true }]`. Push; the "Guest deploy" workflow runs.
3. Check `https://tawla.ly/`, `/ar` and `/t/<slug>` load, and `https://tawla.ly/login` is a 404.

Do the two steps in separate pushes. If step 2 fails because the name is still taken, wait for
step 1 to finish and run "Guest deploy" again.

## Roll back

Put the `tawla.ly` custom domain line back in `wrangler.jsonc` and push.
