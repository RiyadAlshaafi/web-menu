-- Undoes 20261019120000_offline_sync_trust_server.sql: the offline uploads trust the till again
-- (cashier, shift, time and prices). Functions are restored exactly as they were before it.

CREATE OR REPLACE FUNCTION private.stamp_order_line()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
$function$
;

CREATE OR REPLACE FUNCTION public.sync_offline_expense(p_client_id uuid, p_cashier_id uuid, p_shift_id uuid, p_expense_category_id uuid, p_amount numeric, p_description text, p_created_at timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  rid uuid := private.cashier_restaurant_id();
  shift public.shifts%rowtype;
  category public.expense_categories%rowtype;
  label text;
  cafe boolean;
begin
  if rid is null then
    return jsonb_build_object('ok', false, 'error', 'session expired, sign in again');
  end if;
  perform pg_advisory_xact_lock(hashtext('offline_upload:' || p_client_id::text));
  if exists (select 1 from public.shift_expenses where client_id = p_client_id and restaurant_id = rid) then
    return jsonb_build_object('ok', true, 'duplicate', true);
  end if;
  if not exists (select 1 from public.cashiers where id = p_cashier_id and restaurant_id = rid) then
    return jsonb_build_object('ok', false, 'error', 'unknown cashier');
  end if;
  if p_amount is null or p_amount <= 0 or btrim(coalesce(p_description, '')) = '' then
    return jsonb_build_object('ok', false, 'error', 'invalid');
  end if;
  select * into category from public.expense_categories where id = p_expense_category_id and restaurant_id = rid;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'unknown type');
  end if;
  select * into shift from public.shifts where (id = p_shift_id or client_id = p_shift_id) and restaurant_id = rid;
  if not found then
    select * into shift from public.shifts
    where cashier_id = p_cashier_id and restaurant_id = rid and closed_at is null
    order by opened_at desc limit 1;
  end if;
  if not found then
    insert into public.shifts (restaurant_id, cashier_id, opening_cash, opened_at, client_id)
    values (rid, p_cashier_id, 0, coalesce(p_created_at, now()), p_shift_id)
    returning * into shift;
  end if;
  cafe := category.name_en is distinct from 'Cash Withdrawal';
  label := private.next_expense_number(rid);
  insert into public.shift_expenses (
    restaurant_id, shift_id, cashier_id, paid_to_cashier_id, paid_to_cafe, amount, description, kind, display_number,
    expense_category_id, category_name_en, category_name_ar, created_at, client_id
  ) values (
    rid, shift.id, p_cashier_id, case when cafe then null else p_cashier_id end, cafe, p_amount, btrim(p_description),
    'cash_out', label, category.id, category.name_en, category.name_ar, coalesce(p_created_at, now()), p_client_id
  );
  return jsonb_build_object('ok', true, 'display_number', label, 'shift_id', shift.id);
end;
$function$
;

CREATE OR REPLACE FUNCTION public.sync_offline_shift_close(p_client_id uuid, p_cashier_id uuid, p_actual_cash numeric, p_closed_at timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  rid uuid := private.cashier_restaurant_id();
  sid uuid;
begin
  if rid is null then
    return jsonb_build_object('ok', false, 'error', 'session expired, sign in again');
  end if;
  if p_actual_cash is null or p_actual_cash < 0 then
    return jsonb_build_object('ok', false, 'error', 'invalid');
  end if;
  update public.shifts
  set actual_cash = round(p_actual_cash, 2), closed_at = greatest(coalesce(p_closed_at, now()), opened_at)
  where id = (
    select id from public.shifts
    where restaurant_id = rid
      and (id = p_client_id or client_id = p_client_id or (cashier_id = p_cashier_id and closed_at is null))
    order by (id = p_client_id or client_id is not distinct from p_client_id) desc, opened_at desc limit 1
  ) and closed_at is null
  returning id into sid;
  if sid is null then
    -- already closed by an earlier try
    return jsonb_build_object('ok', true, 'duplicate', true);
  end if;
  return jsonb_build_object('ok', true, 'shift_id', sid);
end;
$function$
;

CREATE OR REPLACE FUNCTION public.sync_offline_shift_open(p_client_id uuid, p_cashier_id uuid, p_opened_at timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  rid uuid := private.cashier_restaurant_id();
  shift public.shifts%rowtype;
begin
  if rid is null then
    return jsonb_build_object('ok', false, 'error', 'session expired, sign in again');
  end if;
  if not exists (select 1 from public.cashiers where id = p_cashier_id and restaurant_id = rid) then
    return jsonb_build_object('ok', false, 'error', 'unknown cashier');
  end if;
  perform pg_advisory_xact_lock(hashtext('open_shift:' || p_cashier_id::text));
  select * into shift from public.shifts where client_id = p_client_id and restaurant_id = rid;
  if not found then
    select * into shift from public.shifts
    where cashier_id = p_cashier_id and restaurant_id = rid and closed_at is null
    order by opened_at desc limit 1;
    -- merged into a shift already open on the server: remember the device's id so its sales find it
    if found and shift.client_id is null then
      update public.shifts set client_id = p_client_id where id = shift.id;
    end if;
  end if;
  if not found then
    insert into public.shifts (restaurant_id, cashier_id, opening_cash, opened_at, client_id)
    values (rid, p_cashier_id, 0, coalesce(p_opened_at, now()), p_client_id)
    returning * into shift;
  end if;
  return jsonb_build_object('ok', true, 'shift_id', shift.id);
end;
$function$
;

CREATE OR REPLACE FUNCTION public.sync_offline_takeout(p_client_id uuid, p_cashier_id uuid, p_shift_id uuid, p_lines jsonb, p_payment_type_id uuid, p_paid_at timestamp with time zone, p_year_month text, p_monthly_no integer, p_day_key text, p_day_no integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
$function$
;
