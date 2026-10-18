-- Checks 20261018120000_void_payment.sql as a signed-in cashier device: a cashier voids their own
-- sale on an open shift with a reason, the shift total drops, the order stays paid, and a second
-- void, another cashier's void, a missing reason or a closed shift are refused.
-- Run by tool/test_db.sh. Everything is rolled back; any failed check aborts with its message.

begin;

do $test$
declare
  r jsonb;
  rid uuid;
  cat uuid;
  tea uuid;
  cid uuid;
  cid2 uuid;
  sid uuid;
  pid uuid;
  oid uuid;
  sales numeric;
  count_n integer;
  n integer;
begin
  insert into public.restaurants (name) values ('void cafe') returning id into rid;
  insert into public.menu_categories (restaurant_id, name_en, name_ar) values (rid, 'C', 'C') returning id into cat;
  insert into public.menu_items (restaurant_id, category_id, name_en, price) values (rid, cat, 'Tea', 5) returning id into tea;
  insert into public.cashiers (restaurant_id, name, initials, pin_hash) values (rid, 'V', 'V', 'x') returning id into cid;
  insert into public.cashiers (restaurant_id, name, initials, pin_hash) values (rid, 'W', 'W', 'x') returning id into cid2;
  insert into public.cashier_sessions (cashier_id, restaurant_id, token_hash, expires_at)
  values (cid, rid, encode(extensions.digest('void-token', 'sha256'), 'hex'), now() + interval '1 hour');
  insert into public.cashier_sessions (cashier_id, restaurant_id, token_hash, expires_at)
  values (cid2, rid, encode(extensions.digest('void-token-2', 'sha256'), 'hex'), now() + interval '1 hour');

  perform set_config('request.headers', json_build_object('x-cashier-token', 'void-token')::text, true);
  execute 'set local role anon';
  r := public.open_shift();
  sid := (r->>'shift_id')::uuid;
  assert sid is not null, 'open_shift failed: ' || r::text;
  r := public.quick_takeout_receipt(jsonb_build_array(jsonb_build_object('menu_item_id', tea, 'qty', 2)), null);
  assert (r->>'ok')::boolean, 'takeout failed: ' || r::text;
  r := public.quick_takeout_receipt(jsonb_build_array(jsonb_build_object('menu_item_id', tea, 'qty', 1)), null);
  assert (r->>'ok')::boolean, 'second takeout failed: ' || r::text;
  execute 'reset role';
  select id, order_id into pid, oid from public.payments where shift_id = sid and total_due = 10;

  -- ------------------------------------------------ refusals that change nothing
  execute 'set local role anon';
  r := public.void_payment(pid, '   ');
  assert r->>'error' = 'reason required', 'a blank reason must be refused: ' || r::text;
  perform set_config('request.headers', json_build_object('x-cashier-token', 'void-token-2')::text, true);
  r := public.void_payment(pid, 'left');
  assert r->>'error' = 'not_found', 'another cashier must not void the sale: ' || r::text;
  perform set_config('request.headers', json_build_object('x-cashier-token', 'void-token')::text, true);
  execute 'reset role';
  select count(*) into n from public.payments where id = pid and voided_at is null;
  assert n = 1, 'refused voids must leave the payment untouched';

  -- ------------------------------------------------ the void
  execute 'set local role anon';
  r := public.void_payment(pid, '  Customer left, cold food  ');
  assert (r->>'ok')::boolean, 'void failed: ' || r::text;
  r := public.void_payment(pid, 'again');
  assert r->>'error' = 'already voided', 'a second void must be refused: ' || r::text;
  execute 'reset role';
  select count(*) into n from public.payments
  where id = pid and voided_at is not null and voided_by = cid and void_reason = 'Customer left, cold food';
  assert n = 1, 'the payment must carry the void, who did it and the trimmed reason';
  select cash_sales, transaction_count into sales, count_n from public.shifts where id = sid;
  assert sales = 5 and count_n = 1, 'the shift keeps only the other sale, got ' || sales || ' / ' || count_n;
  select count(*) into n from public.orders where id = oid and status = 'paid';
  assert n = 1, 'the order stays paid so no table reopens';

  -- ------------------------------------------------ a closed shift can't be changed
  execute 'set local role anon';
  r := public.close_shift(5);
  assert (r->>'ok')::boolean, 'close failed: ' || r::text;
  select id into pid from public.payments where shift_id = sid and voided_at is null;
  r := public.void_payment(pid, 'late');
  assert r->>'error' = 'shift closed', 'a closed shift''s sale must not be voided: ' || r::text;
  execute 'reset role';

  raise notice 'void_payment_test: all checks passed';
end;
$test$;

rollback;
