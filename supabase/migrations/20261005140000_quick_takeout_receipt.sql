-- One paid takeout receipt per checkout.
-- Does not reuse an open order on the counter, and does not change dining-table status.
-- settle_cash is unchanged and still settles the open bill for a physical table.

create or replace function public.quick_takeout_receipt(
  p_lines jsonb,
  p_payment_type_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  rid uuid := private.cashier_restaurant_id();
  admin_rid uuid := private.current_restaurant_id();
  actor uuid := coalesce(rid, admin_rid);
  tbl public.dining_tables%rowtype;
  ord public.orders%rowtype;
  due numeric;
  shift public.shifts%rowtype;
  cid uuid;
  type_id uuid;
  yymm text;
  shift_n integer;
  month_n integer;
  shift_label text;
  month_label text;
  assigned jsonb;
  line_count integer := 0;
begin
  if actor is null then
    return jsonb_build_object('ok', false, 'error', 'sign in as a cashier first');
  end if;
  if p_lines is null or jsonb_typeof(p_lines) <> 'array' or jsonb_array_length(p_lines) = 0 then
    return jsonb_build_object('ok', false, 'error', 'cart is empty');
  end if;

  select * into tbl
  from public.dining_tables
  where restaurant_id = actor and lower(btrim(number)) = 'takeout'
  limit 1;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'takeout_table');
  end if;

  type_id := p_payment_type_id;
  if type_id is not null and not exists (
    select 1 from public.payment_types where id = type_id and restaurant_id = actor
  ) then
    type_id := null;
  end if;

  insert into public.orders (restaurant_id, table_id, status, service_type, payment_type_id)
  values (actor, tbl.id, 'served', 'takeout', type_id)
  returning * into ord;

  insert into public.order_lines (order_id, restaurant_id, menu_item_id, name, qty, unit_price, round)
  select ord.id, actor, item.id, coalesce(nullif(item.name_en, ''), item.name_it), x.qty, 0, 1
  from jsonb_to_recordset(p_lines) as x(menu_item_id uuid, qty integer)
  join public.menu_items item on item.id = x.menu_item_id
  where item.restaurant_id = actor
    and item.available
    and not item.sold_out
    and x.qty > 0;
  get diagnostics line_count = row_count;
  if line_count = 0 then
    delete from public.orders where id = ord.id;
    return jsonb_build_object('ok', false, 'error', 'cart is empty');
  end if;

  select round(coalesce(sum(qty * unit_price), 0), 2) into due
  from public.order_lines
  where order_id = ord.id;

  cid := coalesce(
    (select cashier_id from public.cashier_sessions s
      where s.token_hash = encode(extensions.digest(coalesce(private.header('x-cashier-token'), ''), 'sha256'), 'hex')
        and s.expires_at > now()
      limit 1),
    (select id from public.cashiers where restaurant_id = actor order by created_at limit 1)
  );
  if cid is null then
    delete from public.order_lines where order_id = ord.id;
    delete from public.orders where id = ord.id;
    return jsonb_build_object('ok', false, 'error', 'sign in as a cashier first');
  end if;
  select * into shift
  from public.shifts
  where cashier_id = cid and restaurant_id = actor and closed_at is null
  order by opened_at desc
  limit 1;
  if not found then
    insert into public.shifts (restaurant_id, cashier_id, opening_cash)
    values (actor, cid, 0)
    returning * into shift;
  end if;

  assigned := public.assign_shift_order_number(ord.id);
  if coalesce(assigned->>'ok', 'false') <> 'true' then
    return assigned;
  end if;
  select * into ord from public.orders where id = ord.id;
  yymm := to_char(now() at time zone 'Africa/Tripoli', 'YYMM');
  shift_n := ord.shift_order_number;
  shift_label := coalesce(ord.year_month, yymm) || case when length(shift_n::text) >= 3 then shift_n::text else lpad(shift_n::text, 3, '0') end;

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
    actor, ord.id, tbl.id, due, due, 0, cid, shift.id, type_id,
    yymm, shift_n, month_n, shift_label, month_label
  );
  update public.orders set status = 'paid', payment_type_id = type_id, service_type = 'takeout' where id = ord.id;
  update public.shifts
    set cash_sales = cash_sales + due,
        transaction_count = transaction_count + 1
    where id = shift.id;
  return jsonb_build_object(
    'ok', true,
    'order_id', ord.id,
    'total_due', due,
    'year_month', yymm,
    'shift_order_number', shift_n,
    'monthly_order_number', month_n
  );
end;
$$;

revoke all on function public.quick_takeout_receipt(jsonb, uuid) from public;
grant execute on function public.quick_takeout_receipt(jsonb, uuid) to anon, authenticated;
