-- Short display numbers are assigned when a sale is settled.
-- Shift sequence is per open shift. Monthly sequence is per YYMM.
-- The internal payment and order ids stay unchanged.

create table public.order_number_counters (
  restaurant_id uuid not null references public.restaurants (id) on delete cascade,
  scope text not null,
  last_value integer not null,
  primary key (restaurant_id, scope)
);

alter table public.order_number_counters enable row level security;

alter table public.payments
  add column year_month text,
  add column shift_order_number integer,
  add column monthly_order_number integer,
  add column shift_display_number text,
  add column monthly_display_number text;

drop function if exists public.settle_cash(uuid, numeric, boolean, uuid);

create function public.settle_cash(
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
  shift_n integer;
  month_n integer;
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

  yymm := to_char(now() at time zone 'Africa/Tripoli', 'YYMM');
  insert into public.order_number_counters as counters (restaurant_id, scope, last_value)
  values (actor, 'shift:' || shift.id::text, 1)
  on conflict (restaurant_id, scope)
  do update set last_value = counters.last_value + 1
  returning last_value into shift_n;
  insert into public.order_number_counters as counters (restaurant_id, scope, last_value)
  values (actor, 'month:' || yymm, 1)
  on conflict (restaurant_id, scope)
  do update set last_value = counters.last_value + 1
  returning last_value into month_n;

  insert into public.payments (
    restaurant_id, order_id, table_id, total_due, cash_received, change_due, cashier_id, shift_id, payment_type_id,
    year_month, shift_order_number, monthly_order_number, shift_display_number, monthly_display_number
  ) values (
    actor, ord.id, p_table_id, due, p_cash_received, p_cash_received - due, cid, shift.id, type_id,
    yymm, shift_n, month_n, yymm || '-' || shift_n::text, yymm || '-' || month_n::text
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

grant execute on function public.settle_cash(uuid, numeric, boolean, uuid) to anon, authenticated;
