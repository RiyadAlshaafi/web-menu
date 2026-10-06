-- Restores a dev-screen CSV backup as new rows.
-- Original receipt numbers are copied onto the new payments.
-- order_number_counters is not changed.
-- A guest still cannot save a line with no menu item. Import sets dev.import
-- for its own transaction so the saved name and price are kept.

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
  if new.menu_item_id is null then
    if private.is_guest() and current_setting('dev.import', true) is distinct from 'on' then
      raise exception 'guests can only order items from the menu';
    end if;
    new.list_unit_price := coalesce(new.list_unit_price, new.unit_price);
    return new;
  end if;
  select * into item from public.menu_items where id = new.menu_item_id;
  if not found or item.restaurant_id <> parent.restaurant_id then
    raise exception 'menu item is not on this restaurant menu';
  end if;
  new.name := coalesce(nullif(item.name_en, ''), item.name_it);
  new.list_unit_price := item.price;
  new.unit_price := private.menu_sale_price(item.id);
  return new;
end;
$$;

create or replace function public.dev_import_logs(
  p_password text,
  p_receipts jsonb,
  p_expenses jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := private.dev_restaurant_id();
  cid uuid;
  sid uuid;
  rec jsonb;
  line jsonb;
  ord_id uuid;
  tbl_id uuid;
  payee uuid;
begin
  if not private.dev_allowed(p_password) then
    return jsonb_build_object('ok', false, 'error', 'Import did not run.');
  end if;
  if actor is null then
    return jsonb_build_object('ok', false, 'error', 'no restaurant');
  end if;
  if p_receipts is null or jsonb_typeof(p_receipts) <> 'array'
     or p_expenses is null or jsonb_typeof(p_expenses) <> 'array' then
    return jsonb_build_object('ok', false, 'error', 'The backup is not in the expected format.');
  end if;
  if jsonb_array_length(p_receipts) = 0 and jsonb_array_length(p_expenses) = 0 then
    return jsonb_build_object('ok', false, 'error', 'The file has headers but no rows to import.');
  end if;

  for rec in select value from jsonb_array_elements(p_receipts)
  loop
    if rec->>'service' not in ('dine_in', 'takeout') then
      return jsonb_build_object('ok', false, 'error', 'A receipt has an unknown service.');
    end if;
    if rec->>'paid_at' is null or rec->>'total_due' is null then
      return jsonb_build_object('ok', false, 'error', 'A receipt is missing its date or total.');
    end if;
    perform (rec->>'paid_at')::timestamptz;
    perform (rec->>'total_due')::numeric;
    select id into tbl_id
    from public.dining_tables
    where restaurant_id = actor
      and lower(btrim(number)) = lower(btrim(coalesce(rec->>'table', '')))
    limit 1;
    if tbl_id is null then
      return jsonb_build_object('ok', false, 'error', 'No table named ' || coalesce(rec->>'table', '') || '.');
    end if;
    if rec->'lines' is null or jsonb_typeof(rec->'lines') <> 'array' then
      return jsonb_build_object('ok', false, 'error', 'A receipt is missing its items.');
    end if;
    for line in select value from jsonb_array_elements(rec->'lines')
    loop
      if coalesce(line->>'name', '') = ''
         or coalesce((line->>'qty')::integer, 0) <= 0
         or line->>'unit_price' is null then
        return jsonb_build_object('ok', false, 'error', 'A receipt item is incomplete.');
      end if;
      perform (line->>'unit_price')::numeric;
    end loop;
  end loop;

  for rec in select value from jsonb_array_elements(p_expenses)
  loop
    if rec->>'created_at' is null or rec->>'amount' is null or rec->>'description' is null then
      return jsonb_build_object('ok', false, 'error', 'An expense is incomplete.');
    end if;
    perform (rec->>'created_at')::timestamptz;
    if (rec->>'amount')::numeric <= 0 then
      return jsonb_build_object('ok', false, 'error', 'An expense amount must be greater than zero.');
    end if;
    if jsonb_typeof(rec->'paid_to_cafe') <> 'boolean' then
      return jsonb_build_object('ok', false, 'error', 'An expense has a bad paid_to_cafe value.');
    end if;
  end loop;

  select id into cid
  from public.cashiers
  where restaurant_id = actor
  order by created_at
  limit 1;
  if cid is null then
    return jsonb_build_object('ok', false, 'error', 'Add a cashier before importing logs.');
  end if;
  select id into sid
  from public.shifts
  where restaurant_id = actor
  order by opened_at desc
  limit 1;
  if sid is null then
    insert into public.shifts (restaurant_id, cashier_id, opening_cash, closed_at)
    values (actor, cid, 0, now())
    returning id into sid;
  end if;

  perform set_config('dev.import', 'on', true);

  for rec in select value from jsonb_array_elements(p_receipts)
  loop
    select id into tbl_id
    from public.dining_tables
    where restaurant_id = actor
      and lower(btrim(number)) = lower(btrim(rec->>'table'))
    limit 1;
    insert into public.orders (restaurant_id, table_id, status, service_type, cashier_id, created_at)
    values (actor, tbl_id, 'paid', rec->>'service', cid, (rec->>'paid_at')::timestamptz)
    returning id into ord_id;
    for line in select value from jsonb_array_elements(rec->'lines')
    loop
      insert into public.order_lines (order_id, restaurant_id, name, qty, unit_price)
      values (ord_id, actor, line->>'name', (line->>'qty')::integer, (line->>'unit_price')::numeric);
    end loop;
    insert into public.payments (
      restaurant_id, order_id, table_id, total_due, cash_received, change_due,
      cashier_id, shift_id, paid_at, shift_display_number, monthly_display_number
    ) values (
      actor, ord_id, tbl_id, (rec->>'total_due')::numeric, (rec->>'total_due')::numeric, 0,
      cid, sid, (rec->>'paid_at')::timestamptz, nullif(rec->>'receipt', ''), nullif(rec->>'monthly', '')
    );
  end loop;

  for rec in select value from jsonb_array_elements(p_expenses)
  loop
    payee := case when (rec->>'paid_to_cafe')::boolean then null else cid end;
    insert into public.shift_expenses (
      restaurant_id, shift_id, cashier_id, paid_to_cashier_id, paid_to_cafe,
      amount, description, kind, created_at
    ) values (
      actor, sid, cid, payee, (rec->>'paid_to_cafe')::boolean,
      (rec->>'amount')::numeric, rec->>'description', coalesce(nullif(rec->>'kind', ''), 'cash_out'),
      (rec->>'created_at')::timestamptz
    );
  end loop;

  return jsonb_build_object(
    'ok', true,
    'receipts', jsonb_array_length(p_receipts),
    'expenses', jsonb_array_length(p_expenses)
  );
end;
$$;

revoke all on function public.dev_import_logs(text, jsonb, jsonb) from public;
grant execute on function public.dev_import_logs(text, jsonb, jsonb) to anon, authenticated;
