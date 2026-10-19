-- Checks 20261019150000_monthly_archive.sql: old months are listed, exported with a digest and
-- deleted only when unchanged; recent months, other cafes and rows still needed by a later
-- month stay; only the service role may run it; cafes can read which months are archived.
-- Run by tool/test_db.sh. Everything is rolled back; any failed check aborts with its message.

begin;

do $test$
declare
  r jsonb;
  d jsonb;
  rid uuid;
  other uuid;
  cat uuid;
  tea uuid;
  cid uuid;
  old_shift uuid;
  long_shift uuid;
  admin_id uuid;
  old_month text := to_char((now() at time zone 'Africa/Tripoli') - interval '4 months', 'YYYY-MM');
  month_after text := to_char((now() at time zone 'Africa/Tripoli') - interval '3 months', 'YYYY-MM');
  key text;
  n integer;
begin
  insert into public.restaurants (name) values ('archive cafe') returning id into rid;
  insert into public.restaurants (name) values ('archive other') returning id into other;
  insert into public.menu_categories (restaurant_id, name_en, name_ar) values (rid, 'C', 'C') returning id into cat;
  insert into public.menu_items (restaurant_id, category_id, name_en, price) values (rid, cat, 'Tea', 5) returning id into tea;
  insert into public.cashiers (restaurant_id, name, initials, pin_hash) values (rid, 'A', 'A', 'x') returning id into cid;
  insert into public.cashier_sessions (cashier_id, restaurant_id, token_hash, expires_at)
  values (cid, rid, encode(extensions.digest('archive-token', 'sha256'), 'hex'), now() + interval '1 hour');
  perform set_config('request.headers', json_build_object('x-cashier-token', 'archive-token')::text, true);

  -- An old shift with two sales and an expense, closed; then a recent shift with one sale.
  execute 'set local role anon';
  old_shift := (public.open_shift() ->> 'shift_id')::uuid;
  r := public.quick_takeout_receipt(jsonb_build_array(jsonb_build_object('menu_item_id', tea, 'qty', 2)), null);
  r := public.quick_takeout_receipt(jsonb_build_array(jsonb_build_object('menu_item_id', tea, 'qty', 1)), null);
  r := public.close_shift(15);
  assert (r ->> 'ok')::boolean, 'close failed: ' || r::text;
  r := public.open_shift();
  r := public.quick_takeout_receipt(jsonb_build_array(jsonb_build_object('menu_item_id', tea, 'qty', 3)), null);
  execute 'reset role';
  insert into public.shift_expenses (restaurant_id, shift_id, cashier_id, amount, description, kind, paid_to_cafe)
  values (rid, old_shift, cid, 2, 'milk', 'cash_out', true);
  update public.payments set paid_at = paid_at - interval '4 months' where shift_id = old_shift;
  update public.orders set created_at = created_at - interval '4 months'
  where id in (select order_id from public.payments where shift_id = old_shift);
  update public.shifts set opened_at = opened_at - interval '4 months', closed_at = closed_at - interval '4 months'
  where id = old_shift;

  -- A shift closed in the old month that still has a sale a month later must wait for that month.
  insert into public.shifts (restaurant_id, cashier_id, opening_cash, opened_at, closed_at)
  values (rid, cid, 0, now() - interval '4 months', now() - interval '4 months') returning id into long_shift;
  update public.payments set shift_id = long_shift, paid_at = now() - interval '3 months'
  where id = (select id from public.payments where restaurant_id = rid and shift_id <> old_shift limit 1);

  -- ------------------------------------------------ who may run it
  assert not has_function_privilege('anon', 'public.archive_month_export(uuid, text)', 'execute'), 'guests and tills must not export';
  assert not has_function_privilege('authenticated', 'public.archive_month_delete(uuid, text, text, text, bigint, text)', 'execute'),
    'admins must not delete archives';
  assert has_function_privilege('service_role', 'public.archive_month_delete(uuid, text, text, text, bigint, text)', 'execute'),
    'the archive Worker must be able to run it';

  -- ------------------------------------------------ what is due
  select count(*) into n from public.archive_due_months() m where m.restaurant_id = rid and m.year_month = old_month;
  assert n = 1, 'the old month must be due';
  select count(*) into n from public.archive_due_months() m
  where m.restaurant_id = rid and m.year_month >= to_char(now() at time zone 'Africa/Tripoli' - interval '1 month', 'YYYY-MM');
  assert n = 0, 'the last two months are never due';
  r := public.archive_month_export(rid, to_char(now() at time zone 'Africa/Tripoli', 'YYYY-MM'));
  assert r ->> 'error' = 'month is too recent to archive', 'this month must be refused: ' || r::text;

  -- ------------------------------------------------ export
  r := public.archive_month_export(rid, old_month);
  assert (r ->> 'ok')::boolean, 'export failed: ' || r::text;
  d := r -> 'data';
  assert (r ->> 'payments')::int = 2 and (r ->> 'sales_total')::numeric = 15, 'the month has 2 sales worth 15: ' || (r - 'data')::text;
  assert jsonb_array_length(d -> 'orders') = 2 and jsonb_array_length(d -> 'order_lines') = 2, 'orders and lines are in the file';
  assert jsonb_array_length(d -> 'shifts') = 1 and d -> 'shifts' -> 0 ->> 'id' = old_shift::text,
    'only the shift with no later sale is in the file';
  assert jsonb_array_length(d -> 'shift_expenses') = 1, 'its expense is in the file';
  assert r ->> 'digest' = (public.archive_month_export(rid, old_month) ->> 'digest'), 'the same month gives the same digest';
  key := 'archive/' || rid || '/' || old_month || '/1.json.gz';
  -- While the old month is not archived, the next month must not take its shift or expenses.
  d := public.archive_month_export(rid, month_after) -> 'data';
  assert not (d -> 'shifts') @> jsonb_build_array(jsonb_build_object('id', old_shift)),
    'a shift with sales in an earlier, unarchived month must wait for that month';

  -- ------------------------------------------------ refusals that delete nothing
  r := public.archive_month_delete(rid, old_month, 'wrong', key, 100, repeat('a', 64));
  assert r ->> 'error' = 'changed since export', 'a wrong digest deletes nothing: ' || r::text;
  r := public.archive_month_delete(rid, old_month, (public.archive_month_export(rid, old_month) ->> 'digest'),
                                   'archive/' || other || '/' || old_month || '/1.json.gz', 100, repeat('a', 64));
  assert r ->> 'error' = 'the stored file is not described', 'a file in another cafe''s folder is refused: ' || r::text;
  d := public.archive_month_export(rid, old_month);
  update public.shift_expenses set description = 'oat milk' where shift_id = old_shift;
  r := public.archive_month_delete(rid, old_month, d ->> 'digest', key, 100, repeat('a', 64));
  assert r ->> 'error' = 'changed since export', 'a change after the export deletes nothing: ' || r::text;
  select count(*) into n from public.payments where shift_id = old_shift;
  assert n = 2, 'refused deletes keep every sale';

  -- ------------------------------------------------ delete what was archived
  d := public.archive_month_export(rid, old_month);
  r := public.archive_month_delete(rid, old_month, d ->> 'digest', key, 100, repeat('a', 64));
  assert (r ->> 'ok')::boolean, 'delete failed: ' || r::text;
  select count(*) into n from public.payments where shift_id = old_shift;
  assert n = 0, 'the month''s sales leave the database';
  select count(*) into n from public.order_lines l join public.orders o on o.id = l.order_id where o.restaurant_id = rid;
  assert n = 1, 'only the line of the later sale stays, got ' || n;
  select count(*) into n from public.shifts where id = old_shift;
  assert n = 0, 'the archived shift leaves';
  select count(*) into n from public.shift_expenses where shift_id = old_shift;
  assert n = 0, 'its expense leaves';
  select count(*) into n from public.shifts where id = long_shift;
  assert n = 1, 'a shift with a later sale stays until that month is archived';
  select count(*) into n from public.payments where restaurant_id = rid;
  assert n = 1, 'the later sale stays';
  select count(*) into n from public.archived_months where restaurant_id = rid and year_month = old_month and object_key = key
    and payments = 2 and sales_total = 15;
  assert n = 1, 'the archive is recorded with its totals';

  -- ------------------------------------------------ the next month takes the waiting shift
  d := public.archive_month_export(rid, month_after);
  assert jsonb_array_length(d -> 'data' -> 'shifts') = 1 and d -> 'data' -> 'shifts' -> 0 ->> 'id' = long_shift::text,
    'the waiting shift goes with its last sale''s month: ' || (d - 'data')::text;
  r := public.archive_month_delete(rid, month_after, d ->> 'digest',
                                   'archive/' || rid || '/' || month_after || '/1.json.gz', 100, repeat('b', 64));
  assert (r ->> 'ok')::boolean, 'second month failed: ' || r::text;
  select count(*) into n from public.shifts where id = long_shift;
  assert n = 0, 'the waiting shift is archived with its month';

  -- ------------------------------------------------ cafes see only their own archive list
  alter table auth.users disable trigger user;
  insert into auth.users (email) values ('archive@cafe.test') returning id into admin_id;
  alter table auth.users enable trigger user;
  insert into public.profiles (id, restaurant_id) values (admin_id, other);
  perform set_config('request.jwt.claim.sub', admin_id::text, true);
  execute 'set local role authenticated';
  select count(*) into n from public.archived_months;
  execute 'reset role';
  assert n = 0, 'another cafe''s admin sees none of this cafe''s archive';
  perform set_config('request.jwt.claim.sub', '', true);
  execute 'set local role anon';
  select count(*) into n from public.archived_months;
  execute 'reset role';
  assert n = 2, 'the cafe''s own till sees its archived months, got ' || n;

  raise notice 'monthly_archive_test: all checks passed';
end;
$test$;

rollback;
