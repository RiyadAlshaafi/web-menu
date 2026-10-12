-- A shift can't be closed while the cafe still has an unpaid order with dishes on it, so no table
-- is left owing money after the till is counted. Same signature and answer shape as before, so
-- older tills keep working: they just show the refusal text. An order whose dishes were all
-- removed owes nothing and does not block.
--
-- sync_offline_shift_close is left as it is: a shift closed on a till without a connection has
-- already been closed there, and refusing its upload would leave it stuck in the outbox.
-- Undo with supabase/rollbacks/20261015100000_close_shift_needs_paid_orders.down.sql.

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
  unpaid integer;
begin
  if rid is null or cid is null then
    return jsonb_build_object('ok', false, 'error', 'session expired, sign in again');
  end if;
  if p_actual_cash is null or p_actual_cash < 0 then
    return jsonb_build_object('ok', false, 'error', 'invalid');
  end if;
  select count(*) into unpaid
  from public.orders o
  where o.restaurant_id = rid
    and o.status <> 'paid'
    and exists (select 1 from public.order_lines l where l.order_id = o.id);
  if unpaid > 0 then
    return jsonb_build_object('ok', false, 'error', 'unpaid orders still open', 'unpaid_orders', unpaid);
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
