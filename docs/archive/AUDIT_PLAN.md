# Tawla POS — Full Audit, Restructure Plan and Commercial Strategy

> **Read-only analysis.** Nothing in the app was changed to write this. Every finding points at a file and line so you can check it yourself.
> Audited on 2026-10-08 against the **git version** `origin/main` @ `a071835` (release **1.2.0+4**, the "Tawla design" commit), ~14,000 lines of hand-written Dart, ~6,500 lines of SQL across 51 migrations.
> Your local checkout was one commit behind (1.1.1). 1.2.0 changed only screens, theme and translations — the data layer, SQL, and multi-cafe limits are identical, so all data/scale findings apply to both. Line numbers in `lib/data`, `lib/state` and `supabase/` are the same in both versions; screen line numbers refer to 1.2.0. Run `git pull` to get the same code locally.

---

## 0. How to use this document (the repeatable checklist)

Run this checklist **before every release** and **every time you onboard a new cafe**. Tick each box; anything unticked becomes a ticket.

### 0.1 Release checklist (each time)
- [ ] `flutter analyze` → 0 issues
- [ ] `dart format --set-exit-if-changed .` → passes
- [ ] `flutter test` → all green; note the coverage figure (`flutter test --coverage`)
- [ ] `tool/test_db.sh` → every SQL test and rollback passes
- [ ] Supabase **Advisors** (Security + Performance) → no new warnings
- [ ] Search for new hard-coded strings: `Text('[A-Z]` and `return '[A-Z]` outside `l10n/`
- [ ] Search for new brand leaks: `Café Italiano|Cafe Italiano|menu_web_v1|com.example|akakus`
- [ ] Search for new magic colors/sizes: `Color(0x` outside `cafe_theme.dart`, `fontSize: <number>`
- [ ] Every new migration has a test in `supabase/tests` and a rollback in `supabase/rollbacks`
- [ ] Every new `select()` has a restaurant filter **and** a limit or a date window
- [ ] Every new realtime subscription is filtered by `restaurant_id`
- [ ] Every new `await client...` in UI-facing code is in a `try/catch` with a translated message
- [ ] Both languages checked by eye (EN + AR/RTL) at phone width (375px) and till width (1366px)
- [ ] Database size and egress checked in Supabase → Usage (see §3.6 limits)

### 0.2 New-cafe checklist (each sale)
- [ ] Tenant created and setup code issued (dev screen)
- [ ] Owner created admin, changed default colours/logo, **service charge set explicitly** (default is 10%, see B-12)
- [ ] Payment types renamed to the cafe's real methods (Cash, Moamalat card, Sadad, Mobi Cash…)
- [ ] Tables created, QR sheet printed and test-scanned from a guest phone **on mobile data, not Wi-Fi**
- [ ] Till installed with the signed installer, one test sale, one test expense, shift closed
- [ ] Printer test (Arabic receipt)
- [ ] Owner shown the daily summary and how to export

---

## 1. Bugs, inconsistencies, missing features, unfinished placeholders

Severity: **CRITICAL** = blocks selling / data or money risk · **HIGH** = real bug customers will hit · **MEDIUM** = quality/maintainability · **LOW** = polish.

### 1.1 Bugs and risks

| ID | Sev | Where | What is wrong | Recommended fix |
|---|---|---|---|---|
| B-01 | CRITICAL | `supabase/migrations/20261007100000_multi_cafe_slots.sql:20,252`, `lib/data/app_database.dart:85` | **Hard ceiling of 8 cafes.** `check (slot between 1 and 8)`, header regex `^[1-8]$`, and the dev UI all assume 8. Cafe #9 cannot be sold. | Replace "slot number" with an unbounded tenant key (slug/UUID). Keep `slot` only as a legacy alias. See §2 step R-6 and §3. |
| B-02 | CRITICAL | `lib/data/app_database.dart:313-375` | **Realtime is not filtered by cafe.** One channel `cafe-sync` subscribes to *all* rows of 8 tables. Every change in any cafe is RLS-checked against every connected device, and every accepted event triggers a **full reload of ~12 queries** (`_refreshFromDisk`). Cost grows with (cafes × devices × changes). This is the first thing that breaks when you sell to more cafes. | Add `filter: PostgresChangeFilter(type: eq, column: 'restaurant_id', value: id)` per table, name the channel per cafe, or better: move to **Realtime Broadcast** from a trigger (`realtime.broadcast_changes`) on topic `cafe:<id>` and refetch only the changed table. |
| B-03 | HIGH | `lib/data/app_database.dart:313-362` | Tables **not** subscribed: `payments`, `shifts`, `restaurants`, `menu_categories`, `payment_types`, `expense_categories`. Brand colour, category, payment-type and sales changes made on one device show on another only after the 90 s poll (`cafe_store.dart:174`). | Subscribe to them (filtered), or include them in the broadcast topic. |
| B-04 | HIGH | `lib/data/app_database.dart:667,673,677` | **Unbounded reads that grow forever:** `staff_calls` (all calls ever, resolved included), `shifts` (all), `shift_expenses` (all). Every refresh downloads the whole history → slower each month, burns egress and the 500 MB DB. | Window them: unresolved calls + last 24 h; shifts and expenses within the same `historyFrom` window as payments; paginate. |
| B-05 | HIGH | `lib/state/cafe_store.dart:226-227` | `syncFromDisk` returns early when `_pendingWrites > 0`. A realtime event that arrives during a save is dropped; the screen stays stale until the 90 s poll. | Set a "dirty" flag and run one sync after the write finishes. |
| B-06 | HIGH | `lib/state/cafe_store.dart:569-578, 599-611` | `requestPasswordReset` and `completePasswordReset` call Supabase with **no try/catch**. Offline or rate-limited → unhandled exception, spinner never stops. | Wrap and return a translated error, like `signInAdmin` does. |
| B-07 | HIGH | `lib/state/cafe_store.dart:759` | `signOut()` fires `db.client?.auth.signOut()` without awaiting or catching. Errors are lost; on slow networks the next sign-in can race the old session. | `unawaited(...catchError(reportError))` or make `signOut` async. |
| B-08 | HIGH | `lib/state/cafe_store_settings.dart:11,24` | `defaultMenuOrigin = 'https://web-menu-akakus.vercel.app'`. On the Windows till (not web) every printed QR code points to **your personal Vercel URL**. A customer on their own domain gets QR codes for yours. | Store `public_menu_url` per restaurant in the DB; fall back to the build define. |
| B-09 | HIGH | `lib/state/cafe_store_settings.dart:6`, `lib/widgets/cafe_widgets.dart:39` | Empty cafe name falls back to **"Café Italiano"** — a new customer sees another business's name on login/receipts. | Fallback to "Tawla" or to an empty logo-only state. |
| B-10 | HIGH | `lib/data/app_database.dart:2057-2068` | Images are stored at a **fixed path** (`<restaurant>/<item>.jpg`, `upsert: true`). Replacing a photo keeps the same public URL, so phones and the CDN keep showing the **old image**. Images are also uploaded **uncompressed** (full camera size) → eats 1 GB storage and 5 GB egress fast. | Add a version suffix (`<item>-<timestamp>.webp`), delete the old file, resize to ≤ 800 px WebP on the client before upload. |
| B-11 | HIGH | `lib/data/app_database.dart:555-561` + `multi_cafe_slots.sql:164-175` | `has_any_admin()` with no id returns "any cafe in the whole DB has an admin". An **unlinked** device is told an admin exists and is sent to a login it cannot use. | Unlinked device → always show a "Link this device" screen. |
| B-12 | MEDIUM | `lib/data/app_database.dart:97-102, 501` | New cafes silently get **10 % service charge** as the default. Many Libyan cafes charge none. | Default 0 and ask during onboarding. |
| B-13 | MEDIUM | `lib/state/cafe_store.dart:253-256` | `ensureShiftNumbers` calls one RPC **per order, sequentially** (N+1). Slow at shift start with many open orders. | One RPC that numbers a list of order ids. |
| B-14 | MEDIUM | `supabase/migrations/20261009120000_optimize_and_harden.sql:131` | `private.purge_expired_sessions()` exists but **nothing calls it**. `cashier_sessions` grows forever. | Schedule with `pg_cron` (available on free tier) daily. |
| B-15 | MEDIUM | `multi_cafe_slots.sql:180-201` | `list_pos_cashiers(null)` returns **slot 1's cashier names to anyone**; `restaurant_for_slot` lets anyone enumerate every cafe (1..8). Minor information leak, but it becomes worse with unlimited tenants. | Require the slug and drop the "null → slot 1" compatibility path once old builds are gone. |
| B-16 | MEDIUM | `lib/data/app_database.dart:651-655` | Non-guest devices load **every cart** in the cafe with all lines on every refresh. | Only carts with lines, or rely on realtime deltas. |
| B-17 | MEDIUM | `lib/data/app_database.dart:722-724` | Live refreshes keep the *previous* `imageUrl`; a photo changed on another device appears only after the 60 s catalog refresh. | Include `image_url` in the light select (it is a short string). |
| B-18 | MEDIUM | `tool/vercel_build.sh:16-18` | Vercel clones **unpinned Flutter `stable`** every build. A Flutter release can break production without any code change. | Pin a version (`-b 3.x.y`) and update deliberately. |
| B-19 | MEDIUM | `supabase/migrations/20261001120000_…` and `20261001130000_…` | **Two migrations with the same name** (`payment_type_archive`). The first is 3 lines. Confusing history. | Leave as is (never rewrite applied migrations) but document it in a `supabase/MIGRATIONS.md`. |
| B-20 | MEDIUM | `lib/money.dart:45` | Tripoli time is hard-coded as UTC+2. Correct for Libya today, but blocks selling outside Libya and breaks if Libya re-introduces DST (it did in 2012-13). | Store an IANA zone per restaurant (`Africa/Tripoli`) and use `timezone` package. |
| B-21 | LOW | `lib/screens/admin_dashboard_screen.dart` (range label, chart bars and tooltips) | `DateFormat.yMMMd()` / `MMMd()` / `MMMM()` with no locale → English month names in the Arabic UI and in the chart. | Pass `store.locale`. |
| B-22 | LOW | `lib/main.dart:215` | `/dev` relies on `state.extra`; a browser refresh loses it and bounces to login. Intended, but undocumented. | Fine; add a comment. |
| B-23 | LOW | `lib/data/app_database.dart:2080` | `Secrets.hash(value, salt) => value` — an **identity "hash"**. Unused today, but dangerous if someone calls it later. | Delete (see R-2). |

### 1.2 Inconsistencies

| ID | Where | Inconsistency |
|---|---|---|
| I-01 | everywhere | **Five product names**: "Tawla" (title, manifest), "Café Italiano" (pubspec description, fallback name, guest thank-you, auth footers), "CafePOS" (installer folder), "menu_web_v1" (package, Windows ProductName, iOS web-app title), "com.example" (bundle id, Windows CompanyName). |
| I-02 | `lib/l10n/app_en.arb` + AR (`authPosFooter`, `authChangePasswordFooter`, `adminTerminalBadge`, `cashierPosTerminal`) | Fake mock text: "Terminal Station 04", "© Café Italiano Firenze 1984", "Terminal Auth Gateway v4.9", "Terminal #01 · Secure Node", "POS TERMINAL 01". Design-mock leftovers shown to real customers (1.2.0 added two more). |
| I-03 | `lib/l10n/app_en.arb:7,810` | `welcomeMessage` and `guestThankYou` hard-code "Café Italiano" instead of a `{cafe}` placeholder. |
| I-04 | `lib/data/app_database.dart` (17×), `cafe_store.dart` | Errors are a mix of translated strings and raw English (`'Supabase is not configured.'`, `'Could not reach Supabase: $error'`, `'line not found'`, `'cart is empty'`). Arabic users see English technical text. |
| I-05 | `lib/screens/dev_screen.dart`, `admin_screens.dart:305` ("Save PNG"), `auth_screens.dart:986,996`, `admin_wages_screen.dart:314-319` (PDF headers) | Untranslated UI strings. The wages PDF is always English. |
| I-06 | `lib/models/models.dart:24-78`, `app_database.dart:141-142` | Leftovers from the old local-only version: `passwordHash`, `pinHash`, `pinSalt`, `otp => null`, `nextOrderId => 1001`, `isSqlite => false`, `databasePath`. |
| I-07 | `lib/data/app_database.dart:518-530` vs `774-788` | Payment-type mapping is written twice (guest path uses `_mapPaymentTypes`, staff path duplicates it inline). |
| I-08 | `pubspec.yaml:2`, `README.md` | Description says "Café Italiano POS"; README is the untouched Flutter template. |
| I-09 | `web/manifest.json` | `"description": "A new Flutter project."`, theme colour `#0175C2` (Flutter blue) — not the brand. |
| I-10 | `.env.example` | Lists both `SUPABASE_ANON_KEY` and `SUPABASE_PUBLISHABLE_KEY`; the code accepts 4 different names for the same key. |

### 1.3 Empty placeholders / unfinished bits

| ID | Where | What |
|---|---|---|
| P-01 | `README.md` | Flutter template, no project description, no setup steps. |
| P-02 | `lib/state/cafe_store.dart:457` | `_loadGuestLocale() async {}` — empty function kept only to be called. |
| P-03 | `lib/l10n/app_en.arb:16` | "Menu coming soon" — check it is shown only for genuinely empty menus. |
| P-04 | `assets/data/.gitkeep` | Empty asset folder declared in `pubspec.yaml`. |
| P-05 | `pubspec.yaml` | Template comments everywhere (≈70 lines of Flutter boilerplate). |
| P-06 | `web/index.html:4-16,36-43` | Template comments; `apple-mobile-web-app-title` = `menu_web_v1`. |
| P-07 | `plans/001…005` | Five UX plans written but check which are implemented; move done ones to `plans/done/`. |
| P-08 | Android / iOS / macOS / Linux folders | Generated, never configured (bundle id `com.example.menu_web_v1`). Either configure or delete to reduce noise. |

### 1.4 Missing features (core POS gaps)

Ranked by how often a buyer will ask for it:

1. **Kitchen Display / kitchen ticket printing** — orders go to the cashier only; no kitchen/bar routing by category.
2. **Waiter mode** — a phone app for waiters to take orders at the table (today only guests via QR or the cashier).
3. **Owner mobile dashboard + daily closing report** (WhatsApp/Telegram/email at shift close).
4. **Deeper analytics on the admin dashboard** — 1.2.0 added a daily sales/expenses bar chart (`admin_dashboard_screen.dart` `_chart`). Still missing: hourly heat-map, best/worst sellers, per-cashier performance, comparison with last week/month.
5. **Inventory & recipe costing** (stock of coffee beans, milk, cups; cost per dish; profit per dish).
6. **Modifiers / options** (sugar level, size, extra shot, no onion) with price deltas.
7. **Split bill / pay per seat**, **tips**, **refunds/voids with reason and manager PIN**.
8. **Discount by manager PIN & audit log** (who discounted what).
9. **Customer loyalty** by phone number (stamps, points).
10. **Multi-branch** (one owner, several cafes, combined reports).
11. **Reservations / waitlist**.
12. **Dark mode** for night shifts.
13. **ESC/POS direct thermal printing** (today printing goes through the OS print dialog via `printing`).
14. **Role permissions** beyond admin/cashier (manager, waiter, kitchen).
15. **Subscription/billing control for you as the seller** (activate/suspend a cafe, plan limits, expiry date).

---

## 2. Feature ideas — Libya-specific and "wow" features that sell

### 2.1 Libya-specific (strong differentiators against imported POS systems)
| Feature | Why it sells in Libya |
|---|---|
| **Works through internet and power cuts** (already partially there: offline outbox on Windows) — market it hard, and extend it to full LAN mode (§3.4 option D). | Outages are daily reality; foreign cloud POS systems stop working. |
| **Local payment methods pre-configured**: Cash, Moamalat card, Sadad, Tadawul, Mobi Cash, LyPay, bank transfer (Jumhouria / Wahda / Sahara / NCB) with reference number field. | Cash liquidity shortage pushes cafes to e-payments; staff need to record the reference. |
| **Payment QR on the bill** (show the cafe's wallet/bank QR or account number on the guest bill screen). | Guests pay by phone without card terminals. |
| **WhatsApp receipt & order-ready message** (via `wa.me` deep link — free, no API needed). | WhatsApp is the main channel in Libya. |
| **Daily closing summary to the owner on WhatsApp/Telegram** (Telegram Bot API is free). | Owners are often absent; they want the day's cash on their phone at closing. |
| **Ramadan mode**: iftar/suhoor timers, pre-orders for iftar, automatic menu switch at Maghrib (prayer times for Tripoli/Benghazi/Misrata/Sabha). | Biggest season for cafes and restaurants. |
| **Hijri + Gregorian dates on receipts and reports.** | Expected by many owners. |
| **Libyan-dialect Arabic UI option** (friendlier labels) next to MSA. | Feels "made for us". |
| **3-decimal dinar with dirham rounding options** (round to 0.250 / 0.500 for cash). | Small coins are scarce — cashiers round anyway; make it official and reported. |
| **Delivery & pickup by phone number + map pin** with local drivers. | No dominant delivery platform; cafes run their own drivers. |
| **Cost-price in USD with exchange-rate field** for imported supplies (coffee, syrups). | Parallel-market rate changes margins weekly. |
| **Facebook/Instagram menu link** (the `/t/` menu can be a public, table-less menu `/m/<cafe>`). | Libyan cafes market mostly on Facebook and Instagram. |

### 2.2 Smart / eye-catching ("demo wow") features
1. **Live floor map** with table timers (colour turns amber after 45 min, red after 90) — owners love it in demos.
2. **AI menu writer**: owner types "latte" → app writes appetising AR/EN descriptions; photo → auto-crop + background clean.
3. **"Best sellers / dead dishes" menu engineering** chart (Stars, Plowhorses, Puzzles, Dogs).
4. **Busy-hours heat-map** (day × hour) to plan staff.
5. **Theft & error radar**: alerts for unusual voids, discounts, price edits, drawer shortages per cashier.
6. **Guest rating after payment** + one-tap "Review us on Google".
7. **Happy hour / time-based pricing** automatically applied.
8. **Digital signage mode**: a TV shows the menu and "order #123 ready" numbers.
9. **Guest "call waiter / ask for bill / ask for shisha coal"** buttons (call staff already exists — extend the kinds; shisha is big in Libyan cafes).
10. **Branded guest menu themes** (already have colours; add 4–6 ready-made premium themes and a video/hero image).
11. **Owner app as a PWA** installable on the phone home screen with push notifications.
12. **One-tap onboarding**: owner uploads a photo of the paper menu → items are created (OCR/AI).

---

## 3. Redundancies, bad code placement and the restructure plan

### 3.1 What is redundant or misplaced today
| ID | Finding |
|---|---|
| S-01 | `lib/data/app_database.dart` is **~2,100 lines** and does everything: env loading, auth headers, realtime, retry logic, every table's select, mapping JSON→models, every write, image upload, and a `Secrets` util class. Far over the 800-line ceiling. |
| S-02 | `CafeStore` is a **god object** (≈760 lines + 7 `part` files ≈ 2,500 lines). All screens `watch` the whole store, so any change rebuilds every listening screen. |
| S-03 | **Two copies of all data**: `AppDatabase` keeps `_orders`, `_tables`… and `CafeStore` copies them again in `_hydrateOperational()`; getters in `AppDatabase` copy lists on every access (`List.from`). |
| S-04 | **Change detection by giant string fingerprint** (`cafe_store.dart:282-397`) built twice per sync — O(all data) string concatenation on every realtime event. |
| S-05 | JSON→model mapping lives inside `app_database.dart` while `models.dart` has its own `fromJson` with **different keys** (camelCase vs snake_case). Two mappers for one model. |
| S-06 | Screens are split inconsistently: `screens/cashier/*` and `screens/customer/*` are folders, but admin is spread over `admin_screens.dart`, `admin_catalog_screens.dart`, `admin_menu_layout_screen.dart`, … at the top level; `cashier_screens.dart` and `customer_screens.dart` are 17–25-line barrel files. |
| S-07 | Utilities scattered at the root of `lib/`: `csv_safe.dart`, `ledger.dart`, `money.dart`, `pdf_text.dart`, `receipt_print.dart`, `save_bytes*.dart`, `takeout_receipt.dart`, `time_format.dart`, `report_error.dart`, `dev_logs.dart`, `device_location.dart`. |
| S-08 | `money.dart` holds time-zone code; `time_format.dart` holds formatting — split the wrong way. |
| S-09 | Relative imports (`'../models/models.dart'`) mixed with `package:` imports. |
| S-10 | Business rules exist in both Dart and SQL (totals, numbering, shift math). SQL is the source of truth (good); Dart copies drift. |
| S-11 | 51 migrations, many "fix the previous one". Fine to keep, but new installs replay all of them. |

### 3.2 Target structure (feature-first)

```
lib/
  app/                      # main.dart wiring, router, theme bootstrap
    router.dart
    app.dart
  core/                     # no Flutter widgets here
    config/                 # env, build defines, tenant config
    money/                  # CafeMoney, rounding
    time/                   # Tripoli/IANA zone, formatting
    errors/                 # AppFailure sealed class, reportError
    platform/               # save_bytes, update_platform, location
  data/
    supabase/               # client, headers, realtime (one file each)
    dto/                    # snake_case JSON <-> model mappers (ONE place)
    repositories/           # MenuRepository, OrderRepository, PaymentRepository,
                            # ShiftRepository, TableRepository, TenantRepository …
    offline/                # outbox, sync (already exists — move here)
  domain/
    models/                 # split models.dart per entity
    ledger/                 # ledger.dart logic
  features/
    auth/      (screens + controller)
    guest/     (menu, cart, bill, call_staff)
    cashier/   (takeout, floor, alerts, settle, shifts, log)
    admin/     (dashboard, menu, discounts, tables, sales, wages, settings, brand)
    dev/
  ui/                       # design system: tokens, theme, shared widgets
    tokens.dart  (spacing, radius, type scale, colors)
    theme.dart
    widgets/
  l10n/
```

### 3.3 Restructure steps (do them in this order; each step is one PR that keeps the app working)

| Step | What | Risk | Proof it worked |
|---|---|---|---|
| **R-0** | Freeze: tag `v1.1.1`, take a DB backup, record baseline timings (`refreshFromDisk` ms in debug log, web bundle size, `flutter test` time). | none | Baseline numbers written in `docs/BASELINE.md`. |
| **R-1** | Add CI gate: `flutter analyze`, `dart format`, `flutter test --coverage`, `tool/test_db.sh` on every PR. | low | Red build on any regression. |
| **R-2** | Delete dead code (I-06, B-23, P-02, P-04, template comments). | low | Tests still pass. |
| **R-3** | Branding pass (I-01..I-03, I-08, I-09, B-09): one name ("Tawla"), translated placeholders `{cafe}`. **Do not change Windows `CompanyName`/`ProductName`** without a data-folder migration (see `docs/RELEASING.md` warning). | low | Grep for old names returns 0. |
| **R-4** | Design tokens (§4): `ui/tokens.dart` with spacing/radius/type scale; replace literals screen by screen. | low | Grep `fontSize: \d` / `Color(0x` outside `ui/` trends to 0. |
| **R-5** | Split `app_database.dart` into `data/supabase/*` + `dto/*` + one repository per aggregate. Keep `AppDatabase` as a thin facade at first so screens don't change. | medium | Same tests; file sizes < 400 lines. |
| **R-6** | **Tenant model**: replace slots with an unbounded `tenants`/`restaurants.slug` key; add `plan`, `status` (active/suspended), `expires_at`, `public_menu_url`, `timezone`. Migration keeps `slot` as a legacy column. | medium | Can create tenant #9…#500 from the dev screen. |
| **R-7** | **Realtime per tenant** (B-02, B-03): Broadcast topic `cafe:<id>`; refetch only the changed table. | medium | Supabase Realtime dashboard shows messages scoped; refresh count per event = 1 table. |
| **R-8** | **Bounded queries** (B-04, B-16): every list has a window or limit; history loads on demand. | medium | Refresh payload size stays flat as months pass. |
| **R-9** | Split `CafeStore` into feature controllers (`AuthController`, `MenuController`, `OrdersController`, `ShiftController`, `GuestController`, `UpdateController`), each a `ChangeNotifier` provided separately; screens use `context.select` for the bits they need. Remove the fingerprint (S-04) — repositories emit change events instead. | high | Flutter DevTools rebuild counts drop; no full-app rebuild on a single order change. |
| **R-10** | Move screens into `features/*` (pure file moves + `package:` imports). | low | Diff is moves only. |
| **R-11** | Images: client-side resize to WebP, versioned paths, delete old files (B-10). | low | Storage usage per cafe < 20 MB. |
| **R-12** | Scheduled housekeeping with `pg_cron` (B-14) + archive data older than N months to a cold table / CSV export. | low | DB size growth per cafe/month measured and flat. |
| **R-13** | Squash migrations into a **baseline** for *new* projects only (`supabase/baseline.sql`), keep the history for the live project. Needed for the "one project per customer" model (§5). | medium | `supabase db reset` on a fresh project with the baseline equals the live schema (`pg_dump --schema-only` diff = empty). |
| **R-14** | Performance pass: measure again vs R-0; web: `--wasm` already on, check deferred chunks, tree-shake icons, preload Arabic font only when Arabic is chosen. | low | Numbers in `docs/BASELINE.md` improved. |

> Expected gains: refresh traffic per realtime event drops from ~12 queries to 1; DB/egress growth becomes linear in *active* data, not total history; screen rebuilds drop sharply; the 8-cafe ceiling disappears.

---

## 4. Visual and design inconsistencies

| ID | Finding | Evidence | Fix |
|---|---|---|---|
| D-01 | **Two palettes fighting.** Tokens describe a warm cream/terracotta café palette (`cream`, `card`, `peach`, `terracotta`) but the default *surfaces* are a navy header `#1B3A4B` and a cold blue-grey background `#E7EEF2`. Cream cards sit on a cold background. | `lib/theme/cafe_theme.dart:4-23` | Pick one direction. Either warm (cream bg, espresso header, terracotta action) or cool; derive all surfaces from it. |
| D-02 | **15 different corner radii** in 1.2.0 (3, 4, 6, 8, 9, 10, 12, 13, 14, 15, 16, 18, 20, 24, 28). | grep `BorderRadius.circular` | Use a scale: 6 / 10 / 16 / 24 / pill. |
| D-03 | **267 hard-coded font sizes** in 1.2.0 (up from ~250); titles differ per screen, plus `PanelTitle(size: 17)` and the scaled `AppSections.titleSize`. | grep `fontSize: \d` | Type scale in `tokens.dart` (12/14/16/20/24/32) and use `textTheme`. |
| D-04 | **130 hard-coded `Color(0x…)` values** outside the token files in 1.2.0, e.g. `TawlaTokens` hint colour `0xFF6B7A83` inline, switch track `0xFFDDD9D0` inline in the theme. They ignore the cafe's chosen colours. | grep `Color(0x` | Move to tokens / `CafeSurfaces`. |
| D-13 | **Two token systems** (new in 1.2.0): `CafeColors` (`theme/cafe_theme.dart`) and `TawlaTokens` (`widgets/tawla_ui.dart`) define overlapping greys/borders (`CafeColors.line` `#E8E6DE` vs `TawlaTokens.border` `#E3DED5`, `CafeColors.inkMuted` `#56423C` vs `TawlaTokens.muted` `#56606A`). Also, `SoftCard` (old) and `TawlaPanel` (new) both exist as "the card". | `lib/widgets/tawla_ui.dart:9-15` | Merge into one `ui/tokens.dart`; keep one panel widget. |
| D-14 | **Cafe branding only partly applied** (1.2.0): switches are always green and chips use the header colour, regardless of the button colour the admin picks in Brand settings. That is intentional, but the colour picker preview doesn't show it, so owners will think their colour "didn't apply". | `cafe_theme.dart` switch/chip themes | Show these fixed colours in the brand-settings preview or explain it in the UI. |
| D-05 | **Brand flash on start-up**: the opening screen and `DeferredView` loader use the default theme, then the app switches to the cafe's colours. | `lib/main.dart:87, 593` | Cache the last cafe colours locally and use them on the boot screen. |
| D-06 | **Mock text in production UI** (fake terminal numbers, "Firenze 1984", "v4.9"). | `app_en.arb:144,188` | Replace with the real cafe name + real app version. |
| D-07 | **Mixed languages on screen** (English errors/dev texts/PDF headers inside Arabic UI). | I-04, I-05 | Translate everything users can see. |
| D-08 | **Web manifest / PWA colours** are Flutter blue `#0175C2`; installed PWA splash looks like a different product. | `web/manifest.json` | Brand colour + proper icons. |
| D-09 | **No dark mode**; night-shift tills are bright. | `CafeTheme` has only `light` | Add a dark variant from the same tokens. |
| D-10 | Contrast is computed with a single luminance threshold 0.55 (`contrastOn`) — some mid-tone custom colours give low-contrast text. | `cafe_theme.dart:25` | Choose the text colour by WCAG contrast ratio (≥ 4.5:1) and warn the admin in the colour picker. |
| D-11 | Number formatting always uses Western digits (`NumberFormat('#,##0.000','en')`) while dates use the system locale. | `money.dart:76`, B-21 | Decide once (Western digits are common in Libya — fine) and apply the same rule to dates. |
| D-12 | Guest screens and staff screens follow different density/spacing rules (guest menu 28 font-size literals vs admin 27) with no shared spacing scale. | per-file counts | Spacing tokens (4/8/12/16/24/32). |

---

## 5. Selling it: free-tier architecture options (unlimited cafes, no bottleneck)

### 5.1 What actually limits you today
Current model = **one Supabase project, all cafes inside it (shared tables, `restaurant_id` + RLS)**, capped at 8 slots.

Supabase **Free plan** limits to plan around (check the pricing page before deciding — they change):

| Limit (per project) | Approx. free value | What eats it in this app |
|---|---|---|
| Database size | 500 MB | Order/payment history, unbounded calls/expenses (B-04) |
| File storage | 1 GB | Menu photos and logos (B-10) |
| Egress (bandwidth) | ~5 GB / month | Full reloads on every realtime event (B-02), photos |
| Realtime concurrent connections | ~200 | Every till **and every guest phone** holds a socket |
| Realtime messages | ~2 M / month | Unfiltered postgres_changes (B-02) |
| Monthly active users (Auth) | 50,000 | Admins only (cashiers use PIN tokens) — not an issue |
| Free projects per account | **2** | Blocks "one project per cafe" on *your* account |
| Inactivity pause | after ~7 days without traffic | Cafe that closes for Eid/holiday can come back to a paused DB |
| Backups | none on free (you already run a GitHub Actions `pg_dump` — keep it) | |

Realistic capacity of the shared free project **after** the fixes in §3 (R-6…R-12): roughly **20–40 small cafes**, limited first by realtime connections and egress, not DB size. Before the fixes: fewer than 10.

### 5.2 Every option you can plug in

#### Option A — Shared multi-tenant on ONE free Supabase project (current, improved)
- **How:** remove the slot cap (R-6), per-tenant realtime (R-7), bounded queries (R-8), compressed images (R-11), archive old data (R-12).
- **Capacity:** ~20–40 cafes free. When near limits, upgrade *that one project* to Pro (paid by customer fees) — or move to option C/E.
- **Pros:** zero extra work per sale; one deploy updates everyone; one place to back up.
- **Cons:** one noisy cafe affects all; one outage hits everyone; hard cap from free limits.

#### Option B — "Shard" across many free projects (pool of shared projects)
- **How:** each free project holds N cafes (e.g. 20). A tiny **tenant directory** (a 3rd free Supabase project, a Cloudflare KV/D1, or a JSON on Vercel Edge Config) maps `cafe-slug → {supabase_url, anon_key}`. The app reads the directory at boot (`/c/<slug>` already exists — extend it to fetch the project URL) instead of compile-time `SUPABASE_URL`.
- **Free-project limit:** you get 2 free projects per account. Shards beyond that need **separate Supabase accounts/organisations** — technically possible but against the spirit of the free plan and fragile. Prefer option C for scaling shards.
- **Pros:** isolates load; same code.
- **Cons:** migrations must run on every shard (script it with the Supabase CLI); directory becomes critical.

#### Option C — Customer-owned project ("bring your own Supabase") ✅ recommended for unlimited free
- **How:** each cafe owner (or you on their behalf, with their email) creates **their own free Supabase account + project**. You run `supabase db push` with the baseline schema (R-13), deploy the same web build, and register the project in your tenant directory. Their free quota is theirs — **no shared bottleneck, unlimited number of cafes**.
- **Pros:** truly unlimited and free; full isolation; customer owns their data (strong sales argument); one cafe's outage doesn't touch others.
- **Cons:** you need automation for migrations across N projects (a GitHub Action looping over a list of project refs + DB URLs stored as secrets); each project can pause if the cafe is closed > 7 days (mitigate with a daily keep-alive ping from GitHub Actions cron — free).
- **App changes needed:** runtime Supabase URL/key (directory lookup), baseline migration, a migration runner script, health-check dashboard in the dev screen.

#### Option D — Local-first: the Windows till is the server (LAN), cloud is optional
- **How:** the till runs a small local server (Dart `shelf` or PocketBase) with SQLite as the source of truth. Guests scan a QR that points to `http://<till-ip>` on the cafe Wi-Fi (or a local hostname). Cloud (any option above) receives a **sync/backup** stream for the owner's remote dashboard. You already have an outbox + offline mode (`lib/offline/*`) — this generalises it.
- **Pros:** works with **no internet at all** (huge for Libya); zero cloud cost per cafe; fast.
- **Cons:** biggest rewrite; guests must be on cafe Wi-Fi to order; till PC must stay on; local backups needed (USB + cloud).

#### Option E — Self-hosted backend on a free VM (one server for all cafes)
- **How:** Oracle Cloud **Always Free** ARM VM (up to 4 cores / 24 GB RAM, 200 GB disk — check current offer) running **self-hosted Supabase (Docker)** or **PocketBase**. All cafes share it; you control limits.
- **Pros:** very high capacity (hundreds of cafes), no per-project caps, no pausing.
- **Cons:** you are the DBA: updates, backups, security, uptime are your job; Oracle may reclaim idle free VMs; requires a domain + TLS (Cloudflare free).

#### Option F — Other free managed backends (if you leave Supabase)
| Service | Free tier shape | Fit |
|---|---|---|
| **Cloudflare Workers + D1 + Durable Objects** | Generous daily request quota, multiple D1 DBs (one per cafe possible), WebSockets via Durable Objects | Excellent scale, but you rewrite the backend (no RLS/Auth out of the box). |
| **Turso (libSQL)** | Many databases on free (one per cafe) | Good "DB per tenant"; no realtime — add your own. |
| **Neon Postgres** | Several free projects, scale-to-zero | Postgres-compatible (your SQL works), but no Auth/Realtime/Storage — add separately. |
| **Firebase (Spark)** | 1 GB Firestore, daily read/write quotas | Read quotas would be hit by a POS fast; rewrite needed. Not recommended. |
| **Appwrite Cloud (free)** | Projects with DB, auth, realtime | Possible, rewrite needed. |

#### Option G — Hybrid (recommended end-state)
1. **Now (0–10 cafes):** Option A with the fixes. Cheapest, fastest to sell.
2. **Growth (10+ cafes):** Option C — every new cafe gets its own free project; existing cafes migrated one by one using `pg_dump --data-only` filtered by `restaurant_id`. Your shared project becomes the **tenant directory + your billing/licence table**.
3. **Premium tier / unreliable-internet cafes:** add Option D's LAN mode as a paid add-on ("works without internet").
4. **Static web app** stays on **Vercel free** (or Cloudflare Pages free — unlimited bandwidth on static assets, a safer choice when many guests load the menu). One build serves all cafes because the tenant is resolved at runtime from the URL (`/c/<slug>` or subdomain `<slug>.tawla.ly`).
5. **Windows installer + updates** stay on **GitHub Releases** (free) — already built.

### 5.3 Licensing / getting paid (so you can sell repeatedly)
- Tenant table fields: `plan`, `status`, `paid_until`, `max_tables`, `max_devices`. App checks them on login; expired → read-only + banner, never delete data.
- Activate/suspend from the dev screen.
- Pricing idea: one-time setup fee (install + menu entry + QR printing) + monthly subscription; "offline LAN mode" and "multi-branch" as paid add-ons.

---

## 6. Priority summary

| Order | Items | Why first |
|---|---|---|
| 1 | B-01, B-02, B-04, B-08, B-09, I-01..I-03 | Without these you cannot sell to a 9th cafe, and new customers see someone else's brand/URL. |
| 2 | B-03, B-05, B-06, B-07, B-10, B-11, R-1..R-4 | Real bugs customers will hit; cheap fixes. |
| 3 | R-5..R-9, R-13 | Performance + preparing the per-customer-project model. |
| 4 | Missing features 1–7 (§1.4) + Libya pack (§2.1) | What makes buyers say yes. |
| 5 | §2.2 wow features, dark mode, D-01..D-12 | Polish for demos. |
