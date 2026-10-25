-- Checks 20261027120000_move_table.sql as a signed-in cashier device: a tab moves to a free table
-- as the same order; a tab merges into another tab with its rounds capped so nothing reprints;
-- the cart, open calls and guests follow; the first table is freed and loses its phone; moving to
-- the same table, an empty table or another cafe's table is refused.
-- Run by tool/test_db.sh. Everything is rolled back; any failed check aborts with its message.

begin;

do $test$
declare
  r jsonb;
  rid uuid;
  other uuid;
  cat uuid;
  tea uuid;
  cid uuid;
  t1 uuid;
  t2 uuid;
  t3 uuid;
  t_other uuid;
  o1 uuid;
  o3 uuid;
  n integer;
begin
  insert into public.restaurants (name) values ('move cafe') returning id into rid;
  insert into public.restaurants (name) values ('move other cafe') returning id into other;
  insert into public.menu_categories (restaurant_id, name_en, name_ar) values (rid, 'C', 'C') returning id into cat;
  insert into public.menu_items (restaurant_id, category_id, name_en, price) values (rid, cat, 'Tea', 2) returning id into tea;
  insert into public.cashiers (restaurant_id, name, initials, pin_hash) values (rid, 'V', 'V', 'x') returning id into cid;
  insert into public.cashier_sessions (cashier_id, restaurant_id, token_hash, expires_at)
  values (cid, rid, encode(extensions.digest('move-token', 'sha256'), 'hex'), now() + interval '1 hour');
  insert into public.dining_tables (restaurant_id, number, qr_slug, status, guests) values (rid, '1', 'move-1', 'dining', 2) returning id into t1;
  insert into public.dining_tables (restaurant_id, number, qr_slug) values (rid, '2', 'move-2') returning id into t2;
  insert into public.dining_tables (restaurant_id, number, qr_slug, status, guests) values (rid, '3', 'move-3', 'dining', 3) returning id into t3;
  insert into public.dining_tables (restaurant_id, number, qr_slug) values (other, '9', 'move-9') returning id into t_other;

  -- Table 1: a tab with rounds 1 and 2, a cart dish not sent yet, an open call and a phone.
  insert into public.orders (restaurant_id, table_id, table_number, status) values (rid, t1, '1', 'received') returning id into o1;
  insert into public.order_lines (order_id, restaurant_id, menu_item_id, name, qty, unit_price, round)
  values (o1, rid, tea, 'Tea', 1, 2, 1), (o1, rid, tea, 'Tea', 2, 2, 2);
  insert into public.carts (table_id, restaurant_id) values (t1, rid);
  insert into public.cart_lines (table_id, restaurant_id, menu_item_id, name, qty, unit_price) values (t1, rid, tea, 'Tea', 4, 2);
  insert into public.staff_calls (restaurant_id, table_id) values (rid, t1);
  insert into public.table_claims (table_id, restaurant_id, claimed_by) values (t1, rid, 'phone');
  -- Table 3: a tab with round 1 only.
  insert into public.orders (restaurant_id, table_id, table_number, status) values (rid, t3, '3', 'received') returning id into o3;
  insert into public.order_lines (order_id, restaurant_id, menu_item_id, name, qty, unit_price, round) values (o3, rid, tea, 'Tea', 5, 2, 1);

  perform set_config('request.headers', json_build_object('x-cashier-token', 'move-token')::text, true);
  execute 'set local role anon';

  -- ------------------------------------------------ refusals
  r := public.cashier_move_table(t1, t1);
  assert r->>'error' = 'pick another table', 'the same table: ' || r::text;
  r := public.cashier_move_table(t2, t3);
  assert r->>'error' = 'nothing to move', 'an empty table: ' || r::text;
  r := public.cashier_move_table(t1, t_other);
  assert r->>'error' = 'table not found', 'another cafe''s table: ' || r::text;

  -- ------------------------------------------------ move to the free table 2
  r := public.cashier_move_table(t1, t2);
  assert (r->>'ok')::boolean and not (r->>'merged')::boolean, 'move: ' || r::text;
  execute 'reset role';
  select count(*) into n from public.orders where id = o1 and table_id = t2 and table_number = '2';
  assert n = 1, 'the same order now belongs to table 2';
  select count(*) into n from public.cart_lines where table_id = t2 and qty = 4;
  assert n = 1, 'the cart dish followed';
  select count(*) into n from public.staff_calls where table_id = t2 and not resolved;
  assert n = 1, 'the open call followed';
  select count(*) into n from public.dining_tables where id = t1 and status = 'free' and guests = 0;
  assert n = 1, 'table 1 is free';
  select count(*) into n from public.dining_tables where id = t2 and status = 'dining' and guests = 2;
  assert n = 1, 'table 2 is dining with the 2 guests';
  select count(*) into n from public.table_claims where table_id = t1;
  assert n = 0, 'the phone lost table 1';

  -- ------------------------------------------------ merge table 2 into table 3
  execute 'set local role anon';
  r := public.cashier_move_table(t2, t3);
  execute 'reset role';
  assert (r->>'ok')::boolean and (r->>'merged')::boolean, 'merge: ' || r::text;
  select count(*) into n from public.orders where id = o1;
  assert n = 0, 'the emptied order is gone';
  select count(*) into n from public.order_lines where order_id = o3;
  assert n = 3, 'all dishes are on table 3''s tab';
  select max(round) into n from public.order_lines where order_id = o3;
  assert n = 1, 'rounds are capped at table 3''s last round so the kitchen does not print them again';
  select guests into n from public.dining_tables where id = t3;
  assert n = 5, 'guests add up';
  select count(*) into n from public.cart_lines where table_id = t3;
  assert n = 1, 'the cart joined table 3';

  raise notice 'move_table_test: all checks passed';
end $test$;

rollback;
