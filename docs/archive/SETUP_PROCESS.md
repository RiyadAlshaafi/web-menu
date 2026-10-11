# Tawla — Exact Process From Scratch

Companion to [AUDIT_PLAN.md](AUDIT_PLAN.md). This is the **do-list**, in order.

Each step is tagged:
- 🧑 **YOU** — only you can do it (sign-ins, payments, passwords, clicking "authorize", talking to customers).
- 🤖 **CLAUDE** — I can do it in this repo when you ask (code, SQL, scripts, docs, running tests/builds).
- 🤝 **BOTH** — I prepare it, you approve or click the final button.

> Rule: I never type your passwords, API secrets, or card details, and I don't push to `main` without asking you (pushing `main` deploys the live site).

---

## Phase 0 — Get the real code locally (5 min)

| # | Who | Step |
|---|---|---|
| 0.1 | 🧑 | Your local folder is **one commit behind GitHub** (local 1.1.1, GitHub 1.2.0). Run: `git pull origin main` (fast-forward, your untracked `.agents/ .claude/ .mcp.json skills-lock.json` are untouched). |
| 0.2 | 🤖 | Run `flutter pub get`, `flutter analyze`, `flutter test`, and record the baseline in `docs/BASELINE.md` (step R-0). |
| 0.3 | 🧑 | Make sure Docker Desktop is installed if you want `tool/test_db.sh` (SQL tests) to run locally. |

## Phase 1 — Accounts you need (all free) — 🧑 YOU only

Do these once. Use one dedicated business email (e.g. `tawla.business@…`) rather than your personal one, so you can hand things over later.

| # | Service | Why | What to do |
|---|---|---|---|
| 1.1 | **GitHub** (already have: `RiyadAlshaafi/web-menu`) | Code, Actions (CI, backups, Windows builds), Releases (installer + updates) | Turn on 2FA. Consider making the repo **private** before selling (it is public now; the backup workflow encrypts dumps because of that). |
| 1.2 | **Supabase** (already have) | Database, auth, realtime, storage | Turn on 2FA. Note the project ref. |
| 1.3 | **Cloudflare** | Hosts the web app (guest menu + staff web) as Workers static assets | Turn on 2FA. |
| 1.4 | **Cloudflare** (new, free) | Domain DNS, free TLS, optional Pages hosting (unlimited static bandwidth), optional tenant directory (KV/D1) | Sign up; add your domain later. |
| 1.5 | **Domain name** (paid, ~$10/yr — the only non-free item, optional) | Professional links `tawla.ly` / `tawla.app` and per-cafe subdomains | Buy from Cloudflare Registrar or Namecheap. `.ly` domains are registered through Libyan registrars (nic.ly). |
| 1.6 | **Telegram bot** (free, optional) | Daily closing summary to owners | Talk to `@BotFather` → `/newbot` → keep the token secret. |
| 1.7 | **Oracle Cloud Always Free** (only if you choose Option E) | Free VM for self-hosting | Needs a card for identity check (not charged on always-free). |
| 1.8 | **Code-signing certificate** (optional, paid) | Removes the Windows "Unknown publisher" warning on the installer | Later, when sales justify it. |

## Phase 2 — Secure and stabilise what exists (week 1)

| # | Who | Step |
|---|---|---|
| 2.1 | 🧑 | GitHub → Settings → Secrets → Actions: confirm `SUPABASE_DB_URL` and `BACKUP_PASSPHRASE` exist (needed by `.github/workflows/db-backup.yml`). Save the passphrase in a password manager. |
| 2.2 | 🧑 | GitHub → Actions → **Database backup** → *Run workflow*. Wait for green. Download one backup and keep it offline. |
| 2.3 | 🧑 | Supabase → Database → Extensions: enable **pg_cron** (needed for scheduled cleanup B-14 and keep-alive). |
| 2.4 | 🧑 | Supabase → Advisors → Security & Performance: screenshot the current warnings and send them to me. |
| 2.5 | 🤖 | Add CI workflow: analyze + format + tests + SQL tests on every PR (R-1). |
| 2.6 | 🤖 | Fix quick bugs: B-05, B-06, B-07, B-09, B-12, B-17, B-21, B-23 + delete dead code (R-2). Each as a PR on a branch. |
| 2.7 | 🤖 | Branding pass (R-3): one name "Tawla", remove mock "Terminal/Firenze" texts, `{cafe}` placeholders, README, manifest. **Not** the Windows `CompanyName/ProductName` (would orphan till data). |
| 2.8 | 🧑 | Review each PR, test on one till and one phone, then merge. |
| 2.9 | 🧑 | Tell me before merging to `main` — that deploys the live site. |

## Phase 3 — Remove the 8-cafe ceiling and make it scale (weeks 2–3)

| # | Who | Step |
|---|---|---|
| 3.1 | 🤖 | Write migration: unbounded tenants (slug-based), plus `plan`, `status`, `paid_until`, `public_menu_url`, `timezone`; keep `slot` as legacy (R-6, B-01, B-08). With SQL test + rollback file. |
| 3.2 | 🤖 | Per-tenant realtime via Broadcast + per-table refetch (R-7, B-02, B-03). |
| 3.3 | 🤖 | Bounded queries + history on demand (R-8, B-04, B-16). |
| 3.4 | 🤖 | Image compression + versioned paths (R-11, B-10). |
| 3.5 | 🤖 | `pg_cron` jobs: purge expired sessions, archive old calls (R-12, B-14). |
| 3.6 | 🧑 | Run the backup workflow again → then apply the migration in Supabase (SQL editor or `supabase db push`). **DB first, app second** (see `docs/RELEASING.md`). |
| 3.7 | 🤝 | I can apply migrations through the Supabase connection in this session **only if you explicitly say so**; otherwise you paste the SQL. |
| 3.8 | 🧑 | Release a Windows build (Actions → Windows release) and merge web changes; watch the dev screen "Tills and app versions". |

## Phase 4 — Code restructure (weeks 3–6, can run in parallel with sales)

Follow AUDIT_PLAN §3.3 steps **R-4, R-5, R-9, R-10, R-13, R-14** in that order.
- 🤖 I do each step as one PR that keeps the app working.
- 🧑 You review, test on a real till, merge.

## Phase 5 — Choose the hosting model for selling

Pick from AUDIT_PLAN §5.2. Recommended path:

### 5A. Start: shared project (Option A) — up to ~20–40 cafes
| # | Who | Step |
|---|---|---|
| 5A.1 | 🤖 | Dev-screen buttons: create tenant, issue setup code, suspend/activate, set `paid_until`. |
| 5A.2 | 🧑 | Watch Supabase → **Usage** monthly: DB size, egress, realtime connections. When any passes ~70 %, move to 5B. |

### 5B. Grow: one free Supabase project per cafe (Option C)
| # | Who | Step |
|---|---|---|
| 5B.1 | 🤖 | Baseline schema file for new projects (R-13) + `tool/new_tenant_project.sh` (link project, push baseline, seed defaults). |
| 5B.2 | 🤖 | Tenant directory (your shared project or Cloudflare KV): `slug → supabase_url, anon_key`. App reads it at runtime instead of the compile-time `SUPABASE_URL`. |
| 5B.3 | 🤖 | GitHub Action "migrate all tenants": loops over projects, runs backup → migration → smoke test. |
| 5B.4 | 🤖 | GitHub Action daily keep-alive ping per project (prevents free projects pausing during holidays). |
| 5B.5 | 🧑 | **For each new cafe:** create a Supabase account *with the owner's email* (or yours on their behalf, with their permission), create a project in the **EU (Frankfurt)** region (closest to Libya), copy the project URL + publishable key + DB connection string into the tenant secrets. Only you/the owner can sign in and accept Supabase's terms. |
| 5B.6 | 🧑 | Add the project's DB URL as a GitHub secret (e.g. `TENANT_<SLUG>_DB_URL`) so migrations and backups reach it. |

### 5C. Premium: offline LAN mode (Option D) — later, paid add-on
- 🤖 Design + build the local server on the till; 🧑 test in a real cafe with the router unplugged.

### Web hosting
| # | Who | Step |
|---|---|---|
| W.1 | 🧑 | GitHub → Settings → Secrets → Actions: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `CLOUDFLARE_API_TOKEN` (Workers Scripts: Edit), `CLOUDFLARE_ACCOUNT_ID`. |
| W.2 | 🤖 | Pin the Flutter version in `tool/build_web.sh` and `.github/workflows/web-deploy.yml` (B-18). |
| W.3 | 🧑 | (Optional) Workers → tawla-web → Settings → Domains & Routes → add the custom domain. Wildcard subdomain `*.tawla.ly` for per-cafe links needs DNS access — only you. |

## Phase 6 — Features that sell (ongoing)

Order from AUDIT_PLAN §1.4 and §2: kitchen display/tickets → modifiers → owner WhatsApp/Telegram daily summary → Libyan payment methods + payment QR → dashboard analytics → loyalty → Ramadan mode → waiter mode.
- 🤖 I build each one as a PR with tests.
- 🧑 You give real input I cannot invent: the exact payment providers your customers use, their account/QR images, printer models, real menu photos, prices.

## Phase 7 — Onboarding each customer (repeat per sale)

| # | Who | Step |
|---|---|---|
| 7.1 | 🧑 | Agreement + price with the owner; collect cafe name, logo, colours, menu, tables, cashier names, payment methods. |
| 7.2 | 🧑 | Create tenant (5A.1) or project (5B.5); issue setup code from the dev screen. |
| 7.3 | 🧑 | Owner opens `/c/<slug>/admin` and creates the admin with the setup code (owner types their own password). |
| 7.4 | 🤝 | Menu entry: you or the owner type it in, or send me the menu as text/CSV and I prepare an import file. |
| 7.5 | 🧑 | Print table QR codes (Admin → Tables → Save PNG), stick them, test-scan **on mobile data**. |
| 7.6 | 🧑 | Install the till: download `CafePOS-setup-<version>.exe` from GitHub Releases, run it, link the cafe (slot/slug). |
| 7.7 | 🧑 | Test: one table order, one takeout, one expense, close shift, print receipt in Arabic. |
| 7.8 | 🧑 | Train staff (30 min) and leave the owner the daily-summary link. |
| 7.9 | 🧑 | Run the AUDIT_PLAN §0.2 checklist and keep it in the customer's folder. |

## Phase 8 — Every release (repeat)

1. 🤖 Run the AUDIT_PLAN §0.1 checklist and report results.
2. 🧑 Backup workflow → green.
3. 🧑/🤝 Apply migrations (all tenants if Option C) — DB first.
4. 🧑 Bump version, run **Windows release** action; merge web to `main` (auto-deploys to Cloudflare).
5. 🧑 Watch the dev screen until all tills are on the new version.

---

## Quick reference: things I cannot do for you
- Sign in, sign up, or accept terms on GitHub, Supabase, Vercel, Cloudflare, Oracle, Telegram, domain registrars.
- Enter or read real passwords, DB connection strings, API keys, backup passphrase, card details.
- Buy domains or certificates.
- Physically install tills or printers, scan QR codes, or train staff.
- Push to `main`, deploy, or run migrations on the live database **without your explicit go-ahead** for that action.
