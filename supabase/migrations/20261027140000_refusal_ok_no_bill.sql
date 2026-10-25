-- The guest's "OK" on the "item removed" notice only clears the notice. It used to ask for the
-- bill too, so every refused dish sent the cashier a checkout request the guest never meant.
-- Clearing a notice needs no cashier online, so there is no cashier_offline answer any more.
-- Rollback: supabase/rollbacks/20261027140000_refusal_ok_no_bill.down.sql

create or replace function public.guest_confirm_refusal(p_qr_slug text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  tbl public.dining_tables;
  ord public.orders%rowtype;
begin
  tbl := private.table_for_slug(p_qr_slug);
  if tbl.id is null then
    return jsonb_build_object('ok', false, 'error', 'table not found');
  end if;
  select * into ord
  from public.orders
  where table_id = tbl.id and status <> 'paid'
  order by created_at desc
  limit 1
  for update;
  if ord.id is null then
    return jsonb_build_object('ok', false, 'error', 'no open bill');
  end if;
  update public.orders
    set awaiting_customer_confirmation = false,
        refusal_notice = ''
    where id = ord.id;
  return jsonb_build_object('ok', true);
end;
$$;

revoke all on function public.guest_confirm_refusal(text) from public, anon, authenticated;
grant execute on function public.guest_confirm_refusal(text) to anon;
