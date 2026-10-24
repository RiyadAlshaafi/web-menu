-- Checks 20261026120000_sales_report.sql: the admin's report counts Tripoli calendar days (a sale
-- at 23:30 Tripoli is that day, 00:30 the next), keeps voided sales apart, never counts voided
-- expenses, counts an edited expense once, groups by payment type, expense type and employee,
-- returns zeros for an empty range, and only ever reads the admin's own cafe. A till can't call it.
-- Run by tool/test_db.sh. Everything is rolled back; any failed check aborts with its message.

begin;

do $test$
declare
  r jsonb;
  rid uuid;
  other uuid;
  admin_a uuid;
  admin_b uuid;
  cid uuid;
  chef uuid;
  sid uuid;
  osid uuid;
  ocid uuid;
  ord uuid;
  ord2 uuid;
  ord3 uuid;
  ord4 uuid;
  cash uuid;
  card uuid;
  cafe_cat uuid;
  wd_cat uuid;
  old_copy uuid;
  blocked boolean;
begin
  insert into public.restaurants (name) values ('report cafe') returning id into rid;
  insert into public.restaurants (name) values ('report other cafe') returning id into other;
  alter table auth.users disable trigger user;
  insert into auth.users (email) values ('a@report.test') returning id into admin_a;
  insert into auth.users (email) values ('b@report.test') returning id into admin_b;
  alter table auth.users enable trigger user;
  insert into public.profiles (id, restaurant_id) values (admin_a, rid), (admin_b, other);

  insert into public.cashiers (restaurant_id, name, initials, pin_hash) values (rid, 'Sara', 'S', 'x') returning id into cid;
  insert into public.cashiers (restaurant_id, name, initials, pin_hash, role) values (rid, 'Chef Omar', 'O', '', 'chef') returning id into chef;
  insert into public.cashier_sessions (cashier_id, restaurant_id, token_hash, expires_at)
    values (cid, rid, encode(extensions.digest('report-token', 'sha256'), 'hex'), now() + interval '1 hour');
  insert into public.shifts (restaurant_id, cashier_id, opening_cash) values (rid, cid, 0) returning id into sid;
  insert into public.payment_types (restaurant_id, name_en, name_ar, sort_order) values (rid, 'Cash', 'نقداً', 0) returning id into cash;
  insert into public.payment_types (restaurant_id, name_en, name_ar, sort_order) values (rid, 'Card', 'بطاقة', 1) returning id into card;
  insert into public.expense_categories (restaurant_id, name_en, name_ar, sort_order) values (rid, 'Café Expense', 'مصروف', 0) returning id into cafe_cat;
  insert into public.expense_categories (restaurant_id, name_en, name_ar, sort_order) values (rid, 'Cash Withdrawal', 'سحب', 1) returning id into wd_cat;
  insert into public.orders (restaurant_id, table_id, status, service_type) values (rid, null, 'paid', 'takeout') returning id into ord;
  insert into public.orders (restaurant_id, table_id, status, service_type) values (rid, null, 'paid', 'takeout') returning id into ord2;
  insert into public.orders (restaurant_id, table_id, status, service_type) values (rid, null, 'paid', 'takeout') returning id into ord3;
  insert into public.orders (restaurant_id, table_id, status, service_type) values (rid, null, 'paid', 'takeout') returning id into ord4;

  -- Sales (one per order). Tripoli is UTC+2: 21:30 UTC on the 24th is 23:30 there (the 24th); 22:30 UTC is
  -- 00:30 on the 25th; 22:10 UTC on the 23rd is 00:10 on the 24th.
  insert into public.payments (restaurant_id, order_id, total_due, cash_received, change_due, cashier_id, shift_id, client_id, paid_at, payment_type_id)
  values
    (rid, ord, 20, 20, 0, cid, sid, gen_random_uuid(), '2026-10-24 21:30+00', cash),
    (rid, ord2, 8, 8, 0, cid, sid, gen_random_uuid(), '2026-10-24 22:30+00', cash),
    (rid, ord3, 15, 15, 0, cid, sid, gen_random_uuid(), '2026-10-23 22:10+00', card);
  insert into public.payments (restaurant_id, order_id, total_due, cash_received, change_due, cashier_id, shift_id, client_id, paid_at, payment_type_id, voided_at, void_reason)
  values (rid, ord4, 50, 50, 0, cid, sid, gen_random_uuid(), '2026-10-24 10:00+00', cash, '2026-10-24 10:05+00', 'wrong table');

  -- Expenses on the 24th (Tripoli): a cafe expense, an older one with no category (counts as
  -- the cafe's "Café Expense"), a withdrawal paid to Sara, a voided one, and one edited once
  -- (the old copy voided) tagged with the chef. One more on the 25th.
  insert into public.shift_expenses (restaurant_id, shift_id, cashier_id, paid_to_cafe, amount, description, kind, expense_category_id, client_id, created_at)
  values (rid, sid, cid, true, 10, 'milk', 'cash_out', cafe_cat, gen_random_uuid(), '2026-10-24 09:00+00');
  insert into public.shift_expenses (restaurant_id, shift_id, cashier_id, paid_to_cafe, amount, description, kind, client_id, created_at)
  values (rid, sid, cid, true, 5, 'old row', 'cash_out', gen_random_uuid(), '2026-10-24 09:30+00');
  insert into public.shift_expenses (restaurant_id, shift_id, cashier_id, paid_to_cafe, paid_to_cashier_id, paid_to_cashier_name, amount, description, kind, expense_category_id, client_id, created_at)
  values (rid, sid, cid, false, cid, 'Sara', 30, 'advance', 'cash_out', wd_cat, gen_random_uuid(), '2026-10-24 11:00+00');
  insert into public.shift_expenses (restaurant_id, shift_id, cashier_id, paid_to_cafe, amount, description, kind, expense_category_id, client_id, created_at, voided)
  values (rid, sid, cid, true, 99, 'voided', 'cash_out', cafe_cat, gen_random_uuid(), '2026-10-24 12:00+00', true);
  insert into public.shift_expenses (restaurant_id, shift_id, cashier_id, paid_to_cafe, staff_id, staff_name, amount, description, kind, expense_category_id, client_id, created_at, voided)
  values (rid, sid, cid, true, chef, 'Chef Omar', 40, 'chef', 'cash_out', cafe_cat, gen_random_uuid(), '2026-10-24 13:00+00', true)
  returning id into old_copy;
  insert into public.shift_expenses (restaurant_id, shift_id, cashier_id, paid_to_cafe, staff_id, staff_name, amount, description, kind, expense_category_id, client_id, created_at, edited_from)
  values (rid, sid, cid, true, chef, 'Chef Omar', 45, 'chef fixed', 'cash_out', cafe_cat, gen_random_uuid(), '2026-10-24 13:05+00', old_copy);
  insert into public.shift_expenses (restaurant_id, shift_id, cashier_id, paid_to_cafe, amount, description, kind, expense_category_id, client_id, created_at)
  values (rid, sid, cid, true, 7, 'next day', 'cash_out', cafe_cat, gen_random_uuid(), '2026-10-24 22:30+00');

  -- The other cafe sold the same day; it must never show up.
  insert into public.cashiers (restaurant_id, name, initials, pin_hash) values (other, 'Ali', 'A', 'x') returning id into ocid;
  insert into public.shifts (restaurant_id, cashier_id, opening_cash) values (other, ocid, 0) returning id into osid;
  insert into public.orders (restaurant_id, table_id, status, service_type) values (other, null, 'paid', 'takeout') returning id into ord;
  insert into public.payments (restaurant_id, order_id, total_due, cash_received, change_due, cashier_id, shift_id, client_id, paid_at)
  values (other, ord, 1000, 1000, 0, ocid, osid, gen_random_uuid(), '2026-10-24 12:00+00');

  -- ---------------------------------------------------------------- the admin's day
  perform set_config('request.jwt.claim.sub', admin_a::text, true);
  execute 'set local role authenticated';
  r := public.admin_sales_report('2026-10-24', '2026-10-24');
  execute 'reset role';
  assert (r->>'ok')::boolean, 'the report works: ' || r::text;
  assert (r->>'sales_count')::int = 2 and (r->>'sales_total')::numeric = 35,
    'the 23:30 and 00:10 sales are the 24th, the 00:30 one is not: ' || r::text;
  assert (r->>'void_count')::int = 1 and (r->>'void_total')::numeric = 50, 'the void is counted apart: ' || r::text;
  assert (select (m->>'total')::numeric from jsonb_array_elements(r->'by_method') m where m->>'id' = cash::text) = 20, 'cash: ' || r::text;
  assert (select (m->>'total')::numeric from jsonb_array_elements(r->'by_method') m where m->>'id' = card::text) = 15, 'card: ' || r::text;
  assert (select sum((g->>'total')::numeric) from jsonb_array_elements(r->'expenses') g) = 90,
    'expenses 10 + 5 + 30 + 45: the voided one never counts and the edit counts once: ' || r::text;
  assert (select sum((g->>'total')::numeric) from jsonb_array_elements(r->'expenses') g where g->>'type_id' = cafe_cat::text) = 60,
    'the row with no category counts as a cafe expense: ' || r::text;
  assert (select sum((g->>'total')::numeric) from jsonb_array_elements(r->'expenses') g where g->>'employee_id' = chef::text) = 45, 'the chef: ' || r::text;
  assert (select g->>'employee' from jsonb_array_elements(r->'expenses') g where g->>'employee_id' = cid::text) = 'Sara', 'named: ' || r::text;
  assert (select sum((g->>'total')::numeric) from jsonb_array_elements(r->'expenses') g where g->'employee_id' = 'null'::jsonb) = 15,
    'no employee: ' || r::text;

  -- two days: the 25th adds its sale and its expense
  execute 'set local role authenticated';
  r := public.admin_sales_report('2026-10-24', '2026-10-25');
  execute 'reset role';
  assert (r->>'sales_total')::numeric = 43, 'two days: ' || r::text;
  assert (select sum((g->>'total')::numeric) from jsonb_array_elements(r->'expenses') g) = 97, 'two days of expenses: ' || r::text;

  -- an empty range is all zeros
  execute 'set local role authenticated';
  r := public.admin_sales_report('2026-01-01', '2026-01-31');
  execute 'reset role';
  assert (r->>'ok')::boolean and (r->>'sales_count')::int = 0 and (r->>'sales_total')::numeric = 0
    and (r->>'void_count')::int = 0 and r->'by_method' = '[]'::jsonb and r->'expenses' = '[]'::jsonb, 'empty: ' || r::text;

  -- a backwards or too long range is refused
  execute 'set local role authenticated';
  r := public.admin_sales_report('2026-10-25', '2026-10-24');
  assert not (r->>'ok')::boolean, 'to before from is refused: ' || r::text;
  r := public.admin_sales_report('2025-01-01', '2026-10-24');
  assert not (r->>'ok')::boolean, 'more than a year is refused: ' || r::text;
  execute 'reset role';

  -- ---------------------------------------------------------------- another admin sees only theirs
  perform set_config('request.jwt.claim.sub', admin_b::text, true);
  execute 'set local role authenticated';
  r := public.admin_sales_report('2026-10-24', '2026-10-24');
  execute 'reset role';
  assert (r->>'sales_total')::numeric = 1000 and (r->>'void_count')::int = 0, 'cafe B sees only its own sale: ' || r::text;

  -- ---------------------------------------------------------------- a till can't call it
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('request.headers', json_build_object('x-cashier-token', 'report-token')::text, true);
  execute 'set local role anon';
  blocked := false;
  begin
    r := public.admin_sales_report('2026-10-24', '2026-10-24');
  exception when insufficient_privilege then blocked := true;
  end;
  execute 'reset role';
  assert blocked, 'a till (anon) must not read the report';

  raise notice 'sales_report_test: all checks passed';
end $test$;

rollback;
