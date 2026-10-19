-- Checks 20261019110000_same_cafe_links.sql as a signed-in admin: rows of cafe A can't be pointed
-- at cafe B's order, table, dish category or cashier (on update as well as insert), and paid
-- orders and their lines can't be changed or deleted directly. Normal edits keep working.
-- Run by tool/test_db.sh. Everything is rolled back; any failed check aborts with its message.

begin;

do $test$
declare
  rid_a uuid;
  rid_b uuid;
  admin_a uuid;
  cat_a uuid;
  cat_b uuid;
  tea_a uuid;
  table_a uuid;
  table_b uuid;
  cashier_b uuid;
  order_a uuid;
  order_b uuid;
  paid_a uuid;
  line_a uuid;
  paid_line uuid;
  n integer;
  blocked boolean;
begin
  insert into public.restaurants (name) values ('link cafe A') returning id into rid_a;
  insert into public.restaurants (name) values ('link cafe B') returning id into rid_b;
  alter table auth.users disable trigger user;
  insert into auth.users (email) values ('a@links.test') returning id into admin_a;
  alter table auth.users enable trigger user;
  insert into public.profiles (id, restaurant_id) values (admin_a, rid_a);
  insert into public.menu_categories (restaurant_id, name_en, name_ar) values (rid_a, 'A', 'A') returning id into cat_a;
  insert into public.menu_categories (restaurant_id, name_en, name_ar) values (rid_b, 'B', 'B') returning id into cat_b;
  insert into public.menu_items (restaurant_id, category_id, name_en, price) values (rid_a, cat_a, 'Tea', 5) returning id into tea_a;
  insert into public.dining_tables (restaurant_id, number, qr_slug) values (rid_a, 1, 'link-a-1') returning id into table_a;
  insert into public.dining_tables (restaurant_id, number, qr_slug) values (rid_b, 1, 'link-b-1') returning id into table_b;
  insert into public.cashiers (restaurant_id, name, initials, pin_hash) values (rid_b, 'B', 'B', 'x') returning id into cashier_b;
  insert into public.orders (restaurant_id, table_id, status) values (rid_a, table_a, 'received') returning id into order_a;
  insert into public.orders (restaurant_id, table_id, status) values (rid_b, table_b, 'received') returning id into order_b;
  insert into public.orders (restaurant_id, table_id, status, service_type) values (rid_a, null, 'paid', 'takeout') returning id into paid_a;
  insert into public.order_lines (order_id, menu_item_id, qty) values (order_a, tea_a, 1) returning id into line_a;
  insert into public.order_lines (order_id, menu_item_id, qty) values (paid_a, tea_a, 1) returning id into paid_line;

  perform set_config('request.jwt.claim.sub', admin_a::text, true);
  execute 'set local role authenticated';

  -- ------------------------------------------------ links into another cafe are refused
  blocked := false;
  begin
    update public.order_lines set order_id = order_b where id = line_a;
  exception when insufficient_privilege then blocked := true;
  end;
  assert blocked, 'an order line must not move into another cafe''s bill';

  blocked := false;
  begin
    update public.orders set table_id = table_b where id = order_a;
  exception when insufficient_privilege then blocked := true;
  end;
  assert blocked, 'an order must not point at another cafe''s table';

  blocked := false;
  begin
    update public.orders set cashier_id = cashier_b where id = order_a;
  exception when insufficient_privilege then blocked := true;
  end;
  assert blocked, 'an order must not point at another cafe''s cashier';

  blocked := false;
  begin
    update public.menu_items set category_id = cat_b where id = tea_a;
  exception when insufficient_privilege then blocked := true;
  end;
  assert blocked, 'a dish must not move into another cafe''s category';

  blocked := false;
  begin
    insert into public.menu_items (restaurant_id, category_id, name_en, price) values (rid_a, cat_b, 'Spy', 1);
  exception when insufficient_privilege then blocked := true;
  end;
  assert blocked, 'a new dish must not use another cafe''s category';

  -- ------------------------------------------------ paid orders are frozen
  blocked := false;
  begin
    update public.order_lines set unit_price = 0 where id = paid_line;
  exception when insufficient_privilege then blocked := true;
  end;
  assert blocked, 'a paid order''s line price must not change';

  blocked := false;
  begin
    delete from public.order_lines where id = paid_line;
  exception when insufficient_privilege then blocked := true;
  end;
  assert blocked, 'a paid order''s line must not be deleted';

  blocked := false;
  begin
    update public.order_lines set order_id = paid_a where id = line_a;
  exception when insufficient_privilege then blocked := true;
  end;
  assert blocked, 'a line must not be moved onto a paid order';

  blocked := false;
  begin
    delete from public.orders where id = paid_a;
  exception when insufficient_privilege then blocked := true;
  end;
  assert blocked, 'a paid order must not be deleted (it would take its payments with it)';

  -- ------------------------------------------------ normal edits still work
  update public.order_lines set qty = 3 where id = line_a;
  update public.menu_items set name_en = 'Green tea' where id = tea_a;
  update public.orders set status = 'preparing' where id = order_a;
  execute 'reset role';

  select count(*) into n from public.order_lines where id = line_a and qty = 3 and order_id = order_a;
  assert n = 1, 'an unpaid line of the same cafe must stay editable';
  select count(*) into n from public.order_lines where id = paid_line;
  assert n = 1, 'the paid line must still be there';
  select count(*) into n from public.orders where id = order_b and restaurant_id = rid_b;
  assert n = 1, 'the other cafe''s order is untouched';

  raise notice 'same_cafe_links_test: all checks passed';
end;
$test$;

rollback;
