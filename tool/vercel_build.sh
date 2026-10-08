#!/usr/bin/env bash
set -euo pipefail

SUPABASE_URL="${SUPABASE_URL:-${NEXT_PUBLIC_SUPABASE_URL:-}}"
SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-${SUPABASE_PUBLISHABLE_KEY:-${NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY:-${NEXT_PUBLIC_SUPABASE_ANON_KEY:-}}}}"

SUPABASE_URL="${SUPABASE_URL%/}"
SUPABASE_URL="${SUPABASE_URL%/rest/v1}"
SUPABASE_URL="${SUPABASE_URL%/}"

if [ -z "$SUPABASE_URL" ] || [ -z "$SUPABASE_ANON_KEY" ]; then
  echo "Missing Supabase settings. Add SUPABASE_URL and SUPABASE_ANON_KEY to this Vercel project's Production environment, then redeploy." >&2
  exit 1
fi

# Pinned so a new Flutter release can't change production without a commit.
# Update it on purpose, after testing locally with the same version.
FLUTTER_VERSION="3.47.6"

if ! command -v flutter >/dev/null 2>&1; then
  git clone https://github.com/flutter/flutter.git -b "$FLUTTER_VERSION" --depth 1 "$HOME/flutter"
  export PATH="$HOME/flutter/bin:$PATH"
fi
flutter config --enable-web
flutter pub get
flutter build web --release --wasm \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
  --dart-define=DEFAULT_SLOT="${DEFAULT_SLOT:-1}"

# Stamp the menu cache (web/sw.js): a new build replaces the kept app files; the engine files are
# kept until Flutter itself changes.
BUILD_ID="${VERCEL_GIT_COMMIT_SHA:-$(date +%s)}"
ENGINE_ID="$(grep -o '"engineRevision":"[^"]*"' build/web/flutter_bootstrap.js | cut -d'"' -f4 || true)"
sed -i "s/__BUILD_ID__/${BUILD_ID}/; s/__ENGINE_ID__/${ENGINE_ID:-$BUILD_ID}/" build/web/sw.js
