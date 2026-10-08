-- Quick takeout is a label on the order and receipt, not a table: no "takeout" table is needed.
-- Also: offline receipt numbers are reserved only when short, clearing logs never reissues
-- numbers a till already holds, a repeated offline upload can't race itself, and a sale with
-- no daily order number keeps none.
-- Every function keeps its signature, so tills still on the previous app keep working.

-- 1. Quick takeout without a table.
create or replace function public.quick_takeout_receipt(p_lines jsonb, p_payment_type_id uuid default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  rid uuid := private.cashier_restaurant_id();
  admin_rid uuid := private.current_restaurant_id();
  actor uuid := coalesce(rid, admin_rid);
  ord public.orders%rowtype;
  due numeric;
  shift public.shifts%rowtype;
  cid uuid;
  type_id uuid;
  yymm text;
  shift_n integer;
  month_n integer;
  shift_label text;
  month_label text;
  assigned jsonb;
  line_count integer := 0;
begin
  if actor is null then
    return jsonb_build_object('ok', false, 'error', 'sign in as a cashier first');
  end if;
  if p_lines is null or jsonb_typeof(p_lines) <> 'array' or jsonb_array_length(p_lines) = 0 then
    return jsonb_build_object('ok', false, 'error', 'cart is empty');
  end if;
  type_id := p_payment_type_id;
  if type_id is not null and not exists (select 1 from public.payment_types where id = type_id and restaurant_id = actor) then
    type_id := null;
  end if;
  insert into public.orders (restaurant_id, table_id, status, service_type, payment_type_id)
  values (actor, null, 'served', 'takeout', type_id)
  returning * into ord;
  insert into public.order_lines (order_id, restaurant_id, menu_item_id, name, qty, unit_price, round)
  select ord.id, actor, item.id, coalesce(nullif(item.name_en, ''), item.name_it), x.qty, 0, 1
  from jsonb_to_recordset(p_lines) as x(menu_item_id uuid, qty integer)
  join public.menu_items item on item.id = x.menu_item_id
  where item.restaurant_id = actor and item.available and not item.sold_out and x.qty > 0;
  get diagnostics line_count = row_count;
  if line_count = 0 then
    delete from public.orders where id = ord.id;
    return jsonb_build_object('ok', false, 'error', 'cart is empty');
  end if;
  select round(coalesce(sum(qty * unit_price), 0), 2) into due from public.order_lines where order_id = ord.id;
  cid := coalesce(
    (select cashier_id from public.cashier_sessions s
      where s.token_hash = encode(extensions.digest(coalesce(private.header('x-cashier-token'), ''), 'sha256'), 'hex')
        and s.expires_at > now()
      limit 1),
    (select id from public.cashiers where restaurant_id = actor order by created_at limit 1)
  );
  if cid is null then
    delete from public.order_lines where order_id = ord.id;
    delete from public.orders where id = ord.id;
    return jsonb_build_object('ok', false, 'error', 'sign in as a cashier first');
  end if;
  select * into shift from public.shifts
  where cashier_id = cid and restaurant_id = actor and closed_at is null
  order by opened_at desc limit 1;
  if not found then
    insert into public.shifts (restaurant_id, cashier_id, opening_cash) values (actor, cid, 0) returning * into shift;
  end if;
  assigned := public.assign_shift_order_number(ord.id);
  if coalesce(assigned->>'ok', 'false') <> 'true' then
    return assigned;
  end if;
  select * into ord from public.orders where id = ord.id;
  yymm := to_char(now() at time zone 'Africa/Tripoli', 'YYMM');
  shift_n := ord.shift_order_number;
  shift_label := coalesce(ord.year_month, yymm)
    || case when length(shift_n::text) >= 3 then shift_n::text else lpad(shift_n::text, 3, '0') end;
  insert into public.order_number_counters as counters (restaurant_id, scope, last_value)
  values (actor, 'month:' || yymm, 1)
  on conflict (restaurant_id, scope) do update set last_value = counters.last_value + 1
  returning last_value into month_n;
  month_label := yymm || case when length(month_n::text) >= 3 then month_n::text else lpad(month_n::text, 3, '0') end;
  insert into public.payments (
    restaurant_id, order_id, table_id, total_due, cash_received, change_due, cashier_id, shift_id, payment_type_id,
    year_month, shift_order_number, monthly_order_number, shift_display_number, monthly_display_number
  ) values (
    actor, ord.id, null, due, due, 0, cid, shift.id, type_id, yymm, shift_n, month_n, shift_label, month_label
  );
  update public.orders set status = 'paid', payment_type_id = type_id, service_type = 'takeout' where id = ord.id;
  update public.shifts set cash_sales = cash_sales + due, transaction_count = transaction_count + 1 where id = shift.id;
  return jsonb_build_object('ok', true, 'order_id', ord.id, 'total_due', due, 'year_month', yymm,
    'shift_order_number', shift_n, 'monthly_order_number', month_n);
end;
$$;

-- 2. Receipt blocks may hold only monthly numbers or only daily order numbers.
alter table public.receipt_blocks drop constraint if exists receipt_blocks_check;
alter table public.receipt_blocks
  alter column first_no drop not null,
  alter column last_no drop not null,
  alter column day_key drop not null,
  alter column day_first drop not null,
  alter column day_last drop not null;
alter table public.receipt_blocks
  add constraint receipt_blocks_ranges_ok check (
    (first_no is null) = (last_no is null)
    and (first_no is null or last_no >= first_no)
    and (day_first is null) = (day_last is null)
    and (day_first is null) = (day_key is null)
    and (day_first is null or day_last >= day_first)
    and (first_no is not null or day_first is not null)
  );

-- Reserves only what the till is short of: [p_month_count] receipt numbers for this month and
-- [p_day_count] order numbers for today (either may be 0).
create or replace function public.reserve_receipt_numbers(p_month_count integer, p_day_count integer)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  rid uuid := private.cashier_restaurant_id();
  cid uuid := private.session_cashier_id();
  m integer := least(greatest(coalesce(p_month_count, 0), 0), 200);
  d integer := least(greatest(coalesce(p_day_count, 0), 0), 200);
  yymm text := to_char(now() at time zone 'Africa/Tripoli', 'YYMM');
  today text := to_char(now() at time zone 'Africa/Tripoli', 'YYMMDD');
  m_last integer;
  d_last integer;
begin
  if rid is null or cid is null then
    return jsonb_build_object('ok', false, 'error', 'session expired, sign in again');
  end if;
  if m = 0 and d = 0 then
    return jsonb_build_object('ok', false, 'error', 'nothing to reserve');
  end if;
  if m > 0 then
    insert into public.order_number_counters as c (restaurant_id, scope, last_value)
    values (rid, 'month:' || yymm, m)
    on conflict (restaurant_id, scope) do update set last_value = c.last_value + m
    returning last_value into m_last;
  end if;
  if d > 0 then
    insert into public.order_number_counters as c (restaurant_id, scope, last_value)
    values (rid, 'day:' || today, d)
    on conflict (restaurant_id, scope) do update set last_value = c.last_value + d
    returning last_value into d_last;
  end if;
  insert into public.receipt_blocks (restaurant_id, cashier_id, year_month, first_no, last_no, day_key, day_first, day_last)
  values (
    rid, cid, yymm,
    case when m > 0 then m_last - m + 1 end, case when m > 0 then m_last end,
    case when d > 0 then today end, case when d > 0 then d_last - d + 1 end, case when d > 0 then d_last end
  );
  return jsonb_build_object(
    'ok', true, 'year_month', yymm,
    'first', case when m > 0 then m_last - m + 1 end, 'last', case when m > 0 then m_last end,
    'day_key', case when d > 0 then today end,
    'day_first', case when d > 0 then d_last - d + 1 end, 'day_last', case when d > 0 then d_last end
  );
end;
$$;
revoke all on function public.reserve_receipt_numbers(integer, integer) from public, anon, authenticated;
grant execute on function public.reserve_receipt_numbers(integer, integer) to anon, authenticated;

-- 3. Offline takeout: no table, no race with its own retry, no made-up order number.
create or replace function public.sync_offline_takeout(
  p_client_id uuid, p_cashier_id uuid, p_shift_id uuid, p_lines jsonb, p_payment_type_id uuid,
  p_paid_at timestamptz, p_year_month text, p_monthly_no integer, p_day_key text, p_day_no integer
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  rid uuid := private.cashier_restaurant_id();
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
  -- A retry that overlaps a slow first upload waits here, then sees the first one as a duplicate.
  perform pg_advisory_xact_lock(hashtext('offline_upload:' || p_client_id::text));
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
  if type_id is not null and not exists (
    select 1 from public.payment_types where id = type_id and restaurant_id = rid
  ) then
    type_id := null;
  end if;

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

  perform set_config('app.offline_sync', 'on', true);
  insert into public.orders (restaurant_id, table_id, status, service_type, payment_type_id, cashier_id,
                             created_at, client_id, year_month, shift_order_number, number_day)
  values (rid, null, 'served', 'takeout', type_id, p_cashier_id, coalesce(p_paid_at, now()), p_client_id,
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

  m_label := p_year_month
    || case when length(p_monthly_no::text) >= 3 then p_monthly_no::text else lpad(p_monthly_no::text, 3, '0') end;
  d_label := case when p_day_no is null then null
    else p_year_month || case when length(p_day_no::text) >= 3 then p_day_no::text else lpad(p_day_no::text, 3, '0') end
  end;

  insert into public.payments (
    restaurant_id, order_id, table_id, total_due, cash_received, change_due, cashier_id, shift_id, payment_type_id,
    paid_at, year_month, shift_order_number, monthly_order_number, shift_display_number, monthly_display_number,
    client_id, synced_offline, synced_at
  ) values (
    rid, ord.id, null, due, due, 0, p_cashier_id, shift.id, type_id,
    coalesce(p_paid_at, now()), p_year_month, p_day_no, p_monthly_no, d_label, m_label,
    p_client_id, true, now()
  );
  update public.orders set status = 'paid' where id = ord.id;
  update public.shifts set cash_sales = cash_sales + due, transaction_count = transaction_count + 1 where id = shift.id;
  return jsonb_build_object('ok', true, 'order_id', ord.id, 'shift_id', shift.id, 'total_due', due);
end;
$$;

-- 4. Offline expense: same protection against a retry racing the first upload.
create or replace function public.sync_offline_expense(
  p_client_id uuid, p_cashier_id uuid, p_shift_id uuid, p_expense_category_id uuid, p_amount numeric,
  p_description text, p_created_at timestamptz
)
returns jsonb
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
  perform pg_advisory_xact_lock(hashtext('offline_upload:' || p_client_id::text));
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

-- 5. Clearing logs restarts numbering after the numbers tills still hold, never inside them.
create or replace function public.clear_test_logs(p_scope text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  rid uuid := private.cashier_restaurant_id();
  admin_rid uuid := private.current_restaurant_id();
  actor uuid := coalesce(rid, admin_rid);
  cid uuid;
  day_key text;
  yymm text;
  held integer;
  held_day text;
begin
  if actor is null then
    return jsonb_build_object('ok', false, 'error', 'sign in as a cashier first');
  end if;
  if p_scope is distinct from 'cashier' and p_scope is distinct from 'shift' then
    return jsonb_build_object('ok', false, 'error', 'unknown scope');
  end if;

  cid := coalesce(
    (select cashier_id from public.cashier_sessions s
      where s.token_hash = encode(extensions.digest(coalesce(private.header('x-cashier-token'), ''), 'sha256'), 'hex')
        and s.expires_at > now()
      limit 1),
    (select id from public.cashiers where restaurant_id = actor order by created_at limit 1)
  );
  if cid is null then
    return jsonb_build_object('ok', false, 'error', 'sign in as a cashier first');
  end if;

  day_key := to_char(now() at time zone 'Africa/Tripoli', 'YYMMDD');
  yymm := to_char(now() at time zone 'Africa/Tripoli', 'YYMM');

  if p_scope = 'cashier' then
    delete from public.payments
    where restaurant_id = actor and cashier_id = cid;
    update public.shifts as shift
    set cash_sales = coalesce((select sum(payment.total_due) from public.payments as payment where payment.shift_id = shift.id), 0),
        transaction_count = coalesce((select count(*)::integer from public.payments as payment where payment.shift_id = shift.id), 0)
    where shift.restaurant_id = actor and shift.cashier_id = cid;
  else
    delete from public.payments where restaurant_id = actor;
    update public.shifts
    set cash_sales = 0,
        transaction_count = 0
    where restaurant_id = actor;
    delete from public.order_number_counters
    where restaurant_id = actor
      and (scope = 'day:' || day_key or scope like 'day:' || day_key || ':%' or scope = 'month:' || yymm);
    -- Tills may still hold reserved numbers: continue after the highest one so none is handed out twice.
    select max(b.last_no) into held from public.receipt_blocks b where b.restaurant_id = actor and b.year_month = yymm;
    if held is not null then
      insert into public.order_number_counters (restaurant_id, scope, last_value) values (actor, 'month:' || yymm, held);
    end if;
    held_day := day_key;
    select max(b.day_last) into held from public.receipt_blocks b where b.restaurant_id = actor and b.day_key = held_day;
    if held is not null then
      insert into public.order_number_counters (restaurant_id, scope, last_value) values (actor, 'day:' || day_key, held);
    end if;
  end if;

  update public.orders
  set shift_order_number = null,
      number_day = null
  where restaurant_id = actor
    and status <> 'paid'
    and number_day = day_key;

  return jsonb_build_object('ok', true);
end;
$$;

-- 6. The "takeout" table is no longer used: archive it (receipts keep its history).
update public.dining_tables
set archived = true
where lower(btrim(number)) = 'takeout' and not archived
  and not exists (
    select 1 from public.orders o where o.table_id = dining_tables.id and o.status <> 'paid'
  );
