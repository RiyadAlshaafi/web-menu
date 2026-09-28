-- Guest sends can fail if the QR header never reaches RPC. Accept the slug and lines on the call.

drop function if exists public.send_table_cart();
drop function if exists public.send_table_cart(text, jsonb);

create function public.send_table_cart(p_qr_slug text default null, p_lines jsonb default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  tid uuid;
  tbl public.dining_tables%rowtype;
  ord public.orders%rowtype;
  next_round integer;
  line_count integer := 0;
begin
  tid := coalesce(
    (select id from public.dining_tables where qr_slug = nullif(btrim(coalesce(p_qr_slug, '')), '') limit 1),
    private.guest_table_id()
  );
  if tid is null then
    return jsonb_build_object('ok', false, 'error', 'table not found');
  end if;
  select * into tbl from public.dining_tables where id = tid for update;
  if tbl.id is null then
    return jsonb_build_object('ok', false, 'error', 'table not found');
  end if;

  insert into public.carts (table_id, restaurant_id)
  values (tid, tbl.restaurant_id)
  on conflict (table_id) do update set restaurant_id = excluded.restaurant_id;

  if p_lines is not null and jsonb_typeof(p_lines) = 'array' and jsonb_array_length(p_lines) > 0 then
    delete from public.cart_lines where table_id = tid;
    insert into public.cart_lines (table_id, restaurant_id, menu_item_id, name, qty, unit_price)
    select tid, tbl.restaurant_id, item.id, coalesce(nullif(item.name_en, ''), item.name_it), x.qty, 0
    from jsonb_to_recordset(p_lines) as x(menu_item_id uuid, qty integer)
    join public.menu_items item on item.id = x.menu_item_id
    where item.restaurant_id = tbl.restaurant_id and x.qty > 0;
  end if;

  select count(*) into line_count from public.cart_lines where table_id = tid;
  if line_count = 0 then
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

revoke all on function public.send_table_cart(text, jsonb) from public;
grant execute on function public.send_table_cart(text, jsonb) to anon, authenticated;
