-- Checks 20261027150000_guest_bill_needs_payment_type.sql: a guest's bill request is refused
-- until the order is served and, when the cafe offers payment types, an enabled one is picked.
-- A cafe with no payment types needs only a served order; staff asking by table id are unchanged.
-- Run by tool/test_db.sh. Everything is rolled back; any failed check aborts with its message.

begin;

do $test$
declare
  r jsonb;
  rid uuid;
  plain uuid;
  cid uuid;
  sid uuid;
  tid uuid;
  t_plain uuid;
  t_staff uuid;
  oid uuid;
  card uuid;
  off_type uuid;
  n integer;
begin
  insert into public.restaurants (name) values ('bill cafe') returning id into rid;
  insert into public.restaurants (name) values ('bill plain cafe') returning id into plain;
  -- Only the types made here: the cafe with types has one enabled, the plain one none at all.
  delete from public.payment_types where restaurant_id in (rid, plain);
  insert into public.payment_types (restaurant_id, name_en, name_ar) values (rid, 'Card', 'بطاقة') returning id into card;
  insert into public.payment_types (restaurant_id, name_en, name_ar, enabled) values (rid, 'Off', 'x', false) returning id into off_type;
  insert into public.payment_types (restaurant_id, name_en, name_ar, archived) values (plain, 'Old', 'x', true);

  insert into public.dining_tables (restaurant_id, number, qr_slug) values (rid, '1', 'bill-1') returning id into tid;
  insert into public.dining_tables (restaurant_id, number, qr_slug) values (rid, '2', 'bill-2') returning id into t_staff;
  insert into public.dining_tables (restaurant_id, number, qr_slug) values (plain, '1', 'bill-plain') returning id into t_plain;
  insert into public.orders (restaurant_id, table_id, table_number, status) values (rid, tid, '1', 'received') returning id into oid;
  insert into public.orders (restaurant_id, table_id, table_number, status) values (rid, t_staff, '2', 'received');
  insert into public.orders (restaurant_id, table_id, table_number, status) values (plain, t_plain, '1', 'served');

  -- Online cashiers, so guest requests are open in both cafes.
  insert into public.cashiers (restaurant_id, name, initials, pin_hash) values (rid, 'B', 'B', 'x') returning id into cid;
  insert into public.cashier_sessions (cashier_id, restaurant_id, token_hash, expires_at)
    values (cid, rid, encode(extensions.digest('bill-token', 'sha256'), 'hex'), now() + interval '1 hour') returning id into sid;
  insert into public.cashier_presence (session_id, restaurant_id, last_seen) values (sid, rid, now());
  insert into public.cashiers (restaurant_id, name, initials, pin_hash) values (plain, 'P', 'P', 'x') returning id into cid;
  insert into public.cashier_sessions (cashier_id, restaurant_id, token_hash, expires_at)
    values (cid, plain, 'bill-plain-hash', now() + interval '1 hour') returning id into sid;
  insert into public.cashier_presence (session_id, restaurant_id, last_seen) values (sid, plain, now());

  perform set_config('request.headers', '{}', true);
  execute 'set local role anon';

  -- ------------------------------------------------ not served yet
  r := public.request_bill('bill-1');
  assert r = '{"ok": false, "error": "not served"}'::jsonb, 'an unserved order: ' || r::text;

  -- ------------------------------------------------ served, no payment type
  execute 'reset role';
  update public.orders set status = 'served' where id = oid;
  execute 'set local role anon';
  r := public.request_bill('bill-1');
  assert r = '{"ok": false, "error": "payment type required"}'::jsonb, 'no payment type: ' || r::text;

  -- A switched-off type does not count.
  execute 'reset role';
  update public.orders set payment_type_id = off_type where id = oid;
  execute 'set local role anon';
  r := public.request_bill('bill-1');
  assert r->>'error' = 'payment type required', 'a disabled payment type: ' || r::text;

  execute 'reset role';
  select count(*) into n from public.staff_calls where table_id = tid and kind = 'bill';
  assert n = 0, 'refused requests open no bill call, got ' || n;
  assert (select status from public.dining_tables where id = tid) <> 'billRequested', 'refused requests leave the table alone';

  -- ------------------------------------------------ served and paid by card
  update public.orders set payment_type_id = card where id = oid;
  execute 'set local role anon';
  r := public.request_bill('bill-1');
  assert r = '{"ok": true}'::jsonb, 'served with a payment type: ' || r::text;
  execute 'reset role';
  assert (select status from public.dining_tables where id = tid) = 'billRequested', 'the table waits for the bill';
  select count(*) into n from public.staff_calls where table_id = tid and kind = 'bill' and not resolved;
  assert n = 1, 'one bill call, got ' || n;

  -- ------------------------------------------------ a cafe without payment types
  execute 'set local role anon';
  r := public.request_bill('bill-plain');
  assert r = '{"ok": true}'::jsonb, 'no payment types to pick: ' || r::text;

  -- ------------------------------------------------ staff by table id: unchanged
  execute 'reset role';
  perform set_config('request.headers', json_build_object('x-cashier-token', 'bill-token')::text, true);
  execute 'set local role anon';
  r := public.request_bill(null, t_staff);
  assert r = '{"ok": true}'::jsonb, 'staff may ask for an unserved table''s bill: ' || r::text;

  execute 'reset role';
  raise notice 'guest_bill_needs_payment_type_test: all checks passed';
end;
$test$;

rollback;
