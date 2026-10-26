# Windows installer and auto-update — how it was built, from scratch

This explains every piece that turns the Flutter Windows app into an installer (Inno Setup),
publishes it with GitHub Actions, and lets each till update itself. It follows the order the
pieces were added, so you can rebuild it in another project.

Files involved:

| Piece | File |
|---|---|
| Installer script | `windows/installer/cafe_pos.iss` |
| Release workflow (tag → installer + `latest.json`) | `.github/workflows/windows-release.yml` |
| Shared checks (analyze, tests, DB tests) | `.github/workflows/checks.yml` |
| Zip build on every push to `main` | `.github/workflows/windows-build.yml` |
| Local build script | `tool/build_windows.ps1` |
| Version parsing | `lib/update/app_version.dart` |
| Reading `latest.json` | `lib/update/release_info.dart` |
| Download, hash check, backup, silent install | `lib/update/update_platform_io.dart` |
| "Is it safe to install now?" checks | `lib/update/update_checks.dart` |
| 30-minute timer, store wiring | `lib/state/cafe_store_update.dart` |
| Update card on the sign-in screen | `lib/widgets/update_panel.dart` |
| Server side (min version, upload check) | `supabase/migrations/20261011100000_app_updates.sql` |
| Arabic release guide | `docs/RELEASING.md` |

---

## Step 1 — Build the Windows app locally

Prerequisites: Flutter on PATH, Visual Studio "Desktop development with C++", and a `.env`
file with `SUPABASE_URL` and `SUPABASE_ANON_KEY` (copy `.env.example`).

```powershell
.\tool\build_windows.ps1
```

It runs:

```powershell
flutter pub get
flutter build windows --release --dart-define-from-file=.env
```

Output: `build\windows\x64\runner\Release\` (the exe `menu_web_v1.exe` plus its DLLs and `data\`).
That whole folder is what the installer packs.

**Rule injected here:** never change `CompanyName` / `ProductName` in
`windows/runner/Runner.rc`. Windows stores the app's data in a folder named after them
(`%APPDATA%\com.example\menu_web_v1`); renaming them makes a new version look in an empty folder
and lose offline sales. A test guards this.

## Step 2 — Install Inno Setup

On your own PC: download Inno Setup 6 from jrsoftware.org, or:

```powershell
choco install innosetup -y
```

The compiler is `C:\Program Files (x86)\Inno Setup 6\ISCC.exe`.

## Step 3 — Write the installer script (`windows/installer/cafe_pos.iss`)

### 3a. Values passed in from the command line

```iss
#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#ifndef SourceDir
  #define SourceDir "..\..\build\windows\x64\runner\Release"
#endif
#ifndef SupabaseUrl
  #define SupabaseUrl "https://<project>.supabase.co"
#endif
#ifndef SupabaseKey
  #define SupabaseKey "<publishable key>"
#endif
```

`ISCC.exe /DAppVersion=2.6.0 ...` overrides them. The publishable key is public (every web page
carries it), so it is fine in the script.

### 3b. `[Setup]` — the decisions that make silent self-update possible

| Setting | Why |
|---|---|
| `AppId={{6B0F3B5E-...}` | Fixed forever. Change it and Windows treats it as a different app (two installs). |
| `PrivilegesRequired=lowest` | Per-user install, **no admin prompt**, so the app can update itself without a UAC dialog. |
| `DefaultDirName={localappdata}\Programs\CafePOS` | A per-user folder the user can write to. |
| `DisableDirPage=yes`, `DisableProgramGroupPage=yes` | No folder questions; every till is the same. |
| `CloseApplications=force`, `RestartApplications=no` | Setup closes the running app; `[Run]` restarts it instead. |
| `OutputBaseFilename=CafePOS-setup-{#AppVersion}` | The workflow and `latest.json` rely on this exact name. |
| `ArchitecturesAllowed=x64compatible` + `ArchitecturesInstallIn64BitMode=x64compatible` | Flutter builds x64 only. |
| `SetupIconFile=..\runner\resources\app_icon.ico` | Same icon as the app. |

### 3c. Files, shortcuts, restart

```iss
[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Cafe POS"; Filename: "{app}\menu_web_v1.exe"
Name: "{userdesktop}\Cafe POS"; Filename: "{app}\menu_web_v1.exe"

[Run]
Filename: "{app}\menu_web_v1.exe"; Flags: nowait

[UninstallDelete]
Type: files; Name: "{app}\features.json"
Type: files; Name: "{app}\admin_reset.json"
```

`[Run]` without `postinstall` runs even in silent mode, which is what reopens the app after an
auto-update.

**Rule injected here:** customer data never lives in `{app}`. The installer and uninstaller never
touch `%APPDATA%\com.example\menu_web_v1`.

### 3d. `[Code]` — the custom wizard pages (Pascal script)

Page order:

1. **Update** (only when already installed): "Update and keep settings" or "Change settings".
   "Installed" = the exe is in the folder **or** the uninstall registry key
   `...\Uninstall\{AppId}_is1` exists in HKCU or HKLM.
2. **Password** — sent to the server, not checked locally:
   `POST <SupabaseUrl>/rest/v1/rpc/check_dev_access` with `{"p_password": "..."}` through
   `WinHttp.WinHttpRequest.5.1`. Answer `true` = allowed. 5 wrong tries lock it for 15 minutes
   (server side). `ServerOrigin()` strips any path so `.../rest/v1` in a secret still works.
3. **Online / Offline**.
4. **Cafe slot** (online only) — names loaded from `rpc/restaurant_for_slot`; no default, because
   a wrong slot shows another cafe's data.
5. **Admin reset** (offline only) — asks the Edge Function `functions/v1/admin-reset-ticket` for a
   server-signed one-time ticket (valid 24 h) and saves it as `{app}\admin_reset.json`. Setup
   holds no signing key.
6. **Features** — checkboxes. Keys must match `AppFeature.key` in
   `lib/features/app_feature.dart`; `WorksOffline` and `RequiredKey` must match the Dart side.

`CurStepChanged(ssPostInstall)` writes `{app}\features.json`, e.g.
`{"mode": "online", "features": [...], "listed": [...], "slot": 3}`.
It does **nothing** when `WizardSilent` (auto-update) or "keep settings" was chosen, so updates
never change a till's setup.

### 3e. Compile it locally

```powershell
& "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe" /DAppVersion=2.6.0 windows\installer\cafe_pos.iss
```

Output: `build\installer\CafePOS-setup-2.6.0.exe`.

## Step 4 — GitHub Actions

### 4a. One-time repo setup

GitHub → Settings → Secrets and variables → Actions:

- `SUPABASE_DB_URL` — Supabase → Connect → Session pooler (used by the DB tests in `checks.yml`).
- Optional `SUPABASE_URL`, `SUPABASE_ANON_KEY` — if missing, the workflow falls back to the
  public values.

Workflow permission `contents: write` is set inside the workflow so it can create releases.

### 4b. `checks.yml` (reusable)

Called with `uses: ./.github/workflows/checks.yml` and `flutter: true, database: true`.
Runs `flutter analyze`, `flutter test` and the SQL tests. No release is built if it fails.

### 4c. `windows-release.yml` — the real release

Triggers: a pushed tag `v*.*.*`, or **Run workflow** in the Actions tab.

Steps, in order:

1. **Read the version** from `pubspec.yaml` (`version: 2.6.0+35` → `2.6.0`).
   - On a tag: fails if the tag ≠ pubspec version.
   - By hand: fails if tag `v<version>` already exists.
   - A version with a label (`2.6.0-beta.1`) sets `PRERELEASE=true`.
2. **Install Flutter** `subosito/flutter-action@v2`, pinned `flutter-version: 3.47.6`.
3. **Write `.env`** from secrets (or the public fallback).
4. `flutter pub get` then `flutter build windows --release --dart-define-from-file=.env`.
5. **Build the installer**: install Inno Setup with `choco install innosetup` if missing, read the
   `.env`, then:
   ```powershell
   & $iscc "/DAppVersion=$env:VERSION" "/DSupabaseUrl=$origin" "/DSupabaseKey=..." windows\installer\cafe_pos.iss
   ```
6. **Write `latest.json`** next to the installer:
   ```json
   { "version": "2.6.0",
     "url": "https://github.com/RiyadAlshaafi/web-menu/releases/download/v2.6.0/CafePOS-setup-2.6.0.exe",
     "sha256": "<lowercase SHA-256 of the exe>",
     "notes": "" }
   ```
   (`Get-FileHash -Algorithm SHA256`, saved as UTF-8 **without BOM** so Dart parses it.)
7. **Publish** with `softprops/action-gh-release@v2`: uploads the exe + `latest.json`, creates the
   tag on the built commit when run by hand. Pre-releases get `make_latest: false`.

**Key trick:** the app reads
`https://github.com/RiyadAlshaafi/web-menu/releases/latest/download/latest.json`.
GitHub's `/releases/latest/` only points at non-pre-releases, so a beta never auto-updates tills;
you install a beta by hand.

### 4d. `windows-build.yml` — side channel

On every push to `main`: same checks and build, zips the Release folder and uploads it to a fixed
release `windows-latest-build` (`make_latest: false`). For manual testing only; tills don't read it.

## Step 5 — Automatic updates inside the app

### 5a. Know the current version

`PackageInfo.fromPlatform().version` (package `package_info_plus`) — Flutter writes the
`pubspec.yaml` version into the exe. `AppVersion.tryParse` handles `v1.2.3`, `1.2.3+7` and
`1.2.3-beta.1` (a label = pre-release = older than the same number without one).

### 5b. Check every 30 minutes

`lib/state/cafe_store_update.dart`: checks at start and on
`Timer.periodic(Duration(minutes: 30))`. It fetches `latest.json`; `ReleaseInfo.tryParse` rejects
anything odd (bad version, non-https URL, hash not 64 hex chars), so a broken file can never start
an install.

### 5c. Download and verify

`downloadVerified()` streams the exe to `%TEMP%\CafePOS-setup-<version>.exe` while hashing it.
If the SHA-256 differs from `latest.json`, the file is deleted and never run.

### 5d. Only install when no sales can be lost

The "Update ready" card shows **only on the cashier sign-in screen**. On "Install now", it is
blocked (`UpdateBlock`) when:

- a cashier is signed in;
- the server can't be reached;
- offline sales/expenses are still waiting to upload, or were refused;
- the server doesn't have every receipt and expense this till uploaded (last 60 days) — checked by
  `rpc/confirm_uploads`, same count **and** same total to the cent.

### 5e. Back up, install silently, restart

1. `backupAppData()` copies the app-data folder to `...\backups\<timestamp>` (keeps the newest 3),
   with a consistent copy of the offline outbox.
2. Writes a marker `update_check.json`.
3. Starts the installer detached and quits:
   ```
   CafePOS-setup-x.y.z.exe /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /CLOSEAPPLICATIONS
   ```
4. Setup replaces the files (no pages, `features.json` untouched) and `[Run]` reopens the app.
5. On the first start after the update, the marker makes the app compare sales with the server
   again and show the result.

### 5f. Server side (`20261011100000_app_updates.sql`)

- `app_release.min_app_version` + `app_release_info()` — a till older than this must update
  before a cashier can sign in. Set it from the developer screen ("Minimum version").
- `cashier_heartbeat_v2(p_app_version)` — each till reports its version; the developer screen
  ("Tills and app versions") lists them.
- `confirm_uploads(p_ids uuid[])` — the pre-update check from 5d.
- Every migration has a test in `supabase/tests` and a rollback in `supabase/rollbacks`.

## Step 6 — Releasing a new version (day to day)

1. If there's a DB change: run `tool/test_db.sh`, apply the migration to Supabase **first**,
   check old tills still sell. Add first, remove only after every till updated.
2. Raise `version:` in `pubspec.yaml` (e.g. `2.7.0+36`).
3. Commit to `main`.
4. Release:
   ```bash
   git tag v2.7.0
   ```
   ```bash
   git push origin v2.7.0
   ```
   or Actions → **Windows release** → **Run workflow**.
5. Within 30 minutes every till shows the update card.

## Step 7 — First install on a new till

Download `CafePOS-setup-<version>.exe` from the GitHub Releases page once, run it, enter the
setup password (needs internet for that check only), choose online/offline, slot and features.
After that, updates arrive by themselves.

## If something goes wrong

- **Bad app version:** release a higher number with the fix (or the old code). The DB still fits
  it because of "add first, remove later".
- **Bad DB change:** run the matching file in `supabase/rollbacks`.
- **Till data:** close the app, copy a folder from `%APPDATA%\com.example\menu_web_v1\backups`
  back into `%APPDATA%\com.example\menu_web_v1`.
