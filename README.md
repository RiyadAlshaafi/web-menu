# Tawla

Cafe point of sale and QR table ordering, in English and Arabic.

- **Guests** scan the QR code on their table, read the menu, order, call staff and ask for the bill (web).
- **Cashiers** sign in with a PIN, run the floor, take takeout orders, settle bills, record cash movements and close shifts (Windows till or web). The Windows till keeps selling without internet and uploads later.
- **Admins** manage the menu, tables and QR codes, discounts, payment types, cashiers, brand colours and see sales, expenses and wages (web or Windows).

Everything is stored in [Supabase](https://supabase.com) (Postgres, Auth, Realtime, Storage). The Flutter package is still called `menu_web_v1`; the product name is Tawla.

## Run it locally

Needs Flutter 3.47.6 (the version the web and Windows builds pin).

1. Copy `.env.example` to `.env` and fill in the Supabase project URL and publishable key.
2. `flutter pub get`
3. `flutter run -d chrome --dart-define-from-file=.env` (web) or `flutter run -d windows` (the Windows build reads `.env` itself).

A device has to be linked to a cafe before anyone can sign in: open `/c/<cafe-slug>` in the browser, or link it from the developer tools.

## Checks

```bash
flutter analyze
```

```bash
dart format --set-exit-if-changed .
```

```bash
flutter test
```

```bash
PGHOST=localhost PGUSER=postgres tool/test_db.sh
```

`tool/test_db.sh` rebuilds the schema from `supabase/migrations` on a plain local Postgres and runs `supabase/tests`. Every new migration gets a test there and, when it can be undone, a script in `supabase/rollbacks`.

## Builds

| Target | How |
| --- | --- |
| Web | Vercel runs `tool/vercel_build.sh` on every push to `main` (needs `SUPABASE_URL` and `SUPABASE_ANON_KEY` in the Vercel project). |
| Windows | `tool/build_windows.ps1`, or the *Windows release* GitHub Action, which publishes a signed installer the tills update from. See [docs/RELEASING.md](docs/RELEASING.md). |

## Layout

| Path | What |
| --- | --- |
| `lib/data/` | Supabase access (`app_database.dart`), env loading, image upload helpers |
| `lib/state/` | `CafeStore`, the app state, split into `part` files by area |
| `lib/screens/` | Guest (`customer/`), cashier (`cashier/`), admin, sign-in and developer screens |
| `lib/offline/` | The till's outbox and uploader for working without internet |
| `lib/l10n/` | English and Arabic strings (`app_en.arb`, `app_ar.arb`) |
| `supabase/` | Migrations, SQL tests and rollbacks |
| `docs/` | Setup, release and audit notes |
