-- Order numbers (#001, #002 ...) are one counter for the whole cafe: they continue from where the
-- last order stopped, whichever cashier took it, and start again at 001 the next day.
CREATE OR REPLACE FUNCTION public.assign_shift_order_number(p_order_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
  cid := (
    select cashier_id from public.cashier_sessions s
    where s.token_hash = encode(extensions.digest(coalesce(private.header('x-cashier-token'), ''), 'sha256'), 'hex')
      and s.expires_at > now()
    limit 1
  );
  if cid is null then
    return jsonb_build_object('ok', false, 'error', 'session expired, sign in again');
  end if;
  insert into public.order_number_counters as counters (restaurant_id, scope, last_value)
  values (actor, 'day:' || day_key, 1)
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
$function$
;

-- Clearing one cashier's logs no longer resets the shared counter (other cashiers' orders still use it).
CREATE OR REPLACE FUNCTION public.clear_test_logs(p_scope text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  rid uuid := private.cashier_restaurant_id();
  admin_rid uuid := private.current_restaurant_id();
  actor uuid := coalesce(rid, admin_rid);
  cid uuid;
  day_key text;
  yymm text;
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
  end if;

  update public.orders
  set shift_order_number = null,
      number_day = null
  where restaurant_id = actor
    and status <> 'paid'
    and number_day = day_key;

  return jsonb_build_object('ok', true);
end;
$function$
;

-- Continue today's count from the orders already numbered today, so nothing repeats.
insert into public.order_number_counters (restaurant_id, scope, last_value)
select o.restaurant_id, 'day:' || o.number_day, max(o.shift_order_number)
from public.orders o
where o.number_day = to_char(now() at time zone 'Africa/Tripoli', 'YYMMDD')
  and o.shift_order_number is not null
group by o.restaurant_id, o.number_day
on conflict (restaurant_id, scope)
do update set last_value = greatest(public.order_number_counters.last_value, excluded.last_value);
