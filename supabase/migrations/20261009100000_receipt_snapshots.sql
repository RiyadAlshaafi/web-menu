-- Receipts keep their own copy of the table, cashier and payment method so that
-- archiving or deleting those rows can never change, duplicate or break a past sale.
-- (paid_at and the receipt numbers are already plain values on the payment row.)

alter table public.payments
  add column if not exists table_number text,
  add column if not exists is_takeout boolean not null default false,
  add column if not exists cashier_name text,
  add column if not exists payment_type_name_en text,
  add column if not exists payment_type_name_ar text;

update public.payments p
set table_number = coalesce(t.number, ''),
    cashier_name = coalesce(c.name, ''),
    is_takeout = coalesce(o.service_type = 'takeout', false),
    payment_type_name_en = pt.name_en,
    payment_type_name_ar = pt.name_ar
from public.payments p2
left join public.dining_tables t on t.id = p2.table_id
left join public.cashiers c on c.id = p2.cashier_id
left join public.orders o on o.id = p2.order_id
left join public.payment_types pt on pt.id = p2.payment_type_id
where p.id = p2.id and p.table_number is null;

alter table public.payments
  alter column table_number set default '',
  alter column table_number set not null,
  alter column cashier_name set default '',
  alter column cashier_name set not null;

-- Fill the copies when a payment is written, and refresh only the method name
-- when the method is changed. A method that is later deleted keeps its old name.
create or replace function private.snapshot_payment()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    new.table_number := coalesce((select number from public.dining_tables where id = new.table_id), '');
    new.cashier_name := coalesce((select name from public.cashiers where id = new.cashier_id), '');
    new.is_takeout := coalesce((select service_type = 'takeout' from public.orders where id = new.order_id), false);
  end if;
  if new.payment_type_id is not null
     and (tg_op = 'INSERT' or new.payment_type_id is distinct from old.payment_type_id) then
    select name_en, name_ar into new.payment_type_name_en, new.payment_type_name_ar
    from public.payment_types where id = new.payment_type_id;
  end if;
  return new;
end;
$$;

drop trigger if exists payments_snapshot on public.payments;
create trigger payments_snapshot
  before insert or update of payment_type_id on public.payments
  for each row execute function private.snapshot_payment();

-- A sale must survive the removal of its table, cashier or payment method.
alter table public.payments
  alter column table_id drop not null,
  alter column cashier_id drop not null;

alter table public.payments
  drop constraint payments_table_id_fkey,
  drop constraint payments_cashier_id_fkey,
  drop constraint payments_payment_type_id_fkey;

alter table public.payments
  add constraint payments_table_id_fkey foreign key (table_id)
    references public.dining_tables(id) on delete set null,
  add constraint payments_cashier_id_fkey foreign key (cashier_id)
    references public.cashiers(id) on delete set null,
  add constraint payments_payment_type_id_fkey foreign key (payment_type_id)
    references public.payment_types(id) on delete set null;
