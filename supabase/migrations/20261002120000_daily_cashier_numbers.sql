-- Cashier ids count one calendar day in Tripoli (day:YYMMDD:cashier).
-- Admin ids count the whole month (month:YYMM) for every cashier and both service types.
-- Sequence text is padded to 3 digits and is never clipped when it grows past 999.

alter table public.orders
  add column if not exists number_day text;

create or replace function public.assign_shift_order_number(p_order_id uuid)
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
  cid uuid;
  day_key text;
  yymm text;
  n integer;
  seq text;
begin
  if actor is null then
    return jsonb_build_object('ok', false, 'error', 'sign in as a cashier first');
  end if;
  select * into ord
  from public.orders
  where id = p_order_id and restaurant_id = actor and status <> 'paid'
  for update;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'no open bill');
  end if;
  day_key := to_char(now() at time zone 'Africa/Tripoli', 'YYMMDD');
  yymm := left(day_key, 4);
  if ord.shift_order_number is not null and ord.number_day is not distinct from day_key then
    return jsonb_build_object('ok', true, 'year_month', ord.year_month, 'shift_order_number', ord.shift_order_number);
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
  insert into public.order_number_counters as counters (restaurant_id, scope, last_value)
  values (actor, 'day:' || day_key || ':' || cid::text, 1)
  on conflict (restaurant_id, scope)
  do update set last_value = counters.last_value + 1
  returning last_value into n;
  seq := case when length(n::text) >= 3 then n::text else lpad(n::text, 3, '0') end;
  update public.orders
  set year_month = yymm,
      shift_order_number = n,
      number_day = day_key
  where id = ord.id;
  return jsonb_build_object('ok', true, 'year_month', yymm, 'shift_order_number', n, 'display', yymm || seq);
end;
$$;

create or replace function public.settle_cash(
  p_table_id uuid,
  p_cash_received numeric,
  p_apply_service boolean default true,
  p_payment_type_id uuid default null
)
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
  rate numeric;
  shift public.shifts%rowtype;
  cid uuid;
  type_id uuid;
  yymm text;
  day_key text;
  shift_n integer;
  month_n integer;
  shift_label text;
  month_label text;
  assigned jsonb;
begin
  if actor is null then
    return jsonb_build_object('ok', false, 'error', 'sign in as a cashier first');
  end if;
  select * into ord
  from public.orders
  where table_id = p_table_id
    and restaurant_id = actor
    and status <> 'paid'
  order by created_at desc
  limit 1;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'no open bill');
  end if;
  if ord.status is distinct from 'served' then
    return jsonb_build_object('ok', false, 'error', 'order is not served');
  end if;
  type_id := coalesce(p_payment_type_id, ord.payment_type_id);
  if type_id is not null and not exists (
    select 1 from public.payment_types where id = type_id and restaurant_id = actor
  ) then
    type_id := null;
  end if;
  select coalesce((select sum(qty * unit_price) from public.order_lines where order_id = ord.id), 0)
    + coalesce((select sum(qty * unit_price) from public.cart_lines where table_id = p_table_id), 0)
    into due;
  select service_charge_rate into rate from public.restaurants where id = actor;
  if p_apply_service then
    due := round(due * (1 + coalesce(rate, 0)), 2);
  else
    due := round(due, 2);
  end if;
  if p_cash_received < due then
    return jsonb_build_object('ok', false, 'error', 'insufficient cash');
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
  select * into shift
  from public.shifts
  where cashier_id = cid and restaurant_id = actor and closed_at is null
  order by opened_at desc
  limit 1;
  if not found then
    insert into public.shifts (restaurant_id, cashier_id, opening_cash)
    values (actor, cid, 0)
    returning * into shift;
  end if;

  day_key := to_char(now() at time zone 'Africa/Tripoli', 'YYMMDD');
  if ord.shift_order_number is null or ord.number_day is distinct from day_key then
    assigned := public.assign_shift_order_number(ord.id);
    if coalesce(assigned->>'ok', 'false') <> 'true' then
      return assigned;
    end if;
    select * into ord from public.orders where id = ord.id;
  end if;
  yymm := to_char(now() at time zone 'Africa/Tripoli', 'YYMM');
  shift_n := ord.shift_order_number;
  shift_label := coalesce(ord.year_month, yymm) || case when length(shift_n::text) >= 3 then shift_n::text else lpad(shift_n::text, 3, '0') end;

  insert into public.order_number_counters as counters (restaurant_id, scope, last_value)
  values (actor, 'month:' || yymm, 1)
  on conflict (restaurant_id, scope)
  do update set last_value = counters.last_value + 1
  returning last_value into month_n;
  month_label := yymm || case when length(month_n::text) >= 3 then month_n::text else lpad(month_n::text, 3, '0') end;

  insert into public.payments (
    restaurant_id, order_id, table_id, total_due, cash_received, change_due, cashier_id, shift_id, payment_type_id,
    year_month, shift_order_number, monthly_order_number, shift_display_number, monthly_display_number
  ) values (
    actor, ord.id, p_table_id, due, p_cash_received, p_cash_received - due, cid, shift.id, type_id,
    yymm, shift_n, month_n, shift_label, month_label
  );
  update public.orders set status = 'paid', payment_type_id = type_id where id = ord.id;
  update public.dining_tables set status = 'free', guests = 0 where id = p_table_id;
  delete from public.cart_lines where table_id = p_table_id;
  delete from public.carts where table_id = p_table_id;
  update public.staff_calls set resolved = true where table_id = p_table_id and resolved = false;
  update public.shifts
    set cash_sales = cash_sales + due,
        transaction_count = transaction_count + 1
    where id = shift.id;
  return jsonb_build_object('ok', true, 'total_due', due, 'year_month', yymm, 'shift_order_number', shift_n, 'monthly_order_number', month_n);
end;
$$;
