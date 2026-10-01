-- Test helper: wipe cashier sales or the shift register so ticket numbers can be retested.
-- Cashier scope removes that cashier's payments and restarts their day counter.
-- Shift scope empties the register log, zeroes shift totals, and restarts today's numbers.

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
    delete from public.order_number_counters
    where restaurant_id = actor
      and scope = 'day:' || day_key || ':' || cid::text;
  else
    delete from public.payments where restaurant_id = actor;
    update public.shifts
    set cash_sales = 0,
        transaction_count = 0
    where restaurant_id = actor;
    delete from public.order_number_counters
    where restaurant_id = actor
      and (scope like 'day:' || day_key || ':%' or scope = 'month:' || yymm);
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

revoke all on function public.clear_test_logs(text) from public;
grant execute on function public.clear_test_logs(text) to anon, authenticated;
