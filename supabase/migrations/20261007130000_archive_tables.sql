-- Deleting a table must never delete its receipts.
--
-- Until now orders.table_id and payments.table_id were ON DELETE CASCADE, so
-- removing one dining table also removed every order and payment made at it.
-- Tables are now archived instead of deleted, and the database refuses to
-- hard-delete a table that has sales history.

alter table public.dining_tables
  add column if not exists archived boolean not null default false;

-- An archived table's number can be reused by a new table.
alter table public.dining_tables
  drop constraint if exists dining_tables_restaurant_id_number_key;
create unique index if not exists dining_tables_active_number_key
  on public.dining_tables (restaurant_id, number)
  where not archived;

-- NO ACTION (checked at the end of the statement): deleting a table that still
-- has orders or payments fails, while deleting a whole restaurant, which
-- removes both together, still works.
alter table public.orders drop constraint if exists orders_table_id_fkey;
alter table public.orders
  add constraint orders_table_id_fkey
  foreign key (table_id) references public.dining_tables (id) on delete no action;

alter table public.payments drop constraint if exists payments_table_id_fkey;
alter table public.payments
  add constraint payments_table_id_fkey
  foreign key (table_id) references public.dining_tables (id) on delete no action;

-- A guest scanning an archived table's QR code gets nothing.
create or replace function private.guest_restaurant_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select restaurant_id from public.dining_tables
  where qr_slug = private.header('x-qr-slug') and not archived
  limit 1;
$$;

create or replace function private.guest_table_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select id from public.dining_tables
  where qr_slug = private.header('x-qr-slug') and not archived
  limit 1;
$$;
