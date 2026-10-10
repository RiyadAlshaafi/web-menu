-- Checks 20261012100000_audit_fixes.sql: no cafe-less admin or cashier answers, a per-cafe menu
-- address, no default service charge, and numbering several open orders in one call.
-- Run by tool/test_db.sh. Everything is rolled back; any failed check aborts with its message.

begin;

do $test$
declare
  r jsonb;
  rid uuid := (select id from public.restaurants where slot = 2);
  cid uuid;
  o1 uuid;
  o2 uuid;
begin
  -- ---------------------------------------------------------------- B-11 / B-15
  assert not public.has_any_admin(null), 'without a cafe there is never an admin';
  assert not exists (select 1 from public.list_pos_cashiers(null)),
    'without a cafe no cashier names are listed';

  -- ---------------------------------------------------------------- B-08 / B-12
  assert exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'restaurants' and column_name = 'public_menu_url'
  ), 'restaurants must have public_menu_url';
  assert (
    select column_default from information_schema.columns
    where table_schema = 'public' and table_name = 'restaurants' and column_name = 'service_charge_rate'
  ) like '0%' and (
    select column_default from information_schema.columns
    where table_schema = 'public' and table_name = 'restaurants' and column_name = 'service_charge_rate'
  ) not like '0.1%', 'new cafes must start without a service charge';

  -- ---------------------------------------------------------------- B-13
  insert into public.cashiers (restaurant_id, name, initials, pin_hash) values (rid, 'Batch', 'B', 'x') returning id into cid;
  insert into public.cashier_sessions (cashier_id, restaurant_id, token_hash, expires_at)
  values (cid, rid, encode(extensions.digest('batch-token', 'sha256'), 'hex'), now() + interval '1 hour');
  insert into public.orders (restaurant_id, table_id, status, service_type) values (rid, null, 'served', 'takeout') returning id into o1;
  insert into public.orders (restaurant_id, table_id, status, service_type) values (rid, null, 'served', 'takeout') returning id into o2;

  perform set_config('request.headers', json_build_object('x-cashier-token', 'batch-token')::text, true);
  execute 'set local role anon';
  r := public.assign_shift_order_numbers(array[o1, o2, gen_random_uuid()]);
  execute 'reset role';
  assert (r->>'ok')::boolean, 'numbering in one call must work: ' || r::text;
  assert (r->>'numbered')::int = 2, 'both open orders are numbered, the unknown one skipped: ' || r::text;
  assert (select count(*) from public.orders where id in (o1, o2) and shift_order_number is not null) = 2,
    'both orders must carry a number';
  assert (select shift_order_number from public.orders where id = o1)
      <> (select shift_order_number from public.orders where id = o2), 'numbers must differ';

  perform set_config('request.headers', json_build_object('x-cashier-token', 'wrong')::text, true);
  execute 'set local role anon';
  r := public.assign_shift_order_numbers(array[o1]);
  execute 'reset role';
  -- Without a valid cashier session nothing is answered, not even an order that already has a number.
  assert not (r->>'ok')::boolean and r->>'error' = 'sign in as a cashier first',
    'a caller without a session is rejected: ' || r::text;
  assert (select shift_order_number from public.orders where id = o1) is not null,
    'the rejected call must not clear the existing number';
end;
$test$;

rollback;
