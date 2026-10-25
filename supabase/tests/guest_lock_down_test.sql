-- Checks 20261014110000_guest_lock_down.sql: a guest (anon, even with its table's QR slug
-- header, as the Flutter guest page sent it) can no longer read or write any table directly,
-- while a signed-in cashier still sees their cafe and the guest functions still work.
-- Run by tool/test_db.sh. Everything is rolled back; any failed check aborts with its message.

begin;

do $test$
declare
  r jsonb;
  rid uuid;
  tid uuid;
  cat uuid;
  ia uuid;
  cid uuid;
  t text;
  n integer;
  denied boolean;
begin
  insert into public.restaurants (name) values ('lock cafe') returning id into rid;
  insert into public.dining_tables (restaurant_id, number, qr_slug) values (rid, 'L1', 'lock-slug-1') returning id into tid;
  insert into public.menu_categories (restaurant_id, name_en, name_ar) values (rid, 'C', 'C') returning id into cat;
  insert into public.menu_items (restaurant_id, category_id, name_en, price) values (rid, cat, 'Tea', 5) returning id into ia;
  insert into public.payment_types (restaurant_id, name_en, name_ar) values (rid, 'Card', 'بطاقة');
  insert into public.cashiers (restaurant_id, name, initials, pin_hash) values (rid, 'Ali', 'A', 'x') returning id into cid;
  insert into public.cashier_sessions (cashier_id, restaurant_id, token_hash, expires_at)
    values (cid, rid, encode(extensions.digest('lock-token', 'sha256'), 'hex'), now() + interval '1 hour');
  insert into public.staff_calls (restaurant_id, table_id) values (rid, tid);
  insert into public.orders (restaurant_id, table_id, status) values (rid, tid, 'received');

  -- ---------------------------------------------------------------- guest: nothing readable
  perform set_config('request.headers', json_build_object('x-qr-slug', 'lock-slug-1')::text, true);
  execute 'set local role anon';
  for t in
    select c.relname from pg_class c join pg_namespace s on s.oid = c.relnamespace
    where s.nspname = 'public' and c.relkind in ('r', 'p', 'v', 'm')
    order by 1
  loop
    begin
      execute format('select count(*) from public.%I', t) into n;
    exception when insufficient_privilege then
      n := 0;
    end;
    assert n = 0, 'a guest must not read public.' || t || ' directly, saw ' || n || ' rows';
  end loop;

  -- ---------------------------------------------------------------- guest: no direct writes
  denied := false;
  begin
    insert into public.staff_calls (restaurant_id, table_id) values (rid, tid);
  exception when insufficient_privilege then denied := true;
  end;
  assert denied, 'a guest must not insert a staff call directly';

  denied := false;
  begin
    insert into public.carts (restaurant_id, table_id) values (rid, tid);
  exception when insufficient_privilege or not_null_violation or foreign_key_violation then denied := true;
  end;
  assert denied, 'a guest must not create a cart directly';

  update public.dining_tables set status = 'billRequested' where id = tid;
  get diagnostics n = row_count;
  assert n = 0, 'a guest must not update a table directly';
  update public.orders set status = 'paid' where table_id = tid;
  get diagnostics n = row_count;
  assert n = 0, 'a guest must not update an order directly';
  delete from public.order_lines;
  get diagnostics n = row_count;
  assert n = 0, 'a guest must not delete order lines';

  -- ---------------------------------------------------------------- guest functions still work
  r := public.guest_menu('lock-slug-1');
  assert (r->>'ok')::boolean and jsonb_array_length(r->'items') = 1, 'menu through the function: ' || r::text;
  assert jsonb_array_length(r->'payment_types') >= 1, 'payment types through the function';
  r := public.guest_tab('lock-slug-1');
  assert r->'order'->>'status' = 'received', 'tab through the function: ' || r::text;
  r := public.send_table_cart('lock-slug-1', jsonb_build_array(jsonb_build_object('menu_item_id', ia, 'qty', 1)));
  assert (r->>'ok')::boolean, 'ordering through the function: ' || r::text;
  -- A guest's bill needs a served order and a payment type when the cafe has any.
  execute 'reset role';
  update public.orders set status = 'served',
    payment_type_id = (select p.id from public.payment_types p where p.restaurant_id = orders.restaurant_id and p.enabled and not p.archived limit 1)
    where table_id = tid and status <> 'paid';
  execute 'set local role anon';
  r := public.request_bill('lock-slug-1');
  assert (r->>'ok')::boolean, 'bill through the function: ' || r::text;

  -- ---------------------------------------------------------------- cashier unchanged
  execute 'reset role';
  perform set_config('request.headers', json_build_object('x-cashier-token', 'lock-token')::text, true);
  execute 'set local role anon';
  select count(*) into n from public.restaurants where id = rid;
  assert n = 1, 'a cashier still reads the cafe';
  select count(*) into n from public.menu_items where restaurant_id = rid;
  assert n = 1, 'a cashier still reads the menu';
  select count(*) into n from public.orders where table_id = tid;
  assert n = 1, 'a cashier still reads orders';
  select count(*) into n from public.staff_calls where table_id = tid;
  assert n >= 1, 'a cashier still reads staff calls';
  select count(*) into n from public.payment_types where restaurant_id = rid;
  assert n >= 1, 'a cashier still reads payment types';
  execute 'reset role';

  raise notice 'guest_lock_down_test: all checks passed';
end $test$;

rollback;
