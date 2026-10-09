#!/usr/bin/env bash
# Rebuilds the database from supabase/migrations on a plain local Postgres and
# runs the checks in supabase/tests. Nothing touches a Supabase project.
#
# Needs a running Postgres (14+) reachable with psql as a superuser; set
# PGHOST / PGPORT / PGUSER as usual. Creates and drops the database
# $TEST_DB (default cafe_test).
#
#   PGHOST=/tmp PGPORT=5432 PGUSER=postgres tool/test_db.sh
set -euo pipefail

cd "$(dirname "$0")/.."
DB="${TEST_DB:-cafe_test}"
PART2=supabase/migrations/20261008110000_lock_down_direct_writes.sql
PART1=supabase/migrations/20261008100000_security_and_money_fixes.sql

quiet() { PGOPTIONS='-c client_min_messages=error' psql -X -q -o /dev/null -v ON_ERROR_STOP=1 "$@"; }
loud() { psql -X -q -v ON_ERROR_STOP=1 "$@"; }

# Builds $DB from every migration except the ones passed as arguments.
build() {
  quiet -d postgres -c "drop database if exists $DB" -c "create database $DB"
  quiet -d "$DB" -f supabase/tests/supabase_stubs.sql
  for file in supabase/migrations/*.sql; do
    case " $* " in *" $file "*) continue ;; esac
    quiet -d "$DB" -f "$file"
  done
  quiet -d "$DB" -f supabase/tests/seed.sql
  # Part 1 again: it must be safe to apply twice.
  quiet -d "$DB" -f "$PART1"
}

echo "== Part 1 only: the previous app build must keep working"
build "$PART2"
loud -d "$DB" -f supabase/tests/old_app_compat_test.sql

echo "== Parts 1 and 2: the new rules"
build
loud -d "$DB" -f supabase/tests/security_and_money_fixes_test.sql
loud -d "$DB" -f supabase/tests/takeout_and_numbers_test.sql
loud -d "$DB" -f supabase/tests/app_updates_test.sql
loud -d "$DB" -f supabase/tests/live_pings_test.sql
loud -d "$DB" -f supabase/tests/audit_fixes_test.sql

echo "== Rollbacks undo their migration, and the migration applies again afterwards"
for down in supabase/rollbacks/*.down.sql; do
  up="supabase/migrations/$(basename "$down" .down.sql).sql"
  quiet -d "$DB" -f "$down"
  quiet -d "$DB" -f "$up"
done
loud -d "$DB" -f supabase/tests/app_updates_test.sql
loud -d "$DB" -f supabase/tests/audit_fixes_test.sql

quiet -d postgres -c "drop database if exists $DB"
echo "== All database checks passed"
