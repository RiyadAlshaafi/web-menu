-- Checks 20261027110000_refund_line.sql as a signed-in cashier device: a cashier refunds part of
-- their own sale on an open shift with a reason; the amount is the dish's share and the last
-- refund takes what is left; the shift's sales drop and a cash refund leaves the drawer; a card
-- refund does not touch the drawer; too many, another cashier's sale, a missing reason or a
-- closed shift are refused; a later void takes only the rest; the admin's reports count it.
-- Run by tool/test_db.sh. Everything is rolled back; any failed check aborts with its message.

begin;

do $test$
declare
  r jsonb;
  rid uuid;
  admin_a uuid;
  cat uuid;
  tea uuid;
  cake uuid;
  card uuid;
  cid uuid;
  cid2 uuid;
  sid uuid;
  pid uuid;
  card_pid uuid;
  tea_line uuid;
  cake_line uuid;
  card_line uuid;
  sales numeric;
  drawer_out numeric;
  n integer;
begin
  insert into public.restaurants (name) values ('refund cafe') returning id into rid;
  alter table auth.users disable trigger user;
  insert into auth.users (email) values ('a@refund.test') returning id into admin_a;
  alter table auth.users enable trigger user;
  insert into public.profiles (id, restaurant_id) values (admin_a, rid);
  insert into public.menu_categories (restaurant_id, name_en, name_ar) values (rid, 'C', 'C') returning id into cat;
  insert into public.menu_items (restaurant_id, category_id, name_en, price) values (rid, cat, 'Tea', 2) returning id into tea;
  insert into public.menu_items (restaurant_id, category_id, name_en, price) values (rid, cat, 'Cake', 5) returning id into cake;
  insert into public.payment_types (restaurant_id, name_en, name_ar, sort_order) values (rid, 'Card', 'بطاقة', 1) returning id into card;
  insert into public.cashiers (restaurant_id, name, initials, pin_hash) values (rid, 'V', 'V', 'x') returning id into cid;
  insert into public.cashiers (restaurant_id, name, initials, pin_hash) values (rid, 'W', 'W', 'x') returning id into cid2;
  insert into public.cashier_sessions (cashier_id, restaurant_id, token_hash, expires_at)
  values (cid, rid, encode(extensions.digest('refund-token', 'sha256'), 'hex'), now() + interval '1 hour');
  insert into public.cashier_sessions (cashier_id, restaurant_id, token_hash, expires_at)
  values (cid2, rid, encode(extensions.digest('refund-token-2', 'sha256'), 'hex'), now() + interval '1 hour');

  -- A cash sale of 3 tea + 1 cake (11) and a card sale of 1 tea (2).
  perform set_config('request.headers', json_build_object('x-cashier-token', 'refund-token')::text, true);
  execute 'set local role anon';
  r := public.open_shift();
  sid := (r->>'shift_id')::uuid;
  assert sid is not null, 'open_shift failed: ' || r::text;
  r := public.quick_takeout_receipt(jsonb_build_array(
    jsonb_build_object('menu_item_id', tea, 'qty', 3), jsonb_build_object('menu_item_id', cake, 'qty', 1)), null);
  assert (r->>'ok')::boolean, 'takeout failed: ' || r::text;
  r := public.quick_takeout_receipt(jsonb_build_array(jsonb_build_object('menu_item_id', tea, 'qty', 1)), card);
  assert (r->>'ok')::boolean, 'card takeout failed: ' || r::text;
  execute 'reset role';
  select id into pid from public.payments where shift_id = sid and total_due = 11;
  select id into card_pid from public.payments where shift_id = sid and total_due = 2;
  select l.id into tea_line from public.order_lines l join public.payments p on p.order_id = l.order_id where p.id = pid and l.menu_item_id = tea;
  select l.id into cake_line from public.order_lines l join public.payments p on p.order_id = l.order_id where p.id = pid and l.menu_item_id = cake;
  select l.id into card_line from public.order_lines l join public.payments p on p.order_id = l.order_id where p.id = card_pid;

  -- ------------------------------------------------ refusals that change nothing
  execute 'set local role anon';
  r := public.refund_payment_line(pid, tea_line, 1, '  ');
  assert r->>'error' = 'reason required', 'a blank reason: ' || r::text;
  r := public.refund_payment_line(pid, tea_line, 4, 'cold');
  assert r->>'error' = 'too many', 'more than was sold: ' || r::text;
  r := public.refund_payment_line(pid, card_line, 1, 'cold');
  assert r->>'error' = 'not_found', 'a line of another sale: ' || r::text;
  perform set_config('request.headers', json_build_object('x-cashier-token', 'refund-token-2')::text, true);
  r := public.refund_payment_line(pid, tea_line, 1, 'cold');
  assert r->>'error' = 'not_found', 'another cashier''s sale: ' || r::text;
  perform set_config('request.headers', json_build_object('x-cashier-token', 'refund-token')::text, true);
  execute 'reset role';
  select count(*) into n from public.payments where id = pid and refunded_total = 0 and refunds = '[]'::jsonb;
  assert n = 1, 'refused refunds must leave the sale untouched';

  -- ------------------------------------------------ one tea back, in cash
  execute 'set local role anon';
  r := public.refund_payment_line(pid, tea_line, 1, '  cold tea ');
  execute 'reset role';
  assert (r->>'ok')::boolean and (r->>'amount')::numeric = 2, 'one tea is 2: ' || r::text;
  select cash_sales, cash_refunds into sales, drawer_out from public.shifts where id = sid;
  assert sales = 11 and drawer_out = 2, 'sales 13 - 2 and 2 out of the drawer, got ' || sales || ' / ' || drawer_out;
  select count(*) into n from public.payments
  where id = pid and refunded_total = 2 and refunds->0->>'reason' = 'cold tea' and refunds->0->>'by' = cid::text;
  assert n = 1, 'the refund, its trimmed reason and who did it are kept on the sale';

  execute 'set local role anon';
  r := public.refund_payment_line(pid, tea_line, 3, 'more');
  assert r->>'error' = 'too many', 'only 2 tea are left: ' || r::text;
  execute 'reset role';

  -- ------------------------------------------------ a card refund leaves the drawer alone
  execute 'set local role anon';
  r := public.refund_payment_line(card_pid, card_line, 1, 'spilt');
  execute 'reset role';
  assert (r->>'amount')::numeric = 2, 'the whole card sale: ' || r::text;
  select cash_sales, cash_refunds into sales, drawer_out from public.shifts where id = sid;
  assert sales = 9 and drawer_out = 2, 'card refund: sales drop, drawer does not, got ' || sales || ' / ' || drawer_out;

  -- ------------------------------------------------ the reports count it
  perform set_config('request.jwt.claim.sub', admin_a::text, true);
  execute 'set local role authenticated';
  r := public.admin_sales_report(current_date - 1, current_date + 1);
  assert (r->>'sales_total')::numeric = 9 and (r->>'refund_total')::numeric = 4 and (r->>'refund_count')::int = 2,
    'the report is net of refunds: ' || r::text;
  r := public.admin_dish_sales(current_date - 1, current_date + 1);
  assert (select (d->>'qty')::int from jsonb_array_elements(r->'dishes') d where d->>'id' = tea::text) = 2,
    '4 tea sold, 2 given back: ' || r::text;
  execute 'reset role';
  perform set_config('request.jwt.claim.sub', '', true);

  -- ------------------------------------------------ a void takes only the rest
  execute 'set local role anon';
  r := public.void_payment(pid, 'left');
  execute 'reset role';
  assert (r->>'ok')::boolean, 'void failed: ' || r::text;
  select cash_sales, cash_refunds into sales, drawer_out from public.shifts where id = sid;
  assert sales = 0 and drawer_out = 0, 'after the void nothing of the cash sale counts twice, got ' || sales || ' / ' || drawer_out;

  -- ------------------------------------------------ a closed shift can't be changed
  execute 'set local role anon';
  r := public.close_shift(0);
  assert (r->>'ok')::boolean, 'close failed: ' || r::text;
  r := public.refund_payment_line(card_pid, card_line, 1, 'late');
  assert r->>'error' = 'shift closed', 'a closed shift: ' || r::text;
  execute 'reset role';

  raise notice 'refund_line_test: all checks passed';
end $test$;

rollback;
