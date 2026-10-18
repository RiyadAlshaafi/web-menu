-- Dish choices: ingredients (on or off by default, the guest can remove or add them) and extra
-- toppings (off by default). Only a choice that is off by default and turned on is charged; the
-- dish discount never applies to it. A line keeps a snapshot of the choices that differ from the
-- dish defaults, with the price charged, so receipts stay right after the menu changes.
-- Every function keeps its signature: a line without choices still means "dish as it comes".

-- ------------------------------------------------------------ columns

-- [{id, kind: ingredient|topping, nameAr, nameEn, price, defaultOn}]
create or replace function private.valid_dish_options(p_options jsonb)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select jsonb_typeof(p_options) = 'array'
    and jsonb_array_length(p_options) <= 40
    and not exists (
      select 1 from jsonb_array_elements(p_options) o
      where jsonb_typeof(o) <> 'object'
        or jsonb_typeof(o->'id') is distinct from 'string'
        or coalesce(o->>'kind', '') not in ('ingredient', 'topping')
        or jsonb_typeof(o->'defaultOn') is distinct from 'boolean'
        or jsonb_typeof(o->'price') is distinct from 'number'
        or (o->>'price')::numeric < 0
        or length(coalesce(o->>'nameAr', '') || coalesce(o->>'nameEn', '')) = 0
    )
    and (select count(distinct o->>'id') from jsonb_array_elements(p_options) o) = jsonb_array_length(p_options);
$$;

alter table public.menu_items add column if not exists options jsonb not null default '[]'::jsonb;
alter table public.menu_items drop constraint if exists menu_items_options_valid;
alter table public.menu_items add constraint menu_items_options_valid check (private.valid_dish_options(options));
alter table public.cart_lines add column if not exists choices jsonb not null default '[]'::jsonb;
alter table public.order_lines add column if not exists choices jsonb not null default '[]'::jsonb;

-- ------------------------------------------------------------ helpers

-- The choices of one line that differ from the dish defaults: [{id, nameAr, nameEn, on, price}].
-- [p_on] is the full set of option ids that are on (a guest or till send); when it is not an
-- array, [p_diff] (earlier choices, only id and on are read) changes the defaults instead.
-- Names and prices always come from the menu; ids the dish does not have are dropped.
create or replace function private.dish_choices(p_options jsonb, p_on jsonb, p_diff jsonb)
returns jsonb
language sql
immutable
set search_path = ''
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', s.id, 'nameAr', s.name_ar, 'nameEn', s.name_en, 'on', s.is_on,
    'price', case when s.is_on then s.price else 0 end
  ) order by s.n), '[]'::jsonb)
  from (
    select o->>'id' as id, coalesce(o->>'nameAr', '') as name_ar, coalesce(o->>'nameEn', '') as name_en,
           coalesce((o->>'price')::numeric, 0) as price, coalesce((o->>'defaultOn')::boolean, false) as default_on, n,
           case
             when jsonb_typeof(p_on) = 'array' then p_on ? (o->>'id')
             else coalesce((
               select (d->>'on')::boolean
               from jsonb_array_elements(case when jsonb_typeof(p_diff) = 'array' then p_diff else '[]'::jsonb end) d
               where jsonb_typeof(d) = 'object' and d->>'id' = o->>'id' and jsonb_typeof(d->'on') = 'boolean'
               limit 1
             ), coalesce((o->>'defaultOn')::boolean, false))
           end as is_on
    from jsonb_array_elements(case when jsonb_typeof(p_options) = 'array' then p_options else '[]'::jsonb end)
      with ordinality as e(o, n)
  ) s
  where s.is_on <> s.default_on;
$$;

-- What the choices add to one unit of the dish.
create or replace function private.choices_extra(p_choices jsonb)
returns numeric
language sql
immutable
set search_path = ''
as $$
  select coalesce(sum((c->>'price')::numeric), 0)
  from jsonb_array_elements(case when jsonb_typeof(p_choices) = 'array' then p_choices else '[]'::jsonb end) c
  where jsonb_typeof(c) = 'object' and c->>'on' = 'true' and jsonb_typeof(c->'price') = 'number';
$$;

revoke all on function private.valid_dish_options(jsonb) from public, anon, authenticated;
revoke all on function private.dish_choices(jsonb, jsonb, jsonb) from public, anon, authenticated;
revoke all on function private.choices_extra(jsonb) from public, anon, authenticated;

-- ------------------------------------------------------------ line prices

create or replace function private.stamp_cart_line()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  item public.menu_items%rowtype;
  rid uuid;
  extra numeric;
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
    new.choices := '[]'::jsonb;
    new.list_unit_price := coalesce(new.list_unit_price, new.unit_price);
    return new;
  end if;
  select * into item from public.menu_items where id = new.menu_item_id;
  if not found or item.restaurant_id <> rid then
    raise exception 'menu item is not on this restaurant menu';
  end if;
  new.choices := private.dish_choices(item.options, null, new.choices);
  extra := private.choices_extra(new.choices);
  new.list_unit_price := item.price + extra;
  new.unit_price := private.menu_sale_price(item.id) + extra;
  return new;
end;
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
  extra numeric;
begin
  select * into parent from public.orders where id = new.order_id;
  if not found then
    raise exception 'order not found';
  end if;
  new.restaurant_id := parent.restaurant_id;
  if current_setting('app.offline_sync', true) = 'on' then
    if new.menu_item_id is not null then
      select * into item from public.menu_items where id = new.menu_item_id;
      if not found then
        new.menu_item_id := null;
      elsif item.restaurant_id <> parent.restaurant_id then
        raise exception 'menu item is not on this restaurant menu';
      end if;
    end if;
    -- The till's own snapshot is kept as charged; only its shape and size are checked.
    if jsonb_typeof(new.choices) is distinct from 'array' or jsonb_array_length(new.choices) > 40 then
      new.choices := '[]'::jsonb;
    end if;
    new.list_unit_price := coalesce(new.list_unit_price, new.unit_price);
    return new;
  end if;
  if new.menu_item_id is null then
    if private.is_guest() and current_setting('dev.import', true) is distinct from 'on' then
      raise exception 'guests can only order items from the menu';
    end if;
    new.choices := '[]'::jsonb;
    new.list_unit_price := coalesce(new.list_unit_price, new.unit_price);
    return new;
  end if;
  select * into item from public.menu_items where id = new.menu_item_id;
  if not found or item.restaurant_id <> parent.restaurant_id then
    raise exception 'menu item is not on this restaurant menu';
  end if;
  new.name := coalesce(nullif(item.name_en, ''), item.name_it);
  new.choices := private.dish_choices(item.options, null, new.choices);
  extra := private.choices_extra(new.choices);
  new.list_unit_price := item.price + extra;
  new.unit_price := private.menu_sale_price(item.id) + extra;
  return new;
end;
$$;

-- ------------------------------------------------------------ order RPCs

create or replace function public.send_table_cart(
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
  unavailable jsonb;
  slug text := nullif(btrim(coalesce(p_qr_slug, '')), '');
begin
  -- A slug that was sent is final: falling back to the request header when it
  -- does not match could put the order on a different table.
  if slug is not null then
    select id into tid from public.dining_tables where qr_slug = slug and not archived;
  else
    tid := private.guest_table_id();
  end if;
  if tid is null then
    return jsonb_build_object('ok', false, 'error', 'table not found');
  end if;
  select * into tbl from public.dining_tables where id = tid for update;
  if tbl.id is null or tbl.archived then
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
    if jsonb_array_length(p_lines) > 100 then
      return jsonb_build_object('ok', false, 'error', 'too_many_lines');
    end if;
    delete from public.cart_lines where table_id = tid;
    insert into public.cart_lines (table_id, restaurant_id, menu_item_id, name, qty, unit_price, choices)
    select tid, tbl.restaurant_id, item.id, coalesce(nullif(item.name_en, ''), item.name_it), x.qty, 0,
           private.dish_choices(item.options, x."on", null)
    from jsonb_to_recordset(p_lines) as x(menu_item_id uuid, qty integer, "on" jsonb)
    join public.menu_items item on item.id = x.menu_item_id
    where item.restaurant_id = tbl.restaurant_id and x.qty > 0;
  end if;

  select count(*) into line_count from public.cart_lines where table_id = tid;
  if line_count = 0 then
    return jsonb_build_object('ok', false, 'error', 'cart is empty');
  end if;

  if exists (select 1 from public.cart_lines where table_id = tid and qty > 99) then
    return jsonb_build_object('ok', false, 'error', 'qty_too_large');
  end if;

  -- A dish can be switched off after the guest put it in the cart. Refuse the
  -- whole send and name the dishes, so the guest decides what to do instead.
  select coalesce(jsonb_agg(distinct coalesce(nullif(item.name_en, ''), item.name_it)), '[]'::jsonb)
    into unavailable
  from public.cart_lines cl
  join public.menu_items item on item.id = cl.menu_item_id
  where cl.table_id = tid and (not item.available or item.sold_out);
  if jsonb_array_length(unavailable) > 0 then
    return jsonb_build_object('ok', false, 'error', 'items_unavailable', 'items', unavailable);
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

  insert into public.order_lines (order_id, restaurant_id, menu_item_id, name, qty, unit_price, list_unit_price, round, choices)
  select ord.id, tbl.restaurant_id, cl.menu_item_id, cl.name, cl.qty, cl.unit_price, cl.list_unit_price, next_round, cl.choices
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

create or replace function public.quick_takeout_receipt(p_lines jsonb, p_payment_type_id uuid default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  rid uuid := private.cashier_restaurant_id();
  admin_rid uuid := private.current_restaurant_id();
  actor uuid := coalesce(rid, admin_rid);
  ord public.orders%rowtype;
  due numeric;
  shift public.shifts%rowtype;
  cid uuid;
  type_id uuid;
  yymm text;
  shift_n integer;
  month_n integer;
  shift_label text;
  month_label text;
  assigned jsonb;
  line_count integer := 0;
begin
  if actor is null then
    return jsonb_build_object('ok', false, 'error', 'sign in as a cashier first');
  end if;
  if p_lines is null or jsonb_typeof(p_lines) <> 'array' or jsonb_array_length(p_lines) = 0 then
    return jsonb_build_object('ok', false, 'error', 'cart is empty');
  end if;
  type_id := p_payment_type_id;
  if type_id is not null and not exists (select 1 from public.payment_types where id = type_id and restaurant_id = actor) then
    type_id := null;
  end if;
  insert into public.orders (restaurant_id, table_id, status, service_type, payment_type_id)
  values (actor, null, 'served', 'takeout', type_id)
  returning * into ord;
  insert into public.order_lines (order_id, restaurant_id, menu_item_id, name, qty, unit_price, round, choices)
  select ord.id, actor, item.id, coalesce(nullif(item.name_en, ''), item.name_it), x.qty, 0, 1,
         private.dish_choices(item.options, x."on", null)
  from jsonb_to_recordset(p_lines) as x(menu_item_id uuid, qty integer, "on" jsonb)
  join public.menu_items item on item.id = x.menu_item_id
  where item.restaurant_id = actor and item.available and not item.sold_out and x.qty > 0;
  get diagnostics line_count = row_count;
  if line_count = 0 then
    delete from public.orders where id = ord.id;
    return jsonb_build_object('ok', false, 'error', 'cart is empty');
  end if;
  select round(coalesce(sum(qty * unit_price), 0), 2) into due from public.order_lines where order_id = ord.id;
  cid := coalesce(
    (select cashier_id from public.cashier_sessions s
      where s.token_hash = encode(extensions.digest(coalesce(private.header('x-cashier-token'), ''), 'sha256'), 'hex')
        and s.expires_at > now()
      limit 1),
    (select id from public.cashiers where restaurant_id = actor order by created_at limit 1)
  );
  if cid is null then
    delete from public.order_lines where order_id = ord.id;
    delete from public.orders where id = ord.id;
    return jsonb_build_object('ok', false, 'error', 'sign in as a cashier first');
  end if;
  select * into shift from public.shifts
  where cashier_id = cid and restaurant_id = actor and closed_at is null
  order by opened_at desc limit 1;
  if not found then
    insert into public.shifts (restaurant_id, cashier_id, opening_cash) values (actor, cid, 0) returning * into shift;
  end if;
  assigned := public.assign_shift_order_number(ord.id);
  if coalesce(assigned->>'ok', 'false') <> 'true' then
    return assigned;
  end if;
  select * into ord from public.orders where id = ord.id;
  yymm := to_char(now() at time zone 'Africa/Tripoli', 'YYMM');
  shift_n := ord.shift_order_number;
  shift_label := coalesce(ord.year_month, yymm)
    || case when length(shift_n::text) >= 3 then shift_n::text else lpad(shift_n::text, 3, '0') end;
  insert into public.order_number_counters as counters (restaurant_id, scope, last_value)
  values (actor, 'month:' || yymm, 1)
  on conflict (restaurant_id, scope) do update set last_value = counters.last_value + 1
  returning last_value into month_n;
  month_label := yymm || case when length(month_n::text) >= 3 then month_n::text else lpad(month_n::text, 3, '0') end;
  insert into public.payments (
    restaurant_id, order_id, table_id, total_due, cash_received, change_due, cashier_id, shift_id, payment_type_id,
    year_month, shift_order_number, monthly_order_number, shift_display_number, monthly_display_number
  ) values (
    actor, ord.id, null, due, due, 0, cid, shift.id, type_id, yymm, shift_n, month_n, shift_label, month_label
  );
  update public.orders set status = 'paid', payment_type_id = type_id, service_type = 'takeout' where id = ord.id;
  update public.shifts set cash_sales = cash_sales + due, transaction_count = transaction_count + 1 where id = shift.id;
  return jsonb_build_object('ok', true, 'order_id', ord.id, 'total_due', due, 'year_month', yymm,
    'shift_order_number', shift_n, 'monthly_order_number', month_n);
end;
$$;

create or replace function public.sync_offline_takeout(
  p_client_id uuid, p_cashier_id uuid, p_shift_id uuid, p_lines jsonb, p_payment_type_id uuid,
  p_paid_at timestamptz, p_year_month text, p_monthly_no integer, p_day_key text, p_day_no integer
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  rid uuid := private.cashier_restaurant_id();
  ord public.orders%rowtype;
  shift public.shifts%rowtype;
  due numeric := 0;
  type_id uuid := p_payment_type_id;
  line_count integer := 0;
  m_label text;
  d_label text;
begin
  if rid is null then
    return jsonb_build_object('ok', false, 'error', 'session expired, sign in again');
  end if;
  -- A retry that overlaps a slow first upload waits here, then sees the first one as a duplicate.
  perform pg_advisory_xact_lock(hashtext('offline_upload:' || p_client_id::text));
  if exists (select 1 from public.payments where client_id = p_client_id and restaurant_id = rid) then
    return jsonb_build_object('ok', true, 'duplicate', true);
  end if;
  if not exists (select 1 from public.cashiers where id = p_cashier_id and restaurant_id = rid) then
    return jsonb_build_object('ok', false, 'error', 'unknown cashier');
  end if;
  if p_lines is null or jsonb_typeof(p_lines) <> 'array' or jsonb_array_length(p_lines) = 0 then
    return jsonb_build_object('ok', false, 'error', 'cart is empty');
  end if;
  if not exists (
    select 1 from public.receipt_blocks b
    where b.restaurant_id = rid and b.year_month = p_year_month
      and p_monthly_no between b.first_no and b.last_no
  ) then
    return jsonb_build_object('ok', false, 'error', 'receipt number was not reserved');
  end if;
  if p_day_no is not null and not exists (
    select 1 from public.receipt_blocks b
    where b.restaurant_id = rid and b.day_key = p_day_key
      and p_day_no between b.day_first and b.day_last
  ) then
    return jsonb_build_object('ok', false, 'error', 'order number was not reserved');
  end if;
  if type_id is not null and not exists (
    select 1 from public.payment_types where id = type_id and restaurant_id = rid
  ) then
    type_id := null;
  end if;

  select * into shift from public.shifts where (id = p_shift_id or client_id = p_shift_id) and restaurant_id = rid;
  if not found then
    select * into shift from public.shifts
    where cashier_id = p_cashier_id and restaurant_id = rid and closed_at is null
    order by opened_at desc limit 1;
  end if;
  if not found then
    insert into public.shifts (restaurant_id, cashier_id, opening_cash, opened_at, client_id)
    values (rid, p_cashier_id, 0, coalesce(p_paid_at, now()), p_shift_id)
    returning * into shift;
  end if;

  perform set_config('app.offline_sync', 'on', true);
  insert into public.orders (restaurant_id, table_id, status, service_type, payment_type_id, cashier_id,
                             created_at, client_id, year_month, shift_order_number, number_day)
  values (rid, null, 'served', 'takeout', type_id, p_cashier_id, coalesce(p_paid_at, now()), p_client_id,
          p_year_month, p_day_no, case when p_day_no is null then null else p_day_key end)
  returning * into ord;

  insert into public.order_lines (order_id, restaurant_id, menu_item_id, name, qty, unit_price, list_unit_price, round, choices)
  select ord.id, rid, nullif(x.menu_item_id, '')::uuid, coalesce(nullif(x.name, ''), 'Item'), x.qty,
         round(coalesce(x.unit_price, 0), 2), round(coalesce(x.list_unit_price, x.unit_price, 0), 2), 1,
         coalesce(x.choices, '[]'::jsonb)
  from jsonb_to_recordset(p_lines)
    as x(menu_item_id text, name text, qty integer, unit_price numeric, list_unit_price numeric, choices jsonb)
  where x.qty > 0;
  get diagnostics line_count = row_count;
  if line_count = 0 then
    raise exception 'cart is empty';
  end if;
  select round(coalesce(sum(qty * unit_price), 0), 2) into due from public.order_lines where order_id = ord.id;

  m_label := p_year_month
    || case when length(p_monthly_no::text) >= 3 then p_monthly_no::text else lpad(p_monthly_no::text, 3, '0') end;
  d_label := case when p_day_no is null then null
    else p_year_month || case when length(p_day_no::text) >= 3 then p_day_no::text else lpad(p_day_no::text, 3, '0') end
  end;

  insert into public.payments (
    restaurant_id, order_id, table_id, total_due, cash_received, change_due, cashier_id, shift_id, payment_type_id,
    paid_at, year_month, shift_order_number, monthly_order_number, shift_display_number, monthly_display_number,
    client_id, synced_offline, synced_at
  ) values (
    rid, ord.id, null, due, due, 0, p_cashier_id, shift.id, type_id,
    coalesce(p_paid_at, now()), p_year_month, p_day_no, p_monthly_no, d_label, m_label,
    p_client_id, true, now()
  );
  update public.orders set status = 'paid' where id = ord.id;
  update public.shifts set cash_sales = cash_sales + due, transaction_count = transaction_count + 1 where id = shift.id;
  return jsonb_build_object('ok', true, 'order_id', ord.id, 'shift_id', shift.id, 'total_due', due);
end;
$$;

-- ------------------------------------------------------------ guest web

create or replace function public.guest_menu(p_qr_slug text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  tbl public.dining_tables;
  cafe public.restaurants%rowtype;
begin
  tbl := private.table_for_slug(p_qr_slug);
  if tbl.id is null then
    return jsonb_build_object('ok', false, 'error', 'table not found');
  end if;
  select * into cafe from public.restaurants where id = tbl.restaurant_id;

  return jsonb_build_object(
    'ok', true,
    'cafe', jsonb_build_object(
      'id', cafe.id,
      'name', cafe.name,
      'locale', cafe.locale,
      'logo_url', cafe.logo_url,
      'header_color', cafe.header_color,
      'button_color', cafe.button_color,
      'background_color', cafe.background_color,
      'service_charge_rate', cafe.service_charge_rate
    ),
    'table', jsonb_build_object('number', tbl.number),
    'categories', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', c.id,
        'name_en', c.name_en,
        'name_ar', c.name_ar,
        'sort_order', c.sort_order
      ) order by c.sort_order, c.created_at)
      from public.menu_categories c
      where c.restaurant_id = tbl.restaurant_id and c.visible
    ), '[]'::jsonb),
    'items', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', i.id,
        'category_id', i.category_id,
        'name_en', i.name_en,
        'name_ar', i.name_it,
        'description', i.description,
        'price', i.price,
        'sale_price', private.menu_sale_price(i.id),
        'image_url', i.image_url,
        'available', i.available and not i.sold_out,
        'featured', i.featured,
        'sort_order', i.sort_order,
        'options', i.options
      ) order by i.sort_order, i.created_at)
      from public.menu_items i
      join public.menu_categories c on c.id = i.category_id and c.visible
      where i.restaurant_id = tbl.restaurant_id
    ), '[]'::jsonb),
    'payment_types', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', p.id,
        'name_en', p.name_en,
        'name_ar', p.name_ar
      ) order by p.sort_order, p.created_at)
      from public.payment_types p
      where p.restaurant_id = tbl.restaurant_id and p.enabled and not p.archived
    ), '[]'::jsonb)
  );
end;
$$;

create or replace function public.guest_tab(p_qr_slug text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  tbl public.dining_tables;
  ord public.orders%rowtype;
begin
  tbl := private.table_for_slug(p_qr_slug);
  if tbl.id is null then
    return jsonb_build_object('ok', false, 'error', 'table not found');
  end if;
  select * into ord
  from public.orders
  where table_id = tbl.id and status <> 'paid'
  order by created_at desc
  limit 1;

  return jsonb_build_object(
    'ok', true,
    'table', jsonb_build_object('number', tbl.number, 'status', tbl.status),
    'order', case when ord.id is null then null else jsonb_build_object(
      'id', ord.id,
      'status', ord.status,
      'created_at', ord.created_at,
      'order_number', ord.shift_order_number,
      'service_type', ord.service_type,
      'awaiting_confirmation', ord.awaiting_customer_confirmation,
      'refusal_notice', ord.refusal_notice,
      'payment_type_id', ord.payment_type_id,
      'lines', coalesce((
        select jsonb_agg(jsonb_build_object(
          'id', l.id,
          'menu_item_id', l.menu_item_id,
          'name', l.name,
          'qty', l.qty,
          'unit_price', l.unit_price,
          'list_unit_price', l.list_unit_price,
          'round', l.round,
          'choices', l.choices
        ) order by l.round, l.id)
        from public.order_lines l
        where l.order_id = ord.id
      ), '[]'::jsonb)
    ) end
  );
end;
$$;
