-- Undoes 20261028110000_move_table_accept_first.sql: puts back the merge of 20261027120000_move_table.sql.

create or replace function public.cashier_move_table(p_from uuid, p_to uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := coalesce(private.cashier_restaurant_id(), private.current_restaurant_id());
  src public.dining_tables%rowtype;
  dst public.dining_tables%rowtype;
  src_order public.orders%rowtype;
  dst_order public.orders%rowtype;
  last_round integer;
  merged boolean := false;
begin
  if actor is null then
    return jsonb_build_object('ok', false, 'error', 'sign in as a cashier first');
  end if;
  if p_from is null or p_to is null or p_from = p_to then
    return jsonb_build_object('ok', false, 'error', 'pick another table');
  end if;
  -- Lock both in id order so two moves at once can't wait on each other.
  perform 1 from public.dining_tables
  where id in (p_from, p_to) and restaurant_id = actor
  order by id
  for update;
  select * into src from public.dining_tables where id = p_from and restaurant_id = actor and not archived;
  select * into dst from public.dining_tables where id = p_to and restaurant_id = actor and not archived;
  if src.id is null or dst.id is null then
    return jsonb_build_object('ok', false, 'error', 'table not found');
  end if;

  select * into src_order from public.orders
  where table_id = p_from and restaurant_id = actor and status <> 'paid'
  order by created_at desc limit 1;
  if src_order.id is null and not exists (select 1 from public.cart_lines where table_id = p_from) then
    return jsonb_build_object('ok', false, 'error', 'nothing to move');
  end if;
  select * into dst_order from public.orders
  where table_id = p_to and restaurant_id = actor and status <> 'paid'
  order by created_at desc limit 1;

  if src_order.id is not null then
    if dst_order.id is null then
      update public.orders set table_id = p_to, table_number = dst.number where id = src_order.id;
    else
      select coalesce(max(round), 1) into last_round from public.order_lines where order_id = dst_order.id;
      update public.order_lines
        set order_id = dst_order.id, round = least(round, last_round)
        where order_id = src_order.id;
      delete from public.orders where id = src_order.id;
      merged := true;
    end if;
  end if;

  if exists (select 1 from public.cart_lines where table_id = p_from) then
    insert into public.carts (table_id, restaurant_id) values (p_to, actor) on conflict (table_id) do nothing;
    update public.cart_lines set table_id = p_to where table_id = p_from;
  end if;
  delete from public.carts where table_id = p_from;

  update public.staff_calls set table_id = p_to where table_id = p_from and resolved = false;
  update public.dining_tables
    set status = case when dst.status = 'free' then src.status else dst.status end,
        guests = dst.guests + src.guests
    where id = p_to;
  update public.dining_tables set status = 'free', guests = 0 where id = p_from;
  delete from public.table_claims where table_id = p_from;
  return jsonb_build_object('ok', true, 'merged', merged);
end;
$$;

revoke all on function public.cashier_move_table(uuid, uuid) from public;
grant execute on function public.cashier_move_table(uuid, uuid) to anon, authenticated;
