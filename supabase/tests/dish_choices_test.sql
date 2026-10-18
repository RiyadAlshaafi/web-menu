-- Checks 20261018100000_dish_choices.sql: only a choice that is off by default and turned on is
-- charged, removals are free, the dish discount never touches extras, unknown ids are dropped,
-- old payloads without choices still mean "dish as it comes", and offline uploads keep the till's
-- snapshot. Run by tool/test_db.sh. Everything is rolled back; any failed check aborts with its message.

begin;

do $test$
declare
  r jsonb;
  rid uuid;
  tid uuid;
  cat uuid;
  burger uuid;
  tea uuid;
  cid uuid;
  sid uuid;
  oid uuid;
  n integer;
  c jsonb;
  onion text := gen_random_uuid()::text;
  pickles text := gen_random_uuid()::text;
  cheese text := gen_random_uuid()::text;
  yymm text := to_char(now() at time zone 'Africa/Tripoli', 'YYMM');
  today text := to_char(now() at time zone 'Africa/Tripoli', 'YYMMDD');
  opts jsonb;
begin
  opts := jsonb_build_array(
    jsonb_build_object('id', onion, 'kind', 'ingredient', 'nameAr', 'بصل', 'nameEn', 'Onion', 'price', 0.25, 'defaultOn', true),
    jsonb_build_object('id', pickles, 'kind', 'ingredient', 'nameAr', 'مخلل', 'nameEn', 'Pickles', 'price', 0, 'defaultOn', false),
    jsonb_build_object('id', cheese, 'kind', 'topping', 'nameAr', 'جبنة', 'nameEn', 'Extra cheese', 'price', 1.5, 'defaultOn', false)
  );
  insert into public.restaurants (name) values ('choices cafe') returning id into rid;
  insert into public.dining_tables (restaurant_id, number, qr_slug) values (rid, 'C1', 'choices-slug-1') returning id into tid;
  insert into public.menu_categories (restaurant_id, name_en, name_ar) values (rid, 'Food', 'أكل') returning id into cat;
  -- 20% off the dish: 10 becomes 8; extras stay full price.
  insert into public.menu_items (restaurant_id, category_id, name_en, price, discount_percent, discount_applied, options)
    values (rid, cat, 'Burger', 10, 20, true, opts) returning id into burger;
  insert into public.menu_items (restaurant_id, category_id, name_en, price) values (rid, cat, 'Tea', 5) returning id into tea;
  insert into public.cashiers (restaurant_id, name, initials, pin_hash) values (rid, 'Z', 'Z', 'x') returning id into cid;
  insert into public.cashier_sessions (cashier_id, restaurant_id, token_hash, expires_at)
    values (cid, rid, encode(extensions.digest('choices-token', 'sha256'), 'hex'), now() + interval '1 hour') returning id into sid;
  insert into public.cashier_presence (session_id, restaurant_id, last_seen) values (sid, rid, now());

  -- ---------------------------------------------------------------- bad options are refused
  begin
    update public.menu_items set options = '[{"id":"x","kind":"sauce","nameEn":"A","price":1,"defaultOn":false}]' where id = tea;
    raise exception 'an unknown kind must be refused';
  exception when check_violation then null;
  end;
  begin
    update public.menu_items set options = '[{"id":"x","kind":"topping","nameEn":"A","price":-1,"defaultOn":false}]' where id = tea;
    raise exception 'a negative price must be refused';
  exception when check_violation then null;
  end;
  begin
    update public.menu_items set options = jsonb_build_array(opts->0, opts->0) where id = tea;
    raise exception 'duplicate option ids must be refused';
  exception when check_violation then null;
  end;

  -- ---------------------------------------------------------------- guest menu shows the options
  perform set_config('request.headers', '{}', true);
  execute 'set local role anon';
  r := public.guest_menu('choices-slug-1');
  select i into c from jsonb_array_elements(r->'items') i where i->>'id' = burger::text;
  assert jsonb_array_length(c->'options') = 3 and c->'options'->2->>'nameEn' = 'Extra cheese', 'menu options: ' || c::text;
  select i into c from jsonb_array_elements(r->'items') i where i->>'id' = tea::text;
  assert c->'options' = '[]'::jsonb, 'a dish without options returns an empty list: ' || c::text;

  -- ---------------------------------------------------------------- guest order with choices
  -- Line 1: no onion (free removal), pickles (free) and cheese (1.5). Line 2: the dish as it comes.
  -- Line 3: an unknown id is dropped. Line 4: an old payload without "on".
  r := public.send_table_cart('choices-slug-1', jsonb_build_array(
    jsonb_build_object('menu_item_id', burger, 'qty', 2, 'on', jsonb_build_array(pickles, cheese)),
    jsonb_build_object('menu_item_id', burger, 'qty', 1, 'on', jsonb_build_array(onion)),
    jsonb_build_object('menu_item_id', tea, 'qty', 1, 'on', jsonb_build_array(gen_random_uuid()::text)),
    jsonb_build_object('menu_item_id', burger, 'qty', 1)
  ));
  assert (r->>'ok')::boolean, 'order with choices goes through: ' || r::text;
  oid := (r->>'order_id')::uuid;
  execute 'reset role';

  select count(*) into n from public.order_lines where order_id = oid;
  assert n = 4, 'four lines, got ' || n;
  select count(*) into n from public.order_lines where order_id = oid and qty = 2
    and unit_price = 9.5 and list_unit_price = 11.5 and jsonb_array_length(choices) = 3;
  assert n = 1, 'extras add full price on top of the discounted dish: '
    || (select jsonb_agg(to_jsonb(l)) from public.order_lines l where order_id = oid)::text;
  select choices into c from public.order_lines where order_id = oid and qty = 2;
  assert c->0->>'id' = onion and c->0->>'on' = 'false' and (c->0->>'price')::numeric = 0, 'removal is free: ' || c::text;
  assert c->2->>'nameEn' = 'Extra cheese' and (c->2->>'price')::numeric = 1.5, 'cheese snapshot: ' || c::text;
  select count(*) into n from public.order_lines where order_id = oid and menu_item_id = burger and qty = 1
    and unit_price = 8 and list_unit_price = 10 and choices = '[]'::jsonb;
  assert n = 2, 'defaults and old payloads cost the plain dish, got ' || n;
  select count(*) into n from public.order_lines where order_id = oid and menu_item_id = tea and unit_price = 5 and choices = '[]'::jsonb;
  assert n = 1, 'unknown ids are dropped';

  execute 'set local role anon';
  r := public.guest_tab('choices-slug-1');
  execute 'reset role';
  select l into c from jsonb_array_elements(r->'order'->'lines') l where (l->>'qty')::int = 2;
  assert jsonb_array_length(c->'choices') = 3 and (c->>'unit_price')::numeric = 9.5, 'tab shows choices: ' || c::text;

  -- A price change later does not touch the sent line.
  update public.menu_items set options = jsonb_set(options, '{2,price}', '3') where id = burger;
  select count(*) into n from public.order_lines where order_id = oid and unit_price = 9.5;
  assert n = 1, 'sent lines keep the price they were charged';

  -- ---------------------------------------------------------------- the till's direct cart write
  -- The till writes its own snapshot; the server rebuilds names and prices from the menu.
  insert into public.carts (table_id, restaurant_id) values (tid, rid) on conflict (table_id) do nothing;
  insert into public.cart_lines (table_id, restaurant_id, menu_item_id, name, qty, unit_price, choices)
  values (tid, rid, burger, 'x', 1, 0,
          jsonb_build_array(jsonb_build_object('id', cheese, 'on', true, 'price', 0, 'nameEn', 'fake')));
  select choices into c from public.cart_lines where table_id = tid;
  assert (c->0->>'price')::numeric = 3 and c->0->>'nameEn' = 'Extra cheese', 'cart line snapshot comes from the menu: ' || c::text;
  select count(*) into n from public.cart_lines where table_id = tid and unit_price = 11 and list_unit_price = 13;
  assert n = 1, 'cart line price includes extras';
  update public.cart_lines set qty = 3 where table_id = tid;
  select count(*) into n from public.cart_lines where table_id = tid and unit_price = 11 and jsonb_array_length(choices) = 1;
  assert n = 1, 'changing qty keeps the choices';
  delete from public.cart_lines where table_id = tid;

  -- ---------------------------------------------------------------- quick takeout
  perform set_config('request.headers', json_build_object('x-cashier-token', 'choices-token')::text, true);
  execute 'set local role anon';
  r := public.quick_takeout_receipt(jsonb_build_array(
    jsonb_build_object('menu_item_id', burger, 'qty', 1, 'on', jsonb_build_array(onion, cheese)),
    jsonb_build_object('menu_item_id', tea, 'qty', 2)
  ), null);
  execute 'reset role';
  assert (r->>'ok')::boolean, 'takeout with choices: ' || r::text;
  assert (r->>'total_due')::numeric = 21, 'takeout total is 8 + 3 + 2 * 5, got ' || (r->>'total_due');

  -- ---------------------------------------------------------------- offline upload keeps the snapshot
  execute 'set local role anon';
  r := public.reserve_receipt_numbers(1, 0);
  r := public.sync_offline_takeout(
    gen_random_uuid(), cid, gen_random_uuid(),
    jsonb_build_array(jsonb_build_object('menu_item_id', burger::text, 'name', 'Burger', 'qty', 1,
      'unit_price', 9.5, 'list_unit_price', 11.5,
      'choices', jsonb_build_array(jsonb_build_object('id', cheese, 'nameAr', 'جبنة', 'nameEn', 'Extra cheese', 'on', true, 'price', 1.5)))),
    null, now(), yymm, (r->>'first')::integer, today, null);
  execute 'reset role';
  assert (r->>'ok')::boolean, 'offline upload with choices: ' || r::text;
  select choices into c from public.order_lines where order_id = (r->>'order_id')::uuid;
  assert (c->0->>'price')::numeric = 1.5, 'offline line keeps the price charged at the till: ' || c::text;
  assert (r->>'total_due')::numeric = 9.5, 'offline total: ' || r::text;

  -- ---------------------------------------------------------------- helpers stay private
  assert not has_function_privilege('anon', 'private.dish_choices(jsonb, jsonb, jsonb)', 'execute'), 'helper is private';

  raise notice 'dish_choices_test: all checks passed';
end $test$;

rollback;
