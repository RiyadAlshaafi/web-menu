#!/usr/bin/env bash
# Local backend for the guest web app: a plain Postgres database built from
# supabase/migrations (as tool/test_db.sh does), the demo cafes, and PostgREST
# serving its RPCs as the anon role, like Supabase's REST API. Nothing touches a
# Supabase project.
#
#   PGHOST=/var/tmp/pgguest PGPORT=5544 PGUSER=postgres POSTGREST=/path/to/postgrest \
#     guest-web/e2e/local-stack.sh            # builds the database, then runs PostgREST on :3001
set -euo pipefail
cd "$(dirname "$0")/../.."
DB="${E2E_DB:-guest_e2e}"
PORT="${POSTGREST_PORT:-3001}"
quiet() { PGOPTIONS='-c client_min_messages=error' psql -X -q -o /dev/null -v ON_ERROR_STOP=1 "$@"; }

quiet -d postgres -c "drop database if exists $DB with (force)" -c "create database $DB"
quiet -d "$DB" -f supabase/tests/supabase_stubs.sql
for file in supabase/migrations/*.sql; do quiet -d "$DB" -f "$file"; done
quiet -d "$DB" -f guest-web/e2e/demo-seed.sql
echo "database $DB ready"

[ "${BUILD_ONLY:-}" = "1" ] && exit 0
export PGRST_DB_URI="postgres://${PGUSER:-postgres}@/${DB}?host=${PGHOST:-/tmp}&port=${PGPORT:-5432}"
export PGRST_DB_SCHEMAS=public
export PGRST_DB_ANON_ROLE=anon
export PGRST_SERVER_PORT="$PORT"
export PGRST_JWT_SECRET="local-only-secret-local-only-secret-1234"
exec "${POSTGREST:-postgrest}"
