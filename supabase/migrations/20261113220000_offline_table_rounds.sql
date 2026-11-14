create table if not exists private.offline_table_rounds (
  restaurant_id uuid not null references public.restaurants(id) on delete cascade,
  client_id uuid not null,
  primary key (restaurant_id, client_id)
);

alter table private.offline_table_rounds enable row level security;

create or replace function public.sync_offline_table_round(
  p_client_id uuid, p_restaurant_id uuid, p_cashier_id uuid, p_table_id uuid, p_lines jsonb
) returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  rid uuid := private.cashier_restaurant_id();
  slug text;
  answer jsonb;
begin
  if rid is null then
    return jsonb_build_object('ok', false, 'error', 'session expired');
  end if;
  if rid is distinct from p_restaurant_id or private.session_is_waiter() then
    return jsonb_build_object('ok', false, 'error', 'wrong restaurant or role');
  end if;
  if private.session_cashier_id() is distinct from p_cashier_id then
    return jsonb_build_object('ok', false, 'error', 'another cashier');
  end if;

  insert into private.offline_table_rounds values (rid, p_client_id)
    on conflict do nothing;
  if not found then
    return jsonb_build_object('ok', true, 'duplicate', true);
  end if;

  begin
    select qr_slug into slug from public.dining_tables
      where id = p_table_id and restaurant_id = rid and not archived for update;
    if slug is null or btrim(slug) = '' then
      answer := jsonb_build_object('ok', false, 'error', 'table not found');
    elsif jsonb_typeof(p_lines) is distinct from 'array' or jsonb_array_length(p_lines) = 0 then
      answer := jsonb_build_object('ok', false, 'error', 'cart is empty');
    elsif exists (
      select from jsonb_to_recordset(p_lines) as line(menu_item_id uuid, qty integer)
      where line.qty is null or line.qty not between 1 and 99
         or not exists (select from public.menu_items where id = line.menu_item_id and restaurant_id = rid)
    ) then
      answer := jsonb_build_object('ok', false, 'error', 'items_unavailable');
    else
      answer := public.send_table_cart(p_qr_slug => slug, p_lines => p_lines);
    end if;
    if answer->>'ok' is distinct from 'true' then
      raise sqlstate 'P4470';
    end if;
    update public.orders set status = 'preparing'
      where restaurant_id = rid and id = (answer->>'order_id')::uuid and status = 'received';
  exception when sqlstate 'P4470' then
    delete from private.offline_table_rounds where restaurant_id = rid and client_id = p_client_id;
  end;
  return answer;
end;
$$;

revoke all on function public.sync_offline_table_round(uuid, uuid, uuid, uuid, jsonb) from public;
grant execute on function public.sync_offline_table_round(uuid, uuid, uuid, uuid, jsonb) to anon, authenticated;
