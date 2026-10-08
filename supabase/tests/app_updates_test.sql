-- Checks 20261011100000_app_updates.sql: a till's heartbeat records its app version, the server
-- confirms exactly the uploads a till names, the minimum version is set only by the developer
-- tools, and the developer screen lists each till's version for the chosen cafe slot.
-- Run by tool/test_db.sh. Everything is rolled back; any failed check aborts with its message.

begin;

do $test$
declare
  r jsonb;
  rid uuid := (select id from public.restaurants where slot = 2);
  cid uuid;
  sid uuid;
  pay_id uuid := gen_random_uuid();
  exp_id uuid := gen_random_uuid();
  cat uuid;
  ord uuid;
begin
  insert into public.cashiers (restaurant_id, name, initials, pin_hash) values (rid, 'Ali', 'A', 'x') returning id into cid;
  insert into public.cashier_sessions (cashier_id, restaurant_id, token_hash, expires_at)
  values (cid, rid, encode(extensions.digest('update-token', 'sha256'), 'hex'), now() + interval '1 hour');

  -- ---------------------------------------------------------------- heartbeat with version
  perform set_config('request.headers', json_build_object('x-cashier-token', 'update-token')::text, true);
  execute 'set local role anon';
  r := public.cashier_heartbeat_v2('1.4.2');
  execute 'reset role';
  assert (r->>'ok')::boolean, 'the heartbeat must work: ' || r::text;
  assert r->>'min_app_version' = '0.0.0', 'no minimum version at first: ' || r::text;
  assert (select app_version from public.cashier_presence where restaurant_id = rid) = '1.4.2',
    'the till version must be recorded';
  assert private.cashier_online(rid), 'a till with the new heartbeat still counts as online';

  -- The old heartbeat (tills on the previous app) keeps working.
  execute 'set local role anon';
  r := public.cashier_heartbeat();
  execute 'reset role';
  assert (r->>'ok')::boolean, 'the old heartbeat must keep working: ' || r::text;

  -- ---------------------------------------------------------------- confirm uploads
  insert into public.shifts (restaurant_id, cashier_id, opening_cash) values (rid, cid, 0) returning id into sid;
  insert into public.orders (restaurant_id, table_id, status, service_type) values (rid, null, 'served', 'takeout') returning id into ord;
  insert into public.payments (restaurant_id, order_id, total_due, cash_received, change_due, cashier_id, shift_id, client_id)
  values (rid, ord, 12.5, 12.5, 0, cid, sid, pay_id);
  insert into public.expense_categories (restaurant_id, name_en, name_ar) values (rid, 'Supplies', 'Supplies') returning id into cat;
  insert into public.shift_expenses (restaurant_id, shift_id, cashier_id, paid_to_cafe, amount, description, kind, expense_category_id, client_id)
  values (rid, sid, cid, true, 4, 'milk', 'cash_out', cat, exp_id);

  execute 'set local role anon';
  r := public.confirm_uploads(array[pay_id, exp_id, gen_random_uuid(), pay_id]);
  execute 'reset role';
  assert (r->>'receipts')::integer = 1 and (r->>'receipts_total')::numeric = 12.5, 'one receipt of 12.5: ' || r::text;
  assert (r->>'expenses')::integer = 1 and (r->>'expenses_total')::numeric = 4, 'one expense of 4: ' || r::text;

  execute 'set local role anon';
  r := public.confirm_uploads(array[]::uuid[]);
  execute 'reset role';
  assert (r->>'receipts')::integer = 0 and (r->>'expenses')::integer = 0, 'nothing named, nothing found: ' || r::text;

  -- ---------------------------------------------------------------- minimum version
  execute 'set local role anon';
  r := public.dev_set_min_app_version('wrong', '9.9.9');
  assert not (r->>'ok')::boolean, 'a wrong dev password must not change the minimum version';
  r := public.dev_set_min_app_version('devpw', 'abc');
  assert not (r->>'ok')::boolean, 'a malformed version must be refused';
  r := public.dev_set_min_app_version('devpw', '1.5.0');
  assert (r->>'ok')::boolean, 'the developer can set the minimum version: ' || r::text;
  r := public.app_release_info();
  assert r->>'min_app_version' = '1.5.0', 'everyone reads the new minimum: ' || r::text;

  -- ---------------------------------------------------------------- developer device list
  perform set_config('request.headers', json_build_object('x-dev-slot', '2')::text, true);
  r := public.dev_list_devices('devpw');
  execute 'reset role';
  assert (r->>'ok')::boolean, 'the device list must load: ' || r::text;
  assert jsonb_array_length(r->'devices') = 1, 'one till in slot 2: ' || r::text;
  assert r->'devices'->0->>'app_version' = '1.4.2' and r->'devices'->0->>'cashier' = 'Ali', 'version and cashier shown: ' || r::text;

  raise notice 'app_updates_test: all checks passed';
end $test$;

rollback;
