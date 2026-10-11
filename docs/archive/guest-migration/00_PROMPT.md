# Task: Rebuild the GUEST (QR ordering) side of this app in Next.js, leave the staff side in Flutter

You are working in `D:\coding\menu_web_v1`, a Café Italiano POS + QR-ordering app.
- Flutter app (Dart): `lib/` — admin, cashier, and guest/customer screens in one app.
- Backend: Supabase (Postgres + RLS + RPC functions + Realtime). Schema history in `supabase/migrations/` (≈50 migrations, read them in order).
- Project agents exist in `.claude/agents/` (planner, designer, db-analyst) — use `planner` for the plan and `db-analyst` for any DB/RLS question.

Goal: the guest experience is slow on mobile in Flutter web. Rebuild ONLY the guest-facing part as a Next.js app. Admin and cashier stay in Flutter, unchanged except where strictly needed. Both apps keep sharing the same Supabase backend so the cashier sees guest orders exactly as today.

---

## Phase 1 — Study (read-only, no code changes)

Read and understand before touching anything:
1. `lib/main.dart`, `lib/navigation/app_sections.dart` — how the app routes guest vs staff (QR link format, table/cafe params).
2. `lib/screens/customer_screens.dart` — every guest screen, widget, state, and edge case.
3. `lib/state/cafe_store*.dart` (especially `cafe_store_location.dart`, `cafe_store_orders.dart`, `cafe_store_catalog.dart`), `lib/live_updates.dart`, `lib/device_location.dart`, `lib/models/models.dart`, `lib/money.dart`, `lib/l10n/` (Arabic + English, RTL).
4. ALL files in `supabase/migrations/` in order. Pay special attention to:
   - `send_table_cart`, `guest_location_rule`, `guest_ordering_open`
   - `*_guest_and_pin_hardening`, `*_guest_location_check`, `*_guest_ordering_needs_cashier`, `*_guest_gate_opt_in`, `*_presence_per_session`, `*_item_availability`, `*_restaurant_branding`, `*_button_color`, `*_multi_cafe_slots`, `*_takeout_without_table`, `*_lock_down_direct_writes`, `*_security_and_money_fixes`, `*_live_update_pings`, `*_audit_fixes`
5. Use the Supabase MCP (`list_tables`, `get_advisors`, `list_migrations`) to confirm the LIVE schema and RLS match the migration files. Report any drift.

Deliverable of Phase 1: `docs/guest-migration/01_GUEST_FEATURE_INVENTORY.md` containing:
- Every guest feature and rule, with the file:line where it lives today. At minimum confirm and document:
  - Menu browsing by category, item images, prices, item availability (sold-out/hidden)
  - **Menu layout / branding set by staff** (layout style, colors, button color, logo, cafe name) — guest must render whatever staff configured, and update when staff change it
  - Cart, item notes/options, order rounds (adding more to an existing table order)
  - Dine-in with table from QR vs takeout without table
  - **Location check** — guest must be within the cafe's allowed radius (how the rule is computed, what happens on denied/unavailable GPS, cashier-skip option)
  - **Guest ordering requires a cashier online** (presence) — when no cashier is online, guest can browse but cannot order; the opt-in gate setting
  - Order refusal notices, order status/live updates for the guest
  - Multi-cafe slots (which cafe a QR belongs to)
  - Arabic/English + RTL, money formatting
- Every Supabase table/view/RPC/Realtime channel the guest touches, and with what role (anon vs authenticated).
- Anything unclear → list it under "Open questions" and STOP and ask me before Phase 2.

## Phase 2 — Plan (write the plan, then wait for my approval)

Write `docs/guest-migration/02_PLAN.md`:
- **Architecture:** a new Next.js (App Router, TypeScript strict, Tailwind) app in `guest-web/` in this repo. Mobile-first. Server Components for menu render; client components only where interactive (cart, location, live status).
- **API layer (the connection to the Flutter system):** Next.js Route Handlers / Server Actions under `guest-web/app/api/guest/*`. The browser NEVER talks to Supabase with write access directly. Each endpoint:
  - Does exactly ONE job and calls exactly ONE existing whitelisted RPC/query. Proposed set (adjust to what Phase 1 found): `GET menu` (catalog + availability + branding/layout for one cafe), `GET status` (ordering open? cashier online? location rule), `POST order` (→ `send_table_cart`), `GET order/:id status` (guest's own order only).
  - Validates every input with **zod** (ids are UUID, quantities are bounded ints, notes length-capped, no unknown fields). Rejects anything extra.
  - Never trusts prices, totals, availability, cashier-online or location from the client — the database decides. Price is recomputed server-side.
  - Is **rate limited** per IP + per table/session (e.g. Upstash Ratelimit or Vercel's rate limiting). Propose concrete limits (e.g. order: 5/min, menu: 60/min) and justify them.
  - Returns a consistent `{ ok, data, error }` shape; error messages never leak SQL/internal details.
  - Uses ONLY the Supabase **anon/publishable key** on the server, with RLS doing the enforcement. The `service_role` key must NOT be used anywhere in `guest-web/`. If something seems to need it, stop and propose an RPC with `security definer` + tight checks instead.
- **Row Level Security:** audit every table the guest can reach. Guest (anon) must be able to: read only active menu/branding/availability for the cafe in the QR; create orders ONLY via the RPC (no direct INSERT/UPDATE/DELETE on any table); read only its own order status. Guest must NOT be able to read other orders, staff data, payments, shifts, expenses, wages, logs, PINs, or other cafes. Write any needed changes as a NEW migration in `supabase/migrations/` (never edit old ones), and include SQL tests proving each allowed/denied case.
- **Realtime:** how the guest page receives menu/layout/availability changes and order status (reuse the existing publication/ping design; anon must only receive its cafe's public data).
- **Flutter changes:** the guest routes in Flutter should redirect to the new Next.js URL (keep old QR codes working). List exactly what changes in Flutter — keep it minimal. Admin/cashier untouched.
- **Hosting:** Vercel, env vars, custom domain/subpath, how QR URLs map.
- Task list with phases, and risks.

STOP after Phase 2 and wait for my "approved".

## Phase 3 — Build (after approval)

- Follow TDD: write tests first for each API route (valid, invalid input, rate-limited, cashier offline, outside location, sold-out item, wrong cafe, price tampering).
- Build the UI to match the current guest look and the staff-configured layout/branding, Arabic + English with correct RTL.
- Performance budget on a mid-range phone over 4G: first contentful paint < 1.5s, JS for the menu page < 150 KB gzipped, images via `next/image` (WebP/AVIF, sized).
- Accessibility: tap targets ≥ 44px, contrast AA, works with screen readers.

## Phase 4 — Verify (must all pass before saying "done")

1. Unit + API tests pass; coverage ≥ 80% on `guest-web/`.
2. Playwright E2E on a mobile viewport (iPhone + Android profiles) covering: browse → add to cart → order succeeds; cashier offline → order blocked with clear message; location denied/outside radius → blocked; staff changes layout/colors/availability in Flutter → guest page updates; takeout without table; Arabic RTL.
3. RLS tests: each denied case actually fails as anon (prove with SQL or supabase-js tests).
4. Supabase `get_advisors` (security + performance) shows no new warnings.
5. Run the `security-review` skill and the `code-review` skill on the diff; fix CRITICAL/HIGH.
6. Run the real Flutter cashier app against the same DB and confirm a Next.js guest order appears and can be settled exactly like before.
7. Lighthouse mobile score for the menu page ≥ 90 performance.

Report results honestly with the actual numbers and test output. If anything fails or was skipped, say so.

## Rules
- Do not modify admin/cashier behaviour. Do not edit existing migrations. Do not commit secrets (`.env*` stays gitignored; check `.mcp.json` too).
- Branch: follow the project memory rule (work on `main`) unless I say otherwise. Commit in small conventional commits. **Pushing `main` auto-deploys the live site on Vercel — never push or deploy without asking me first.**
- When unsure about a business rule, ask — don't guess.
