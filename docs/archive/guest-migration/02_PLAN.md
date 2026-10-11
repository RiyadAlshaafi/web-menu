# Guest web rebuild: plan

Phase 2 of the guest rebuild. Built on [01_GUEST_FEATURE_INVENTORY.md](01_GUEST_FEATURE_INVENTORY.md)
(the "inventory"). Nothing here is built yet; this waits for Riyad's "approved".

## Decisions already made (2026-10-11)

Riyad accepted every default from the inventory's open questions:

| # | Decision |
| --- | --- |
| Q1 | Dine-in only, like today. No takeout choice for guests. |
| Q2 | The cart lives on each phone and is sent in one `send_table_cart` call. Phones at one table no longer share a cart. |
| Q3 | Brand only what staff can set today: name, logo, header and button colours, category/dish order and visibility, featured dishes, discounts, availability. No new "layout style". |
| Q4 | No item notes or options. |
| Q5 | A new Vercel project for the guest app. Old QR codes are forwarded; cafes' `public_menu_url` is switched so new QR codes go straight there. Domain still open (see [Open items](#open-items)): plan uses the default `*.vercel.app` URL. |
| Q6 | Staff changes to menu, colours and availability reach open guest pages within seconds. |
| Q7 | Bill rules stay exactly as today; nothing new is enforced on the server. |
| Q8 | One open "call staff" per table; repeat taps re-use it. |
| Q9 | Work on a feature branch with PRs, never directly on `main`. |
| Deploy | "Push the guest only to web": only the guest web app is deployed (Vercel). No Windows or other native release for this work; cashier and admin screens are not changed. |

---

## 1. Architecture

```
 phone ──HTTPS──▶ guest-web (Next.js on Vercel)
                    │  Server Components render the menu
                    │  /api/guest/* route handlers (zod, rate limit)
                    ▼
                 Supabase (anon key, x-qr-slug header, SECURITY DEFINER RPCs)
                    ▲
 phone ──WSS (read-only broadcast pings)── Supabase Realtime
                    ▲
 Flutter cashier/admin (unchanged) ─── same tables, same RPCs
```

- New app in `guest-web/` in this repo: Next.js (App Router), TypeScript `strict`, Tailwind,
  pnpm or npm (whatever the Vercel project settles on; npm by default, `package-lock.json`
  committed). Node 22.
- Mobile-first, max content width 430 px like today (`customer/call_staff.dart:89-99`).
- Server Components for anything that is only rendered: header, category list, dish rows,
  prices. Client components only for: language choice, cart and dish sheet, location check,
  ordering-open status, live updates, tab/bill actions.
- No Supabase client library in the menu page's JS bundle except the small Realtime client
  (see §4), loaded after first paint.

### Pages

| Route | What | Rendering |
| --- | --- | --- |
| `/` | Forwards old-style links `/#/t/<slug>[/cart|/bill]` to `/t/<slug>[...]` with a tiny inline script; otherwise a plain "Scan the QR code on your table" page | Static |
| `/t/[slug]` | Language choice (every fresh visit, like today), then the menu | Server Component; language from `?lang=en|ar` so the first HTML is already in the right language and direction |
| `/t/[slug]/tab` | Table Bill: live order card, status steps, new additions, call server, request bill (today `/t/<slug>/cart`) | Server shell + client status |
| `/t/[slug]/bill` | Final bill: lines, service charge, total, payment method, confirm and request bill, paid view | Server shell + client actions |
| `/t/[slug]/cart` | Redirects to `/tab` so forwarded old links still land | Redirect |

Unknown or archived slug: the same "This QR code doesn't match a table" page with Retry
(inventory §1). Missing `lang`: show the language screen with the cafe's locale preselected.

### Behaviour kept from today

Everything listed in inventory §2 except the decisions above: category chips (All, Chef's
Specials, visible categories), spotlight card, struck-through unavailable dishes, discount
prices, dish sheet with quantity, 99-per-dish cap, "Verify Your Order" sheet, rounds, live
status steps, bill after "served", payment method, refusal notice, location and cashier-offline
banners with the same texts, "Powered by Tawla", English/Arabic with RTL, `#,##0.000 LYD` /
`د.ل` money, Tripoli time, Plus Jakarta Sans + Noto Naskh Arabic (the same font files in
`assets/fonts`, self-hosted with `next/font/local`).

Error texts: every server code the guest can get is mapped to a translated message; unknown
errors show the generic "Something went wrong" text, never the raw server string (fixes
inventory §2.14).

---

## 2. API layer: `guest-web/app/api/guest/*`

The browser never calls Supabase to read or write data. It calls these route handlers, which
call Supabase from the server with the **anon/publishable key** and the `x-qr-slug` header.
`service_role` is not used anywhere in `guest-web/` (a test greps the source and the built
output for it and for `SUPABASE_SERVICE_ROLE`).

Every endpoint:

- does one job and makes exactly one Supabase RPC call;
- validates input with zod `.strict()` schemas (unknown fields rejected);
- answers `{ ok: true, data }` or `{ ok: false, error: { code, message } }`, where `code` is a
  fixed list (`bad_request`, `rate_limited`, `table_not_found`, `cashier_offline`,
  `location_required`, `too_far`, `items_unavailable`, `qty_too_large`, `cart_empty`,
  `no_open_bill`, `not_served`, `server_error`) and `message` is never a Postgres error text;
- sends `Cache-Control: no-store` (except `menu`, see below);
- never takes prices, totals, availability, cashier status or the location verdict from the
  client: the database decides all of them (prices are re-stamped by `stamp_cart_line` /
  `stamp_order_line`, inventory §3.2).

Shared input rules: `slug` = `^[a-z0-9]{6,32}$` (today's slugs are 12 chars; a little slack
for older tables), ids = UUID, `qty` = int 1-99, at most 100 lines, `lat` -90..90, `lng`
-180..180, `accuracy` 0..10000.

| Endpoint | Input | Calls | Returns |
| --- | --- | --- | --- |
| `GET /api/guest/menu?slug=` | slug | new RPC `guest_menu(p_qr_slug)` | cafe display fields (name, logo, header/button colours, locale, service charge rate, restaurant id for the live topic), table number, visible categories, their dishes (incl. unavailable, for "Not available"), enabled payment types |
| `GET /api/guest/status?slug=` | slug | new RPC `guest_status(p_qr_slug)` | `ordering_open`, `location: { enabled, radius_m }` |
| `POST /api/guest/location` | slug, lat, lng, accuracy | existing `guest_location_rule` | `allowed` / `too_far` |
| `POST /api/guest/order` | slug, lines `[{ menuItemId, qty }]`, lat?, lng?, accuracy? | existing `send_table_cart` (service type always `dine_in`) | `{ orderId, round }` or a mapped error; `items_unavailable` lists the dish names |
| `GET /api/guest/tab?slug=` | slug | new RPC `guest_tab(p_qr_slug)` | table number and status, the open order only (status, daily number, created time, lines with round, refusal notice, payment type), or `null` |
| `POST /api/guest/call-staff` | slug | new RPC `guest_call_staff(p_qr_slug)` | ok (re-uses an open assistance call, Q8) |
| `POST /api/guest/bill` | slug | existing `request_bill` | ok |
| `POST /api/guest/payment-type` | slug, typeId | existing `set_table_payment_type` | ok |
| `POST /api/guest/refusal` | slug | new RPC `guest_confirm_refusal(p_qr_slug)` | ok (clears the notice and requests the bill in one transaction, same as today's two calls) |

"Bill only after served" stays a client rule (Q7): the tab/bill pages disable the button and
show today's message; `request_bill` itself is unchanged.

The `menu` response may be cached at Vercel's edge for a few seconds per slug
(`s-maxage=5, stale-while-revalidate=30`) to absorb a burst of phones scanning at once; a live
ping makes the client refetch with a cache-busting version stamp, so staff changes still show
within seconds.

### Rate limits

Upstash Ratelimit (sliding window) with an Upstash Redis store from the Vercel Marketplace.
Keys combine the client IP (`x-forwarded-for` first hop, as set by Vercel) and the table slug.
Cafe guests often share one public IP on the cafe Wi-Fi, so per-IP limits are generous and the
tight limits are per table.

| Endpoint | Per IP | Per table slug | Why |
| --- | --- | --- | --- |
| menu | 120 / min | 60 / min | A page load plus live refetches; a full table of phones on one Wi-Fi stays well under |
| status | 120 / min | 40 / min | Each open page polls every 15 s (4 / min); 10 phones at a table = 40 |
| location | 30 / min | 20 / min | A check on open, retries, and one before each send |
| order | 20 / min | 6 / min | A real table sends a round every few minutes; stops scripted floods of the kitchen |
| tab | 120 / min | 60 / min | Refetched on each live ping |
| call-staff | 10 / min | 3 / min | The RPC de-duplicates anyway; this stops alert spam |
| bill, payment-type, refusal | 20 / min | 6 / min | Rare actions |

Over the limit: HTTP 429 with `rate_limited` and `Retry-After`. If Upstash is not configured
(local dev, tests) the limiter falls back to an in-memory window and logs a warning once; the
production build fails its start-up check without the Upstash variables.

---

## 3. Database and Row Level Security

All changes are **new** files in `supabase/migrations/`, each with a test in
`supabase/tests/` (run by `tool/test_db.sh`) and a rollback in `supabase/rollbacks/`.
Existing migrations are not edited. Applied to the live project one by one, after a
"Database backup" workflow run, as today (the live migration history has drifted, inventory
"Live schema vs migrations", so no `supabase db push`).

### Migration A: `2026101xxxxxxx_guest_web_rpcs.sql` (additive, safe with the current Flutter app)

New `SECURITY DEFINER`, `search_path = ''` functions, `execute` granted to `anon` only
(revoked from `public` and `authenticated`), each resolving the table from `p_qr_slug`
(non-archived) and never from anything else:

- `guest_menu(p_qr_slug)`: display columns only. Does not return `location_lat/lng`, `slot`,
  `slug`, `active`, `require_cashier_online`, `auto_print_receipt`, `public_menu_url`, `tax_rate`.
- `guest_status(p_qr_slug)`: wraps the existing `guest_ordering_open` and the "enabled/radius"
  part of `guest_location_rule`.
- `guest_tab(p_qr_slug)`: the table's open order and its lines only (not paid history).
- `guest_call_staff(p_qr_slug)`: inserts an `assistance` call unless one is open for the
  table; respects `zz_guest_needs_cashier`.
- `guest_confirm_refusal(p_qr_slug)`: same effect as `confirm_order_refusal` followed by
  `request_bill`, in one transaction.

Nothing existing changes, so the current Flutter guest page keeps working while both run.

### Migration B: `2026101xxxxxxx_guest_lock_down.sql` (applied only after the Flutter redirect is live and has soaked)

Removes every direct guest path, so a guest can do nothing except call the RPCs:

| Table | Dropped guest policy |
| --- | --- |
| `carts`, `cart_lines` | `carts_guest`, `cart_lines_guest` (ALL) |
| `staff_calls` | `calls_guest_insert`, `calls_guest_update`, `calls_guest_select` |
| `restaurants` | `restaurants_guest_select`, and the `guest_restaurant_id()` branch of `restaurants_select` |
| `menu_items`, `menu_categories`, `payment_types` | `items_guest`, `categories_guest`, guest branch of `payment_types_read` |
| `orders`, `order_lines`, `dining_tables` | `orders_guest_select`, `lines_guest_select`, `tables_guest` |

Cashier (`x-cashier-token`) and admin policies are untouched, so the cashier still sees guest
orders exactly as today: orders are still created by the same `send_table_cart`, with the same
rows, rounds, prices, triggers and pings. Fewer permissive policies per table also clears most
of the "multiple permissive policies" performance warnings.

The existing guest RPCs (`send_table_cart`, `request_bill`, `set_table_payment_type`,
`guest_location_rule`, `guest_ordering_open`, `confirm_order_refusal`) keep their signatures,
so an old cached Flutter guest page still orders; only its direct cart/call writes and table
reads fail, which is why B waits for the soak.

### SQL tests: `supabase/tests/guest_web_test.sql`

Runs as `anon` with `request.headers` set, like the existing tests. Allowed: menu of the
slug's own cafe; status; location verdict; order via `send_table_cart` with server prices
(a tampered `unit_price` in `cart_lines` is impossible because the guest can't write it, and
`send_table_cart` ignores anything but id + qty); tab shows only the open order; call staff
de-duplicates; bill; payment type; refusal confirm. Denied (after B): every direct
select/insert/update/delete on all 24 public tables with a guest slug; another cafe's menu or
order through any RPC; an archived table's slug; `cashier_offline`, `too_far`,
`location_required`, sold-out, `qty_too_large`, `too_many_lines`; staff tables (`payments`,
`shifts`, `shift_expenses`, `cashiers`, `cashier_sessions`, `profiles`, `dev_access`,
`restaurant_setup`, PIN columns) return nothing. The same denied cases are also run from
`supabase-js` against a local Supabase in the API tests (§7).

---

## 4. Realtime

Keep the existing ping design (inventory §2.12): rows carry no data, the page refetches
through the API.

- The guest page subscribes, with the publishable key, to the public broadcast topics
  `guest:<slug>` (its order, its calls, its table) and `cafe:<restaurant_id>` (menu,
  categories, branding, payment types, availability).
- `cafe:` pings fire for every change in the cafe, so the client only reacts when the ping's
  `table` is `restaurants`, `menu_items`, `menu_categories` or `payment_types`, and debounces
  300 ms before refetching `menu`. `guest:` pings refetch `tab`.
- Safety net like today: refetch on tab focus / page show, and every 90 s; status poll every
  15 s.
- No schema change is needed for this. The anon key in the browser is the same public key the
  Flutter web app ships today; after migration B it cannot read or write any table as a guest.
- The Realtime client is loaded with a dynamic import after first paint so it stays out of the
  menu's initial JS budget.

---

## 5. Flutter changes (minimal; admin and cashier untouched)

| Change | File |
| --- | --- |
| Inline script before `flutter_bootstrap.js`: if `location.hash` matches `#/t/<slug>[/cart|/bill]` and a guest URL is set, `location.replace(<guest url>/t/<slug>...)` before Flutter downloads | `web/index.html` |
| Stamp the guest URL into that script from a `GUEST_WEB_URL` Vercel variable; empty = no redirect (so this can ship first, dark) | `tool/vercel_build.sh` |

No Dart code changes: both changes are web-only files, so the Windows till build is
identical. Merging them to `main` still starts the existing *Windows build* workflow
(`.github/workflows/windows-build.yml` runs on every push to `main`) and refreshes the
"windows-latest-build" zip from unchanged Dart code; no versioned Windows release is made
(that needs a `v*` tag). If you'd rather it didn't run at all, the workflow can get a
`paths-ignore` for `web/**`, `guest-web/**`, `docs/**` and `tool/vercel_build.sh`, but only if
you ask.

QR codes printed from the admin keep using `public_menu_url` + `/#/t/<slug>`
(`cafe_store_settings.dart:18-31`); once `public_menu_url` points at the guest app, its `/`
page forwards them. Admin code is not changed. Switching `public_menu_url` for the live cafes
is a one-line data update, done only with Riyad's go-ahead. The Windows till ignores all of
this (guest routes are web only).

The guest screens in `lib/screens/customer/` stay in the code until the new app has run for a
while; removing them is a later, separate change.

---

## 6. Hosting

- New Vercel project (e.g. `tawla-guest`) on the same repo, Root Directory `guest-web`,
  framework Next.js, "Ignored Build Step" so it only builds when `guest-web/` changes. The
  existing `web-menu` project keeps building Flutter as today; its build is unaffected by the
  new folder.
- Environment variables (Production and Preview):
  - `SUPABASE_URL`, `SUPABASE_ANON_KEY`: server-side API calls (same values as today).
  - `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY`: Realtime only.
  - `UPSTASH_REDIS_REST_URL`, `UPSTASH_REDIS_REST_TOKEN`: rate limits.
  - No `service_role` variable exists in this project.
- Security headers like `vercel.json` today, plus a Content-Security-Policy that allows the
  Supabase project for `connect-src` (HTTPS and WSS) and Supabase Storage for images.
  `Permissions-Policy: geolocation=(self)`.
- Images through `next/image` with `remotePatterns` for the project's Storage host, sized per
  slot (68 px rows, full-width spotlight and sheet), AVIF/WebP. Vercel's image optimisation
  has a monthly quota on the current plan; if it runs out, the fallback is Supabase's image
  transformation URLs.
- URL mapping: `https://<guest domain>/t/<slug>` is the new QR format;
  `https://<guest domain>/#/t/<slug>` and `https://web-menu-akakus.vercel.app/#/t/<slug>` both
  forward to it.
- Creating the Vercel project, its variables and the Upstash store are actions on Riyad's
  accounts: I'll ask before each one.

---

## 7. Task list

Each phase is its own PR to `main` from a feature branch; nothing is merged or deployed
without Riyad's word. Pushing `main` deploys the Flutter site, so Flutter changes merge only
when the guest app is live.

**Phase 3a: database (TDD)**
1. Write `guest_web_test.sql` cases first (fail), then migration A until they pass; rollback
   script; `tool/test_db.sh` green.
2. Write the denied cases for B, then migration B and its rollback.

**Phase 3b: guest-web skeleton**
3. Next.js app, strict TS, Tailwind, ESLint, Vitest, Playwright, fonts, i18n strings ported
   from the `guest*` ARB keys (en/ar), money/time helpers with tests against
   `lib/money.dart` behaviour.

**Phase 3c: API (TDD)**
4. For each endpoint, tests first: valid, invalid input, extra fields, rate-limited, cashier
   offline, outside location, sold-out item, wrong cafe, price tampering, unknown errors
   mapped. Run against a local Supabase built from the migrations.
5. Implement endpoints, zod schemas, rate limiter, error mapping.

**Phase 3d: UI**
6. Language screen, menu (Server Components), dish sheet, cart and verify sheet, banners,
   tab, bill, refusal notice, Realtime hook; RTL; staff branding.
7. Performance and accessibility pass (budgets in Phase 4).

**Phase 3e: switch-over (each step on Riyad's word)**
8. Apply migration A live (after a backup run).
9. Create the Vercel project and Upstash store; deploy guest-web; smoke test with a test table.
10. Merge the web-only Flutter redirect with `GUEST_WEB_URL` empty, then set it, and switch the cafes'
    `public_menu_url`.
11. After a soak with no Flutter guest traffic, apply migration B.

**Phase 4: verify** (the brief's list): unit + API coverage ≥ 80 % on `guest-web/`;
Playwright on iPhone and Android profiles for browse→order, cashier offline, location
denied/outside, staff changes reaching the page, Arabic RTL (takeout is out of scope per Q1);
RLS denied cases as anon; `get_advisors` with no new warnings; `security-review` and
`code-review` on the diff; a Next.js guest order settled in the real Flutter cashier app
against the same database (needs a cashier signed in; I'll ask you to do that step or to
share a test PIN for a test slot); Lighthouse mobile ≥ 90; FCP < 1.5 s on mid-range 4G; menu
page JS < 150 KB gzipped; tap targets ≥ 44 px; contrast AA (staff colours that fail AA get
the same black/white text rule the Flutter app uses).

---

## 8. Risks

| Risk | Mitigation |
| --- | --- |
| Old QR fragment links: a Flutter service worker (`web/sw.js`) can serve a cached `index.html` without the redirect for a while | The worker fetches `/` network-first with a 3 s timeout (`web/sw.js:54-71`), so on a slow network an old copy can open the Flutter guest page once; it still works until migration B, which waits for the soak |
| Per-phone cart (Q2): two phones at a table can each send a round | That is already how rounds work; the cashier sees both rounds on one order |
| GPS can be spoofed | Same as today; the check stops casual remote orders only |
| Shared cafe Wi-Fi IP hits per-IP limits | Generous per-IP limits, tight per-table limits |
| Migration B too early breaks old cached Flutter guest pages | B only after the soak; rollback script ready |
| Live migration history drift | Apply new files by hand like today, record them, take a backup first |
| Staff colours with poor contrast | Same automatic black/white text rule as Flutter; AA checked in Playwright |
| Vercel image quota | Fallback to Supabase image transforms |
| Realtime outage | Polls and focus refetches as today |
| Lighthouse/FCP targets depend on the Supabase region (eu-central-1) and the phone's network | Edge-cached menu response, server-rendered HTML, fonts subset and preloaded |

## Open items

- **Domain** for the guest app. Until one is chosen the plan uses the default
  `tawla-guest.vercel.app`-style URL; switching later only means updating `GUEST_WEB_URL` and
  `public_menu_url`.
- **Cashier test for Phase 4 step 6**: a signed-in cashier on a test slot is needed to settle a
  Next.js order in the real Flutter app.
