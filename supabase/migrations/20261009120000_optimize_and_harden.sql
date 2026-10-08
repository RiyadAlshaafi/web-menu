-- Optimisation and integrity pass. Behaviour of the app is unchanged.

-- 1. Indexes for foreign keys and the queries the app runs most (tenant first, newest first).
create index if not exists order_lines_restaurant_idx on public.order_lines (restaurant_id, order_id);
create index if not exists order_lines_menu_item_idx on public.order_lines (menu_item_id) where menu_item_id is not null;
create index if not exists payments_shift_idx on public.payments (shift_id);
create index if not exists payments_table_idx on public.payments (table_id) where table_id is not null;
create index if not exists payments_cashier_idx on public.payments (restaurant_id, cashier_id, paid_at desc);
create index if not exists payments_payment_type_idx on public.payments (payment_type_id) where payment_type_id is not null;
create index if not exists orders_cashier_idx on public.orders (cashier_id) where cashier_id is not null;
create index if not exists orders_payment_type_idx on public.orders (payment_type_id) where payment_type_id is not null;
create index if not exists shifts_restaurant_idx on public.shifts (restaurant_id, opened_at desc);
create index if not exists shifts_cashier_idx on public.shifts (cashier_id, opened_at desc) where cashier_id is not null;
create index if not exists shift_expenses_shift_idx on public.shift_expenses (shift_id);
create index if not exists shift_expenses_restaurant_idx on public.shift_expenses (restaurant_id, created_at desc);
create index if not exists shift_expenses_cashier_idx on public.shift_expenses (cashier_id) where cashier_id is not null;
create index if not exists shift_expenses_paid_to_idx on public.shift_expenses (paid_to_cashier_id) where paid_to_cashier_id is not null;
create index if not exists shift_expenses_edited_from_idx on public.shift_expenses (edited_from) where edited_from is not null;
create index if not exists shift_expenses_category_idx on public.shift_expenses (expense_category_id) where expense_category_id is not null;
create index if not exists cashiers_restaurant_idx on public.cashiers (restaurant_id);
create index if not exists cashier_sessions_cashier_idx on public.cashier_sessions (cashier_id);
create index if not exists cashier_sessions_restaurant_idx on public.cashier_sessions (restaurant_id, expires_at);
create index if not exists profiles_restaurant_idx on public.profiles (restaurant_id);
create index if not exists menu_items_category_idx on public.menu_items (category_id);
create index if not exists cart_lines_menu_item_idx on public.cart_lines (menu_item_id) where menu_item_id is not null;
create index if not exists cart_lines_restaurant_idx on public.cart_lines (restaurant_id);
create index if not exists carts_restaurant_idx on public.carts (restaurant_id);
create index if not exists payment_method_changes_restaurant_idx on public.payment_method_changes (restaurant_id, created_at desc);

-- 2. Rules the database now enforces itself (no duplicates, no double-open records).
-- Older data may break a rule; it must never stop this migration (and every later one).
-- A cashier with several open shifts keeps the newest; the older ones are closed as they were.
update public.shifts s
set closed_at = greatest(s.opened_at, coalesce(
  (select max(p.paid_at) from public.payments p where p.shift_id = s.id), s.opened_at))
where s.closed_at is null and s.cashier_id is not null
  and exists (
    select 1 from public.shifts newer
    where newer.cashier_id = s.cashier_id and newer.closed_at is null
      and (newer.opened_at, newer.id) > (s.opened_at, s.id)
  );
create unique index if not exists shifts_one_open_per_cashier on public.shifts (cashier_id) where closed_at is null;
-- Open orders and receipt numbers are not changed automatically: if duplicates exist the rule is
-- skipped with a notice, so someone can look at them and apply it later.
do $$
begin
  if exists (select 1 from public.orders where status <> 'paid' and table_id is not null
             group by table_id having count(*) > 1) then
    raise notice 'orders_one_open_per_table skipped: some tables have more than one open order';
  else
    create unique index if not exists orders_one_open_per_table on public.orders (table_id) where status <> 'paid';
  end if;
  if exists (select 1 from public.payments where monthly_order_number is not null
             group by restaurant_id, year_month, monthly_order_number having count(*) > 1) then
    raise notice 'payments_monthly_number_key skipped: some receipts share a monthly number';
  else
    create unique index if not exists payments_monthly_number_key
      on public.payments (restaurant_id, year_month, monthly_order_number) where monthly_order_number is not null;
  end if;
end $$;

-- 3. Value checks, added NOT VALID so old rows are never rejected, then validated.
alter table public.restaurants
  add constraint restaurants_rates_range check (service_charge_rate between 0 and 1 and tax_rate between 0 and 1) not valid;
alter table public.payments
  add constraint payments_amounts_ok check (total_due >= 0 and cash_received >= total_due and change_due >= 0) not valid;
alter table public.shifts
  add constraint shifts_times_ok check (closed_at is null or closed_at >= opened_at) not valid,
  add constraint shifts_amounts_ok check (opening_cash >= 0 and cash_sales >= 0 and (actual_cash is null or actual_cash >= 0)) not valid;
alter table public.cashiers
  add constraint cashiers_name_len check (length(btrim(name)) between 1 and 60) not valid,
  add constraint cashiers_initials_len check (length(initials) between 1 and 4) not valid;
-- Each check is validated on its own: if old rows break one, it stays NOT VALID (new rows are
-- still checked) instead of failing the migration.
do $$
declare
  c record;
begin
  for c in
    select * from (values
      ('public.restaurants', 'restaurants_rates_range'),
      ('public.payments', 'payments_amounts_ok'),
      ('public.shifts', 'shifts_times_ok'),
      ('public.shifts', 'shifts_amounts_ok'),
      ('public.cashiers', 'cashiers_name_len'),
      ('public.cashiers', 'cashiers_initials_len')
    ) as v(tbl, con)
  loop
    begin
      execute format('alter table %s validate constraint %I', c.tbl, c.con);
    exception when check_violation then
      raise notice '% left NOT VALID: some existing rows break it', c.con;
    end;
  end loop;
end $$;

-- 4. Row-level-security speed: evaluate auth.uid() and the private helpers once per query, not per row.
do $$
declare
  pol record;
  q text;
  w text;
  stmt text;
begin
  for pol in
    select schemaname, tablename, policyname, qual, with_check
    from pg_policies where schemaname = 'public'
  loop
    q := pol.qual;
    w := pol.with_check;
    if q is not null then
      q := regexp_replace(q, '(?<!select )((auth|private)\.[a-z_]+\(\))', '(select \1)', 'g');
    end if;
    if w is not null then
      w := regexp_replace(w, '(?<!select )((auth|private)\.[a-z_]+\(\))', '(select \1)', 'g');
    end if;
    if q is distinct from pol.qual or w is distinct from pol.with_check then
      stmt := format('alter policy %I on %I.%I', pol.policyname, pol.schemaname, pol.tablename);
      if q is not null then stmt := stmt || ' using (' || q || ')'; end if;
      if w is not null then stmt := stmt || ' with check (' || w || ')'; end if;
      execute stmt;
    end if;
  end loop;
end $$;

-- 5. Least privilege: clients never need TRUNCATE, TRIGGER or REFERENCES.
revoke truncate, trigger, references on all tables in schema public from anon, authenticated;
alter default privileges in schema public revoke truncate, trigger, references on tables from anon, authenticated;

-- 6. Housekeeping helper: drop expired cashier sign-ins (call from a scheduled job).
create or replace function private.purge_expired_sessions()
returns integer language sql security definer set search_path = '' as $$
  with gone as (delete from public.cashier_sessions where expires_at < now() - interval '7 days' returning 1)
  select count(*)::integer from gone;
$$;
revoke execute on function private.purge_expired_sessions() from public, anon, authenticated;
