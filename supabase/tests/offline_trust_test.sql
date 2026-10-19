-- Checks 20261019120000_offline_sync_trust_server.sql as a signed-in cashier device: offline
-- uploads are booked to the signed-in cashier and their own shift, use menu prices, and can't
-- be dated in the future or before their receipt number was reserved.
-- Run by tool/test_db.sh. Everything is rolled back; any failed check aborts with its message.

begin;

do $test$
declare
  r jsonb;
  b jsonb;
  rid uuid;
  cat uuid;
  tea uuid;
  cid uuid;
  cid2 uuid;
  shift_b uuid;
  oid uuid;
  n integer;
  due numeric;
  at timestamptz;
  yymm text := to_char(now() at time zone 'Africa/Tripoli', 'YYMM');
  today text := to_char(now() at time zone 'Africa/Tripoli', 'YYMMDD');
begin
  insert into public.restaurants (name) values ('offline trust cafe') returning id into rid;
  insert into public.menu_categories (restaurant_id, name_en, name_ar) values (rid, 'C', 'C') returning id into cat;
  insert into public.menu_items (restaurant_id, category_id, name_en, price) values (rid, cat, 'Tea', 5) returning id into tea;
  insert into public.cashiers (restaurant_id, name, initials, pin_hash) values (rid, 'A', 'A', 'x') returning id into cid;
  insert into public.cashiers (restaurant_id, name, initials, pin_hash) values (rid, 'B', 'B', 'x') returning id into cid2;
  insert into public.cashier_sessions (cashier_id, restaurant_id, token_hash, expires_at)
  values (cid, rid, encode(extensions.digest('trust-token', 'sha256'), 'hex'), now() + interval '1 hour');
  insert into public.shifts (restaurant_id, cashier_id, opening_cash) values (rid, cid2, 0) returning id into shift_b;
  perform set_config('request.headers', json_build_object('x-cashier-token', 'trust-token')::text, true);

  execute 'set local role anon';
  b := public.reserve_receipt_numbers(5, 0);
  assert (b->>'ok')::boolean, 'reserve failed: ' || b::text;

  -- ------------------------------------------------ a colleague's name is refused, nothing is booked
  r := public.sync_offline_takeout(
    gen_random_uuid(), cid2, shift_b,
    jsonb_build_array(jsonb_build_object('menu_item_id', tea::text, 'name', 'Tea', 'qty', 1, 'unit_price', 5)),
    null, now(), yymm, (b->>'first')::integer, today, null);
  assert r->>'error' = 'offline work belongs to another cashier', 'a sale booked to a colleague must be refused: ' || r::text;
  r := public.sync_offline_expense(gen_random_uuid(), cid2, shift_b,
    (select id from public.expense_categories where restaurant_id = rid limit 1), 10, 'x', now());
  assert r->>'error' = 'offline work belongs to another cashier', 'an expense booked to a colleague must be refused: ' || r::text;
  r := public.sync_offline_shift_open(gen_random_uuid(), cid2, now());
  assert r->>'error' = 'offline work belongs to another cashier', 'a colleague''s shift open must be refused: ' || r::text;
  r := public.sync_offline_shift_close(shift_b, cid2, 0, now());
  assert r->>'error' = 'offline work belongs to another cashier', 'a colleague''s shift close must be refused: ' || r::text;

  -- ------------------------------------------------ own sale: menu price, own shift, sane time
  r := public.sync_offline_takeout(
    gen_random_uuid(), cid, shift_b,
    jsonb_build_array(jsonb_build_object('menu_item_id', tea::text, 'name', 'Tea', 'qty', 2, 'unit_price', 0.5)),
    null, now() + interval '3 days', yymm, (b->>'first')::integer + 1, today, null);
  assert (r->>'ok')::boolean, 'own offline sale must upload: ' || r::text;
  assert (r->>'total_due')::numeric = 10, 'the sale must use the menu price 2 x 5, got ' || (r->>'total_due');
  assert (r->>'shift_id')::uuid <> shift_b, 'the sale must not land on a colleague''s shift';
  oid := (r->>'order_id')::uuid;

  -- a sale dated long before its number was reserved is dated at the reservation
  r := public.sync_offline_takeout(
    gen_random_uuid(), cid, null,
    jsonb_build_array(jsonb_build_object('menu_item_id', tea::text, 'name', 'Tea', 'qty', 1, 'unit_price', 5)),
    null, '2000-01-01', yymm, (b->>'first')::integer + 2, today, null);
  assert (r->>'ok')::boolean, 'an old-dated offline sale must still upload: ' || r::text;
  execute 'reset role';

  select total_due, paid_at into due, at from public.payments where order_id = oid;
  assert due = 10, 'the payment must carry the menu total';
  assert at <= now(), 'a sale must not be dated in the future';
  select count(*) into n from public.payments p
  where p.order_id = oid and p.cashier_id = cid
    and p.shift_id in (select id from public.shifts where cashier_id = cid);
  assert n = 1, 'the payment must be booked to the signed-in cashier and their shift';
  select count(*) into n from public.payments
  where order_id = (r->>'order_id')::uuid and paid_at >= (select min(created_at) from public.receipt_blocks where restaurant_id = rid);
  assert n = 1, 'a sale must not be dated before its receipt number was reserved';
  select cash_sales into due from public.shifts where id = shift_b;
  assert due = 0, 'the colleague''s shift total must be untouched';

  -- ------------------------------------------------ closing can't reach a colleague's shift
  execute 'set local role anon';
  r := public.sync_offline_shift_close(shift_b, cid, 99, now());
  execute 'reset role';
  select count(*) into n from public.shifts where id = shift_b and closed_at is null;
  assert n = 1, 'a colleague''s open shift must stay open';

  raise notice 'offline_trust_test: all checks passed';
end;
$test$;

rollback;
