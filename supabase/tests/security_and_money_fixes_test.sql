-- Checks the rules from 20261008100000_security_and_money_fixes.sql and
-- 20261008110000_lock_down_direct_writes.sql as each kind of caller: a guest
-- (QR slug header), a cashier (PIN token header), a stranger and the developer
-- (signed-in users). Run by tool/test_db.sh after both migrations. Everything
-- is rolled back; any failed check aborts with its message.

begin;

do $test$
declare
  r jsonb;
  r2 jsonb;
  rid uuid;
  tid uuid;
  cat uuid;
  ia uuid;
  ib uuid;
  ic uuid;
  cid uuid;
  oid uuid;
  oid2 uuid;
  lid uuid;
  dev uuid;
  sid uuid;
  stranger uuid := gen_random_uuid();
  n integer;
  fa integer;
  st text;
begin
  insert into public.restaurants (name, service_charge_rate) values ('test cafe', 0.10) returning id into rid;
  insert into public.dining_tables (restaurant_id, number, qr_slug) values (rid, 'T1', 'test-slug-1') returning id into tid;
  insert into public.dining_tables (restaurant_id, number, qr_slug, archived) values (rid, 'T2', 'test-slug-2', true);
  insert into public.menu_categories (restaurant_id, name_en, name_ar) values (rid, 'C', 'C') returning id into cat;
  insert into public.menu_items (restaurant_id, category_id, name_en, price) values (rid, cat, 'Avail', 10) returning id into ia;
  insert into public.menu_items (restaurant_id, category_id, name_en, price, available) values (rid, cat, 'Off', 10, false) returning id into ib;
  insert into public.menu_items (restaurant_id, category_id, name_en, price, sold_out) values (rid, cat, 'Gone', 10, true) returning id into ic;

  -- ---------------------------------------------------------------- guest
  perform set_config('request.headers', json_build_object('x-qr-slug', 'test-slug-1')::text, true);
  execute 'set local role anon';

  r := public.send_table_cart('test-slug-1', jsonb_build_array(
    jsonb_build_object('menu_item_id', ia, 'qty', 1),
    jsonb_build_object('menu_item_id', ib, 'qty', 1),
    jsonb_build_object('menu_item_id', ic, 'qty', 1)));
  assert r->>'error' = 'items_unavailable', 'unavailable dishes must be refused: ' || r::text;
  assert r->'items' @> '["Off", "Gone"]'::jsonb, 'refusal must name the dishes: ' || r::text;

  r := public.send_table_cart('test-slug-1', jsonb_build_array(jsonb_build_object('menu_item_id', ia, 'qty', 100)));
  assert r->>'error' = 'qty_too_large', 'qty 100 must be refused: ' || r::text;

  r := public.send_table_cart('test-slug-2', jsonb_build_array(jsonb_build_object('menu_item_id', ia, 'qty', 1)));
  assert r->>'error' = 'table not found', 'an archived table must not take orders: ' || r::text;

  r := public.send_table_cart('test-slug-1', jsonb_build_array(jsonb_build_object('menu_item_id', ia, 'qty', 2)));
  assert (r->>'ok')::boolean, 'a good order must go through: ' || r::text;
  oid := (r->>'order_id')::uuid;

  r := public.set_order_status(oid, 'preparing');
  assert not (r->>'ok')::boolean, 'a guest must not change the kitchen status';

  r := public.request_bill('test-slug-1');
  r2 := public.request_bill('test-slug-1');
  assert (r->>'ok')::boolean and (r2->>'ok')::boolean, 'bill request failed: ' || r::text;

  update public.dining_tables set number = 'hacked' where id = tid;
  get diagnostics n = row_count;
  assert n = 0, 'a guest must not edit the table row';

  begin
    insert into public.orders (restaurant_id, table_id, status) values (rid, tid, 'served');
    assert false, 'a guest must not insert orders directly';
  exception when insufficient_privilege then
    null;
  end;

  begin
    perform public.dev_wipe_menu('x');
    assert false, 'anonymous callers must not reach the developer tools';
  exception when insufficient_privilege then
    null;
  end;

  execute 'reset role';
  select status into st from public.dining_tables where id = tid;
  assert st = 'billRequested', 'table must wait for the bill, is ' || st;
  select count(*) into n from public.staff_calls where table_id = tid and kind = 'bill' and not resolved;
  assert n = 1, 'two bill requests must open one bill call, got ' || n;

  -- ---------------------------------------------------------------- cashier
  insert into public.cashiers (restaurant_id, name, initials, pin_hash) values (rid, 'Z', 'Z', 'x') returning id into cid;
  insert into public.cashier_sessions (cashier_id, restaurant_id, token_hash, expires_at)
  values (cid, rid, encode(extensions.digest('test-token', 'sha256'), 'hex'), now() + interval '1 hour');
  perform set_config('request.headers', json_build_object('x-cashier-token', 'test-token')::text, true);
  execute 'set local role anon';

  r := public.set_order_status(oid, 'ready');
  assert r->>'error' = 'invalid status change', 'skipping a kitchen step must be refused: ' || r::text;
  r := public.set_order_status(oid, 'preparing');
  r2 := public.set_order_status(oid, 'ready');
  assert (r->>'ok')::boolean and (r2->>'ok')::boolean, 'one step at a time must work';

  r := public.settle_cash(tid, 100, true, null);
  assert r->>'error' = 'order is not served', 'an unserved order must not be settled: ' || r::text;
  r := public.set_order_status(oid, 'served');
  assert (r->>'ok')::boolean, 'serving failed: ' || r::text;

  r := public.open_shift();
  r2 := public.open_shift();
  sid := (r->>'shift_id')::uuid;
  assert sid is not null and r->>'shift_id' = r2->>'shift_id', 'open_shift must reuse the open shift';
  r := public.set_opening_cash(50);
  assert (r->>'ok')::boolean, 'opening float failed: ' || r::text;

  update public.shifts set cash_sales = 999999 where id = sid;
  get diagnostics n = row_count;
  assert n = 0, 'a cashier device must not edit shift totals';
  update public.order_lines set unit_price = 0 where order_id = oid;
  get diagnostics n = row_count;
  assert n = 0, 'a cashier device must not edit line prices';

  execute 'reset role';
  -- A dish left unsent in the cart at payment time.
  insert into public.carts (table_id, restaurant_id) values (tid, rid) on conflict do nothing;
  insert into public.cart_lines (table_id, restaurant_id, menu_item_id, name, qty, unit_price) values (tid, rid, ia, 'x', 5, 0);
  execute 'set local role anon';
  r := public.settle_cash(tid, 100, true, null);
  assert (r->>'ok')::boolean, 'settle failed: ' || r::text;
  assert (r->>'total_due')::numeric = 22.00, 'due must be 2 x 10 + 10% service, unsent dishes free, got ' || (r->>'total_due');

  execute 'reset role';
  select count(*) into n from public.cart_lines where table_id = tid;
  assert n = 0, 'settling must clear the cart';
  select cash_sales::text into st from public.shifts where id = sid;
  assert st = '22.00', 'shift sales must be 22.00, got ' || st;

  -- A refused dish is removed as one line.
  perform set_config('request.headers', json_build_object('x-qr-slug', 'test-slug-1')::text, true);
  execute 'set local role anon';
  r := public.send_table_cart('test-slug-1', jsonb_build_array(jsonb_build_object('menu_item_id', ia, 'qty', 1)));
  oid2 := (r->>'order_id')::uuid;
  execute 'reset role';
  select id into lid from public.order_lines where order_id = oid2 limit 1;
  perform set_config('request.headers', json_build_object('x-cashier-token', 'test-token')::text, true);
  execute 'set local role anon';
  r := public.remove_order_line(lid);
  assert (r->>'ok')::boolean, 'remove line failed: ' || r::text;
  r := public.close_shift(10);
  assert (r->>'ok')::boolean, 'close shift failed: ' || r::text;
  perform public.cashier_logout();
  execute 'reset role';
  select count(*) into n from public.order_lines where order_id = oid2;
  assert n = 0, 'the refused line must be gone';
  select count(*) into n from public.cashier_sessions where cashier_id = cid;
  assert n = 0, 'sign-out must end the cashier session';
  select actual_cash::text into st from public.shifts where id = sid and closed_at is not null;
  assert st = '10.00', 'shift must close with the counted cash';

  -- ---------------------------------------------------------------- developer tools
  select p.id into dev from public.profiles p join public.restaurants rr on rr.id = p.restaurant_id where rr.slot = 1;
  select failed_attempts into fa from public.dev_access limit 1;

  perform set_config('request.jwt.claims', json_build_object('sub', stranger, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
  assert not public.check_dev_access('devpw'), 'a stranger must be refused even with the right password';
  r := public.dev_list_slots('devpw');
  assert not (r->>'ok')::boolean, 'a stranger must not list slots';
  execute 'reset role';
  select failed_attempts into n from public.dev_access limit 1;
  assert n = fa, 'strangers must not move the lockout counter';

  perform set_config('request.jwt.claims', json_build_object('sub', dev, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
  assert not public.check_dev_access('nope'), 'the wrong password must be refused';
  assert public.check_dev_access('devpw'), 'the developer with the right password must get in';
  r := public.dev_list_slots('devpw');
  assert (r->>'ok')::boolean, 'the developer must list slots';
  perform set_config('request.headers', json_build_object('x-dev-slot', '1')::text, true);
  r := public.dev_reset_admin('devpw');
  assert not (r->>'ok')::boolean, 'the developer account must not be removable from the app';
  execute 'reset role';

  raise notice 'security_and_money_fixes_test: all checks passed';
end $test$;

rollback;
