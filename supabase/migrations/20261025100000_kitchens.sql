-- Kitchens: a cafe can cook in more than one place (pizza oven, grill, bar). The admin adds a
-- kitchen and ticks the categories it makes; each category belongs to at most one kitchen. Which
-- printer a kitchen uses is chosen on each till, since every till sees its own printers.
-- A category with no kitchen goes to the cafe's first kitchen; a cafe with no kitchens prints
-- every dish on the till's one kitchen printer, as before.
-- Safe to apply twice. Rollback: supabase/rollbacks/20261025100000_kitchens.down.sql

create table if not exists public.kitchens (
  id uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null references public.restaurants (id) on delete cascade,
  name text not null check (length(btrim(name)) between 1 and 60),
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists kitchens_restaurant_idx on public.kitchens (restaurant_id, sort_order);

-- Deleting a kitchen sends its categories back to the first kitchen.
alter table public.menu_categories
  add column if not exists kitchen_id uuid references public.kitchens (id) on delete set null;

create index if not exists menu_categories_kitchen_idx
  on public.menu_categories (kitchen_id) where kitchen_id is not null;

alter table public.kitchens enable row level security;

-- Tills read them to split kitchen tickets; only the admin changes them.
drop policy if exists kitchens_read on public.kitchens;
create policy kitchens_read on public.kitchens
  for select to anon, authenticated
  using (
    restaurant_id = private.current_restaurant_id()
    or restaurant_id = private.cashier_restaurant_id()
  );

drop policy if exists kitchens_admin on public.kitchens;
create policy kitchens_admin on public.kitchens
  for all to authenticated
  using (restaurant_id = private.current_restaurant_id())
  with check (restaurant_id = private.current_restaurant_id());

-- A category can only point at a kitchen of its own cafe.
drop trigger if exists zz_same_cafe on public.menu_categories;
create trigger zz_same_cafe before insert or update on public.menu_categories
  for each row execute function private.check_same_cafe('kitchen_id:kitchens');

-- Tills refresh when a kitchen is added, renamed or removed.
create or replace trigger zz_live_ping after insert or update or delete on public.kitchens
  for each row execute function private.live_ping();
