-- Cashiers and admins can mark a dish unavailable without rewriting the whole menu.

create or replace function public.set_item_available(p_item_id uuid, p_available boolean)
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
  update public.menu_items
    set available = p_available
    where id = p_item_id and restaurant_id = rid;
end;
$$;

revoke all on function public.set_item_available(uuid, boolean) from public;
grant execute on function public.set_item_available(uuid, boolean) to anon, authenticated;

do $$
begin
  alter publication supabase_realtime add table public.menu_items;
exception
  when duplicate_object then null;
end $$;
