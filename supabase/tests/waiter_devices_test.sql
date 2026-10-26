-- Checks 20261028100000_waiter_devices.sql: a cashier signs in as a till and a server with a
-- device as a waiter, while other staff can't sign in; a waiter is refused on settling, shifts,
-- expenses and takeout and reads no payments, shifts or expenses, but may still move a table and
-- mark a dish sold out; a waiter clears a table only once it is paid; only a till counts as
-- "a cashier is online"; an admin adds a device server only with a PIN.
-- Run by tool/test_db.sh. Everything is rolled back; any failed check aborts with its message.

begin;

do $test$
declare
  r jsonb;
  rid uuid;
  admin_a uuid;
  cat uuid;
  tea uuid;
  till_id uuid;
  waiter_id uuid;
  plain_server uuid;
  chef uuid;
  sid uuid;
  t1 uuid;
  t2 uuid;
  paid_order uuid;
  open_order uuid;
  pay_type uuid;
  till_token text;
  waiter_token text;
  n integer;
  refused boolean;
begin
  insert into public.restaurants (name) values ('waiter cafe') returning id into rid;
  alter table auth.users disable trigger user;
  insert into auth.users (email) values ('a@waiter.test') returning id into admin_a;
  alter table auth.users enable trigger user;
  insert into public.profiles (id, restaurant_id) values (admin_a, rid);
  insert into public.menu_categories (restaurant_id, name_en, name_ar) values (rid, 'C', 'C') returning id into cat;
  insert into public.menu_items (restaurant_id, category_id, name_en, price) values (rid, cat, 'Tea', 2) returning id into tea;
  insert into public.payment_types (restaurant_id, name_en, name_ar) values (rid, 'Cash', 'نقدي') returning id into pay_type;

  insert into public.cashiers (restaurant_id, name, initials, pin_hash)
    values (rid, 'Till', 'T', extensions.crypt('1111', extensions.gen_salt('bf'))) returning id into till_id;
  insert into public.cashiers (restaurant_id, name, initials, pin_hash, role, uses_device)
    values (rid, 'Waiter', 'W', extensions.crypt('2222', extensions.gen_salt('bf')), 'server', true) returning id into waiter_id;
  insert into public.cashiers (restaurant_id, name, initials, pin_hash, role)
    values (rid, 'Plain', 'P', extensions.crypt('3333', extensions.gen_salt('bf')), 'server') returning id into plain_server;
  insert into public.cashiers (restaurant_id, name, initials, pin_hash, role, uses_device)
    values (rid, 'Chef', 'C', extensions.crypt('4444', extensions.gen_salt('bf')), 'chef', true) returning id into chef;

  insert into public.dining_tables (restaurant_id, number, qr_slug, status, guests) values (rid, '1', 'waiter-1', 'dining', 2) returning id into t1;
  insert into public.dining_tables (restaurant_id, number, qr_slug) values (rid, '2', 'waiter-2') returning id into t2;
  insert into public.shifts (restaurant_id, cashier_id, opening_cash) values (rid, till_id, 0) returning id into sid;
  insert into public.orders (restaurant_id, table_id, table_number, status) values (rid, null, null, 'paid') returning id into paid_order;
  insert into public.payments (restaurant_id, order_id, total_due, cash_received, change_due, cashier_id, shift_id, client_id)
    values (rid, paid_order, 2, 2, 0, till_id, sid, gen_random_uuid());
  insert into public.shift_expenses (restaurant_id, shift_id, cashier_id, amount, description, paid_to_cafe)
    values (rid, sid, till_id, 1, 'milk', true);
  insert into public.orders (restaurant_id, table_id, table_number, status) values (rid, t1, '1', 'served') returning id into open_order;
  insert into public.order_lines (order_id, restaurant_id, menu_item_id, name, qty, unit_price, round)
    values (open_order, rid, tea, 'Tea', 1, 2, 1);

  execute 'set local role anon';

  -- ------------------------------------------------ sign-in
  r := public.cashier_login(till_id, '1111');
  assert (r->>'ok')::boolean and r->>'kind' = 'till', 'a cashier is a till: ' || r::text;
  till_token := r->>'token';
  r := public.cashier_login(waiter_id, '2222');
  assert (r->>'ok')::boolean and r->>'kind' = 'waiter', 'a device server is a waiter: ' || r::text;
  waiter_token := r->>'token';
  r := public.cashier_login(plain_server, '3333');
  assert not (r->>'ok')::boolean, 'a server without a device can''t sign in: ' || r::text;
  r := public.cashier_login(chef, '4444');
  assert not (r->>'ok')::boolean, 'a chef can''t sign in, device or not: ' || r::text;
  assert (select count(*) from public.list_pos_cashiers(rid) c where c.uses_device) = 2,
    'the sign-in list says who uses a device';

  -- ------------------------------------------------ the waiter: no money
  perform set_config('request.headers', json_build_object('x-cashier-token', waiter_token)::text, true);
  execute 'reset role';
  assert private.session_is_waiter() and not private.session_is_till(), 'the waiter session is a waiter';
  execute 'set local role anon';

  refused := false;
  begin
    perform public.settle_cash(t1, 2, false, pay_type);
  exception when insufficient_privilege then refused := true;
  end;
  assert refused, 'a waiter can''t settle';
  refused := false;
  begin
    perform public.settle_part(t1, '[]'::jsonb, 2, false, pay_type);
  exception when insufficient_privilege then refused := true;
  end;
  assert refused, 'a waiter can''t settle part of a bill';
  refused := false;
  begin
    perform public.open_shift();
  exception when insufficient_privilege then refused := true;
  end;
  assert refused, 'a waiter can''t open a shift';
  refused := false;
  begin
    perform public.record_cash_movement(sid, null, 1, 'tip', null);
  exception when insufficient_privilege then refused := true;
  end;
  assert refused, 'a waiter can''t record an expense';
  refused := false;
  begin
    perform public.quick_takeout_receipt('[]'::jsonb, pay_type);
  exception when insufficient_privilege then refused := true;
  end;
  assert refused, 'a waiter can''t ring up takeout';
  refused := false;
  begin
    perform public.cashier_clear_table(t1);
  exception when insufficient_privilege then refused := true;
  end;
  assert refused, 'a waiter can''t use the till''s clear, which drops unpaid orders';

  assert (select count(*) from public.payments) = 0, 'a waiter reads no payments';
  assert (select count(*) from public.shifts) = 0, 'a waiter reads no shifts';
  assert (select count(*) from public.shift_expenses) = 0, 'a waiter reads no expenses';
  assert (select count(*) from public.expense_categories) = 0, 'a waiter reads no expense types';
  refused := false;
  begin
    insert into public.shifts (restaurant_id, cashier_id, opening_cash) values (rid, waiter_id, 0);
  exception when insufficient_privilege then refused := true;
  end;
  assert refused, 'a waiter can''t write a shift straight to the table';
  delete from public.orders where id = open_order;
  get diagnostics n = row_count;
  assert n = 0, 'a waiter can''t delete an unpaid order straight from the table';

  -- ------------------------------------------------ the waiter: still serves
  assert (select count(*) from public.orders where restaurant_id = rid) = 2, 'a waiter reads orders';
  assert (select count(*) from public.menu_items where restaurant_id = rid) = 1, 'a waiter reads the menu';
  perform public.set_item_available(tea, false);
  execute 'reset role';
  assert not (select available from public.menu_items where id = tea), 'a waiter marks a dish sold out';
  execute 'set local role anon';

  -- ------------------------------------------------ clearing waits for payment
  r := public.waiter_clear_table(t1);
  assert not (r->>'ok')::boolean and r->>'code' = 'unpaid', 'an unpaid table stays: ' || r::text;
  assert (select status from public.dining_tables where id = t1) <> 'free', 'the table is still taken';

  r := public.cashier_move_table(t1, t2);
  assert (r->>'ok')::boolean, 'a waiter moves a table: ' || r::text;

  -- ------------------------------------------------ the till: unchanged
  perform set_config('request.headers', json_build_object('x-cashier-token', till_token)::text, true);
  assert (select count(*) from public.payments) = 1, 'a till still reads payments';
  assert (select count(*) from public.shift_expenses) = 1, 'a till still reads its expenses';
  r := public.settle_cash(t2, 10, false, pay_type);
  assert (r->>'ok')::boolean, 'the till settles table 2: ' || r::text;

  perform set_config('request.headers', json_build_object('x-cashier-token', waiter_token)::text, true);
  r := public.waiter_clear_table(t2);
  assert (r->>'ok')::boolean, 'a paid table clears: ' || r::text;
  assert (select status from public.dining_tables where id = t2) = 'free', 'the paid table is free';

  -- ------------------------------------------------ only a till is "a cashier online"
  r := public.cashier_heartbeat_v2('1.0.0');
  assert (r->>'ok')::boolean, 'a waiter heartbeats: ' || r::text;
  execute 'reset role';
  assert not private.cashier_online(rid), 'a waiter alone is not a cashier online';
  execute 'set local role anon';
  perform set_config('request.headers', json_build_object('x-cashier-token', till_token)::text, true);
  perform public.cashier_heartbeat_v2('1.0.0');
  execute 'reset role';
  assert private.cashier_online(rid), 'a till is a cashier online';

  -- ------------------------------------------------ the admin adds a device server
  execute 'reset role';
  perform set_config('request.headers', '{}', true);
  perform set_config('request.jwt.claim.sub', admin_a::text, true);
  execute 'set local role authenticated';
  refused := false;
  begin
    perform public.create_cashier('Nour', '', 'N', 'server', true);
  exception when others then refused := sqlerrm = 'PIN must be 4 digits';
  end;
  assert refused, 'a device server needs a PIN';
  waiter_id := public.create_cashier('Nour', '5555', 'N', 'server', true);
  plain_server := public.create_cashier('Ali', '', 'A', 'server');
  execute 'reset role';
  assert (select uses_device from public.cashiers where id = waiter_id), 'the new server uses a device';
  assert not (select uses_device from public.cashiers where id = plain_server), 'a plain server does not';
  execute 'set local role anon';
  r := public.cashier_login(waiter_id, '5555');
  assert (r->>'ok')::boolean and r->>'kind' = 'waiter', 'the new device server signs in: ' || r::text;
  execute 'reset role';

  raise notice 'waiter_devices_test: all checks passed';
end;
$test$;

rollback;
