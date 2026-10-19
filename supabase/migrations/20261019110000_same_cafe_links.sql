-- Every link from one cafe row to another row must stay inside the same cafe, on insert AND update.
-- Before this, RLS only checked "is this row mine"; an admin could update one of their order lines
-- (or orders, dishes, shifts, staff calls) to point at another cafe's order, table or cashier.
--
-- Also freezes paid orders against direct table writes from the app roles: their lines can't be
-- repriced, moved or deleted, and the paid order itself can't be edited or deleted (deleting it
-- used to cascade into its payments). The RPCs, which run as the table owner, are not affected.

-- Arguments are 'column:table' pairs; each non-null column must point at a row of the same cafe.
-- On update only changed links are checked, so old rows can still be edited in other columns.
create or replace function private.check_same_cafe()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  pair text;
  col text;
  ref_id text;
  owner uuid;
  fresh jsonb := to_jsonb(new);
  stale jsonb := case when tg_op = 'UPDATE' then to_jsonb(old) end;
begin
  foreach pair in array tg_argv loop
    col := split_part(pair, ':', 1);
    ref_id := fresh ->> col;
    continue when ref_id is null;
    continue when stale is not null
      and stale ->> col is not distinct from ref_id
      and stale ->> 'restaurant_id' is not distinct from fresh ->> 'restaurant_id';
    execute format('select restaurant_id from public.%I where id = $1', split_part(pair, ':', 2))
      into owner using ref_id::uuid;
    if owner is distinct from (fresh ->> 'restaurant_id')::uuid then
      raise exception '% belongs to another cafe', col using errcode = '42501';
    end if;
  end loop;
  return new;
end;
$$;

-- Security invoker on purpose: current_user is the app role only for direct table writes.
create or replace function private.freeze_paid_order()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  paid boolean := false;
begin
  if current_user not in ('anon', 'authenticated') then
    return coalesce(new, old);
  end if;
  if tg_table_name = 'orders' then
    paid := old.status = 'paid';
  else
    if tg_op <> 'INSERT' then
      select o.status = 'paid' into paid from public.orders o where o.id = old.order_id;
    end if;
    if not coalesce(paid, false) and tg_op <> 'DELETE' then
      select o.status = 'paid' into paid from public.orders o where o.id = new.order_id;
    end if;
  end if;
  if coalesce(paid, false) then
    raise exception 'paid orders cannot be changed' using errcode = '42501';
  end if;
  return coalesce(new, old);
end;
$$;

revoke all on function private.check_same_cafe() from public, anon, authenticated;
revoke all on function private.freeze_paid_order() from public, anon, authenticated;

drop trigger if exists zz_same_cafe on public.order_lines;
create trigger zz_same_cafe before insert or update on public.order_lines
  for each row execute function private.check_same_cafe('order_id:orders', 'menu_item_id:menu_items');

drop trigger if exists zz_same_cafe on public.orders;
create trigger zz_same_cafe before insert or update on public.orders
  for each row execute function private.check_same_cafe(
    'table_id:dining_tables', 'cashier_id:cashiers', 'payment_type_id:payment_types');

drop trigger if exists zz_same_cafe on public.menu_items;
create trigger zz_same_cafe before insert or update on public.menu_items
  for each row execute function private.check_same_cafe('category_id:menu_categories');

drop trigger if exists zz_same_cafe on public.shifts;
create trigger zz_same_cafe before insert or update on public.shifts
  for each row execute function private.check_same_cafe('cashier_id:cashiers');

drop trigger if exists zz_same_cafe on public.staff_calls;
create trigger zz_same_cafe before insert or update on public.staff_calls
  for each row execute function private.check_same_cafe('table_id:dining_tables');

drop trigger if exists zz_same_cafe on public.payments;
create trigger zz_same_cafe before insert or update on public.payments
  for each row execute function private.check_same_cafe(
    'order_id:orders', 'shift_id:shifts', 'table_id:dining_tables', 'cashier_id:cashiers',
    'payment_type_id:payment_types', 'voided_by:cashiers');

drop trigger if exists zz_same_cafe on public.shift_expenses;
create trigger zz_same_cafe before insert or update on public.shift_expenses
  for each row execute function private.check_same_cafe(
    'shift_id:shifts', 'cashier_id:cashiers', 'paid_to_cashier_id:cashiers',
    'expense_category_id:expense_categories');

drop trigger if exists freeze_paid_order on public.order_lines;
create trigger freeze_paid_order before insert or update or delete on public.order_lines
  for each row execute function private.freeze_paid_order();

drop trigger if exists freeze_paid_order on public.orders;
create trigger freeze_paid_order before update or delete on public.orders
  for each row execute function private.freeze_paid_order();
