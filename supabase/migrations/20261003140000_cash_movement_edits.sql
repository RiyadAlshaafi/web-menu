-- Correction trail for cash-outs. The live table is shift_expenses
-- (the app has no separate cash_movements table). Void the old row and
-- insert a new one. Do not touch settle_cash or order-number scopes.

alter table public.shift_expenses
  add column if not exists edited_from uuid references public.shift_expenses (id),
  add column if not exists voided boolean not null default false,
  add column if not exists display_number text;

create or replace function private.session_cashier_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select s.cashier_id
  from public.cashier_sessions s
  where s.token_hash = encode(extensions.digest(coalesce(private.header('x-cashier-token'), ''), 'sha256'), 'hex')
    and s.expires_at > now()
  limit 1;
$$;

create or replace function private.next_expense_number(p_restaurant_id uuid)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  n integer;
begin
  insert into public.order_number_counters as counters (restaurant_id, scope, last_value)
  values (p_restaurant_id, 'expense', 1)
  on conflict (restaurant_id, scope)
  do update set last_value = counters.last_value + 1
  returning last_value into n;
  return 'E-' || case when length(n::text) >= 3 then n::text else lpad(n::text, 3, '0') end;
end;
$$;

revoke all on function private.next_expense_number(uuid) from public, anon, authenticated;

create or replace function public.record_cash_movement(
  p_shift_id uuid,
  p_type text,
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
  new_id uuid;
  label text;
  cafe boolean := p_type = 'cafe';
begin
  if cid is null or rid is null then
    return jsonb_build_object('ok', false, 'error', 'sign in as a cashier first');
  end if;
  if p_type is distinct from 'cafe' and p_type is distinct from 'withdrawal' then
    return jsonb_build_object('ok', false, 'error', 'unknown type');
  end if;
  if p_amount is null or p_amount <= 0 or btrim(coalesce(p_description, '')) = '' then
    return jsonb_build_object('ok', false, 'error', 'invalid');
  end if;
  select * into shift
  from public.shifts
  where id = p_shift_id and restaurant_id = rid and cashier_id = cid and closed_at is null;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'not_found');
  end if;
  label := private.next_expense_number(rid);
  insert into public.shift_expenses (
    restaurant_id, shift_id, cashier_id, paid_to_cashier_id, paid_to_cafe,
    amount, description, kind, display_number
  ) values (
    rid, shift.id, cid,
    case when cafe then null else cid end,
    cafe, p_amount, btrim(p_description), 'cash_out', label
  )
  returning id into new_id;
  return jsonb_build_object('ok', true, 'id', new_id, 'display_number', label);
end;
$$;

create or replace function public.edit_cash_movement(
  p_id uuid,
  p_type text,
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
  new_id uuid;
  label text;
  cafe boolean := p_type = 'cafe';
begin
  if cid is null or rid is null then
    return jsonb_build_object('ok', false, 'error', 'sign in as a cashier first');
  end if;
  if p_type is distinct from 'cafe' and p_type is distinct from 'withdrawal' then
    return jsonb_build_object('ok', false, 'error', 'unknown type');
  end if;
  if p_amount is null or p_amount <= 0 or btrim(coalesce(p_description, '')) = '' then
    return jsonb_build_object('ok', false, 'error', 'invalid');
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
  update public.shift_expenses set voided = true where id = original.id;
  label := private.next_expense_number(rid);
  insert into public.shift_expenses (
    restaurant_id, shift_id, cashier_id, paid_to_cashier_id, paid_to_cafe,
    amount, description, kind, display_number, edited_from
  ) values (
    original.restaurant_id, original.shift_id, cid,
    case when cafe then null else cid end,
    cafe, p_amount, btrim(p_description), 'cash_out', label, original.id
  )
  returning id into new_id;
  return jsonb_build_object('ok', true, 'id', new_id, 'display_number', label);
end;
$$;

revoke all on function public.record_cash_movement(uuid, text, numeric, text) from public;
revoke all on function public.edit_cash_movement(uuid, text, numeric, text) from public;
grant execute on function public.record_cash_movement(uuid, text, numeric, text) to anon, authenticated;
grant execute on function public.edit_cash_movement(uuid, text, numeric, text) to anon, authenticated;

drop policy if exists shift_expenses_cashier on public.shift_expenses;
create policy shift_expenses_cashier on public.shift_expenses
  for select to anon
  using (
    restaurant_id = private.cashier_restaurant_id()
    and cashier_id = private.session_cashier_id()
  );

drop policy if exists shift_expenses_staff on public.shift_expenses;
create policy shift_expenses_staff on public.shift_expenses
  for select to authenticated
  using (restaurant_id = private.actor_restaurant_id());

with numbered as (
  select id, row_number() over (partition by restaurant_id order by created_at, id) as n
  from public.shift_expenses
  where display_number is null
)
update public.shift_expenses as expense
set display_number = 'E-' || lpad(numbered.n::text, 3, '0')
from numbered
where expense.id = numbered.id;

insert into public.order_number_counters (restaurant_id, scope, last_value)
select restaurant_id, 'expense', count(*)::integer
from public.shift_expenses
group by restaurant_id
on conflict (restaurant_id, scope) do update
set last_value = greatest(public.order_number_counters.last_value, excluded.last_value);
