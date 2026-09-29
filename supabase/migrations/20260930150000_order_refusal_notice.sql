alter table public.orders
  add column if not exists awaiting_customer_confirmation boolean not null default false,
  add column if not exists refusal_notice text not null default '';

create or replace function public.note_order_refusal(p_order_id uuid, p_item_name text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  rid uuid := coalesce(private.current_restaurant_id(), private.cashier_restaurant_id());
begin
  if rid is null then
    raise exception 'sign in required';
  end if;
  update public.orders
    set awaiting_customer_confirmation = true,
        refusal_notice = trim(both ' ' from refusal_notice || ' ' || btrim(p_item_name))
    where id = p_order_id and restaurant_id = rid;
end;
$$;

create or replace function public.confirm_order_refusal(p_order_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.orders
    set awaiting_customer_confirmation = false,
        refusal_notice = ''
    where id = p_order_id
      and table_id = private.guest_table_id();
end;
$$;

revoke all on function public.note_order_refusal(uuid, text) from public;
revoke all on function public.confirm_order_refusal(uuid) from public;
grant execute on function public.note_order_refusal(uuid, text) to anon, authenticated;
grant execute on function public.confirm_order_refusal(uuid) to anon, authenticated;
