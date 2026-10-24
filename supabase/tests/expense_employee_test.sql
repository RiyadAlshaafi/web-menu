-- Checks 20261024120000_expense_employee.sql: any expense can be tagged with an employee, the tag
-- survives an edit, a cashier or an unknown person is refused, and cash withdrawals still use "paid to".
-- Run by tool/test_db.sh. Everything is rolled back; any failed check aborts with its message.

begin;

do $test$
declare
  r jsonb;
  rid uuid;
  cid uuid;
  chef uuid;
  other_cafe_cashier uuid;
  sh uuid;
  shop uuid;
  cafe_cat uuid;
  wd_cat uuid;
  new_id uuid;
  row_ public.shift_expenses%rowtype;
begin
  insert into public.restaurants (name) values ('employee cafe') returning id into rid;
  insert into public.cashiers (restaurant_id, name, initials, pin_hash) values (rid, 'Cash', 'C', 'x') returning id into cid;
  insert into public.cashiers (restaurant_id, name, initials, pin_hash, role) values (rid, 'Chef Omar', 'O', '', 'chef') returning id into chef;
  insert into public.restaurants (name) values ('other cafe') returning id into shop;
  insert into public.cashiers (restaurant_id, name, initials, pin_hash, role) values (shop, 'Stranger', 'S', '', 'chef') returning id into other_cafe_cashier;
  insert into public.cashier_sessions (cashier_id, restaurant_id, token_hash, expires_at)
  values (cid, rid, encode(extensions.digest('emp-token', 'sha256'), 'hex'), now() + interval '1 hour');
  insert into public.shifts (restaurant_id, cashier_id, opening_cash) values (rid, cid, 0) returning id into sh;
  insert into public.expense_categories (restaurant_id, name_en, name_ar, sort_order) values (rid, 'Café Expense', 'x', 0) returning id into cafe_cat;
  insert into public.expense_categories (restaurant_id, name_en, name_ar, sort_order) values (rid, 'Cash Withdrawal', 'x', 1) returning id into wd_cat;
  assert cafe_cat is not null and wd_cat is not null, 'the cafe needs a normal and a withdrawal category';
  perform set_config('request.headers', json_build_object('x-cashier-token', 'emp-token')::text, true);

  execute 'set local role anon';

  -- no employee: an ordinary expense with no tag
  r := public.record_cash_movement(sh, cafe_cat, 10, 'gas', null);
  assert (r->>'ok')::boolean, 'plain expense must save: ' || r::text;
  execute 'reset role';
  select * into row_ from public.shift_expenses where id = (r->>'id')::uuid;
  assert row_.staff_id is null and row_.paid_to_cafe, 'an untagged expense has no employee';

  -- tagged with the chef: saved, named, and still a cafe expense (cash totals unchanged)
  execute 'set local role anon';
  r := public.record_cash_movement(sh, cafe_cat, 25, 'chef advance', chef);
  assert (r->>'ok')::boolean, 'a tagged expense must save: ' || r::text;
  new_id := (r->>'id')::uuid;
  execute 'reset role';
  select * into row_ from public.shift_expenses where id = new_id;
  assert row_.staff_id = chef and row_.staff_name = 'Chef Omar', 'the employee and a copy of the name are saved';
  assert row_.paid_to_cafe and row_.paid_to_cashier_id is null, 'the tag must not turn the expense into a withdrawal';

  -- editing keeps the tag
  execute 'set local role anon';
  r := public.edit_cash_movement(new_id, cafe_cat, 30, 'chef advance fixed');
  assert (r->>'ok')::boolean, 'edit must work: ' || r::text;
  execute 'reset role';
  select * into row_ from public.shift_expenses where id = (r->>'id')::uuid;
  assert row_.staff_id = chef and row_.amount = 30, 'the edited copy keeps the employee';

  -- a person from another cafe is refused
  execute 'set local role anon';
  r := public.record_cash_movement(sh, cafe_cat, 5, 'x', other_cafe_cashier);
  assert r->>'error' = 'invalid', 'another cafe''s staff must be refused: ' || r::text;

  -- a withdrawal still goes to "paid to", not to the tag
  r := public.record_cash_movement(sh, wd_cat, 40, 'cash to chef', chef);
  assert (r->>'ok')::boolean, 'withdrawal must save: ' || r::text;
  execute 'reset role';
  select * into row_ from public.shift_expenses where id = (r->>'id')::uuid;
  assert row_.paid_to_cashier_id = chef and row_.staff_id is null and not row_.paid_to_cafe, 'a withdrawal is paid to the chef';
end;
$test$;

rollback;
do $$ begin raise notice 'expense_employee_test: all checks passed'; end $$;
