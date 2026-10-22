-- Undoes 20261022110000_expense_paid_to.

drop function if exists public.record_cash_movement(uuid, uuid, numeric, text, uuid);
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
revoke all on function public.record_cash_movement(uuid, uuid, numeric, text) from public;
grant execute on function public.record_cash_movement(uuid, uuid, numeric, text) to anon, authenticated;

create or replace function public.edit_cash_movement(
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
grant execute on function public.record_cash_movement(uuid, uuid, numeric, text) to anon, authenticated;

drop function if exists public.sync_offline_expense(uuid, uuid, uuid, uuid, numeric, text, timestamptz, uuid);

create or replace function public.sync_offline_expense(
  p_client_id uuid, p_cashier_id uuid, p_shift_id uuid, p_expense_category_id uuid, p_amount numeric,
  p_description text, p_created_at timestamptz
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  rid uuid := private.cashier_restaurant_id();
  cid uuid := private.session_cashier_id();
  shift public.shifts%rowtype;
  category public.expense_categories%rowtype;
  made_at timestamptz := least(coalesce(p_created_at, now()), now());
  label text;
  cafe boolean;
begin
  if rid is null or cid is null then
    return jsonb_build_object('ok', false, 'error', 'session expired, sign in again');
  end if;
  perform pg_advisory_xact_lock(hashtext('offline_upload:' || p_client_id::text));
  if exists (select 1 from public.shift_expenses where client_id = p_client_id and restaurant_id = rid) then
    return jsonb_build_object('ok', true, 'duplicate', true);
  end if;
  if p_cashier_id is distinct from cid then
    return jsonb_build_object('ok', false, 'error', 'offline work belongs to another cashier');
  end if;
  if p_amount is null or p_amount <= 0 or p_amount > 1000000 or btrim(coalesce(p_description, '')) = '' then
    return jsonb_build_object('ok', false, 'error', 'invalid');
  end if;
  select * into category from public.expense_categories where id = p_expense_category_id and restaurant_id = rid;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'unknown type');
  end if;
  shift := private.offline_shift(rid, cid, p_shift_id, made_at);
  cafe := category.name_en is distinct from 'Cash Withdrawal';
  label := private.next_expense_number(rid);
  insert into public.shift_expenses (
    restaurant_id, shift_id, cashier_id, paid_to_cashier_id, paid_to_cafe, amount, description, kind, display_number,
    expense_category_id, category_name_en, category_name_ar, created_at, client_id
  ) values (
    rid, shift.id, cid, case when cafe then null else cid end, cafe, round(p_amount, 2), btrim(p_description),
    'cash_out', label, category.id, category.name_en, category.name_ar, made_at, p_client_id
  );
  return jsonb_build_object('ok', true, 'display_number', label, 'shift_id', shift.id);
end;
$$;
revoke all on function public.sync_offline_expense(uuid, uuid, uuid, uuid, numeric, text, timestamptz) from public, anon, authenticated;
grant execute on function public.sync_offline_expense(uuid, uuid, uuid, uuid, numeric, text, timestamptz) to anon, authenticated;
