-- Guests may browse without a location. Ordering is blocked only when the
-- cafe turned the check on and saved a point. Allowance for GPS error is
-- capped at 50 m: distance - least(accuracy, 50) must be within the radius.

alter table public.restaurants
  add column if not exists location_lat double precision,
  add column if not exists location_lng double precision,
  add column if not exists location_radius_m integer not null default 100,
  add column if not exists location_check_enabled boolean not null default false;

alter table public.restaurants drop constraint if exists restaurants_location_radius_m_range;
alter table public.restaurants
  add constraint restaurants_location_radius_m_range check (location_radius_m between 30 and 500);

revoke select (location_lat, location_lng) on table public.restaurants from anon;

create or replace function private.distance_m(
  lat1 double precision,
  lng1 double precision,
  lat2 double precision,
  lng2 double precision
)
returns double precision
language sql
immutable
set search_path = ''
as $$
  select 6371000 * 2 * asin(least(1, sqrt(
    power(sin(radians(lat2 - lat1) / 2), 2)
    + cos(radians(lat1)) * cos(radians(lat2)) * power(sin(radians(lng2 - lng1) / 2), 2)
  )));
$$;

revoke all on function private.distance_m(double precision, double precision, double precision, double precision) from public, anon, authenticated;

-- null means the order may proceed. Otherwise 'location_required' or 'too_far'.
create or replace function private.order_location_error(
  p_restaurant_id uuid,
  p_lat double precision,
  p_lng double precision,
  p_accuracy_m double precision
)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  enabled boolean;
  radius_m integer;
  cafe_lat double precision;
  cafe_lng double precision;
  distance double precision;
  allowance double precision;
begin
  select location_check_enabled, location_radius_m, location_lat, location_lng
    into enabled, radius_m, cafe_lat, cafe_lng
  from public.restaurants
  where id = p_restaurant_id;
  if not found or coalesce(enabled, false) = false or cafe_lat is null or cafe_lng is null then
    return null;
  end if;
  if p_lat is null or p_lng is null then
    return 'location_required';
  end if;
  distance := private.distance_m(cafe_lat, cafe_lng, p_lat, p_lng);
  allowance := least(coalesce(p_accuracy_m, 0), 50);
  if distance - allowance <= radius_m then
    return null;
  end if;
  return 'too_far';
end;
$$;

revoke all on function private.order_location_error(uuid, double precision, double precision, double precision) from public, anon, authenticated;

drop function if exists public.send_table_cart(text, jsonb, text);
drop function if exists public.send_table_cart(text, jsonb, text, double precision, double precision, double precision);

create function public.send_table_cart(
  p_qr_slug text default null,
  p_lines jsonb default null,
  p_service_type text default 'dine_in',
  p_lat double precision default null,
  p_lng double precision default null,
  p_accuracy_m double precision default null
)
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
  service text := case when p_service_type = 'takeout' then 'takeout' else 'dine_in' end;
  location_error text;
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

  location_error := private.order_location_error(tbl.restaurant_id, p_lat, p_lng, p_accuracy_m);
  if location_error is not null then
    return jsonb_build_object('ok', false, 'error', location_error);
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
    insert into public.orders (restaurant_id, table_id, status, service_type)
    values (tbl.restaurant_id, tid, 'received', service)
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
  if ord.service_type <> 'takeout' and tbl.status = 'free' then
    update public.dining_tables
      set status = 'dining',
          guests = case when guests = 0 then seats else guests end
      where id = tid;
  end if;
  return jsonb_build_object('ok', true, 'order_id', ord.id, 'round', next_round, 'service_type', ord.service_type);
end;
$$;

revoke all on function public.send_table_cart(text, jsonb, text, double precision, double precision, double precision) from public;
grant execute on function public.send_table_cart(text, jsonb, text, double precision, double precision, double precision) to anon, authenticated;

create or replace function public.guest_location_rule(
  p_qr_slug text,
  p_lat double precision default null,
  p_lng double precision default null,
  p_accuracy_m double precision default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  rid uuid;
  enabled boolean;
  radius_m integer;
  cafe_lat double precision;
  cafe_lng double precision;
  location_error text;
begin
  select t.restaurant_id into rid
  from public.dining_tables t
  where t.qr_slug = nullif(btrim(coalesce(p_qr_slug, '')), '')
  limit 1;
  if rid is null then
    select restaurant_id into rid from public.dining_tables where id = private.guest_table_id();
  end if;
  if rid is null then
    return jsonb_build_object('enabled', false, 'radius_m', 100);
  end if;

  select location_check_enabled, location_radius_m, location_lat, location_lng
    into enabled, radius_m, cafe_lat, cafe_lng
  from public.restaurants
  where id = rid;

  enabled := coalesce(enabled, false) and cafe_lat is not null and cafe_lng is not null;
  if p_lat is null or p_lng is null or not enabled then
    return jsonb_build_object('enabled', enabled, 'radius_m', coalesce(radius_m, 100));
  end if;

  location_error := private.order_location_error(rid, p_lat, p_lng, p_accuracy_m);
  return jsonb_build_object(
    'enabled', true,
    'radius_m', coalesce(radius_m, 100),
    'status', coalesce(location_error, 'allowed')
  );
end;
$$;

revoke all on function public.guest_location_rule(text, double precision, double precision, double precision) from public;
grant execute on function public.guest_location_rule(text, double precision, double precision, double precision) to anon, authenticated;
