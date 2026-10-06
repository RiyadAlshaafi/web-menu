-- The direct writes the app build from before 20261008100000 still makes.
-- They must keep working with that migration alone, so it can go live before
-- the new app is deployed. Run by tool/test_db.sh without the part 2 migration.

begin;

do $test$
declare
  r jsonb;
  n integer;
  rid uuid;
  tid uuid;
  cat uuid;
  ia uuid;
  cid uuid;
  oid uuid;
  sid uuid := gen_random_uuid();
begin
  insert into public.restaurants (name) values ('old app cafe') returning id into rid;
  insert into public.dining_tables (restaurant_id, number, qr_slug) values (rid, 'T1', 'old-slug-1') returning id into tid;
  insert into public.menu_categories (restaurant_id, name_en, name_ar) values (rid, 'C', 'C') returning id into cat;
  insert into public.menu_items (restaurant_id, category_id, name_en, price) values (rid, cat, 'Avail', 10) returning id into ia;

  -- Guest: order, then mark the own table as waiting for the bill directly.
  perform set_config('request.headers', json_build_object('x-qr-slug', 'old-slug-1')::text, true);
  execute 'set local role anon';
  r := public.send_table_cart('old-slug-1', jsonb_build_array(jsonb_build_object('menu_item_id', ia, 'qty', 1)));
  assert (r->>'ok')::boolean, 'old guest order failed: ' || r::text;
  oid := (r->>'order_id')::uuid;
  update public.dining_tables set status = 'billRequested' where id = tid;
  get diagnostics n = row_count;
  assert n = 1, 'old guest bill request (direct table update) must still work';
  execute 'reset role';

  -- Cashier: direct status write, shift upsert, order line rewrite.
  insert into public.cashiers (restaurant_id, name, initials, pin_hash) values (rid, 'Z', 'Z', 'x') returning id into cid;
  insert into public.cashier_sessions (cashier_id, restaurant_id, token_hash, expires_at)
  values (cid, rid, encode(extensions.digest('old-token', 'sha256'), 'hex'), now() + interval '1 hour');
  perform set_config('request.headers', json_build_object('x-cashier-token', 'old-token')::text, true);
  execute 'set local role anon';
  update public.orders set status = 'preparing' where id = oid;
  get diagnostics n = row_count;
  assert n = 1, 'old cashier status update must still work';
  insert into public.shifts (id, restaurant_id, cashier_id, opening_cash) values (sid, rid, cid, 0);
  update public.shifts set opening_cash = 20 where id = sid;
  get diagnostics n = row_count;
  assert n = 1, 'old cashier shift write must still work';
  delete from public.order_lines where order_id = oid;
  get diagnostics n = row_count;
  assert n = 1, 'old cashier line rewrite must still work';
  execute 'reset role';

  raise notice 'old_app_compat_test: all checks passed';
end $test$;

rollback;
