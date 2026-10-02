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

if ! command -v flutter >/dev/null 2>&1; then
  git clone https://github.com/flutter/flutter.git -b stable --depth 1 "$HOME/flutter"
  export PATH="$HOME/flutter/bin:$PATH"
fi
flutter config --enable-web
flutter pub get
flutter build web --release --wasm \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"
