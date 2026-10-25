-- Undoes 20261027150000_guest_bill_needs_payment_type.sql: guests may ask for the bill at any time again.

create or replace function public.request_bill(p_qr_slug text default null, p_table_id uuid default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  staff uuid := coalesce(private.cashier_restaurant_id(), private.current_restaurant_id());
  slug text := nullif(btrim(coalesce(p_qr_slug, '')), '');
  tbl public.dining_tables%rowtype;
  ord public.orders%rowtype;
begin
  if slug is not null then
    select * into tbl from public.dining_tables where qr_slug = slug and not archived for update;
  elsif p_table_id is not null and staff is not null then
    select * into tbl from public.dining_tables where id = p_table_id and restaurant_id = staff for update;
  else
    select * into tbl from public.dining_tables where id = private.guest_table_id() for update;
  end if;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'table not found');
  end if;
  select * into ord
  from public.orders
  where table_id = tbl.id and status <> 'paid'
  order by created_at desc
  limit 1;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'no open bill');
  end if;
  if ord.service_type is distinct from 'takeout' and tbl.status <> 'billRequested' then
    update public.dining_tables set status = 'billRequested' where id = tbl.id;
  end if;
  if not exists (
    select 1 from public.staff_calls
    where table_id = tbl.id and kind = 'bill' and not resolved
  ) then
    insert into public.staff_calls (restaurant_id, table_id, kind)
    values (tbl.restaurant_id, tbl.id, 'bill');
  end if;
  return jsonb_build_object('ok', true);
end;
$$;


revoke all on function public.request_bill(text, uuid) from public;
grant execute on function public.request_bill(text, uuid) to anon, authenticated;
