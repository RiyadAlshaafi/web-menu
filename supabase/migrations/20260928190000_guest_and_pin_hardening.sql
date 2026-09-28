-- Cashier PINs lock after repeated misses, prices come from the menu, and guests reach only their own table.

alter table public.cashiers
  add column if not exists failed_pin_attempts integer not null default 0,
  add column if not exists pin_locked_until timestamptz;

-- Every 5th miss locks the cashier: 15 minutes, then 30, 60, ... up to 24 hours.
create or replace function public.cashier_login(p_cashier_id uuid, p_pin text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  c public.cashiers%rowtype;
  raw_token text;
  lock_for interval;
begin
  select * into c from public.cashiers where id = p_cashier_id and active for update;
  if not found then
    return jsonb_build_object('ok', false);
  end if;
  if c.pin_locked_until > now() then
    return jsonb_build_object(
      'ok', false,
      'code', 'locked',
      'retry_after_seconds', ceil(extract(epoch from c.pin_locked_until - now()))::int
    );
  end if;
  if c.pin_hash is distinct from extensions.crypt(coalesce(p_pin, ''), c.pin_hash) then
    c.failed_pin_attempts := c.failed_pin_attempts + 1;
    if c.failed_pin_attempts % 5 = 0 then
      lock_for := least(
        interval '15 minutes' * power(2, c.failed_pin_attempts / 5 - 1),
        interval '24 hours'
      );
      update public.cashiers
        set failed_pin_attempts = c.failed_pin_attempts,
            pin_locked_until = now() + lock_for
        where id = c.id;
      return jsonb_build_object(
        'ok', false,
        'code', 'locked',
        'retry_after_seconds', extract(epoch from lock_for)::int
      );
    end if;
    update public.cashiers set failed_pin_attempts = c.failed_pin_attempts where id = c.id;
    return jsonb_build_object('ok', false);
  end if;
  update public.cashiers set failed_pin_attempts = 0, pin_locked_until = null where id = c.id;
  raw_token := encode(extensions.gen_random_bytes(32), 'hex');
  insert into public.cashier_sessions (cashier_id, restaurant_id, token_hash, expires_at)
  values (
    c.id,
    c.restaurant_id,
    encode(extensions.digest(raw_token, 'sha256'), 'hex'),
    now() + interval '12 hours'
  );
  return jsonb_build_object(
    'ok', true,
    'token', raw_token,
    'restaurant_id', c.restaurant_id,
    'cashier_id', c.id,
    'name', c.name,
    'initials', c.initials
  );
end;
$$;

create or replace function private.is_guest()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select auth.uid() is null and private.cashier_restaurant_id() is null;
$$;

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
    return new;
  end if;
  select * into item from public.menu_items where id = new.menu_item_id;
  if not found or item.restaurant_id <> parent.restaurant_id then
    raise exception 'menu item is not on this restaurant menu';
  end if;
  new.name := coalesce(nullif(item.name_en, ''), item.name_it);
  new.unit_price := private.menu_sale_price(item.id);
  return new;
end;
$$;

create or replace function private.stamp_cart()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  rid uuid;
begin
  select restaurant_id into rid from public.dining_tables where id = new.table_id;
  if rid is null then
    raise exception 'table not found';
  end if;
  new.restaurant_id := rid;
  return new;
end;
$$;

drop trigger if exists stamp_cart on public.carts;
create trigger stamp_cart before insert or update on public.carts
  for each row execute function private.stamp_cart();

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
    return new;
  end if;
  select * into item from public.menu_items where id = new.menu_item_id;
  if not found or item.restaurant_id <> rid then
    raise exception 'menu item is not on this restaurant menu';
  end if;
  new.unit_price := private.menu_sale_price(item.id);
  return new;
end;
$$;

drop trigger if exists stamp_cart_line on public.cart_lines;
create trigger stamp_cart_line before insert or update on public.cart_lines
  for each row execute function private.stamp_cart_line();

drop policy if exists carts_all on public.carts;
drop policy if exists cart_lines_all on public.cart_lines;
drop policy if exists calls_all on public.staff_calls;

create policy carts_staff on public.carts
  for all to anon, authenticated
  using (restaurant_id = (select private.actor_restaurant_id()))
  with check (restaurant_id = (select private.actor_restaurant_id()));

create policy carts_guest on public.carts
  for all to anon
  using (table_id = (select private.guest_table_id()))
  with check (table_id = (select private.guest_table_id()));

create policy cart_lines_staff on public.cart_lines
  for all to anon, authenticated
  using (restaurant_id = (select private.actor_restaurant_id()))
  with check (restaurant_id = (select private.actor_restaurant_id()));

create policy cart_lines_guest on public.cart_lines
  for all to anon
  using (table_id = (select private.guest_table_id()))
  with check (table_id = (select private.guest_table_id()));

create policy calls_staff on public.staff_calls
  for all to anon, authenticated
  using (restaurant_id = (select private.actor_restaurant_id()))
  with check (restaurant_id = (select private.actor_restaurant_id()));

create policy calls_guest_select on public.staff_calls
  for select to anon
  using (table_id = (select private.guest_table_id()));

create policy calls_guest_insert on public.staff_calls
  for insert to anon
  with check (
    table_id = (select private.guest_table_id())
    and restaurant_id = (select private.guest_restaurant_id())
  );

create policy calls_guest_update on public.staff_calls
  for update to anon
  using (table_id = (select private.guest_table_id()))
  with check (
    table_id = (select private.guest_table_id())
    and restaurant_id = (select private.guest_restaurant_id())
  );
