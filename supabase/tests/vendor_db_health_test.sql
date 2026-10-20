-- Checks 20261020140000_vendor_db_health.sql: the database health report needs the developer
-- password, describes the database, lists the biggest tables, sums file storage per bucket and
-- counts rows written per day for 14 days, with today last.
-- Run by tool/test_db.sh. Everything is rolled back; any failed check aborts with its message.

begin;

do $test$
declare
  r jsonb;
  rid uuid := (select id from public.restaurants where slot = 2);
  before_orders integer;
begin
  insert into public.dev_access (password_hash)
  values (extensions.crypt('health-pw', extensions.gen_salt('bf', 4)));

  -- ---------------------------------------------------------------- password gate
  execute 'set local role anon';
  r := public.vendor_db_health('wrong');
  execute 'reset role';
  assert not (r->>'ok')::boolean and not r ? 'database', 'a wrong password must get nothing: ' || r::text;

  -- ---------------------------------------------------------------- the report
  execute 'set local role anon';
  r := public.vendor_db_health('health-pw');
  execute 'reset role';
  assert (r->>'ok')::boolean, 'the right password must work: ' || r::text;
  before_orders := (r->'ingestion'->13->>'orders')::integer;

  assert (r->'database'->>'size_bytes')::bigint > 0, 'database size is reported: ' || (r->'database')::text;
  assert (r->'database'->>'connections')::integer >= 1, 'at least this connection is counted';
  assert (r->'database'->>'max_connections')::integer >= (r->'database'->>'connections')::integer,
    'max connections is at least the current count';

  assert jsonb_array_length(r->'tables') between 1 and 12, 'at most 12 tables listed: ' || jsonb_array_length(r->'tables');
  assert (r->'tables'->0->>'total_bytes')::bigint >= (r->'tables'->-1->>'total_bytes')::bigint,
    'tables are biggest first';
  assert r->'tables'->0 ? 'name' and r->'tables'->0 ? 'dead_rows' and r->'tables'->0 ? 'inserts', 'table rows carry the write counters';

  assert jsonb_array_length(r->'ingestion') = 14, 'fourteen days of ingestion: ' || jsonb_array_length(r->'ingestion');
  assert (r->'ingestion'->13->>'day')::date = (now() at time zone 'utc')::date, 'today is the last day';

  -- ---------------------------------------------------------------- sees new data
  insert into public.orders (restaurant_id, table_id, status, service_type) values (rid, null, 'received', 'takeout');
  insert into public.orders (restaurant_id, table_id, status, service_type) values (rid, null, 'received', 'takeout');
  insert into storage.objects (bucket_id, name, metadata) values
    ('health-test', 'a.png', '{"size": 1000}'),
    ('health-test', 'b.png', '{"size": 500}');

  execute 'set local role anon';
  r := public.vendor_db_health('health-pw');
  execute 'reset role';
  assert (r->'ingestion'->13->>'orders')::integer = before_orders + 2, 'today''s new orders are counted: ' || (r->'ingestion'->13)::text;
  assert (select (b->>'bytes')::bigint from jsonb_array_elements(r->'storage'->'buckets') b where b->>'id' = 'health-test') = 1500,
    'bucket bytes are summed: ' || (r->'storage')::text;
  assert (r->'storage'->>'total_bytes')::bigint >= 1500 and (r->'storage'->>'objects')::integer >= 2, 'storage totals include the files';

  -- ---------------------------------------------------------------- nothing per cafe
  assert position(rid::text in r::text) = 0, 'the report never names a cafe';
end
$test$;

rollback;
