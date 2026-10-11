# Guest (QR ordering) feature inventory

Phase 1 of the guest rebuild (see the brief, `00_PROMPT.md`). Read-only study of what the
guest side does today, where it lives, and what it touches in Supabase. Nothing in the app or
database was changed.

Studied at commit `6e0457d` (release 1.4.3), 2026-10-11.

How this was checked:

- Read the guest screens, `CafeStore` parts, `AppDatabase` guest paths, l10n, money and theme code.
- Rebuilt the database from all 50 files in `supabase/migrations` on a local Postgres 16 with
  `tool/test_db.sh` (all checks pass), then read the final policies, functions, triggers and
  grants from that build instead of reconstructing them by hand.
- Compared the live project (`kzafgozkgvcflcizuemr`) with that build through the Supabase MCP:
  migration history, policies, function bodies, Realtime publication, advisors. See
  [Live schema vs migrations](#live-schema-vs-migrations).
- The brief mentions `.claude/agents/` (planner, designer, db-analyst). That folder is not in
  the repository, so the equivalent work was done directly from the migrations and the live schema.

---

## 1. How a guest arrives

| What | Where |
| --- | --- |
| QR codes encode `https://<base>/#/t/<qr_slug>` (hash routing, so the slug is in the URL fragment and never reaches a server) | `lib/state/cafe_store_settings.dart:18-31` (`guestLink`), printed by `lib/screens/admin_screens.dart:181` |
| `<base>` is the cafe's `restaurants.public_menu_url`, then the `PUBLIC_MENU_URL` build define, then the admin's own origin. Live: every cafe has `https://web-menu-akakus.vercel.app` | `cafe_store_settings.dart:18-31`, migration `20261012100000_audit_fixes.sql` (B-08) |
| `qr_slug` is 12 random chars `[a-z0-9]` (~62 bits), unique across all cafes; it is the guest's only credential | `lib/data/app_database.dart:2207` (`Secrets.publicId`), `dining_tables_qr_slug_key` |
| The first URL is captured before Flutter boots so `/t/<slug>` survives the opening screen | `lib/main.dart:38-42` |
| Routes `/t/:tableId`, `/t/:tableId/cart`, `/t/:tableId/bill`, each wrapped in `GuestSession` | `lib/main.dart:233-253` |
| `/cart` and `/bill` bounce back to the menu when the table has no open order | `lib/main.dart:163-173` |
| `/c/<cafe-slug>` is NOT a guest route: it links a staff device to a cafe | `lib/main.dart:197-211` |
| The guest page loads the whole Flutter app (same bundle as admin/cashier, staff screens deferred) | `lib/main.dart:11-17` |

### GuestSession (`lib/main.dart:422-532`)

- On open: `store.ensureGuest(slug)` (`lib/state/cafe_store.dart:784-793`), which sets the
  `x-qr-slug` header, reloads data as a guest and starts live sync, and starts the
  "is ordering open" poll.
- Loading screen while that runs (`lib/screens/customer/loading.dart:3-30`).
- Unknown or archived slug: "This QR code doesn't match a table" with Retry
  (`loading.dart:32-68`, `main.dart:523`).
- Language picker on every fresh page load, never saved on the phone (`loading.dart:70-156`,
  `cafe_store.dart:498-504`). Default selection is the cafe's own locale.
- When the table's order is paid (table back to `free`, no open order, empty cart) the guest is
  sent back to the menu (`main.dart:486-504`).

### Multi-cafe slots

- Eight cafes (`restaurants.slot` 1-8) share one database (`20261007100000_multi_cafe_slots.sql`).
- A QR belongs to whichever cafe owns the table: `dining_tables.qr_slug -> restaurant_id`.
  There is no cafe id in the guest URL; `private.guest_restaurant_id()` derives it from the slug.
- `restaurants.active` is not checked on the guest path (a table of an inactive slot still works).

---

## 2. Guest features and rules

### 2.1 Menu browsing (`lib/screens/customer/menu.dart`)

| Feature / rule | Where |
| --- | --- |
| Header: cafe logo (or initials), cafe name, "Table N • Dine-in" (or "• Takeout" when the open order is takeout) in the header colour | `customer/guest_parts.dart:22-98` |
| Page title "Mezzogiorno Menu" (fixed string, not the cafe name) | `menu.dart:136-143`, `app_en.arb:700` |
| Category chips: All, Chef's Specials, then visible categories in `sort_order`; selected chip uses the button colour | `menu.dart:144-181`, `352-378` |
| Only categories with `visible = true` are shown; their items follow. Hidden categories hide their dishes | `lib/state/cafe_store_catalog.dart:29-34`, `111-112`; RLS `categories_guest` |
| Dishes sorted by `sort_order` inside each category; category headings only when more than one category is listed | `menu.dart:107-124`, `198-228` |
| Spotlight card: the first `featured` dish, on "All" and "Chef's Specials" | `menu.dart:185-188`, `380-437` |
| "Chef's Specials" filter = `featured` dishes | `menu.dart:110` |
| Item count line, "Powered by Tawla" footer | `menu.dart:189-197`, `229-231` |
| Dish photo (`image_url`, Supabase Storage URL), first 4 pre-warmed | `menu.dart:338-350`, `DishPhoto` in `lib/widgets/cafe_widgets.dart` |
| Name in the guest's language: `name_en` for English, `name_it` (holds the Arabic name) for Arabic, falling back to the other | `lib/models/models.dart:146-148` |
| Description shown in the dish sheet only (single language) | `menu.dart:683` |
| Price: `sale_price = price × (100 − discount_percent)/100` when `discount_applied`; list price struck through when discounted | `models.dart:138-140`, `menu.dart:521-543` |
| Sold out / unavailable (`available = false` or `sold_out = true`): name struck through, "Not available" instead of price, add button disabled, dish sheet won't open | `catalog.dart:36`, `menu.dart:452-519`, `589-612` |
| Badge with how many of this dish are in the cart | `menu.dart:493-512` |
| Empty menu hint | `menu.dart:182-183` |
| Dish sheet: big photo, both language names, description, quantity stepper (min 1), "Add to Order • amount" | `menu.dart:611-760` |

### 2.2 Branding and layout set by staff

What staff can configure and the guest renders:

| Setting | Column | Guest use |
| --- | --- | --- |
| Cafe name | `restaurants.name` | Header, loading and language screens, "Thank you for dining with …" (`'Tawla'` when empty, `cafe_store_settings.dart:4-7`) |
| Logo | `restaurants.logo_url` | Round badge; initials when empty or it fails to load (`guest_parts.dart:13-55`) |
| Header colour | `restaurants.header_color` | Guest header bar, prices, cart badge (`guest_parts.dart:57-98`, `menu.dart:522`) |
| Button colour | `restaurants.button_color` | Chips, buttons, badges, status stepper, discounted price, "Not available" text (`menu.dart`, `cart.dart:207`) |
| Background colour | `restaurants.background_color` | Only used to pick a readable button-ink colour (`lib/theme/cafe_theme.dart:83`); the guest page itself is always cream `#FDF9F2` (`guest_parts.dart:4-11`) |
| Sidebar colour | `restaurants.sidebar_color` | Not used by guest screens |
| Text colour on header/button | derived: black or white, whichever contrasts more | `cafe_theme.dart:35`, `76-83` |
| Category order and visibility, dish order, featured flag, discounts | `menu_categories.sort_order/visible`, `menu_items.sort_order/featured/discount_*` | Admin "Menu layout" screen (`lib/screens/admin_menu_layout_screen.dart`) and catalog screens |
| Dish availability | `menu_items.available`, `sold_out` | Cashier/admin "Dishes" screen via `set_item_available` (`lib/screens/dish_availability_screen.dart`) |

Defaults when a colour is empty: header `#1B3A4B`, button `#BA5333`, background `#E7EEF2`,
sidebar `#FFFFFF` (`cafe_theme.dart:20-23`).

There is **no "layout style" setting** (grid vs list, card style, etc.) in the code or schema.
"Menu layout" in the admin means category/dish ordering and visibility. See open question Q3.

Updates while the guest page is open: any change to `restaurants`, `menu_items`,
`menu_categories` sends a Realtime ping on `cafe:<restaurant_id>` only, not on the guest topic
(`live_ping()` only adds `guest:<slug>` when the row has a table id). The guest page therefore
picks up branding/menu/availability changes from its 90-second safety poll, a ping caused by
its own table, or the next order send. See §4 and open question Q6.

### 2.3 Cart, quantities, notes

| Feature / rule | Where |
| --- | --- |
| Cart is per table and stored in Supabase (`carts`, `cart_lines`), written directly by the guest phone on every tap (delete-all-then-insert); everyone at the same table shares one cart | `cafe_store_orders.dart:93-126`, `app_database.dart:1578-1584`, `1741-1772` |
| Max 99 of one dish (client and server) | `cafe_store_orders.dart:90-97`, `send_table_cart` (`qty_too_large`) |
| Bar in the button colour: "N items • Cart · total", opens "Verify Your Order" | `menu.dart:237-336` |
| "Verify Your Order" sheet: table pill, per-line ± (down to 0 removes), subtotal, total, "Confirm & Send to Kitchen", "Modify Order & Back to Menu"; double-send guarded | `menu.dart:763-996` |
| After a successful send the guest goes to the Table Bill page | `menu.dart:286-291` |
| **Item notes / options / modifiers: do not exist.** `orders.notes` exists but nothing on the guest side sets it, and `cart_lines`/`order_lines` have no notes column | `models.dart:293-309`; schema |
| Cart prices shown are the client's copy, but the server re-prices every line from the menu (`stamp_cart_line`, `stamp_order_line`) | §3 |

### 2.4 Order rounds (adding more to an open order)

- One open (unpaid) order per table (`orders_one_open_per_table` unique index).
- Each send appends lines with `round = max(round)+1` and sets the order status back to `received`
  (`send_table_cart`, from `20260928200000_order_rounds.sql`).
- The Table Bill page lists sent lines and "New Additions" (cart lines not sent yet)
  (`customer/cart.dart:78-120`).

### 2.5 Dine-in vs takeout

- Every guest order is sent as `dine_in` today. `serviceForTable()` returns the open order's
  type, else a per-slug choice, else `dine_in` (`cafe_store_orders.dart:57-63`). The choice
  setter `chooseService()` (`cafe_store_orders.dart:53-56`) is never called from any screen.
- The "How are you ordering? Dine-in / Takeout" strings still exist (`app_en.arb:862-867`) but
  no screen uses them: the guest takeout choice was removed at some point.
- `send_table_cart` still accepts `p_service_type = 'takeout'`: such an order does not mark the
  table `dining` and a bill request does not mark it `billRequested`.
- `20261010100000_takeout_without_table.sql` is the **cashier's** quick takeout
  (`quick_takeout_receipt`), not a guest feature.
- See open question Q1.

### 2.6 Location check

| Rule | Where |
| --- | --- |
| Per-cafe switch `location_check_enabled`, point `location_lat/lng`, radius `location_radius_m` (30-500 m, default 100), set by admin via `save_cafe_location` | `restaurants` columns, `20261002170000_guest_location_check.sql`, `20261004150000_save_cafe_location.sql` |
| Check is off unless enabled AND a point is saved | `guest_location_rule`, `private.order_location_error` |
| Allowed when `distance − min(accuracy, 50 m) ≤ radius` (haversine `private.distance_m`) | `private.order_location_error` |
| Guest flow: on menu open, ask `guest_location_rule(slug)`; if enabled, read GPS (high accuracy, 20 s timeout) and ask again with lat/lng/accuracy; result `allowed` / `too_far` / unavailable | `lib/state/cafe_store_location.dart:11-83`, `lib/device_location.dart:46-71` |
| A good fix is trusted for 10 minutes, then re-checked before sending | `cafe_store_location.dart:65`, `85-99` |
| Denied permission: banner "Location is needed…", iPhone hint, "Allow location" button. Unavailable / too far: banner and "Retry". Browsing still works | `menu.dart:545-587`, `998-1007`, `app_en.arb:902-908` |
| While blocked, add buttons and the cart bar show the reason in a snackbar instead of acting | `menu.dart:589-609`, `1024-1036` |
| Server enforces it again on send: `send_table_cart` returns `location_required` / `too_far` | `send_table_cart` |
| Cashier skip: a signed-in cashier session (`x-cashier-token`) skips the check; there is no per-cafe "skip" switch | `20261004140000_cashier_skip_location.sql`, `order_location_error` first lines |
| Rule lookup fails: check treated as off (server still enforces) | `cafe_store_location.dart:31-38` |
| Only `send_table_cart` checks location. Call staff, request bill, set payment type do not | functions in §3 |

The coordinates come from the phone, so a determined guest can fake them; the check stops
casual remote ordering, not a spoofed GPS. Live: slot 1 has it on with a 30 m radius.

### 2.7 Ordering needs a cashier online (presence)

| Rule | Where |
| --- | --- |
| Per-cafe opt-in `restaurants.require_cashier_online` (default off), admin Settings switch "Pause guest ordering when no cashier is online" | `20261009180000_guest_gate_opt_in.sql`, `cafe_store_settings.dart:81-88` |
| A cashier counts as online while one signed-in session has a heartbeat in the last 45 s (cashier apps call `cashier_heartbeat_v2` every 15 s) | `private.cashier_online`, `20261009170000_presence_per_session.sql`, `cafe_store_offline.dart:85-108` |
| Guest page polls `guest_ordering_open(slug)` now and every 15 s | `cafe_store_offline.dart:499-522` |
| Closed: banner "Ordering is paused right now because the cashier is offline. You can still browse the menu."; add, cart, call staff and bill buttons show that message instead | `menu.dart:998-999`, `customer/call_staff.dart:72-82`, `cart.dart:152-160` |
| Server enforces with trigger `zz_guest_needs_cashier` on `cart_lines`, `order_lines`, `staff_calls` (raises `cashier_offline` for guests) | `private.guest_needs_cashier` |
| A `cashier_offline` error from any action flips the page to closed at once | `menu.dart:1042-1045`, `cafe_store_orders.dart:284-287` |
| Live: slot 1 has it on, the other cafes off | live `restaurants` |

### 2.8 Table Bill page (`/t/<slug>/cart`, `lib/screens/customer/cart.dart`)

- Live tab card: "Order #NNN" (daily order number `shift_order_number`, padded to 3 digits;
  `—` until a cashier device assigns it), sent time in Tripoli time (UTC+2), 4-step status
  stepper Received → Preparing → Ready → Served, "Kitchen is preparing…" until Ready
  (`cart.dart:37-77`, `199-255`, `lib/money.dart:93-99`, `lib/time_format.dart:7`).
- New Additions (unsent cart lines) with ±, ticket summary of all lines and total.
- "Call Server" and "Request Bill". Request Bill only once the order is `served` and the cart is
  empty; otherwise "You can request the bill after the waiter marks your order served."
  (`cart.dart:149-184`, `cafe_store_orders.dart:255-258`).
- Bottom nav: Menu, Table Bill (disabled until an order exists), Call Staff
  (`customer/call_staff.dart:18-87`).

### 2.9 Final bill page (`/t/<slug>/bill`, `lib/screens/customer/bill.dart`)

- Sent lines only, subtotal, "Service Charge (N%)" from `restaurants.service_charge_rate`,
  "Hospitality & VAT (Included) —", total = subtotal × (1 + rate) (`bill.dart:22-100`,
  `cafe_store_orders.dart:73-85`).
- Payment method dropdown of the cafe's enabled payment types, saved on the order with
  `set_table_payment_type` (`bill.dart:105-136`, `cafe_store_payments.dart:57-68`).
- "Confirm and request bill": needs `served`, and a payment type when the cafe has any
  (`bill.dart:137-153`).
- Paid view: tick, "PAID / Payment Successful / Thank you for dining with <cafe>!" when the
  order is gone and the table is free (`bill.dart:26`, `62-76`).
- The totals shown are display only; the cashier's `settle_cash` computes the charged amount.

### 2.10 Call staff

- "Call Staff" (nav) and "Call Server" (bill page) add a `staff_calls` row of kind
  `assistance`. "Request sent" only after the save succeeds, else a generic error
  (`customer/call_staff.dart:5-16`, `cafe_store_orders.dart:293-305`).
- Written by a **direct upsert** into `staff_calls` from the guest phone
  (`app_database.dart:2074-2089`), allowed by policies `calls_guest_insert` / `calls_guest_update`.
- No rate limit or "one open call" rule: every tap inserts a new call.

### 2.11 Order refusal notices

- Cashier refuses a sent line: the line is removed (`remove_order_line`), the dish is set
  unavailable, and `note_order_refusal` sets `awaiting_customer_confirmation` and appends the
  dish name to `refusal_notice` (`cafe_store_catalog.dart:54-78`).
- Guest sees "Item removed: <names> — currently unavailable." with a "Confirm and request bill"
  button on the menu and Table Bill pages (`bill.dart:201-230`).
- Confirming calls `confirm_order_refusal` then **force-requests the bill**, skipping the
  "served" rule (`cafe_store_catalog.dart:80-87`). See open question Q7.

### 2.12 Live updates for the guest

- Realtime broadcast topic `guest:<qr_slug>` (public channel), event `change`, payload only
  `{table: <name>}`; the page then reloads its data through normal RLS-checked requests
  (`app_database.dart:302-306`, `338-417`; `20261013100000_live_update_pings.sql`).
- Pings to `guest:<slug>` come from changes to rows with that table's id: `orders`,
  `order_lines`, `carts`, `cart_lines`, `staff_calls`, `dining_tables`.
- Menu, category, branding and payment-type changes ping `cafe:<id>` only (see §2.2).
- `postgres_changes` subscriptions are also opened, but guests never receive rows from them
  (Realtime does not pass `x-qr-slug` to RLS), as the migration notes.
- Safety poll every 90 s, re-sync on app resume, plus the 15 s ordering-open poll
  (`cafe_store.dart:176-196`).

### 2.13 Language, RTL, money

- English and Arabic (`lib/l10n/app_en.arb`, `app_ar.arb`, 96 `guest*` keys plus shared ones
  such as `noMenu`, `noOrders`, `cashierNotAvailable`, `serviceTakeout`, `payChoose`, `errGeneric`).
- RTL for Arabic via `Directionality`, re-applied inside bottom sheets (`main.dart:506-516`,
  `menu.dart:1012-1022`).
- Money: `#,##0.000` with Latin digits in both languages, suffix `LYD` (English) or `د.ل`
  (Arabic) (`lib/money.dart:143-156`). Three decimals on screen; prices are stored as
  `numeric(12,2)`.
- Times: Tripoli, fixed UTC+2 (`lib/money.dart:116`, `lib/time_format.dart:7`).
- Category names have both languages (`name_en`, `name_ar`); payment types too.

### 2.14 Error texts the guest can see

`guestOrderErrorText` (`menu.dart:1038-1053`) maps server codes: `cashier_offline`,
`too_far`, `location_required`, `items_unavailable` ("Sorry, these dishes are no longer
available: …"), `qty_too_large`. Any other error (e.g. `table not found`, `cart is empty`,
`too_many_lines`) is shown as the raw server string.

---

## 3. What the guest touches in Supabase

The guest uses the **anon/publishable key** with no Supabase Auth session. Its identity is the
`x-qr-slug` request header, which policies read via `private.header()` →
`private.guest_table_id()` / `private.guest_restaurant_id()`. Most RPCs also take the slug as
`p_qr_slug`.

### 3.1 Reads (role `anon`, header `x-qr-slug`)

| Table | Query (from `app_database.dart:597-801`) | Policy | Notes |
| --- | --- | --- | --- |
| `dining_tables` | `select *` | `tables_guest`: own table only | |
| `restaurants` | `select name, locale, service_charge_rate, tax_rate, logo_url, public_menu_url, header/sidebar/background/button_color, auto_print_receipt, require_cashier_online` (`:528-554`) | `restaurants_guest_select`: own cafe, **all columns** | Anon with a slug can also read `location_lat/lng`, `slot`, `slug`, `active` |
| `menu_categories` | `select *` | `categories_guest`: own cafe, `visible` only | |
| `menu_items` | `select *` | `items_guest`: own cafe, all rows incl. unavailable and items of hidden categories | Needed to show "Not available" |
| `payment_types` | `select * order by sort_order` | `payment_types_read`: own cafe, `enabled` | Includes archived-but-enabled rows; the app filters `archived` |
| `orders` + `order_lines` | `select *, order_lines(*) where table_id = <own> and status <> 'paid'` (`:1031-1041`) | `orders_guest_select`, `lines_guest_select`: own table, **any status** | A slug holder can read the table's paid order history too |
| `carts` + `cart_lines` | `select *, cart_lines(*) where table_id = <own>` | `carts_guest`, `cart_lines_guest` (ALL) | |
| `staff_calls` | not read by the guest app | `calls_guest_select` exists | |
| `has_any_admin(rid)` RPC | called on every refresh | anon | Harmless boolean |

### 3.2 Writes

| Action | How | Server checks |
| --- | --- | --- |
| Edit cart | **Direct** upsert `carts`, delete + insert `cart_lines` (`app_database.dart:1741-1772`) | RLS own table; `stamp_cart_line` re-prices from the menu and refuses non-menu lines for guests; `zz_guest_needs_cashier` |
| Send order | RPC `send_table_cart(p_qr_slug, p_lines[{menu_item_id, qty}], p_service_type, p_lat, p_lng, p_accuracy_m)` (`:1701-1739`) | Table by slug, location, ≤ 100 lines, qty ≤ 99, items on this cafe's menu, refuses unavailable/sold-out, re-prices, adds a round, marks table `dining`; triggers for cashier-online |
| Call staff | **Direct** upsert into `staff_calls` with a client id, kind `assistance` (`:2074-2089`) | RLS `calls_guest_insert` / `calls_guest_update` (own table and cafe); `zz_guest_needs_cashier`. Guest can also UPDATE its table's calls (e.g. set `resolved`) |
| Request bill | RPC `request_bill(p_qr_slug)` (`:2014-2022`) | Needs an open order; marks `billRequested` (dine-in) and opens one bill call. Does **not** check `served` (the app does) |
| Payment method | RPC `set_table_payment_type(p_qr_slug, p_type_id)` (`:1316-1329`) | Type enabled and of the table's cafe, open order exists |
| Confirm refusal | RPC `confirm_order_refusal(p_order_id)` (`:2127-2135`) | Order must belong to the header's table (uses header, not `p_qr_slug`) |
| Location rule | RPC `guest_location_rule(p_qr_slug, p_lat?, p_lng?, p_accuracy_m?)` (`:1586-1601`) | Read-only |
| Ordering open | RPC `guest_ordering_open(p_qr_slug)` (`cafe_store_offline.dart:509-522`) | Read-only |

All these RPCs are `SECURITY DEFINER`, `search_path = ''`, executable by `anon`.

### 3.3 Realtime

| Channel | Who | Content |
| --- | --- | --- |
| `guest:<qr_slug>` broadcast (public, `realtime.send(..., private => false)`) | Guest page | `{table}` ping only |
| `cafe:<restaurant_id>` broadcast (public) | Staff | `{table}` ping only. Not subscribed by the guest today, but anyone who knows a restaurant id can subscribe |
| `cafe-sync:<rid>` postgres_changes | opened by every device | Delivers rows to admins only |

### 3.4 Roles

Guest = `anon` + `x-qr-slug`. Cashier tills are also `anon` (+ `x-cashier-token`); admins are
`authenticated`. Several policies are shared by anon guests and anon cashiers
(`carts_staff`, `cart_lines_staff`, `calls_staff` list `{anon, authenticated}` and rely on
`actor_restaurant_id()` being null for a guest).

### 3.5 What a guest cannot reach today (verified on the local build's policies)

`cashiers`, `cashier_sessions`, `cashier_presence`, `payments`, `payment_method_changes`,
`shifts`, `shift_expenses`, `expense_categories`, `profiles`, `dev_access`,
`restaurant_setup`, `receipt_blocks`, `order_number_counters`, `app_release`: no anon policy
matches without a cashier token or admin session, or RLS is on with no policy. Other cafes'
rows: every guest policy is keyed on the slug's own table or cafe.

---

## 4. Findings that matter for the rebuild

1. **Guests write tables directly** (carts, cart_lines, staff_calls). The brief wants
   "create orders ONLY via the RPC, no direct INSERT/UPDATE/DELETE". Needs a new migration with
   a `guest_call_staff` RPC and removal of the guest write policies, done only after the Flutter
   guest page stops using them (same two-step pattern as `lock_down_direct_writes`).
2. **The cart does not need to live in the database for the cashier.** No cashier or admin
   screen reads `carts` (`grep cartFor lib/screens/cashier*` finds nothing), and
   `send_table_cart` already accepts the whole cart in `p_lines`. A Next.js guest can keep the
   cart on the phone and send it in one call. This changes one behaviour: phones at the same
   table would no longer share a cart (Q2).
3. **Old QR codes carry the slug in a `#` fragment**, so no server or Vercel redirect can see
   it. Keeping them working needs a small script in the Flutter `web/index.html` (or in a page
   served at `/`) that reads `location.hash` and forwards `#/t/<slug>` to the new app.
4. **Menu/branding changes don't ping the guest topic**; today's guest sees them within 90 s.
   The new app can subscribe to `cafe:<rid>` as well (public, no data), or the trigger can be
   extended (Q6).
5. **Request bill and refusal confirm skip the `served` rule on the server**; only the app
   enforces it.
6. **Raw server error strings reach guests** for unmapped errors (§2.14).
7. `restaurants_guest_select` exposes every restaurant column to a slug holder, including the
   cafe's coordinates. A guest-facing view or RPC returning only display columns would fix it.
8. The service charge on the guest bill uses `service_charge_rate` but the cashier can settle
   without service (`settle_cash(p_apply_service)`), so the guest total can differ from what is
   charged. Existing behaviour, noted for parity.

---

## Live schema vs migrations

Checked on 2026-10-11 against project `kzafgozkgvcflcizuemr` (Postgres 17).

| Check | Result |
| --- | --- |
| RLS policies (`public`) | **Identical** to the local build from `supabase/migrations` (41 policies). |
| Function bodies | Same logic. Many bodies differ only by Windows line endings (CRLF) in the live copies. `has_any_admin`, `list_pos_cashiers`, `assign_shift_order_numbers` match the content of `20261012100000_audit_fixes.sql`. |
| Migration history (`supabase_migrations`) | **Drift in bookkeeping, not in schema.** Live history has 48 entries, all with different timestamps from the repo files. Not recorded under their own names although their changes are live: `security_and_money_fixes`, `guest_ordering_needs_cashier`, `fix_signed_out_load`, `presence_per_session`, `guest_gate_opt_in`, `audit_fixes` (live has one combined `guest_ordering_gate_presence_opt_in` entry, and `pg_cron` is installed). Live-only entries: `dev_import_line_snapshot`, `payment_type_archive_settle`, `lock_dev_tools_to_developer`, `restore_dev_tools_password_only`. A `supabase db push` from the repo would try to re-run files, so new migrations should keep being applied one by one as today. |
| Extra live schema | `backup_20261007` schema with copies of all tables (not in the repo). |
| Realtime publication | Live publishes `cart_lines, carts, dining_tables, menu_items, order_lines, orders, payments, shift_expenses, staff_calls`. The guest relies on broadcast pings, so this does not affect it. |
| Security advisors | 49 × "anon/authenticated can execute SECURITY DEFINER function" (by design: every RPC checks the header/session itself), 7 × "RLS enabled, no policy" (intended deny-all tables), leaked-password protection off. No guest-specific warning. |
| Performance advisors | 19 × multiple permissive policies (guest + cashier policies on the same table), unused indexes, 2 unindexed FKs (`payments.cashier_id`, `receipt_blocks.cashier_id`), tables without primary keys in `backup_20261007`. |

---

## Open questions

These change what gets built. Each has the default I would pick.

- **Q1. Takeout for guests.** Today every guest order is dine-in; the takeout choice was removed
  from the guest page and "takeout without table" is a cashier feature. Should the new guest app
  offer Dine-in / Takeout? *Default: no, keep dine-in only (parity).*
- **Q2. Shared cart per table.** Today all phones at one table share one cart stored in the
  database. Keeping the cart on each phone (sent in one `send_table_cart` call) removes all
  direct guest writes and many requests. Is a per-phone cart OK? *Default: per-phone cart.*
- **Q3. "Layout style".** There is no layout style setting (grid/list etc.) today; staff control
  colours, logo, name, category/dish order and visibility, featured dishes, discounts and
  availability. Build only those? *Default: yes, only what exists.*
- **Q4. Item notes / options.** They don't exist today. Add them in this rebuild?
  *Default: no (would need schema changes and cashier/receipt changes in Flutter).*
- **Q5. Where the new app lives.** Old QR codes point at `https://web-menu-akakus.vercel.app/#/t/<slug>`
  (the Flutter site). Options: (a) a new Vercel project on its own domain, with a tiny redirect
  script added to the Flutter `index.html`; (b) Next.js takes over the main domain and Flutter
  moves. *Default: (a), new project, and the cafes' `public_menu_url` switched to it so new QR
  codes skip the redirect.* What domain do you want?
- **Q6. Menu/branding updates speed.** Today a guest sees staff changes within about 90 s. Should
  they appear within seconds? *Default: yes, by also listening to the cafe's public ping
  topic (no data, no schema change).*
- **Q7. Bill rules.** Should the server enforce "bill only after served" (today only the app
  does), and should confirming a refusal still request the bill immediately?
  *Default: keep today's behaviour exactly, enforce nothing new.*
- **Q8. Call staff limits.** Today every tap creates a new staff call. Allow one open
  assistance call per table (repeat taps re-use it)? *Default: yes, in the new RPC.*
- **Q9. Branch.** The brief says commit on `main` per the memory rule, but this session works on
  a feature branch and opens a draft PR (pushing `main` deploys). *Default: feature branch + PR.*
