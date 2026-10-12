-- Checks 20261015100000_close_shift_needs_paid_orders.sql as a signed-in cashier device: a shift
-- can't close while the cafe has an unpaid order with dishes on it, an emptied order or another
-- cafe's order does not block, and a close made offline still uploads.
-- Run by tool/test_db.sh. Everything is rolled back; any failed check aborts with its message.

begin;

do $test$
declare
  r jsonb;
  rid uuid;
  other uuid;
  cat uuid;
  ia uuid;
  tid uuid;
  cid uuid;
  sid uuid;
  owing uuid;
  n integer;
begin
  insert into public.restaurants (name) values ('shift cafe') returning id into rid;
  insert into public.restaurants (name) values ('other cafe') returning id into other;
  insert into public.menu_categories (restaurant_id, name_en, name_ar) values (rid, 'C', 'C') returning id into cat;
  insert into public.menu_items (restaurant_id, category_id, name_en, price) values (rid, cat, 'Tea', 5) returning id into ia;
  insert into public.dining_tables (restaurant_id, number, qr_slug) values (rid, 'S1', 'shift-slug-1') returning id into tid;
  insert into public.cashiers (restaurant_id, name, initials, pin_hash) values (rid, 'Z', 'Z', 'x') returning id into cid;
  insert into public.cashier_sessions (cashier_id, restaurant_id, token_hash, expires_at)
  values (cid, rid, encode(extensions.digest('shift-token', 'sha256'), 'hex'), now() + interval '1 hour');

  -- A served table that has not paid, an order whose dishes were all removed, and another
  -- cafe's unpaid order.
  insert into public.orders (restaurant_id, table_id, status) values (rid, tid, 'served') returning id into owing;
  insert into public.order_lines (order_id, menu_item_id, name, qty, unit_price) values (owing, ia, 'Tea', 2, 5);
  insert into public.orders (restaurant_id, table_id, status) values (rid, tid, 'received');
  insert into public.orders (restaurant_id, table_id, status, service_type) values (other, null, 'served', 'takeout');

  perform set_config('request.headers', json_build_object('x-cashier-token', 'shift-token')::text, true);
  execute 'set local role anon';
  r := public.open_shift();
  sid := (r->>'shift_id')::uuid;
  assert sid is not null, 'open_shift failed: ' || r::text;

  -- ------------------------------------------------ an unpaid table blocks the close
  r := public.close_shift(40);
  assert not (r->>'ok')::boolean and r->>'error' = 'unpaid orders still open',
    'closing with an unpaid table must be refused: ' || r::text;
  assert (r->>'unpaid_orders')::int = 1,
    'only the order with dishes counts, not the emptied one or the other cafe''s: ' || r::text;
  execute 'reset role';
  select count(*) into n from public.shifts where id = sid and closed_at is null and actual_cash is null;
  assert n = 1, 'the refused close must leave the shift open and untouched';

  -- ------------------------------------------------ once it is paid the shift closes
  update public.orders set status = 'paid' where id = owing;
  execute 'set local role anon';
  r := public.close_shift(40);
  assert (r->>'ok')::boolean and (r->>'shift_id')::uuid = sid, 'close after payment failed: ' || r::text;
  execute 'reset role';

  -- ------------------------------------------------ a close made offline still uploads
  -- The till already closed the shift without a connection; refusing it would wedge the outbox.
  insert into public.orders (restaurant_id, table_id, status) values (rid, tid, 'served') returning id into owing;
  insert into public.order_lines (order_id, menu_item_id, name, qty, unit_price) values (owing, ia, 'Tea', 1, 5);
  execute 'set local role anon';
  r := public.open_shift();
  sid := (r->>'shift_id')::uuid;
  r := public.sync_offline_shift_close(gen_random_uuid(), cid, 12, now());
  assert (r->>'ok')::boolean and (r->>'shift_id')::uuid = sid,
    'an offline close must upload even with an unpaid table: ' || r::text;
  execute 'reset role';
  select count(*) into n from public.shifts where id = sid and closed_at is not null;
  assert n = 1, 'the offline close must close the shift';
end;
$test$;

rollback;
