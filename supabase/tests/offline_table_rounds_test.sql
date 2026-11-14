begin;

do $test$
declare
  cafe uuid;
  category uuid;
  dish uuid;
  cashier uuid;
  dining_table uuid;
  operation uuid := gen_random_uuid();
  lines jsonb;
  result jsonb;
  saved_order uuid;
begin
  insert into public.restaurants (name) values ('Offline table test') returning id into cafe;
  insert into public.menu_categories (restaurant_id, name_en, name_ar)
    values (cafe, 'Drinks', 'Drinks') returning id into category;
  insert into public.menu_items (restaurant_id, category_id, name_en, price)
    values (cafe, category, 'Tea', 5) returning id into dish;
  insert into public.cashiers (restaurant_id, name, initials, pin_hash)
    values (cafe, 'Cashier', 'C', 'x') returning id into cashier;
  insert into public.dining_tables (restaurant_id, number, qr_slug)
    values (cafe, '5', 'offline-table-test') returning id into dining_table;
  insert into public.cashier_sessions (cashier_id, restaurant_id, token_hash, expires_at)
    values (cashier, cafe, encode(extensions.digest('offline-table-test', 'sha256'), 'hex'), now() + interval '1 hour');
  perform set_config('request.headers', '{"x-cashier-token":"offline-table-test"}', true);
  lines := jsonb_build_array(jsonb_build_object('menu_item_id', dish, 'qty', 2));
  execute 'set local role anon';
  result := public.sync_offline_table_round(operation, cafe, cashier, dining_table, lines);
  assert result->>'ok' = 'true', result::text;
  saved_order := (result->>'order_id')::uuid;
  result := public.sync_offline_table_round(operation, cafe, cashier, dining_table, lines);
  assert result->>'duplicate' = 'true', result::text;
  result := public.sync_offline_table_round(gen_random_uuid(), gen_random_uuid(), cashier, dining_table, lines);
  assert result->>'ok' = 'false', result::text;
  execute 'reset role';
  assert (select sum(qty) from public.order_lines where order_id = saved_order) = 2;
  assert (select status from public.orders where id = saved_order) = 'preparing';
end;
$test$;

rollback;
