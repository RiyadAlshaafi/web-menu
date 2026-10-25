-- Split the bill: pay for some of a table's dishes now and keep the rest on the open tab, so each
-- guest can pay their own part, each with their own payment type. The picked dishes (some of a
-- line's quantity is fine) move to a new paid order on the same table, with the tab's order
-- number, paid with the same rules as settle_cash (service charge, numbers, shift totals). The table stays open until
-- its last part is paid with settle_cash. Picking every dish is refused: that is a normal settle.
--
-- A part of a line becomes its own line. It keeps the price, choices and round it was ordered
-- with, and the dish's stock is not taken twice.
-- Undo with supabase/rollbacks/20261027130000_settle_part.down.sql.

create or replace function public.settle_part(
  p_table_id uuid,
  p_lines jsonb,
  p_cash_received numeric,
  p_apply_service boolean default true,
  p_payment_type_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := coalesce(private.cashier_restaurant_id(), private.current_restaurant_id());
  ord public.orders%rowtype;
  part public.orders%rowtype;
  line public.order_lines%rowtype;
  pick jsonb;
  pick_qty integer;
  picked_qty integer := 0;
  total_qty integer;
  copy_id uuid;
  due numeric;
  rate numeric;
  shift public.shifts%rowtype;
  cid uuid;
  type_id uuid;
  yymm text;
  shift_n integer;
  month_n integer;
  shift_label text;
  month_label text;
  assigned jsonb;
begin
  if actor is null then
    return jsonb_build_object('ok', false, 'error', 'sign in as a cashier first');
  end if;
  cid := private.session_cashier_id();
  if cid is null then
    return jsonb_build_object('ok', false, 'error', 'session expired, sign in again');
  end if;
  if jsonb_typeof(p_lines) is distinct from 'array' or jsonb_array_length(p_lines) = 0 or jsonb_array_length(p_lines) > 100 then
    return jsonb_build_object('ok', false, 'error', 'pick dishes');
  end if;
  select * into ord
  from public.orders
  where table_id = p_table_id and restaurant_id = actor and status <> 'paid'
  order by created_at desc
  limit 1
  for update;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'no open bill');
  end if;
  if ord.status is distinct from 'served' then
    return jsonb_build_object('ok', false, 'error', 'order is not served');
  end if;

  -- Check every pick before changing anything.
  for pick in select * from jsonb_array_elements(p_lines) loop
    pick_qty := coalesce((pick->>'qty')::int, 0);
    if pick_qty < 1 or not exists (
      select 1 from public.order_lines
      where id = (pick->>'line_id')::uuid and order_id = ord.id and qty >= pick_qty
    ) then
      return jsonb_build_object('ok', false, 'error', 'pick dishes');
    end if;
    picked_qty := picked_qty + pick_qty;
  end loop;
  if (select count(distinct x->>'line_id') from jsonb_array_elements(p_lines) x) <> jsonb_array_length(p_lines) then
    return jsonb_build_object('ok', false, 'error', 'pick dishes');
  end if;
  select coalesce(sum(qty), 0) into total_qty from public.order_lines where order_id = ord.id;
  if picked_qty >= total_qty then
    return jsonb_build_object('ok', false, 'error', 'whole bill');
  end if;

  -- The part carries the tab's order number, so its receipt reads as part of that order. It is
  -- made paid at once: a table holds only one open order.
  if ord.shift_order_number is null or ord.number_day is distinct from to_char(now() at time zone 'Africa/Tripoli', 'YYMMDD') then
    assigned := public.assign_shift_order_number(ord.id);
    if coalesce(assigned->>'ok', 'false') <> 'true' then
      return assigned;
    end if;
    select * into ord from public.orders where id = ord.id;
  end if;
  insert into public.orders (
    restaurant_id, table_id, table_number, status, service_type, cashier_id, payment_type_id,
    year_month, shift_order_number, number_day
  ) values (
    actor, p_table_id, ord.table_number, 'paid', ord.service_type, cid, ord.payment_type_id,
    ord.year_month, ord.shift_order_number, ord.number_day
  )
  returning * into part;

  for pick in select * from jsonb_array_elements(p_lines) loop
    pick_qty := (pick->>'qty')::int;
    select * into line from public.order_lines where id = (pick->>'line_id')::uuid for update;
    if pick_qty = line.qty then
      update public.order_lines set order_id = part.id where id = line.id;
    else
      update public.order_lines set qty = qty - pick_qty where id = line.id;
      insert into public.order_lines (order_id, restaurant_id, menu_item_id, name, qty, unit_price)
      values (part.id, actor, line.menu_item_id, line.name, pick_qty, line.unit_price)
      returning id into copy_id;
      -- The new row is priced from today's menu on insert; give it back the ordered price.
      update public.order_lines
        set name = line.name, unit_price = line.unit_price, list_unit_price = line.list_unit_price,
            choices = line.choices, round = line.round
        where id = copy_id;
      -- Inserting took the dish's stock again; these were already counted when ordered.
      update public.menu_items set stock_qty = stock_qty + pick_qty
        where id = line.menu_item_id and restaurant_id = actor and stock_qty is not null;
    end if;
  end loop;

  -- Pay the part, as settle_cash does, but leave the table open for the rest.
  type_id := coalesce(p_payment_type_id, ord.payment_type_id);
  if type_id is not null and not exists (
    select 1 from public.payment_types where id = type_id and restaurant_id = actor
  ) then
    type_id := null;
  end if;
  select coalesce(sum(qty * unit_price), 0) into due from public.order_lines where order_id = part.id;
  select service_charge_rate into rate from public.restaurants where id = actor;
  due := round(case when p_apply_service then due * (1 + coalesce(rate, 0)) else due end, 2);
  if p_cash_received < due then
    raise exception 'insufficient cash' using errcode = 'P0001';
  end if;
  select * into shift
  from public.shifts
  where cashier_id = cid and restaurant_id = actor and closed_at is null
  order by opened_at desc
  limit 1;
  if not found then
    insert into public.shifts (restaurant_id, cashier_id, opening_cash) values (actor, cid, 0) returning * into shift;
  end if;
  yymm := to_char(now() at time zone 'Africa/Tripoli', 'YYMM');
  shift_n := part.shift_order_number;
  shift_label := coalesce(part.year_month, yymm) || case when length(shift_n::text) >= 3 then shift_n::text else lpad(shift_n::text, 3, '0') end;
  insert into public.order_number_counters as counters (restaurant_id, scope, last_value)
  values (actor, 'month:' || yymm, 1)
  on conflict (restaurant_id, scope)
  do update set last_value = counters.last_value + 1
  returning last_value into month_n;
  month_label := yymm || case when length(month_n::text) >= 3 then month_n::text else lpad(month_n::text, 3, '0') end;

  insert into public.payments (
    restaurant_id, order_id, table_id, total_due, cash_received, change_due, cashier_id, shift_id, payment_type_id,
    year_month, shift_order_number, monthly_order_number, shift_display_number, monthly_display_number
  ) values (
    actor, part.id, p_table_id, due, p_cash_received, p_cash_received - due, cid, shift.id, type_id,
    yymm, shift_n, month_n, shift_label, month_label
  );
  update public.orders set payment_type_id = type_id where id = part.id;
  update public.shifts
    set cash_sales = cash_sales + due,
        transaction_count = transaction_count + 1
    where id = shift.id;
  return jsonb_build_object('ok', true, 'order_id', part.id, 'total_due', due);
exception
  when sqlstate 'P0001' then
    if sqlerrm = 'insufficient cash' then
      return jsonb_build_object('ok', false, 'error', 'insufficient cash');
    end if;
    raise;
end;
$$;

revoke all on function public.settle_part(uuid, jsonb, numeric, boolean, uuid) from public;
grant execute on function public.settle_part(uuid, jsonb, numeric, boolean, uuid) to anon, authenticated;
