-- Expense categories, same shape as payment types. Cash-outs live in
-- shift_expenses (there is no cash_movements table). paid_to_cafe stays:
-- false only for the seeded "Cash Withdrawal" category, true for every
-- other category, including custom ones. Category names are copied onto
-- the row so a later delete still displays.

create table public.expense_categories (
  id uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null references public.restaurants (id) on delete cascade,
  name_en text not null,
  name_ar text not null,
  enabled boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

create index expense_categories_restaurant_idx
  on public.expense_categories (restaurant_id, sort_order);

insert into public.expense_categories (restaurant_id, name_en, name_ar, sort_order)
select r.id, seed.name_en, seed.name_ar, seed.sort_order
from public.restaurants r
cross join (values
  ('Café Expense', 'مصروف المقهى', 0),
  ('Cash Withdrawal', 'سحب نقدي', 1)
) as seed(name_en, name_ar, sort_order);

alter table public.shift_expenses
  add column if not exists expense_category_id uuid references public.expense_categories (id) on delete set null,
  add column if not exists category_name_en text,
  add column if not exists category_name_ar text;

update public.shift_expenses as expense
set
  expense_category_id = category.id,
  category_name_en = category.name_en,
  category_name_ar = category.name_ar
from public.expense_categories as category
where category.restaurant_id = expense.restaurant_id
  and expense.expense_category_id is null
  and (
    (expense.paid_to_cafe and category.name_en = 'Café Expense')
    or (not expense.paid_to_cafe and category.name_en = 'Cash Withdrawal')
  );

alter table public.expense_categories enable row level security;

create policy expense_categories_read on public.expense_categories
  for select to anon, authenticated
  using (
    restaurant_id = private.current_restaurant_id()
    or (restaurant_id = private.cashier_restaurant_id() and enabled)
  );

create policy expense_categories_admin on public.expense_categories
  for all to authenticated
  using (restaurant_id = private.current_restaurant_id())
  with check (restaurant_id = private.current_restaurant_id());

drop function if exists public.record_cash_movement(uuid, text, numeric, text);
drop function if exists public.edit_cash_movement(uuid, text, numeric, text);

create function public.record_cash_movement(
  p_shift_id uuid,
  p_expense_category_id uuid,
  p_amount numeric,
  p_description text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  cid uuid := private.session_cashier_id();
  rid uuid := private.cashier_restaurant_id();
  shift public.shifts%rowtype;
  category public.expense_categories%rowtype;
  new_id uuid;
  label text;
  cafe boolean;
begin
  if cid is null or rid is null then
    return jsonb_build_object('ok', false, 'error', 'sign in as a cashier first');
  end if;
  if p_amount is null or p_amount <= 0 or btrim(coalesce(p_description, '')) = '' then
    return jsonb_build_object('ok', false, 'error', 'invalid');
  end if;
  select * into category
  from public.expense_categories
  where id = p_expense_category_id and restaurant_id = rid and enabled;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'unknown type');
  end if;
  select * into shift
  from public.shifts
  where id = p_shift_id and restaurant_id = rid and cashier_id = cid and closed_at is null;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'not_found');
  end if;
  cafe := category.name_en is distinct from 'Cash Withdrawal';
  label := private.next_expense_number(rid);
  insert into public.shift_expenses (
    restaurant_id, shift_id, cashier_id, paid_to_cashier_id, paid_to_cafe,
    amount, description, kind, display_number,
    expense_category_id, category_name_en, category_name_ar
  ) values (
    rid, shift.id, cid,
    case when cafe then null else cid end,
    cafe, p_amount, btrim(p_description), 'cash_out', label,
    category.id, category.name_en, category.name_ar
  )
  returning id into new_id;
  return jsonb_build_object('ok', true, 'id', new_id, 'display_number', label);
end;
$$;

create function public.edit_cash_movement(
  p_id uuid,
  p_expense_category_id uuid,
  p_amount numeric,
  p_description text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  cid uuid := private.session_cashier_id();
  rid uuid := private.cashier_restaurant_id();
  original public.shift_expenses%rowtype;
  shift public.shifts%rowtype;
  category public.expense_categories%rowtype;
  new_id uuid;
  label text;
  cafe boolean;
begin
  if cid is null or rid is null then
    return jsonb_build_object('ok', false, 'error', 'sign in as a cashier first');
  end if;
  if p_amount is null or p_amount <= 0 or btrim(coalesce(p_description, '')) = '' then
    return jsonb_build_object('ok', false, 'error', 'invalid');
  end if;
  select * into category
  from public.expense_categories
  where id = p_expense_category_id and restaurant_id = rid and enabled;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'unknown type');
  end if;
  select * into original
  from public.shift_expenses
  where id = p_id and restaurant_id = rid and cashier_id = cid and voided = false
  for update;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'not_found');
  end if;
  select * into shift
  from public.shifts
  where id = original.shift_id and cashier_id = cid and closed_at is null;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'not_found');
  end if;
  cafe := category.name_en is distinct from 'Cash Withdrawal';
  update public.shift_expenses set voided = true where id = original.id;
  label := private.next_expense_number(rid);
  insert into public.shift_expenses (
    restaurant_id, shift_id, cashier_id, paid_to_cashier_id, paid_to_cafe,
    amount, description, kind, display_number, edited_from,
    expense_category_id, category_name_en, category_name_ar
  ) values (
    original.restaurant_id, original.shift_id, cid,
    case when cafe then null else cid end,
    cafe, p_amount, btrim(p_description), 'cash_out', label, original.id,
    category.id, category.name_en, category.name_ar
  )
  returning id into new_id;
  return jsonb_build_object('ok', true, 'id', new_id, 'display_number', label);
end;
$$;

revoke all on function public.record_cash_movement(uuid, uuid, numeric, text) from public;
revoke all on function public.edit_cash_movement(uuid, uuid, numeric, text) from public;
grant execute on function public.record_cash_movement(uuid, uuid, numeric, text) to anon, authenticated;
grant execute on function public.edit_cash_movement(uuid, uuid, numeric, text) to anon, authenticated;
