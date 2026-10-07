-- Deleting a table, cashier or payment method must never delete or block other records.
-- History rows keep a plain-text copy of the names they show, and their links become
-- optional (SET NULL) instead of cascading or blocking.

-- orders: keep the table number as text
alter table public.orders add column if not exists table_number text not null default '';
update public.orders o set table_number = coalesce(t.number, '')
from public.dining_tables t where t.id = o.table_id and o.table_number = '';

-- shifts and expenses: keep cashier names as text
alter table public.shifts add column if not exists cashier_name text not null default '';
update public.shifts s set cashier_name = coalesce(c.name, '')
from public.cashiers c where c.id = s.cashier_id and s.cashier_name = '';

alter table public.shift_expenses
  add column if not exists cashier_name text not null default '',
  add column if not exists paid_to_cashier_name text not null default '';
update public.shift_expenses e set cashier_name = coalesce(c.name, '')
from public.cashiers c where c.id = e.cashier_id and e.cashier_name = '';
update public.shift_expenses e set paid_to_cashier_name = coalesce(c.name, '')
from public.cashiers c where c.id = e.paid_to_cashier_id and e.paid_to_cashier_name = '';

create or replace function private.snapshot_order()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  new.table_number := coalesce((select number from public.dining_tables where id = new.table_id), new.table_number, '');
  return new;
end;
$$;
drop trigger if exists orders_snapshot on public.orders;
create trigger orders_snapshot before insert on public.orders
  for each row execute function private.snapshot_order();

create or replace function private.snapshot_shift()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  new.cashier_name := coalesce((select name from public.cashiers where id = new.cashier_id), new.cashier_name, '');
  return new;
end;
$$;
drop trigger if exists shifts_snapshot on public.shifts;
create trigger shifts_snapshot before insert on public.shifts
  for each row execute function private.snapshot_shift();

create or replace function private.snapshot_expense()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  new.cashier_name := coalesce((select name from public.cashiers where id = new.cashier_id), new.cashier_name, '');
  new.paid_to_cashier_name := coalesce((select name from public.cashiers where id = new.paid_to_cashier_id), new.paid_to_cashier_name, '');
  return new;
end;
$$;
drop trigger if exists shift_expenses_snapshot on public.shift_expenses;
create trigger shift_expenses_snapshot before insert on public.shift_expenses
  for each row execute function private.snapshot_expense();

-- links become optional and never cascade or block
alter table public.orders alter column table_id drop not null;
alter table public.shifts alter column cashier_id drop not null;
alter table public.shift_expenses alter column cashier_id drop not null;

alter table public.orders
  drop constraint orders_table_id_fkey,
  drop constraint orders_payment_type_id_fkey;
alter table public.orders
  add constraint orders_table_id_fkey foreign key (table_id)
    references public.dining_tables(id) on delete set null,
  add constraint orders_payment_type_id_fkey foreign key (payment_type_id)
    references public.payment_types(id) on delete set null;

alter table public.shifts drop constraint shifts_cashier_id_fkey;
alter table public.shifts add constraint shifts_cashier_id_fkey foreign key (cashier_id)
  references public.cashiers(id) on delete set null;

alter table public.shift_expenses
  drop constraint shift_expenses_cashier_id_fkey,
  drop constraint shift_expenses_paid_to_cashier_id_fkey;
alter table public.shift_expenses
  add constraint shift_expenses_cashier_id_fkey foreign key (cashier_id)
    references public.cashiers(id) on delete set null,
  add constraint shift_expenses_paid_to_cashier_id_fkey foreign key (paid_to_cashier_id)
    references public.cashiers(id) on delete set null;

-- no duplicates among what staff can pick today
create unique index if not exists cashiers_active_name_key
  on public.cashiers (restaurant_id, lower(btrim(name))) where active;
create unique index if not exists payment_types_active_name_key
  on public.payment_types (restaurant_id, lower(btrim(name_en))) where not archived;

-- An expense paid to a cashier stays valid after that cashier is deleted (the name is kept).
alter table public.shift_expenses drop constraint shift_expenses_payee;
alter table public.shift_expenses add constraint shift_expenses_payee check (
  (paid_to_cafe and paid_to_cashier_id is null)
  or (not paid_to_cafe and (paid_to_cashier_id is not null or paid_to_cashier_name <> ''))
);
