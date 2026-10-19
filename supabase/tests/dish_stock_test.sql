-- Checks 20261019160000_dish_stock.sql: a dish without stock is never counted; each dish put on an
-- order (quick takeout, a table round sent by a cashier or a guest) lowers the count, never below
-- 0; at 0 the dish is sold out and a till saving an older copy cannot turn it back on. Also checks
-- that a cashier can send a table's order by its QR slug while the cafe's location check is on.
-- Run by tool/test_db.sh. Everything is rolled back; any failed check aborts with its message.

begin;

do $test$
declare
  r jsonb;
  rid uuid;
  tid uuid;
  cat uuid;
  cake uuid;
  tea uuid;
  cid uuid;
  sid uuid;
  left_qty integer;
  sold boolean;
begin
  insert into public.restaurants (name, location_check_enabled, location_lat, location_lng, location_radius_m)
    values ('stock cafe', true, 32.9, 13.2, 100) returning id into rid;
  insert into public.dining_tables (restaurant_id, number, qr_slug) values (rid, 'S1', 'stock-slug-1') returning id into tid;
  insert into public.menu_categories (restaurant_id, name_en, name_ar) values (rid, 'Food', 'أكل') returning id into cat;
  insert into public.menu_items (restaurant_id, category_id, name_en, price, stock_qty)
    values (rid, cat, 'Cake', 10, 4) returning id into cake;
  insert into public.menu_items (restaurant_id, category_id, name_en, price) values (rid, cat, 'Tea', 5) returning id into tea;
  insert into public.cashiers (restaurant_id, name, initials, pin_hash) values (rid, 'S', 'S', 'x') returning id into cid;
  insert into public.cashier_sessions (cashier_id, restaurant_id, token_hash, expires_at)
    values (cid, rid, encode(extensions.digest('stock-token', 'sha256'), 'hex'), now() + interval '1 hour') returning id into sid;
  insert into public.cashier_presence (session_id, restaurant_id, last_seen) values (sid, rid, now());

  begin
    update public.menu_items set stock_qty = -1 where id = cake;
    raise exception 'a negative stock must be refused';
  exception when check_violation then null;
  end;

  -- ---------------------------------------------------------------- quick takeout lowers it
  perform set_config('request.headers', json_build_object('x-cashier-token', 'stock-token')::text, true);
  execute 'set local role anon';
  r := public.quick_takeout_receipt(jsonb_build_array(
    jsonb_build_object('menu_item_id', cake, 'qty', 1),
    jsonb_build_object('menu_item_id', tea, 'qty', 3)
  ), null);
  execute 'reset role';
  assert (r->>'ok')::boolean, 'takeout: ' || r::text;
  select stock_qty, sold_out into left_qty, sold from public.menu_items where id = cake;
  assert left_qty = 3 and not sold, 'takeout of 1 leaves 3, got ' || left_qty;
  select stock_qty into left_qty from public.menu_items where id = tea;
  assert left_qty is null, 'a dish without a limit is not counted';

  -- ---------------------------------------------------------------- a cashier sends a table round by slug
  perform set_config('request.headers', json_build_object('x-cashier-token', 'stock-token')::text, true);
  execute 'set local role anon';
  r := public.send_table_cart('stock-slug-1', jsonb_build_array(jsonb_build_object('menu_item_id', cake, 'qty', 2)));
  execute 'reset role';
  assert (r->>'ok')::boolean, 'a cashier skips the location check and names the table: ' || r::text;
  select stock_qty, sold_out into left_qty, sold from public.menu_items where id = cake;
  assert left_qty = 1 and not sold, 'table round of 2 leaves 1, got ' || left_qty;

  -- ---------------------------------------------------------------- more than is left: 0 and sold out
  perform set_config('request.headers', json_build_object('x-cashier-token', 'stock-token')::text, true);
  execute 'set local role anon';
  r := public.quick_takeout_receipt(jsonb_build_array(jsonb_build_object('menu_item_id', cake, 'qty', 2)), null);
  execute 'reset role';
  assert (r->>'ok')::boolean, 'a sale is never lost to the count: ' || r::text;
  select stock_qty, sold_out into left_qty, sold from public.menu_items where id = cake;
  assert left_qty = 0 and sold, 'stock stops at 0 and the dish is sold out';

  -- ---------------------------------------------------------------- an older copy cannot revive it
  update public.menu_items set sold_out = false, name_en = 'Cake!' where id = cake;
  select sold_out into sold from public.menu_items where id = cake;
  assert sold, 'with 0 left the dish stays sold out';

  -- ---------------------------------------------------------------- restock
  update public.menu_items set stock_qty = 13, sold_out = false where id = cake;
  select stock_qty, sold_out into left_qty, sold from public.menu_items where id = cake;
  assert left_qty = 13 and not sold, 'restocking turns the dish back on';

  assert not has_function_privilege('anon', 'private.take_dish_stock()', 'execute'), 'trigger function is private';

  raise notice 'dish_stock_test: all checks passed';
end $test$;

rollback;
