#!/usr/bin/env bash
# Moves cafe months older than the last two from the database to R2 (see
# supabase/migrations/20261019150000_monthly_archive.sql). For each due month: export it, gzip it,
# upload it, download it again and compare, and only then let the database delete those rows.
# A month that changed in between is left for the next run and its upload is removed.
#
# Needs psql, jq, gzip, sha256sum and the aws CLI. Environment:
#   DB_URL                 Postgres connection string (the Supabase session pooler URL)
#   S3_ENDPOINT            https://<account id>.r2.cloudflarestorage.com
#   ARCHIVE_BUCKET         R2 bucket name
#   AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY   an R2 API token with write access to that bucket
#   DRY_RUN=1              upload and check, but delete nothing
set -euo pipefail

: "${DB_URL:?}" "${S3_ENDPOINT:?}" "${ARCHIVE_BUCKET:?}"
export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-auto}"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# Statements come on stdin so psql fills in :'variables' (it doesn't for -c).
sql() { psql "$DB_URL" -X -At -q -v ON_ERROR_STOP=1 "$@"; }
s3() { aws --endpoint-url "$S3_ENDPOINT" "$@" < /dev/null; }

archived=0
skipped=0
while read -r rid month; do
  [ -n "$rid" ] || continue
  sql -v rid="$rid" -v month="$month" <<< "select public.archive_month_export(:'rid', :'month')" > "$work/export.json"
  if [ "$(jq -r .ok "$work/export.json")" != "true" ]; then
    echo "skip $rid $month: $(jq -r .error "$work/export.json")"
    skipped=$((skipped + 1))
    continue
  fi
  digest="$(jq -r .digest "$work/export.json")"
  payments="$(jq -r .payments "$work/export.json")"
  jq -c .data "$work/export.json" | gzip -9n > "$work/month.json.gz"
  sha="$(sha256sum "$work/month.json.gz" | cut -d' ' -f1)"
  bytes="$(stat -c %s "$work/month.json.gz")"
  key="archive/$rid/$month/$(date -u +%Y%m%dT%H%M%SZ).json.gz"

  s3 s3 cp --only-show-errors --content-type application/gzip \
    "$work/month.json.gz" "s3://$ARCHIVE_BUCKET/$key"
  s3 s3 cp --only-show-errors "s3://$ARCHIVE_BUCKET/$key" "$work/check.json.gz"
  if [ "$(sha256sum "$work/check.json.gz" | cut -d' ' -f1)" != "$sha" ]; then
    echo "::error::$key did not read back the same; nothing deleted" >&2
    exit 1
  fi

  if [ "${DRY_RUN:-}" = "1" ]; then
    echo "dry run: $key ($payments sales, $bytes bytes) uploaded, nothing deleted"
    continue
  fi
  result="$(sql -v rid="$rid" -v month="$month" -v digest="$digest" -v key="$key" -v bytes="$bytes" -v sha="$sha" \
    <<< "select public.archive_month_delete(:'rid', :'month', :'digest', :'key', :'bytes'::bigint, :'sha')")"
  if [ "$(jq -r .ok <<< "$result")" != "true" ]; then
    echo "skip $rid $month: $(jq -r .error <<< "$result"); upload removed, retried next run"
    s3 s3 rm --only-show-errors "s3://$ARCHIVE_BUCKET/$key"
    skipped=$((skipped + 1))
    continue
  fi
  echo "archived $key: $result"
  archived=$((archived + 1))
done < <(sql -F ' ' <<< "select restaurant_id, year_month from public.archive_due_months()")

echo "done: $archived archived, $skipped left for the next run"
