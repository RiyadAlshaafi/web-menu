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
# Removes guest direct table access; the "previous app build" below predates it.
GUEST_LOCK=supabase/migrations/20261014110000_guest_lock_down.sql
CLOSE_SHIFT=supabase/migrations/20261015100000_close_shift_needs_paid_orders.sql
DISH_CHOICES=supabase/migrations/20261018100000_dish_choices.sql

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
  # Re-applying part 1 also restores its older close_shift; put the current one back.
  quiet -d "$DB" -f "$CLOSE_SHIFT"
  # It also restores the older send_table_cart; put the one with dish choices back.
  quiet -d "$DB" -f "$DISH_CHOICES"
  # That re-run in turn undoes later migrations; apply those again so the newest definitions win.
  for file in supabase/migrations/*.sql; do
    [[ "$file" > "$DISH_CHOICES" ]] || continue
    case " $* " in *" $file "*) continue ;; esac
    quiet -d "$DB" -f "$file"
  done
}

echo "== Part 1 only: the previous app build must keep working"
build "$PART2" "$GUEST_LOCK"
loud -d "$DB" -f supabase/tests/old_app_compat_test.sql

echo "== Parts 1 and 2: the new rules"
build
loud -d "$DB" -f supabase/tests/security_and_money_fixes_test.sql
loud -d "$DB" -f supabase/tests/takeout_and_numbers_test.sql
loud -d "$DB" -f supabase/tests/app_updates_test.sql
loud -d "$DB" -f supabase/tests/live_pings_test.sql
loud -d "$DB" -f supabase/tests/audit_fixes_test.sql
loud -d "$DB" -f supabase/tests/guest_web_test.sql
loud -d "$DB" -f supabase/tests/guest_lock_down_test.sql
loud -d "$DB" -f supabase/tests/close_shift_unpaid_test.sql
loud -d "$DB" -f supabase/tests/dish_choices_test.sql
loud -d "$DB" -f supabase/tests/void_payment_test.sql
loud -d "$DB" -f supabase/tests/same_cafe_links_test.sql
loud -d "$DB" -f supabase/tests/offline_trust_test.sql
loud -d "$DB" -f supabase/tests/pin_rate_and_table_test.sql
loud -d "$DB" -f supabase/tests/dish_stock_test.sql
loud -d "$DB" -f supabase/tests/vendor_fleet_test.sql
loud -d "$DB" -f supabase/tests/slot_suspension_test.sql
loud -d "$DB" -f supabase/tests/vendor_export_logs_test.sql
loud -d "$DB" -f supabase/tests/vendor_db_health_test.sql
loud -d "$DB" -f supabase/tests/guest_visitors_test.sql
loud -d "$DB" -f supabase/tests/table_claims_test.sql
loud -d "$DB" -f supabase/tests/feedback_test.sql
loud -d "$DB" -f supabase/tests/dev_import_test.sql
loud -d "$DB" -f supabase/tests/kitchens_test.sql
loud -d "$DB" -f supabase/tests/expense_employee_test.sql
loud -d "$DB" -f supabase/tests/guest_menu_url_dev_only_test.sql
loud -d "$DB" -f supabase/tests/receipt_settings_test.sql

echo "== Rollbacks undo their migration, and the migration applies again afterwards"
for down in supabase/rollbacks/*.down.sql; do
  up="supabase/migrations/$(basename "$down" .down.sql).sql"
  quiet -d "$DB" -f "$down"
  quiet -d "$DB" -f "$up"
done
loud -d "$DB" -f supabase/tests/app_updates_test.sql
loud -d "$DB" -f supabase/tests/audit_fixes_test.sql
loud -d "$DB" -f supabase/tests/guest_web_test.sql
loud -d "$DB" -f supabase/tests/guest_lock_down_test.sql
loud -d "$DB" -f supabase/tests/close_shift_unpaid_test.sql
loud -d "$DB" -f supabase/tests/dish_choices_test.sql
loud -d "$DB" -f supabase/tests/void_payment_test.sql
loud -d "$DB" -f supabase/tests/same_cafe_links_test.sql
loud -d "$DB" -f supabase/tests/offline_trust_test.sql
loud -d "$DB" -f supabase/tests/pin_rate_and_table_test.sql
loud -d "$DB" -f supabase/tests/table_claims_test.sql
loud -d "$DB" -f supabase/tests/kitchens_test.sql
loud -d "$DB" -f supabase/tests/expense_employee_test.sql
loud -d "$DB" -f supabase/tests/guest_menu_url_dev_only_test.sql
loud -d "$DB" -f supabase/tests/receipt_settings_test.sql

quiet -d postgres -c "drop database if exists $DB"
echo "== All database checks passed"
