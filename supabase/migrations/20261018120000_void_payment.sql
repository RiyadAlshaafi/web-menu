-- A cashier can void a paid sale (a customer had a problem and left). The order stays 'paid' so
-- its table is not reopened; the payment row carries the void and its reason, and the shift's
-- sales total and count drop as if the sale never happened. Only the cashier who took the sale,
-- while that shift is still open. Undo with supabase/rollbacks/20261018120000_void_payment.down.sql.

alter table public.payments
  add column if not exists voided_at timestamptz,
  add column if not exists voided_by uuid references public.cashiers (id) on delete set null,
  add column if not exists void_reason text;

create or replace function public.void_payment(p_payment_id uuid, p_reason text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  cid uuid := private.session_cashier_id();
  rid uuid := private.cashier_restaurant_id();
  pay public.payments%rowtype;
begin
  if cid is null or rid is null then
    return jsonb_build_object('ok', false, 'error', 'sign in as a cashier first');
  end if;
  if btrim(coalesce(p_reason, '')) = '' then
    return jsonb_build_object('ok', false, 'error', 'reason required');
  end if;
  -- An offline sale keeps its till-side id as client_id, so either id finds it.
  select * into pay
  from public.payments
  where (id = p_payment_id or client_id = p_payment_id)
    and restaurant_id = rid and cashier_id = cid
  for update;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'not_found');
  end if;
  if pay.voided_at is not null then
    return jsonb_build_object('ok', false, 'error', 'already voided');
  end if;
  if not exists (
    select 1 from public.shifts
    where id = pay.shift_id and cashier_id = cid and closed_at is null
  ) then
    return jsonb_build_object('ok', false, 'error', 'shift closed');
  end if;
  update public.payments
    set voided_at = now(), voided_by = cid, void_reason = left(btrim(p_reason), 200)
    where id = pay.id;
  update public.shifts
    set cash_sales = greatest(cash_sales - pay.total_due, 0),
        transaction_count = greatest(transaction_count - 1, 0)
    where id = pay.shift_id;
  return jsonb_build_object('ok', true, 'id', pay.id);
end;
$$;

revoke all on function public.void_payment(uuid, text) from public;
grant execute on function public.void_payment(uuid, text) to anon, authenticated;
