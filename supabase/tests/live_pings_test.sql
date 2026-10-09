-- Checks 20261013100000_live_update_pings.sql: every change a cashier or guest must see sends a
-- broadcast ping (no row data) to the cafe's topic and, for table rows, to that table's guest
-- topic; one ping per topic per transaction; a failed ping never blocks the change.
-- Run by tool/test_db.sh against the realtime.send stand-in in supabase_stubs.sql.
-- Everything is rolled back; any failed check aborts with its message.

begin;

do $test$
declare
  rid uuid;
  tid uuid;
  other_tid uuid;
  oid uuid;
  cat uuid;
  item uuid;
  n integer;
  p jsonb;
begin
  insert into public.restaurants (name) values ('ping cafe') returning id into rid;
  insert into public.dining_tables (restaurant_id, number, qr_slug) values (rid, '7', 'ping-slug-7') returning id into tid;
  insert into public.dining_tables (restaurant_id, number, qr_slug) values (rid, '8', 'ping-slug-8') returning id into other_tid;
  insert into public.menu_categories (restaurant_id, name_en, name_ar) values (rid, 'C', 'C') returning id into cat;
  insert into public.menu_items (restaurant_id, category_id, name_en, price) values (rid, cat, 'Tea', 5) returning id into item;
  delete from realtime.sent_for_tests;
  -- Each test step below is its own "transaction" for the per-transaction de-duplication.
  perform set_config('app.live_pinged', '', true);

  -- A guest order with two lines: one ping to the cafe, one to that table's guest topic.
  insert into public.orders (restaurant_id, table_id, status) values (rid, tid, 'received') returning id into oid;
  insert into public.order_lines (order_id, restaurant_id, menu_item_id, name, qty, unit_price)
  values (oid, rid, item, 'Tea', 1, 5), (oid, rid, item, 'Tea', 2, 5);

  select count(*) into n from realtime.sent_for_tests where topic = 'cafe:' || rid;
  assert n = 1, 'one cafe ping per transaction, got ' || n;
  select count(*) into n from realtime.sent_for_tests where topic = 'guest:ping-slug-7';
  assert n = 1, 'one guest ping for that table per transaction, got ' || n;
  select count(*) into n from realtime.sent_for_tests where topic = 'guest:ping-slug-8';
  assert n = 0, 'another table''s guest never hears about this order';

  select payload into p from realtime.sent_for_tests where topic = 'guest:ping-slug-7';
  assert p = '{"table": "orders"}'::jsonb, 'a ping carries no row data: ' || p::text;
  assert (select bool_and(not private and event = 'change') from realtime.sent_for_tests),
    'pings go out as public "change" broadcasts';

  -- The cashier changes the status in a new transaction: the guest is pinged again.
  delete from realtime.sent_for_tests;
  perform set_config('app.live_pinged', '', true);
  update public.orders set status = 'preparing' where id = oid;
  select count(*) into n from realtime.sent_for_tests where topic = 'guest:ping-slug-7';
  assert n = 1, 'a status change pings the guest, got ' || n;
  select count(*) into n from realtime.sent_for_tests where topic = 'cafe:' || rid;
  assert n = 1, 'a status change pings the cafe, got ' || n;

  -- A staff call reaches the cafe and the calling table.
  delete from realtime.sent_for_tests;
  perform set_config('app.live_pinged', '', true);
  insert into public.staff_calls (restaurant_id, table_id) values (rid, tid);
  select count(*) into n from realtime.sent_for_tests where topic in ('cafe:' || rid, 'guest:ping-slug-7');
  assert n = 2, 'a staff call pings the cafe and the table, got ' || n;

  -- Takeout has no table: only the cafe is pinged.
  delete from realtime.sent_for_tests;
  perform set_config('app.live_pinged', '', true);
  insert into public.orders (restaurant_id, table_id, status, service_type) values (rid, null, 'served', 'takeout');
  select count(*) into n from realtime.sent_for_tests;
  assert n = 1 and exists (select 1 from realtime.sent_for_tests where topic = 'cafe:' || rid), 'takeout pings only the cafe';

  -- A broken broadcast never blocks a sale.
  alter function realtime.send(jsonb, text, text, boolean) rename to send_ok;
  create function realtime.send(payload jsonb, event text, topic text, private boolean)
  returns void language plpgsql as $f$ begin raise exception 'realtime down'; end $f$;
  perform set_config('app.live_pinged', '', true);
  insert into public.orders (restaurant_id, table_id, status) values (rid, other_tid, 'received');
  select count(*) into n from public.orders where table_id = other_tid;
  assert n = 1, 'the order is saved even when the ping fails';

  raise notice 'live_pings_test: all checks passed';
end $test$;

rollback;
