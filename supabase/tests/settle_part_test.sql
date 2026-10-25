-- Checks 20261027130000_settle_part.sql as a signed-in cashier device: part of a served tab is
-- paid on its own (with its own payment type and the service charge) while the rest stays open
-- on the table; part of a line keeps its ordered price and does not take stock twice; too little
-- cash rolls everything back; picking the whole bill or a dish of another tab is refused; the
-- last part is paid with settle_cash and frees the table.
-- Run by tool/test_db.sh. Everything is rolled back; any failed check aborts with its message.

begin;

do $test$
declare
  r jsonb;
  rid uuid;
  cat uuid;
  tea uuid;
  cake uuid;
  card uuid;
  cid uuid;
  sid uuid;
  t1 uuid;
  o1 uuid;
  tea_line uuid;
  cake_line uuid;
  n integer;
  v numeric;
begin
  insert into public.restaurants (name, service_charge_rate) values ('split cafe', 0.1) returning id into rid;
  insert into public.menu_categories (restaurant_id, name_en, name_ar) values (rid, 'C', 'C') returning id into cat;
  insert into public.menu_items (restaurant_id, category_id, name_en, price, stock_qty) values (rid, cat, 'Tea', 2, 10) returning id into tea;
  insert into public.menu_items (restaurant_id, category_id, name_en, price) values (rid, cat, 'Cake', 5) returning id into cake;
  insert into public.payment_types (restaurant_id, name_en, name_ar, sort_order) values (rid, 'Card', 'بطاقة', 1) returning id into card;
  insert into public.cashiers (restaurant_id, name, initials, pin_hash) values (rid, 'V', 'V', 'x') returning id into cid;
  insert into public.cashier_sessions (cashier_id, restaurant_id, token_hash, expires_at)
  values (cid, rid, encode(extensions.digest('split-token', 'sha256'), 'hex'), now() + interval '1 hour');
  insert into public.dining_tables (restaurant_id, number, qr_slug, status, guests) values (rid, '1', 'split-1', 'dining', 2) returning id into t1;

  -- A served tab: 3 tea (ordered at 2, the menu now says 3) and 1 cake.
  insert into public.orders (restaurant_id, table_id, table_number, status) values (rid, t1, '1', 'served') returning id into o1;
  insert into public.order_lines (order_id, restaurant_id, menu_item_id, name, qty, unit_price, round)
  values (o1, rid, tea, 'Tea', 3, 2, 2) returning id into tea_line;
  insert into public.order_lines (order_id, restaurant_id, menu_item_id, name, qty, unit_price)
  values (o1, rid, cake, 'Cake', 1, 5) returning id into cake_line;
  update public.menu_items set price = 3, stock_qty = 7 where id = tea;

  perform set_config('request.headers', json_build_object('x-cashier-token', 'split-token')::text, true);
  execute 'set local role anon';
  r := public.open_shift();
  sid := (r->>'shift_id')::uuid;

  -- ------------------------------------------------ refusals
  r := public.settle_part(t1, jsonb_build_array(jsonb_build_object('line_id', tea_line, 'qty', 3), jsonb_build_object('line_id', cake_line, 'qty', 1)), 100);
  assert r->>'error' = 'whole bill', 'every dish is a normal settle: ' || r::text;
  r := public.settle_part(t1, jsonb_build_array(jsonb_build_object('line_id', tea_line, 'qty', 4)), 100);
  assert r->>'error' = 'pick dishes', 'more than ordered: ' || r::text;
  r := public.settle_part(t1, '[]'::jsonb, 100);
  assert r->>'error' = 'pick dishes', 'nothing picked: ' || r::text;
  r := public.settle_part(t1, jsonb_build_array(jsonb_build_object('line_id', tea_line, 'qty', 1)), 1);
  assert r->>'error' = 'insufficient cash', 'too little cash: ' || r::text;
  execute 'reset role';
  select count(*) into n from public.orders where table_id = t1;
  assert n = 1, 'a refused part changes nothing';
  select qty into n from public.order_lines where id = tea_line;
  assert n = 3, 'the line is untouched after too little cash';

  -- ------------------------------------------------ one tea, by card
  execute 'set local role anon';
  r := public.settle_part(t1, jsonb_build_array(jsonb_build_object('line_id', tea_line, 'qty', 1)), 2.2, true, card);
  execute 'reset role';
  assert (r->>'ok')::boolean and (r->>'total_due')::numeric = 2.2, 'one tea at its ordered 2, plus 10%: ' || r::text;
  select count(*) into n from public.payments where order_id = (r->>'order_id')::uuid and payment_type_id = card and total_due = 2.2;
  assert n = 1, 'the part has its own card payment';
  select count(*) into n from public.order_lines where order_id = (r->>'order_id')::uuid and unit_price = 2 and round = 2 and qty = 1;
  assert n = 1, 'the part line keeps its ordered price and round';
  select qty into n from public.order_lines where id = tea_line;
  assert n = 2, 'two tea stay on the tab';
  select stock_qty into n from public.menu_items where id = tea;
  assert n = 7, 'the tea stock is not taken twice';
  select count(*) into n from public.dining_tables where id = t1 and status = 'dining';
  assert n = 1, 'the table stays open for the rest';
  select cash_sales into v from public.shifts where id = sid;
  assert v = 2.2, 'the shift counts the part: ' || v;

  -- ------------------------------------------------ the cake, whole line
  execute 'set local role anon';
  r := public.settle_part(t1, jsonb_build_array(jsonb_build_object('line_id', cake_line, 'qty', 1)), 10);
  execute 'reset role';
  assert (r->>'ok')::boolean and (r->>'total_due')::numeric = 5.5, 'cake: ' || r::text;
  select count(*) into n from public.order_lines where id = cake_line and order_id = (r->>'order_id')::uuid;
  assert n = 1, 'a whole line moves as it is';

  -- ------------------------------------------------ the rest with a normal settle
  execute 'set local role anon';
  r := public.settle_cash(t1, 10);
  execute 'reset role';
  assert (r->>'ok')::boolean and (r->>'total_due')::numeric = 4.4, 'the last two tea: ' || r::text;
  select count(*) into n from public.dining_tables where id = t1 and status = 'free';
  assert n = 1, 'the table is free once the last part is paid';
  select count(*) into n from public.payments where table_id = t1;
  assert n = 3, 'three payments for one table';

  raise notice 'settle_part_test: all checks passed';
end $test$;

rollback;
