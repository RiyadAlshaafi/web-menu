-- Undoes 20261027140000_refusal_ok_no_bill.sql: the guest's OK on a refused dish asks for the bill again.

create or replace function public.guest_confirm_refusal(p_qr_slug text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  tbl public.dining_tables;
  ord public.orders%rowtype;
  result jsonb;
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
  -- A refused bill call (cashier offline) lands in the handler below, which also undoes the
  -- update above, so the notice stays until the bill request goes through.
  result := public.request_bill(tbl.qr_slug, null);
  return result;
exception when raise_exception then
  if sqlerrm = 'cashier_offline' then
    return jsonb_build_object('ok', false, 'error', 'cashier_offline');
  end if;
  raise;
end;
$$;

revoke all on function public.guest_confirm_refusal(text) from public, anon, authenticated;
grant execute on function public.guest_confirm_refusal(text) to anon;
