-- Checks 20261010100000_takeout_without_table.sql as a signed-in cashier device: quick takeout
-- needs no "takeout" table, receipt numbers are reserved only when asked for, clearing logs
-- never reissues reserved numbers, and an offline sale without a daily number keeps none.
-- Run by tool/test_db.sh. Everything is rolled back; any failed check aborts with its message.

begin;

do $test$
declare
  r jsonb;
  rid uuid;
  cat uuid;
  ia uuid;
  cid uuid;
  sid uuid;
  oid uuid;
  n integer;
  t text;
  yymm text := to_char(now() at time zone 'Africa/Tripoli', 'YYMM');
  today text := to_char(now() at time zone 'Africa/Tripoli', 'YYMMDD');
begin
  insert into public.restaurants (name) values ('takeout cafe') returning id into rid;
  insert into public.menu_categories (restaurant_id, name_en, name_ar) values (rid, 'C', 'C') returning id into cat;
  insert into public.menu_items (restaurant_id, category_id, name_en, price) values (rid, cat, 'Tea', 5) returning id into ia;
  insert into public.cashiers (restaurant_id, name, initials, pin_hash) values (rid, 'Z', 'Z', 'x') returning id into cid;
  insert into public.cashier_sessions (cashier_id, restaurant_id, token_hash, expires_at)
  values (cid, rid, encode(extensions.digest('takeout-token', 'sha256'), 'hex'), now() + interval '1 hour');
  perform set_config('request.headers', json_build_object('x-cashier-token', 'takeout-token')::text, true);

  -- ------------------------------------------------ quick takeout, no table in this cafe
  execute 'set local role anon';
  r := public.quick_takeout_receipt(jsonb_build_array(jsonb_build_object('menu_item_id', ia, 'qty', 2)), null);
  execute 'reset role';
  assert (r->>'ok')::boolean, 'quick takeout must work without a takeout table: ' || r::text;
  oid := (r->>'order_id')::uuid;
  select count(*) into n from public.orders where id = oid and table_id is null and service_type = 'takeout' and status = 'paid';
  assert n = 1, 'the takeout order must have no table and be paid';
  select count(*) into n from public.payments where order_id = oid and table_id is null and is_takeout and table_number = '';
  assert n = 1, 'the takeout receipt must be marked takeout with no table';

  -- Two takeouts in a row never clash (no shared table any more).
  execute 'set local role anon';
  r := public.quick_takeout_receipt(jsonb_build_array(jsonb_build_object('menu_item_id', ia, 'qty', 1)), null);
  execute 'reset role';
  assert (r->>'ok')::boolean, 'a second takeout must work: ' || r::text;

  -- ------------------------------------------------ reserve only what is short
  execute 'set local role anon';
  r := public.reserve_receipt_numbers(0, 10);
  execute 'reset role';
  assert (r->>'ok')::boolean, 'a day-only reservation must work: ' || r::text;
  assert r->'first' = 'null'::jsonb and r->>'day_key' = today, 'a day-only block takes no monthly numbers: ' || r::text;
  assert (r->>'day_last')::integer - (r->>'day_first')::integer = 9, 'ten day numbers: ' || r::text;

  execute 'set local role anon';
  r := public.reserve_receipt_numbers(50, 0);
  execute 'reset role';
  assert (r->>'ok')::boolean and r->'day_key' = 'null'::jsonb, 'a month-only block takes no day numbers: ' || r::text;
  assert (r->>'last')::integer - (r->>'first')::integer = 49, 'fifty monthly numbers: ' || r::text;

  execute 'set local role anon';
  r := public.reserve_receipt_numbers(0, 0);
  execute 'reset role';
  assert not (r->>'ok')::boolean, 'reserving nothing must be refused';

  -- ------------------------------------------------ offline sale with no daily number keeps none
  sid := gen_random_uuid();
  select max(last_no) into n from public.receipt_blocks where restaurant_id = rid;
  execute 'set local role anon';
  r := public.sync_offline_takeout(
    gen_random_uuid(), cid, sid,
    jsonb_build_array(jsonb_build_object('menu_item_id', ia::text, 'name', 'Tea', 'qty', 1, 'unit_price', 5)),
    null, now(), yymm, n, today, null);
  execute 'reset role';
  assert (r->>'ok')::boolean, 'an offline takeout must upload without a table: ' || r::text;
  select shift_display_number into t from public.payments where order_id = (r->>'order_id')::uuid;
  assert t is null, 'no daily number must stay no daily number, got ' || coalesce(t, 'null');
  select count(*) into n from public.orders where id = (r->>'order_id')::uuid and table_id is null;
  assert n = 1, 'the offline takeout order must have no table';

  -- ------------------------------------------------ clearing logs continues after held numbers
  execute 'set local role anon';
  r := public.clear_test_logs('shift');
  execute 'reset role';
  assert (r->>'ok')::boolean, 'clearing logs must work: ' || r::text;
  select last_value into n from public.order_number_counters where restaurant_id = rid and scope = 'month:' || yymm;
  assert n = (select max(last_no) from public.receipt_blocks where restaurant_id = rid and year_month = yymm),
    'the month counter must continue after reserved numbers, got ' || coalesce(n::text, 'null');
  select last_value into n from public.order_number_counters where restaurant_id = rid and scope = 'day:' || today;
  assert n = (select max(day_last) from public.receipt_blocks where restaurant_id = rid and day_key = today),
    'the day counter must continue after reserved numbers, got ' || coalesce(n::text, 'null');

  raise notice 'takeout_and_numbers_test: all checks passed';
end $test$;

rollback;
