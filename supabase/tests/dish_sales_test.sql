-- Checks 20261027100000_dish_sales.sql: dishes sold in a range of Tripoli days, voided sales left
-- out, a deleted dish grouped by its saved name, most sold
-- first, only the admin's own cafe, and a till can't call it.
-- Run by tool/test_db.sh. Everything is rolled back; any failed check aborts with its message.

begin;

do $test$
declare
  r jsonb;
  rid uuid;
  other uuid;
  admin_a uuid;
  cid uuid;
  sid uuid;
  cat uuid;
  tea uuid;
  cake uuid;
  ord uuid;
  ord2 uuid;
  ord3 uuid;
  ord4 uuid;
  blocked boolean;
begin
  insert into public.restaurants (name) values ('dish cafe') returning id into rid;
  insert into public.restaurants (name) values ('dish other cafe') returning id into other;
  alter table auth.users disable trigger user;
  insert into auth.users (email) values ('a@dish.test') returning id into admin_a;
  alter table auth.users enable trigger user;
  insert into public.profiles (id, restaurant_id) values (admin_a, rid);

  insert into public.cashiers (restaurant_id, name, initials, pin_hash) values (rid, 'Sara', 'S', 'x') returning id into cid;
  insert into public.cashier_sessions (cashier_id, restaurant_id, token_hash, expires_at)
    values (cid, rid, encode(extensions.digest('dish-token', 'sha256'), 'hex'), now() + interval '1 hour');
  insert into public.shifts (restaurant_id, cashier_id, opening_cash) values (rid, cid, 0) returning id into sid;
  insert into public.menu_categories (restaurant_id, name_en, name_ar) values (rid, 'Drinks', 'مشروبات') returning id into cat;
  insert into public.menu_items (restaurant_id, category_id, name_en, price) values (rid, cat, 'Tea', 2) returning id into tea;
  insert into public.menu_items (restaurant_id, category_id, name_en, price) values (rid, cat, 'Cake', 5) returning id into cake;
  insert into public.orders (restaurant_id, table_id, status, service_type) values (rid, null, 'paid', 'takeout') returning id into ord;
  insert into public.orders (restaurant_id, table_id, status, service_type) values (rid, null, 'paid', 'takeout') returning id into ord2;
  insert into public.orders (restaurant_id, table_id, status, service_type) values (rid, null, 'paid', 'takeout') returning id into ord3;
  insert into public.orders (restaurant_id, table_id, status, service_type) values (rid, null, 'paid', 'takeout') returning id into ord4;

  -- ord: 3 tea + 1 cake. ord2: 2 tea + an old dish no longer on the menu.
  -- ord3: voided. ord4: paid the next day (Tripoli). A line without a dish needs the import switch.
  perform set_config('dev.import', 'on', true);
  insert into public.order_lines (order_id, restaurant_id, menu_item_id, name, qty, unit_price) values
    (ord, rid, tea, 'Tea', 3, 2), (ord, rid, cake, 'Cake', 1, 5),
    (ord2, rid, tea, 'Tea', 2, 2), (ord2, rid, null, 'Old soup', 1, 4),
    (ord3, rid, cake, 'Cake', 9, 5),
    (ord4, rid, cake, 'Cake', 7, 5);
  perform set_config('dev.import', '', true);
  insert into public.payments (restaurant_id, order_id, total_due, cash_received, change_due, cashier_id, shift_id, client_id, paid_at)
  values
    (rid, ord, 11, 11, 0, cid, sid, gen_random_uuid(), '2026-10-24 09:00+00'),
    (rid, ord2, 8, 8, 0, cid, sid, gen_random_uuid(), '2026-10-24 21:30+00'),
    (rid, ord4, 35, 35, 0, cid, sid, gen_random_uuid(), '2026-10-24 22:30+00');
  insert into public.payments (restaurant_id, order_id, total_due, cash_received, change_due, cashier_id, shift_id, client_id, paid_at, voided_at, void_reason)
  values (rid, ord3, 45, 45, 0, cid, sid, gen_random_uuid(), '2026-10-24 10:00+00', '2026-10-24 10:05+00', 'left');

  perform set_config('request.jwt.claim.sub', admin_a::text, true);
  execute 'set local role authenticated';
  r := public.admin_dish_sales('2026-10-24', '2026-10-24');
  execute 'reset role';
  assert (r->>'ok')::boolean, 'it works: ' || r::text;
  assert jsonb_array_length(r->'dishes') = 3, 'tea, cake and the old soup: ' || r::text;
  assert r->'dishes'->0->>'id' = tea::text and (r->'dishes'->0->>'qty')::int = 5 and (r->'dishes'->0->>'total')::numeric = 10,
    'tea first, 5 sold across two orders: ' || r::text;
  assert (select (d->>'qty')::int from jsonb_array_elements(r->'dishes') d where d->>'id' = cake::text) = 1,
    'the voided cakes and the next day''s do not count: ' || r::text;
  assert (select d->>'name' from jsonb_array_elements(r->'dishes') d where d->'id' = 'null'::jsonb) = 'Old soup', 'a deleted dish: ' || r::text;

  execute 'set local role authenticated';
  r := public.admin_dish_sales('2026-01-01', '2026-01-31');
  assert (r->>'ok')::boolean and r->'dishes' = '[]'::jsonb, 'empty: ' || r::text;
  r := public.admin_dish_sales('2026-10-25', '2026-10-24');
  assert not (r->>'ok')::boolean, 'backwards is refused: ' || r::text;
  execute 'reset role';

  -- another cafe's admin sees none of it
  alter table auth.users disable trigger user;
  insert into auth.users (email) values ('b@dish.test') returning id into admin_a;
  alter table auth.users enable trigger user;
  insert into public.profiles (id, restaurant_id) values (admin_a, other);
  perform set_config('request.jwt.claim.sub', admin_a::text, true);
  execute 'set local role authenticated';
  r := public.admin_dish_sales('2026-10-24', '2026-10-24');
  execute 'reset role';
  assert r->'dishes' = '[]'::jsonb, 'cafe B sees nothing: ' || r::text;

  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('request.headers', json_build_object('x-cashier-token', 'dish-token')::text, true);
  execute 'set local role anon';
  blocked := false;
  begin
    r := public.admin_dish_sales('2026-10-24', '2026-10-24');
  exception when insufficient_privilege then blocked := true;
  end;
  execute 'reset role';
  assert blocked, 'a till (anon) must not read dish sales';

  raise notice 'dish_sales_test: all checks passed';
end $test$;

rollback;
