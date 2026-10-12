-- Undoes 20261015100000_close_shift_needs_paid_orders.sql: close_shift no longer checks for
-- unpaid orders. Restored exactly as 20261008100000_security_and_money_fixes.sql defines it.

create or replace function public.close_shift(p_actual_cash numeric)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  rid uuid := private.cashier_restaurant_id();
  cid uuid := private.session_cashier_id();
  sid uuid;
begin
  if rid is null or cid is null then
    return jsonb_build_object('ok', false, 'error', 'session expired, sign in again');
  end if;
  if p_actual_cash is null or p_actual_cash < 0 then
    return jsonb_build_object('ok', false, 'error', 'invalid');
  end if;
  update public.shifts
  set actual_cash = round(p_actual_cash, 2),
      closed_at = now()
  where id = (
    select id from public.shifts
    where cashier_id = cid and restaurant_id = rid and closed_at is null
    order by opened_at desc
    limit 1
  )
  returning id into sid;
  if sid is null then
    return jsonb_build_object('ok', false, 'error', 'no open shift');
  end if;
  return jsonb_build_object('ok', true, 'shift_id', sid);
end;
$$;

revoke all on function public.close_shift(numeric) from public;
grant execute on function public.close_shift(numeric) to anon, authenticated;
