# Plan: receipts on the cafe PC, nightly backups to Cloudflare R2

Status: plan only, no code written. Date: 2026-10-14.

## Goal

Keep each cafe's sales on its own PC, so the shared Supabase database stays small and cheap.
Back every cafe up to the cloud each night so a broken PC never loses more than one day.

## Who stores what

| Place | What it holds | How long |
|---|---|---|
| Cafe PC (SQLite file) | Receipts, order lines, payments, shifts, expenses, cashier logs | Forever (the source of truth) |
| Supabase | Menu, tables, settings, **live** QR orders, one small summary row per cafe per day | Live orders deleted 48 h after they are paid |
| Cloudflare R2 | Compressed copies of each cafe's SQLite file | 30 daily + 12 monthly copies |
| Cloudflare Worker | Hands out upload/download links, checks the cafe is who it says it is | No data stored |

## How a normal day works

1. Cashier sells. Each paid receipt is written to the PC's SQLite file first (works without internet).
2. QR orders from guests still arrive through Supabase, the same as today.
3. When a QR order is paid, the PC copies it into SQLite. 48 h later a nightly job deletes it from Supabase.
4. At shift close, the PC sends one summary row to Supabase (sales total, receipt count, expenses).
   The owner can then see daily totals from anywhere without the full receipts living in the cloud.

## How the nightly backup works

1. Trigger: at shift close and once at night (e.g. 03:00 if the PC is on). The next app start catches up if a backup was missed.
2. The app makes a clean copy of the SQLite file (`VACUUM INTO`), then gzips it (about 4× smaller).
3. The app asks the Worker: "I am cafe X, device Y, give me an upload link." It sends its device token.
4. The Worker checks the token and returns a 10-minute upload link for `cafes/<cafe_id>/<date>.db.gz` only.
5. The app uploads the file straight to R2, then tells the Worker "done" with the file size and a checksum.
6. If anything fails, the app retries on the next shift close or app start. It shows a warning after 2 missed days.

The app already has a SQLite outbox with a `backupTo` copy function (`lib/offline/outbox_store_io.dart`), which this can build on.

## How a restore works

1. New or repaired PC: install the exe and log in as the cafe's admin.
2. The app asks the Worker for that cafe's backup list and shows dates.
3. Admin picks one. The app downloads it, checks the checksum, and opens it as the new SQLite file.
4. The old file is renamed, not deleted, so a wrong pick can be undone.

## Security

- **The R2 key never goes inside the exe.** Only the Worker holds it.
- Each device gets its own token at first login. You can revoke one stolen PC without touching other cafes.
- The Worker only gives links inside the asking cafe's own folder, so one cafe can never read another's backups.
- The bucket is private. R2 encrypts files at rest.
- Optional later: also encrypt on the PC before upload, with the key stored server-side (if the key lived only on the PC, a dead PC would make its backups useless).

## Your view as the owner of the system

- A small page (served by the Worker) lists every cafe with its last backup time and size.
- Red row if a cafe has no backup for 48 h, so you can call them before data is at risk.

## Cost (prices from memory, check before launch)

- Compressed backup after 1 year of 250 receipts/day: about 25 MB.
- 30 daily + 12 monthly copies is about 1 GB per cafe at most, usually much less early on.
- R2: free up to 10 GB, then about $0.015 per GB per month. No download fees.
- Worker: free plan covers 100,000 requests a day, far more than needed.
- Supabase: stays small (menu + 48 h of live orders + daily summaries), so the free plan holds many more cafes. Realtime limits (about 25 cafes) become the next ceiling.

## Risks and answers

| Risk | Answer |
|---|---|
| PC dies mid-day | Lose sales since the last backup. Shift-close backups cut this to one shift. |
| Cafe has 2+ devices (kitchen screen, waiter phone) | They keep talking through Supabase live orders. Only the main cashier PC keeps the receipt history. |
| Owner wants a full report from home | Daily summary rows cover totals. Full receipt detail needs the cafe PC or a restored backup. |
| PC clock is wrong | Backup names use the Worker's date, not the PC's. |
| Cafe PC offline for weeks | Backups queue up locally and the warning shows. Sales keep working. |

## Build order (one step at a time)

1. Create the private R2 bucket and the Worker (upload link, download link, list, "done").
2. Device tokens: issue at first admin login, store on the PC, revoke from your page.
3. Backup in the app: copy, gzip, upload, retry, warning after 2 missed days.
4. Restore screen in the app.
5. Your status page with the red "no backup" rows.
6. Cloud product only: write paid receipts to SQLite, send daily summary rows, delete live orders after 48 h.
7. Test: kill the PC mid-day, restore on a second PC, compare totals.

Steps 1–5 also work for Level 1 and Level 2 (offline exes) as-is. Step 6 is only for the cloud product.

## Open questions

1. Start with Level 1/2 (backup only) or the cloud product (bigger change, step 6)? Recommended: Level 1, since it is smaller and proves the backup works.
2. Nightly time: 03:00, or only at shift close? Recommended: both.
3. Does any current cafe use more than one cashier PC? If yes, step 6 needs a design for which PC owns the history.
