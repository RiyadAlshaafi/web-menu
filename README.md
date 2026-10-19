# Tawla

Cafe point of sale and QR table ordering, in English and Arabic.

- **Guests** scan the table's QR code, read the menu, order, call staff and ask for the bill (`guest-web/`, on `tawla.ly/t/...`).
- **Cashiers** run the floor, take takeout orders, settle bills and close shifts (Windows till or web). The Windows till keeps selling offline and uploads later.
- **Admins** manage the menu, tables, QR codes, staff, prices and reports (web or Windows).
- **Everyone else** lands on the public sales page (`guest-web/`, on `tawla.ly` and `tawla.ly/ar`). It links to no staff screen.

The Flutter package is still called `menu_web_v1`; the product is Tawla.

## Folder map

| Path | What |
| --- | --- |
| `lib/` | Flutter staff app (cashier and admin) |
| `lib/core/` · `printing/` · `platform/` | Money and time helpers · receipts and PDFs · file saving, sound, location |
| `lib/data/` · `state/` · `offline/` | Supabase access · app state (`CafeStore`) · the till's offline outbox |
| `lib/screens/` · `widgets/` · `l10n/` | Screens · shared widgets · English and Arabic strings |
| `guest-web/` | Guest app (Next.js), deployed as a Cloudflare Worker |
| `supabase/` | `migrations/`, SQL `tests/` and `rollbacks/` |
| `web/`, `windows/` | Flutter web shell and Windows runner and installer |
| `tool/` | Build and test scripts |
| `.github/workflows/` | Deploys, Windows builds and the daily database backup |
| `docs/` | Release guide; `docs/archive/` holds finished plans |
| `archive/` | Unused Android, iOS, macOS and Linux folders, and the icon tools |

## Tech stack

- **Staff app:** Flutter 3.47.6 (Dart), `provider`, `go_router`, `supabase_flutter`, SQLite for the offline outbox
- **Guest app:** Next.js 16, React 19, Tailwind 4, Zod, OpenNext for Cloudflare, Node 22
- **Backend:** Supabase (Postgres, Auth, Realtime, Storage, RPC functions)
- **Hosting:** Cloudflare Workers on `tawla.ly` (`tawla-web` for the staff site on `staff.tawla.ly`, `tawla-guest` for the sales page and `/t/*`)
- **Tests:** `flutter_test`, Vitest, Playwright, plain SQL tests

## Run it locally

Staff app:

```bash
cp .env.example .env
```

```bash
flutter pub get
```

```bash
flutter run -d chrome --dart-define-from-file=.env
```

On Windows use `flutter run -d windows` (it reads `.env` itself). Before anyone can sign in, link the device to a cafe: open `/c/<cafe-slug>`.

Guest app:

```bash
cd guest-web && npm ci && npm run dev
```

Put its variables in `guest-web/.env.local`. To run without a Supabase project, see `guest-web/README.md`.

Checks:

```bash
flutter analyze && flutter test
```

```bash
cd guest-web && npm run typecheck && npm run lint && npm test
```

```bash
PGHOST=localhost PGUSER=postgres tool/test_db.sh
```

## Environment variables

Names only. Never commit values; `.env` and `.env.*` are git-ignored, except `.env.example`.

| Name | Used by |
| --- | --- |
| `SUPABASE_URL`, `SUPABASE_ANON_KEY` | Staff app (`.env`) and guest app server |
| `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY` | Guest app browser (live updates) |
| `UPSTASH_REDIS_REST_URL`, `UPSTASH_REDIS_REST_TOKEN` | Guest app rate limits (optional) |
| `GUEST_WEB_URL` | Staff web build: where old guest QR links forward to |
| `DEFAULT_SLOT` | Staff web build: cafe slot (`tool/build_web.sh` defaults it to 1) |
| `PUBLIC_MENU_URL` | Staff build: base address for table QR codes (`tool/build_web.sh` defaults it to `https://tawla.ly`) |
| `NEXT_PUBLIC_WHATSAPP_NUMBER` (variable `WHATSAPP_NUMBER`) | Sales page: digits of the WhatsApp number; the button is hidden when unset |
| `NEXT_PUBLIC_DEMO_MENU_PATH` (variable `DEMO_MENU_PATH`) | Sales page: a demo menu path such as `/t/<slug>`; the button is hidden when unset |
| `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID` | GitHub Actions deploys |
| `SUPABASE_DB_URL`, `R2_ACCOUNT_ID`, `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY` | Monthly archive of receipts and expenses to R2 (`db-archive.yml`) |

Windows till releases: [docs/RELEASING.md](docs/RELEASING.md).
