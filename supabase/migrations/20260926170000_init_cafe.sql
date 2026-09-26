-- Café Italiano: one Postgres database for every restaurant.
-- No sample restaurants, dishes, tables, or orders.

create extension if not exists pgcrypto with schema extensions;

create schema if not exists private;

create or replace function private.header(p_name text)
returns text
language sql
stable
set search_path = ''
as $$
  select nullif(
    case
      when current_setting('request.headers', true) is null then null
      else current_setting('request.headers', true)::json ->> p_name
    end,
    ''
  );
$$;

create table public.restaurants (
  id uuid primary key default gen_random_uuid(),
  name text not null default '',
  locale text not null default 'en',
  service_charge_rate numeric(8, 4) not null default 0.10,
  tax_rate numeric(8, 4) not null default 0,
  created_at timestamptz not null default now()
);

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  restaurant_id uuid not null references public.restaurants (id) on delete cascade,
  role text not null default 'admin' check (role = 'admin'),
  display_name text not null default '',
  created_at timestamptz not null default now()
);

create or replace function private.current_restaurant_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select restaurant_id from public.profiles where id = auth.uid();
$$;

create table public.cashiers (
  id uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null references public.restaurants (id) on delete cascade,
  name text not null,
  initials text not null,
  pin_hash text not null,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.cashier_sessions (
  id uuid primary key default gen_random_uuid(),
  cashier_id uuid not null references public.cashiers (id) on delete cascade,
  restaurant_id uuid not null references public.restaurants (id) on delete cascade,
  token_hash text not null unique,
  expires_at timestamptz not null,
  created_at timestamptz not null default now()
);

create or replace function private.cashier_restaurant_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select s.restaurant_id
  from public.cashier_sessions s
  where s.token_hash = encode(extensions.digest(coalesce(private.header('x-cashier-token'), ''), 'sha256'), 'hex')
    and s.expires_at > now()
  limit 1;
$$;

create table public.dining_tables (
  id uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null references public.restaurants (id) on delete cascade,
  number text not null,
  qr_slug text not null,
  zone text not null default 'Main Floor',
  seats integer not null default 4 check (seats > 0),
  status text not null default 'free' check (status in ('free', 'dining', 'billRequested')),
  guests integer not null default 0 check (guests >= 0),
  created_at timestamptz not null default now(),
  unique (restaurant_id, number),
  unique (qr_slug)
);

create table public.menu_categories (
  id uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null references public.restaurants (id) on delete cascade,
  name_en text not null,
  name_ar text not null,
  sort_order integer not null default 0,
  spotlight boolean not null default false,
  visible boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.menu_items (
  id uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null references public.restaurants (id) on delete cascade,
  category_id uuid not null references public.menu_categories (id) on delete cascade,
  name_it text not null default '',
  name_en text not null default '',
  description text not null default '',
  price numeric(12, 2) not null check (price >= 0),
  image_url text not null default '',
  available boolean not null default true,
  sold_out boolean not null default false,
  featured boolean not null default false,
  sort_order integer not null default 0,
  discount_percent numeric(5, 2) not null default 0 check (discount_percent >= 0 and discount_percent <= 100),
  discount_applied boolean not null default false,
  created_at timestamptz not null default now()
);

create table public.orders (
  id uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null references public.restaurants (id) on delete cascade,
  table_id uuid not null references public.dining_tables (id) on delete cascade,
  status text not null default 'received' check (status in ('received', 'preparing', 'ready', 'served', 'paid')),
  notes text not null default '',
  cashier_id uuid references public.cashiers (id) on delete set null,
  created_at timestamptz not null default now()
);

create table public.order_lines (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders (id) on delete cascade,
  restaurant_id uuid not null references public.restaurants (id) on delete cascade,
  menu_item_id uuid references public.menu_items (id) on delete set null,
  name text not null,
  qty integer not null check (qty > 0),
  unit_price numeric(12, 2) not null check (unit_price >= 0)
);

create table public.carts (
  table_id uuid primary key references public.dining_tables (id) on delete cascade,
  restaurant_id uuid not null references public.restaurants (id) on delete cascade
);

create table public.cart_lines (
  id uuid primary key default gen_random_uuid(),
  table_id uuid not null references public.carts (table_id) on delete cascade,
  restaurant_id uuid not null references public.restaurants (id) on delete cascade,
  menu_item_id uuid references public.menu_items (id) on delete set null,
  name text not null,
  qty integer not null check (qty > 0),
  unit_price numeric(12, 2) not null check (unit_price >= 0)
);

create table public.shifts (
  id uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null references public.restaurants (id) on delete cascade,
  cashier_id uuid not null references public.cashiers (id) on delete cascade,
  opened_at timestamptz not null default now(),
  closed_at timestamptz,
  opening_cash numeric(12, 2) not null default 0,
  cash_sales numeric(12, 2) not null default 0,
  cash_refunds numeric(12, 2) not null default 0,
  cash_adjustments numeric(12, 2) not null default 0,
  actual_cash numeric(12, 2),
  transaction_count integer not null default 0
);

create table public.payments (
  id uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null references public.restaurants (id) on delete cascade,
  order_id uuid not null references public.orders (id) on delete cascade,
  table_id uuid not null references public.dining_tables (id) on delete cascade,
  total_due numeric(12, 2) not null,
  cash_received numeric(12, 2) not null,
  change_due numeric(12, 2) not null,
  cashier_id uuid not null references public.cashiers (id),
  shift_id uuid not null references public.shifts (id),
  paid_at timestamptz not null default now()
);

create table public.staff_calls (
  id uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null references public.restaurants (id) on delete cascade,
  table_id uuid not null references public.dining_tables (id) on delete cascade,
  kind text not null default 'assistance',
  resolved boolean not null default false,
  created_at timestamptz not null default now()
);

create index dining_tables_restaurant_idx on public.dining_tables (restaurant_id);
create index menu_categories_restaurant_idx on public.menu_categories (restaurant_id, sort_order);
create index menu_items_restaurant_idx on public.menu_items (restaurant_id, category_id);
create index orders_restaurant_idx on public.orders (restaurant_id, created_at desc);
create index orders_table_idx on public.orders (table_id);
create index order_lines_order_idx on public.order_lines (order_id);
create index payments_restaurant_idx on public.payments (restaurant_id, paid_at desc);
create index staff_calls_restaurant_idx on public.staff_calls (restaurant_id, resolved);

create or replace function private.actor_restaurant_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(private.current_restaurant_id(), private.cashier_restaurant_id());
$$;

create or replace function private.guest_table_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select id from public.dining_tables where qr_slug = private.header('x-qr-slug') limit 1;
$$;

create or replace function private.guest_restaurant_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select restaurant_id from public.dining_tables where qr_slug = private.header('x-qr-slug') limit 1;
$$;

create or replace function private.handle_new_admin()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  rid uuid;
begin
  insert into public.restaurants (name) values ('') returning id into rid;
  insert into public.profiles (id, restaurant_id, role, display_name)
  values (new.id, rid, 'admin', coalesce(new.email, ''));
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function private.handle_new_admin();

create or replace function private.menu_sale_price(p_item_id uuid)
returns numeric
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when discount_applied and discount_percent > 0
      then round(price * (100 - discount_percent) / 100, 2)
    else price
  end
  from public.menu_items
  where id = p_item_id;
$$;

create or replace function private.stamp_order()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  guest_restaurant uuid := private.guest_restaurant_id();
  guest_table uuid := private.guest_table_id();
begin
  if guest_table is not null and auth.uid() is null and private.cashier_restaurant_id() is null then
    new.table_id := guest_table;
    new.restaurant_id := guest_restaurant;
  elsif new.restaurant_id is null then
    new.restaurant_id := private.actor_restaurant_id();
  end if;
  return new;
end;
$$;

create trigger stamp_order before insert on public.orders
  for each row execute function private.stamp_order();

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
  if new.menu_item_id is not null then
    select * into item from public.menu_items where id = new.menu_item_id;
    if not found or item.restaurant_id <> parent.restaurant_id then
      raise exception 'menu item is not on this restaurant menu';
    end if;
    new.name := coalesce(nullif(item.name_en, ''), item.name_it);
    new.unit_price := private.menu_sale_price(item.id);
  end if;
  return new;
end;
$$;

create trigger stamp_order_line before insert on public.order_lines
  for each row execute function private.stamp_order_line();

create or replace function private.block_unpaid_close()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status = 'paid' and old.status is distinct from 'paid' then
    if not exists (select 1 from public.payments p where p.order_id = new.id) then
      raise exception 'a verified cash payment is required before an order can be paid';
    end if;
  end if;
  return new;
end;
$$;

create trigger block_unpaid_close before update on public.orders
  for each row execute function private.block_unpaid_close();

create or replace function public.has_any_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.profiles);
$$;

create or replace function public.list_pos_cashiers(p_restaurant_id uuid default null)
returns table (id uuid, name text, initials text)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  rid uuid := p_restaurant_id;
begin
  if rid is null then
    if (select count(*) from public.restaurants) = 1 then
      select r.id into rid from public.restaurants r limit 1;
    else
      return;
    end if;
  end if;
  return query
    select c.id, c.name, c.initials
    from public.cashiers c
    where c.restaurant_id = rid and c.active;
end;
$$;

create or replace function public.create_cashier(p_name text, p_pin text, p_initials text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  rid uuid := private.current_restaurant_id();
  new_id uuid;
begin
  if rid is null or private.current_restaurant_id() is null then
    raise exception 'admin sign-in required';
  end if;
  if auth.uid() is null then
    raise exception 'admin sign-in required';
  end if;
  if p_pin !~ '^[0-9]{4}$' then
    raise exception 'PIN must be 4 digits';
  end if;
  insert into public.cashiers (restaurant_id, name, initials, pin_hash)
  values (rid, btrim(p_name), p_initials, extensions.crypt(p_pin, extensions.gen_salt('bf')))
  returning id into new_id;
  return new_id;
end;
$$;

create or replace function public.cashier_login(p_cashier_id uuid, p_pin text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  c public.cashiers%rowtype;
  raw_token text;
begin
  select * into c from public.cashiers where id = p_cashier_id and active;
  if not found or c.pin_hash is distinct from extensions.crypt(p_pin, c.pin_hash) then
    return jsonb_build_object('ok', false);
  end if;
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

create or replace function public.settle_cash(p_table_id uuid, p_cash_received numeric)
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
begin
  if actor is null then
    return jsonb_build_object('ok', false, 'error', 'sign in as a cashier first');
  end if;
  select * into ord
  from public.orders
  where table_id = p_table_id
    and restaurant_id = actor
    and status <> 'paid'
  order by created_at desc
  limit 1;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'no open bill');
  end if;
  select coalesce(sum(qty * unit_price), 0) into due
  from public.order_lines where order_id = ord.id;
  due := round(due * (1 + (select service_charge_rate from public.restaurants where id = actor)), 2);
  if p_cash_received < due then
    return jsonb_build_object('ok', false, 'error', 'insufficient cash');
  end if;
  cid := coalesce(
    (select cashier_id from public.cashier_sessions s
      where s.token_hash = encode(extensions.digest(coalesce(private.header('x-cashier-token'), ''), 'sha256'), 'hex')
        and s.expires_at > now()
      limit 1),
    (select id from public.cashiers where restaurant_id = actor order by created_at limit 1)
  );
  if cid is null then
    return jsonb_build_object('ok', false, 'error', 'sign in as a cashier first');
  end if;
  select * into shift
  from public.shifts
  where cashier_id = cid and restaurant_id = actor and closed_at is null
  order by opened_at desc
  limit 1;
  if not found then
    insert into public.shifts (restaurant_id, cashier_id, opening_cash)
    values (actor, cid, 0)
    returning * into shift;
  end if;
  insert into public.payments (
    restaurant_id, order_id, table_id, total_due, cash_received, change_due, cashier_id, shift_id
  ) values (
    actor, ord.id, p_table_id, due, p_cash_received, p_cash_received - due, cid, shift.id
  );
  update public.orders set status = 'paid' where id = ord.id;
  update public.dining_tables set status = 'free', guests = 0 where id = p_table_id;
  update public.shifts
    set cash_sales = cash_sales + due,
        transaction_count = transaction_count + 1
    where id = shift.id;
  return jsonb_build_object('ok', true);
end;
$$;

revoke all on function public.has_any_admin() from public;
revoke all on function public.list_pos_cashiers(uuid) from public;
revoke all on function public.create_cashier(text, text, text) from public;
revoke all on function public.cashier_login(uuid, text) from public;
revoke all on function public.settle_cash(uuid, numeric) from public;
grant execute on function public.has_any_admin() to anon, authenticated;
grant execute on function public.list_pos_cashiers(uuid) to anon, authenticated;
grant execute on function public.create_cashier(text, text, text) to authenticated;
grant execute on function public.cashier_login(uuid, text) to anon, authenticated;
grant execute on function public.settle_cash(uuid, numeric) to anon, authenticated;

alter table public.restaurants enable row level security;
alter table public.profiles enable row level security;
alter table public.cashiers enable row level security;
alter table public.cashier_sessions enable row level security;
alter table public.dining_tables enable row level security;
alter table public.menu_categories enable row level security;
alter table public.menu_items enable row level security;
alter table public.orders enable row level security;
alter table public.order_lines enable row level security;
alter table public.carts enable row level security;
alter table public.cart_lines enable row level security;
alter table public.shifts enable row level security;
alter table public.payments enable row level security;
alter table public.staff_calls enable row level security;

create policy restaurants_select on public.restaurants
  for select to authenticated
  using (id = private.actor_restaurant_id() or id = private.guest_restaurant_id());

create policy restaurants_guest_select on public.restaurants
  for select to anon
  using (id = private.guest_restaurant_id());

create policy restaurants_update on public.restaurants
  for update to authenticated
  using (id = private.current_restaurant_id())
  with check (id = private.current_restaurant_id());

create policy profiles_select on public.profiles
  for select to authenticated
  using (id = auth.uid());

create policy profiles_update on public.profiles
  for update to authenticated
  using (id = auth.uid())
  with check (
    id = auth.uid()
    and role = 'admin'
    and restaurant_id = private.current_restaurant_id()
  );

create policy cashiers_staff on public.cashiers
  for all to authenticated
  using (restaurant_id = private.current_restaurant_id())
  with check (restaurant_id = private.current_restaurant_id());

create policy tables_staff on public.dining_tables
  for all to authenticated
  using (restaurant_id = private.actor_restaurant_id())
  with check (restaurant_id = private.current_restaurant_id() or restaurant_id = private.cashier_restaurant_id());

create policy tables_guest on public.dining_tables
  for select to anon
  using (id = private.guest_table_id());

create policy tables_guest_update on public.dining_tables
  for update to anon
  using (id = private.guest_table_id())
  with check (id = private.guest_table_id());

create policy categories_staff on public.menu_categories
  for all to authenticated
  using (restaurant_id = private.actor_restaurant_id())
  with check (restaurant_id = private.actor_restaurant_id());

create policy categories_guest on public.menu_categories
  for select to anon
  using (restaurant_id = private.guest_restaurant_id() and visible);

create policy items_staff on public.menu_items
  for all to authenticated
  using (restaurant_id = private.actor_restaurant_id())
  with check (restaurant_id = private.actor_restaurant_id());

create policy items_guest on public.menu_items
  for select to anon
  using (restaurant_id = private.guest_restaurant_id());

create policy orders_staff on public.orders
  for all to authenticated
  using (restaurant_id = private.actor_restaurant_id())
  with check (restaurant_id = private.actor_restaurant_id());

create policy orders_guest_select on public.orders
  for select to anon
  using (table_id = private.guest_table_id());

create policy orders_guest_insert on public.orders
  for insert to anon
  with check (table_id = private.guest_table_id());

create policy lines_staff on public.order_lines
  for all to authenticated
  using (restaurant_id = private.actor_restaurant_id())
  with check (restaurant_id = private.actor_restaurant_id());

create policy lines_guest_select on public.order_lines
  for select to anon
  using (order_id in (select id from public.orders where table_id = private.guest_table_id()));

create policy lines_guest_insert on public.order_lines
  for insert to anon
  with check (order_id in (select id from public.orders where table_id = private.guest_table_id()));

create policy carts_all on public.carts
  for all to anon, authenticated
  using (restaurant_id = coalesce(private.actor_restaurant_id(), private.guest_restaurant_id()))
  with check (restaurant_id = coalesce(private.actor_restaurant_id(), private.guest_restaurant_id()));

create policy cart_lines_all on public.cart_lines
  for all to anon, authenticated
  using (restaurant_id = coalesce(private.actor_restaurant_id(), private.guest_restaurant_id()))
  with check (restaurant_id = coalesce(private.actor_restaurant_id(), private.guest_restaurant_id()));

create policy calls_all on public.staff_calls
  for all to anon, authenticated
  using (restaurant_id = coalesce(private.actor_restaurant_id(), private.guest_restaurant_id()))
  with check (restaurant_id = coalesce(private.actor_restaurant_id(), private.guest_restaurant_id()));

create policy shifts_staff on public.shifts
  for all to authenticated
  using (restaurant_id = private.actor_restaurant_id())
  with check (restaurant_id = private.actor_restaurant_id());

create policy payments_staff on public.payments
  for select to authenticated
  using (restaurant_id = private.actor_restaurant_id());

revoke all on table public.cashier_sessions from anon, authenticated;

insert into storage.buckets (id, name, public)
values ('menu-images', 'menu-images', true)
on conflict (id) do nothing;

create policy menu_images_read on storage.objects
  for select to anon, authenticated
  using (bucket_id = 'menu-images');

create policy menu_images_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'menu-images'
    and (storage.foldername(name))[1] = private.current_restaurant_id()::text
  );

create policy menu_images_update on storage.objects
  for update to authenticated
  using (
    bucket_id = 'menu-images'
    and (storage.foldername(name))[1] = private.current_restaurant_id()::text
  )
  with check (
    bucket_id = 'menu-images'
    and (storage.foldername(name))[1] = private.current_restaurant_id()::text
  );

create policy menu_images_delete on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'menu-images'
    and (storage.foldername(name))[1] = private.current_restaurant_id()::text
  );

alter publication supabase_realtime add table public.orders;
alter publication supabase_realtime add table public.order_lines;
alter publication supabase_realtime add table public.dining_tables;
alter publication supabase_realtime add table public.staff_calls;
alter publication supabase_realtime add table public.payments;
