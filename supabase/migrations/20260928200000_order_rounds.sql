-- A table keeps one open order. Each send from the cart adds its lines as the next round.

alter table public.order_lines
  add column if not exists round integer not null default 1 check (round > 0);

create or replace function public.send_table_cart()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  tid uuid := private.guest_table_id();
  tbl public.dining_tables%rowtype;
  ord public.orders%rowtype;
  next_round integer;
begin
  if tid is null then
    return jsonb_build_object('ok', false, 'error', 'table not found');
  end if;
  select * into tbl from public.dining_tables where id = tid for update;
  if not exists (select 1 from public.cart_lines where table_id = tid) then
    return jsonb_build_object('ok', false, 'error', 'cart is empty');
  end if;
  select * into ord
  from public.orders
  where table_id = tid and status <> 'paid'
  order by created_at desc
  limit 1
  for update;
  if not found then
    insert into public.orders (restaurant_id, table_id, status)
    values (tbl.restaurant_id, tid, 'received')
    returning * into ord;
    next_round := 1;
  else
    select coalesce(max(round), 0) + 1 into next_round from public.order_lines where order_id = ord.id;
    update public.orders set status = 'received' where id = ord.id;
  end if;
  insert into public.order_lines (order_id, restaurant_id, menu_item_id, name, qty, unit_price, round)
  select ord.id, tbl.restaurant_id, cl.menu_item_id, cl.name, cl.qty, cl.unit_price, next_round
  from public.cart_lines cl
  where cl.table_id = tid;
  delete from public.cart_lines where table_id = tid;
  if tbl.status = 'free' then
    update public.dining_tables
      set status = 'dining',
          guests = case when guests = 0 then seats else guests end
      where id = tid;
  end if;
  return jsonb_build_object('ok', true, 'order_id', ord.id, 'round', next_round);
end;
$$;

revoke all on function public.send_table_cart() from public;
grant execute on function public.send_table_cart() to anon, authenticated;
