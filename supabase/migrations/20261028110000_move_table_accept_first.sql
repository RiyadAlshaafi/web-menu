-- Fixes merging two tables (cashier_move_table), which could lose dishes or print them twice.
--
-- A merge keeps each dish's round, capped at the other tab's last round, so the kitchen treats
-- them as rounds it already printed. That is only true when both tabs are past Accept:
--   - an order still "received" (a guest's or a waiter's order waiting for Accept) has printed
--     nothing, so its dishes would be marked as printed and never cooked;
--   - a printed order merged into a "received" one would have its dishes printed again.
-- So a merge where either tab is still waiting for Accept is refused with 'accept the new order
-- first'. Moving a tab to a free table is unchanged (the order itself moves).
-- After a merge the tab takes the less advanced status of the two, so dishes still cooking on one
-- table do not show as served.
-- Undo with supabase/rollbacks/20261028110000_move_table_accept_first.down.sql.

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
      if src_order.status::text = 'received' or dst_order.status::text = 'received' then
        return jsonb_build_object('ok', false, 'error', 'accept the new order first');
      end if;
      select coalesce(max(round), 1) into last_round from public.order_lines where order_id = dst_order.id;
      update public.order_lines
        set order_id = dst_order.id, round = least(round, last_round)
        where order_id = src_order.id;
      delete from public.orders where id = src_order.id;
      update public.orders
        set status = case
          when array_position(array['received', 'preparing', 'ready', 'served'], src_order.status::text)
             < array_position(array['received', 'preparing', 'ready', 'served'], dst_order.status::text)
          then src_order.status else dst_order.status end
        where id = dst_order.id;
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
