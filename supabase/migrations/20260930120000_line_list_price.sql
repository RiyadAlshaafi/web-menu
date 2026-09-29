-- Freeze the menu price next to the charged price so the deducted discount cannot drift later.

alter table public.cart_lines
  add column if not exists list_unit_price numeric(12, 2);

alter table public.order_lines
  add column if not exists list_unit_price numeric(12, 2);

create or replace function private.stamp_order_line()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  item public.menu_items%rowtype;
  parent public.orders%rowtype;
begin
  select * into parent from public.orders where id = new.order_id;
  if not found then
    raise exception 'order not found';
  end if;
  new.restaurant_id := parent.restaurant_id;
  if new.menu_item_id is null then
    if private.is_guest() then
      raise exception 'guests can only order items from the menu';
    end if;
    new.list_unit_price := coalesce(new.list_unit_price, new.unit_price);
    return new;
  end if;
  select * into item from public.menu_items where id = new.menu_item_id;
  if not found or item.restaurant_id <> parent.restaurant_id then
    raise exception 'menu item is not on this restaurant menu';
  end if;
  new.name := coalesce(nullif(item.name_en, ''), item.name_it);
  new.list_unit_price := item.price;
  new.unit_price := private.menu_sale_price(item.id);
  return new;
end;
$$;

create or replace function private.stamp_cart_line()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  item public.menu_items%rowtype;
  rid uuid;
begin
  select restaurant_id into rid from public.carts where table_id = new.table_id;
  if rid is null then
    raise exception 'cart not found';
  end if;
  new.restaurant_id := rid;
  if new.menu_item_id is null then
    if private.is_guest() then
      raise exception 'guests can only order items from the menu';
    end if;
    new.list_unit_price := coalesce(new.list_unit_price, new.unit_price);
    return new;
  end if;
  select * into item from public.menu_items where id = new.menu_item_id;
  if not found or item.restaurant_id <> rid then
    raise exception 'menu item is not on this restaurant menu';
  end if;
  new.list_unit_price := item.price;
  new.unit_price := private.menu_sale_price(item.id);
  return new;
end;
$$;

create or replace function public.send_table_cart(p_qr_slug text default null, p_lines jsonb default null)
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

  insert into public.order_lines (order_id, restaurant_id, menu_item_id, name, qty, unit_price, list_unit_price, round)
  select ord.id, tbl.restaurant_id, cl.menu_item_id, cl.name, cl.qty, cl.unit_price, cl.list_unit_price, next_round
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
