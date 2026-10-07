-- Offline support: a cashier device can save takeout sales, expenses and shift changes locally and
-- upload them later. Every upload carries a unique id (client_id) so a retry never duplicates it, and
-- receipt numbers come from blocks the device reserved while it was online.

alter table public.orders add column if not exists client_id uuid;
alter table public.payments add column if not exists client_id uuid;
alter table public.shift_expenses add column if not exists client_id uuid;
alter table public.shifts add column if not exists client_id uuid;
alter table public.payments add column if not exists synced_offline boolean not null default false;
alter table public.payments add column if not exists synced_at timestamptz;

create unique index if not exists orders_client_id_key on public.orders (client_id) where client_id is not null;
create unique index if not exists payments_client_id_key on public.payments (client_id) where client_id is not null;
create unique index if not exists shift_expenses_client_id_key on public.shift_expenses (client_id) where client_id is not null;
create unique index if not exists shifts_client_id_key on public.shifts (client_id) where client_id is not null;

-- Number blocks reserved by a device. A synced receipt must use a number from one of its blocks.
create table if not exists public.receipt_blocks (
  id uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null references public.restaurants(id) on delete cascade,
  cashier_id uuid references public.cashiers(id) on delete set null,
  year_month text not null,
  first_no integer not null,
  last_no integer not null,
  day_key text not null,
  day_first integer not null,
  day_last integer not null,
  created_at timestamptz not null default now(),
  check (last_no >= first_no and day_last >= day_first)
);
create index if not exists receipt_blocks_restaurant_idx on public.receipt_blocks (restaurant_id, year_month);
alter table public.receipt_blocks enable row level security;
revoke all on public.receipt_blocks from anon, authenticated;

-- Reserve receipt and daily order numbers for offline use.
create or replace function public.reserve_receipt_numbers(p_count integer default 50)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  rid uuid := private.cashier_restaurant_id();
  cid uuid := private.session_cashier_id();
  n integer := least(greatest(coalesce(p_count, 50), 1), 200);
  yymm text := to_char(now() at time zone 'Africa/Tripoli', 'YYMM');
  day_key text := to_char(now() at time zone 'Africa/Tripoli', 'YYMMDD');
  m_last integer;
  d_last integer;
begin
  if rid is null or cid is null then
    return jsonb_build_object('ok', false, 'error', 'session expired, sign in again');
  end if;
  insert into public.order_number_counters as c (restaurant_id, scope, last_value)
  values (rid, 'month:' || yymm, n)
  on conflict (restaurant_id, scope) do update set last_value = c.last_value + n
  returning last_value into m_last;
  insert into public.order_number_counters as c (restaurant_id, scope, last_value)
  values (rid, 'day:' || day_key, n)
  on conflict (restaurant_id, scope) do update set last_value = c.last_value + n
  returning last_value into d_last;
  insert into public.receipt_blocks (restaurant_id, cashier_id, year_month, first_no, last_no, day_key, day_first, day_last)
  values (rid, cid, yymm, m_last - n + 1, m_last, day_key, d_last - n + 1, d_last);
  return jsonb_build_object('ok', true, 'year_month', yymm, 'first', m_last - n + 1, 'last', m_last,
    'day_key', day_key, 'day_first', d_last - n + 1, 'day_last', d_last);
end;
$$;

-- Upload one offline takeout sale. Safe to call again with the same client_id.
create or replace function public.sync_offline_takeout(
  p_client_id uuid,
  p_cashier_id uuid,
  p_shift_id uuid,
  p_lines jsonb,
  p_payment_type_id uuid,
  p_paid_at timestamptz,
  p_year_month text,
  p_monthly_no integer,
  p_day_key text,
  p_day_no integer
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  rid uuid := private.cashier_restaurant_id();
  tbl public.dining_tables%rowtype;
  ord public.orders%rowtype;
  shift public.shifts%rowtype;
  due numeric := 0;
  type_id uuid := p_payment_type_id;
  line_count integer := 0;
  m_label text;
  d_label text;
begin
  if rid is null then
    return jsonb_build_object('ok', false, 'error', 'session expired, sign in again');
  end if;
  if exists (select 1 from public.payments where client_id = p_client_id and restaurant_id = rid) then
    return jsonb_build_object('ok', true, 'duplicate', true);
  end if;
  if not exists (select 1 from public.cashiers where id = p_cashier_id and restaurant_id = rid) then
    return jsonb_build_object('ok', false, 'error', 'unknown cashier');
  end if;
  if p_lines is null or jsonb_typeof(p_lines) <> 'array' or jsonb_array_length(p_lines) = 0 then
    return jsonb_build_object('ok', false, 'error', 'cart is empty');
  end if;
  if not exists (
    select 1 from public.receipt_blocks b
    where b.restaurant_id = rid and b.year_month = p_year_month
      and p_monthly_no between b.first_no and b.last_no
  ) then
    return jsonb_build_object('ok', false, 'error', 'receipt number was not reserved');
  end if;
  if p_day_no is not null and not exists (
    select 1 from public.receipt_blocks b
    where b.restaurant_id = rid and b.day_key = p_day_key
      and p_day_no between b.day_first and b.day_last
  ) then
    return jsonb_build_object('ok', false, 'error', 'order number was not reserved');
  end if;

  select * into tbl from public.dining_tables
  where restaurant_id = rid and lower(btrim(number)) = 'takeout' limit 1;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'takeout_table');
  end if;
  if type_id is not null and not exists (
    select 1 from public.payment_types where id = type_id and restaurant_id = rid
  ) then
    type_id := null;
  end if;

  -- the shift the sale belongs to: the one it was made in, else the cashier's open shift, else a new one
  select * into shift from public.shifts where (id = p_shift_id or client_id = p_shift_id) and restaurant_id = rid;
  if not found then
    select * into shift from public.shifts
    where cashier_id = p_cashier_id and restaurant_id = rid and closed_at is null
    order by opened_at desc limit 1;
  end if;
  if not found then
    insert into public.shifts (restaurant_id, cashier_id, opening_cash, opened_at, client_id)
    values (rid, p_cashier_id, 0, coalesce(p_paid_at, now()), p_shift_id)
    returning * into shift;
  end if;

  -- keep the prices the customer was charged at the till, not today's menu price
  perform set_config('app.offline_sync', 'on', true);
  insert into public.orders (restaurant_id, table_id, status, service_type, payment_type_id, cashier_id,
                             created_at, client_id, year_month, shift_order_number, number_day)
  values (rid, tbl.id, 'served', 'takeout', type_id, p_cashier_id, coalesce(p_paid_at, now()), p_client_id,
          p_year_month, p_day_no, case when p_day_no is null then null else p_day_key end)
  returning * into ord;

  insert into public.order_lines (order_id, restaurant_id, menu_item_id, name, qty, unit_price, list_unit_price, round)
  select ord.id, rid, nullif(x.menu_item_id, '')::uuid, coalesce(nullif(x.name, ''), 'Item'), x.qty,
         round(coalesce(x.unit_price, 0), 2), round(coalesce(x.list_unit_price, x.unit_price, 0), 2), 1
  from jsonb_to_recordset(p_lines) as x(menu_item_id text, name text, qty integer, unit_price numeric, list_unit_price numeric)
  where x.qty > 0;
  get diagnostics line_count = row_count;
  if line_count = 0 then
    raise exception 'cart is empty';
  end if;
  select round(coalesce(sum(qty * unit_price), 0), 2) into due from public.order_lines where order_id = ord.id;

  m_label := p_year_month || case when length(p_monthly_no::text) >= 3 then p_monthly_no::text else lpad(p_monthly_no::text, 3, '0') end;
  d_label := p_year_month || case when length(coalesce(p_day_no, 0)::text) >= 3 then coalesce(p_day_no, 0)::text else lpad(coalesce(p_day_no, 0)::text, 3, '0') end;

  insert into public.payments (
    restaurant_id, order_id, table_id, total_due, cash_received, change_due, cashier_id, shift_id, payment_type_id,
    paid_at, year_month, shift_order_number, monthly_order_number, shift_display_number, monthly_display_number,
    client_id, synced_offline, synced_at
  ) values (
    rid, ord.id, tbl.id, due, due, 0, p_cashier_id, shift.id, type_id,
    coalesce(p_paid_at, now()), p_year_month, p_day_no, p_monthly_no, d_label, m_label,
    p_client_id, true, now()
  );
  update public.orders set status = 'paid' where id = ord.id;
  update public.shifts set cash_sales = cash_sales + due, transaction_count = transaction_count + 1 where id = shift.id;
  return jsonb_build_object('ok', true, 'order_id', ord.id, 'shift_id', shift.id, 'total_due', due);
end;
$$;

-- Upload one offline expense.
create or replace function public.sync_offline_expense(
  p_client_id uuid,
  p_cashier_id uuid,
  p_shift_id uuid,
  p_expense_category_id uuid,
  p_amount numeric,
  p_description text,
  p_created_at timestamptz
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  rid uuid := private.cashier_restaurant_id();
  shift public.shifts%rowtype;
  category public.expense_categories%rowtype;
  label text;
  cafe boolean;
begin
  if rid is null then
    return jsonb_build_object('ok', false, 'error', 'session expired, sign in again');
  end if;
  if exists (select 1 from public.shift_expenses where client_id = p_client_id and restaurant_id = rid) then
    return jsonb_build_object('ok', true, 'duplicate', true);
  end if;
  if not exists (select 1 from public.cashiers where id = p_cashier_id and restaurant_id = rid) then
    return jsonb_build_object('ok', false, 'error', 'unknown cashier');
  end if;
  if p_amount is null or p_amount <= 0 or btrim(coalesce(p_description, '')) = '' then
    return jsonb_build_object('ok', false, 'error', 'invalid');
  end if;
  select * into category from public.expense_categories where id = p_expense_category_id and restaurant_id = rid;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'unknown type');
  end if;
  select * into shift from public.shifts where (id = p_shift_id or client_id = p_shift_id) and restaurant_id = rid;
  if not found then
    select * into shift from public.shifts
    where cashier_id = p_cashier_id and restaurant_id = rid and closed_at is null
    order by opened_at desc limit 1;
  end if;
  if not found then
    insert into public.shifts (restaurant_id, cashier_id, opening_cash, opened_at, client_id)
    values (rid, p_cashier_id, 0, coalesce(p_created_at, now()), p_shift_id)
    returning * into shift;
  end if;
  cafe := category.name_en is distinct from 'Cash Withdrawal';
  label := private.next_expense_number(rid);
  insert into public.shift_expenses (
    restaurant_id, shift_id, cashier_id, paid_to_cashier_id, paid_to_cafe, amount, description, kind, display_number,
    expense_category_id, category_name_en, category_name_ar, created_at, client_id
  ) values (
    rid, shift.id, p_cashier_id, case when cafe then null else p_cashier_id end, cafe, p_amount, btrim(p_description),
    'cash_out', label, category.id, category.name_en, category.name_ar, coalesce(p_created_at, now()), p_client_id
  );
  return jsonb_build_object('ok', true, 'display_number', label, 'shift_id', shift.id);
end;
$$;

-- Open a shift made offline (same id as on the device). Reuses the cashier's open shift if one exists.
create or replace function public.sync_offline_shift_open(
  p_client_id uuid,
  p_cashier_id uuid,
  p_opened_at timestamptz
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  rid uuid := private.cashier_restaurant_id();
  shift public.shifts%rowtype;
begin
  if rid is null then
    return jsonb_build_object('ok', false, 'error', 'session expired, sign in again');
  end if;
  if not exists (select 1 from public.cashiers where id = p_cashier_id and restaurant_id = rid) then
    return jsonb_build_object('ok', false, 'error', 'unknown cashier');
  end if;
  perform pg_advisory_xact_lock(hashtext('open_shift:' || p_cashier_id::text));
  select * into shift from public.shifts where client_id = p_client_id and restaurant_id = rid;
  if not found then
    select * into shift from public.shifts
    where cashier_id = p_cashier_id and restaurant_id = rid and closed_at is null
    order by opened_at desc limit 1;
    -- merged into a shift already open on the server: remember the device's id so its sales find it
    if found and shift.client_id is null then
      update public.shifts set client_id = p_client_id where id = shift.id;
    end if;
  end if;
  if not found then
    insert into public.shifts (restaurant_id, cashier_id, opening_cash, opened_at, client_id)
    values (rid, p_cashier_id, 0, coalesce(p_opened_at, now()), p_client_id)
    returning * into shift;
  end if;
  return jsonb_build_object('ok', true, 'shift_id', shift.id);
end;
$$;

-- Close a shift made or closed offline.
create or replace function public.sync_offline_shift_close(
  p_client_id uuid,
  p_cashier_id uuid,
  p_actual_cash numeric,
  p_closed_at timestamptz
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  rid uuid := private.cashier_restaurant_id();
  sid uuid;
begin
  if rid is null then
    return jsonb_build_object('ok', false, 'error', 'session expired, sign in again');
  end if;
  if p_actual_cash is null or p_actual_cash < 0 then
    return jsonb_build_object('ok', false, 'error', 'invalid');
  end if;
  update public.shifts
  set actual_cash = round(p_actual_cash, 2), closed_at = greatest(coalesce(p_closed_at, now()), opened_at)
  where id = (
    select id from public.shifts
    where restaurant_id = rid
      and (id = p_client_id or client_id = p_client_id or (cashier_id = p_cashier_id and closed_at is null))
    order by (id = p_client_id or client_id is not distinct from p_client_id) desc, opened_at desc limit 1
  ) and closed_at is null
  returning id into sid;
  if sid is null then
    -- already closed by an earlier try
    return jsonb_build_object('ok', true, 'duplicate', true);
  end if;
  return jsonb_build_object('ok', true, 'shift_id', sid);
end;
$$;

revoke execute on function public.reserve_receipt_numbers(integer) from public, anon, authenticated;
revoke execute on function public.sync_offline_takeout(uuid, uuid, uuid, jsonb, uuid, timestamptz, text, integer, text, integer) from public, anon, authenticated;
revoke execute on function public.sync_offline_expense(uuid, uuid, uuid, uuid, numeric, text, timestamptz) from public, anon, authenticated;
revoke execute on function public.sync_offline_shift_open(uuid, uuid, timestamptz) from public, anon, authenticated;
revoke execute on function public.sync_offline_shift_close(uuid, uuid, numeric, timestamptz) from public, anon, authenticated;
grant execute on function public.reserve_receipt_numbers(integer) to anon, authenticated;
grant execute on function public.sync_offline_takeout(uuid, uuid, uuid, jsonb, uuid, timestamptz, text, integer, text, integer) to anon, authenticated;
grant execute on function public.sync_offline_expense(uuid, uuid, uuid, uuid, numeric, text, timestamptz) to anon, authenticated;
grant execute on function public.sync_offline_shift_open(uuid, uuid, timestamptz) to anon, authenticated;
grant execute on function public.sync_offline_shift_close(uuid, uuid, numeric, timestamptz) to anon, authenticated;

-- Order lines normally take today's menu price. An offline upload keeps the price charged at the till,
-- and a dish deleted since then is kept by name only.
create or replace function private.stamp_order_line()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  item public.menu_items%rowtype;
  parent public.orders%rowtype;
begin
  select * into parent from public.orders where id = new.order_id;
  if not found then
    raise exception 'order not found';
  end if;
  new.restaurant_id := parent.restaurant_id;
  if current_setting('app.offline_sync', true) = 'on' then
    if new.menu_item_id is not null then
      select * into item from public.menu_items where id = new.menu_item_id;
      if not found then
        new.menu_item_id := null;
      elsif item.restaurant_id <> parent.restaurant_id then
        raise exception 'menu item is not on this restaurant menu';
      end if;
    end if;
    new.list_unit_price := coalesce(new.list_unit_price, new.unit_price);
    return new;
  end if;
  if new.menu_item_id is null then
    if private.is_guest() and current_setting('dev.import', true) is distinct from 'on' then
      raise exception 'guests can only order items from the menu';
    end if;
    new.list_unit_price := coalesce(new.list_unit_price, new.unit_price);
    return new;
  end if;
  select * into item from public.menu_items where id = new.menu_item_id;
  if not found or item.restaurant_id <> parent.restaurant_id then
    raise exception 'menu item is not on this restaurant menu';
  end if;
  new.name := coalesce(nullif(item.name_en, ''), item.name_it);
  new.list_unit_price := item.price;
  new.unit_price := private.menu_sale_price(item.id);
  return new;
end;
$$;
