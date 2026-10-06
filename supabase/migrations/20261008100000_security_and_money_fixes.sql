-- Security and money fixes, part 1. Safe to apply while the previous app build
-- is still live: nothing it uses is removed. Part 2
-- (20261008110000_lock_down_direct_writes.sql) removes the direct writes once
-- the app that uses the RPCs below is deployed.
--
-- 1. Developer tools stay password-only (restores the live project after a
--    short-lived sign-in lock).
-- 2. Guests cannot order dishes that are unavailable or sold out, huge
--    quantities, or through an archived table's QR code.
-- 3. Settling a bill charges only what was sent to the kitchen. Unsent cart
--    items are still cleared, but not charged.
-- 4. Narrow RPCs for order status, refused lines, bill requests, shifts and
--    cashier sign-out, so the app stops rewriting whole rows (an order status
--    change used to delete and re-insert every line, re-pricing it).

-- ------------------------------------------------------------ developer tools

-- The developer tools stay password-only: they are used on a customer's device
-- to link it to a cafe slot, where nobody is signed in. This puts back what
-- 20261006160000_dev_access_hardening.sql set up, undoing a developer-sign-in
-- lock that was applied to the live project for a short while. On a database
-- that never had that lock, it changes nothing.

create or replace function public.check_dev_access(p_password text)
returns boolean
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  rec public.dev_access%rowtype;
begin
  select * into rec
  from public.dev_access
  where password_hash like '$2%'
  order by created_at desc
  limit 1;

  if not found then
    return false;
  end if;

  if rec.locked_until is not null and rec.locked_until > now() then
    return false;
  end if;

  if rec.password_hash = extensions.crypt(coalesce(p_password, ''), rec.password_hash) then
    if rec.failed_attempts <> 0 or rec.locked_until is not null then
      update public.dev_access
      set failed_attempts = 0, locked_until = null
      where id = rec.id;
    end if;
    return true;
  end if;

  update public.dev_access
  set failed_attempts = case when failed_attempts + 1 >= 5 then 0 else failed_attempts + 1 end,
      locked_until = case when failed_attempts + 1 >= 5 then now() + interval '15 minutes' else locked_until end
  where id = rec.id;
  return false;
end;
$$;

do $$
declare
  fn regprocedure;
begin
  for fn in
    select p.oid::regprocedure
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and (p.proname like 'dev\_%' or p.proname = 'check_dev_access')
  loop
    execute format('revoke all on function %s from public', fn);
    execute format('grant execute on function %s to anon, authenticated', fn);
  end loop;
end $$;

drop function if exists private.is_developer();
drop table if exists private.developers;

-- ------------------------------------------------------------ helpers

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

revoke all on function private.session_cashier_id() from public, anon, authenticated;

create index if not exists cart_lines_table_idx on public.cart_lines (table_id);
create index if not exists staff_calls_table_idx on public.staff_calls (table_id);

-- ------------------------------------------------------------ guest ordering

create or replace function public.send_table_cart(
  p_qr_slug text default null,
  p_lines jsonb default null,
  p_service_type text default 'dine_in',
  p_lat double precision default null,
  p_lng double precision default null,
  p_accuracy_m double precision default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  tid uuid;
  tbl public.dining_tables%rowtype;
  ord public.orders%rowtype;
  next_round integer;
  line_count integer := 0;
  service text := case when p_service_type = 'takeout' then 'takeout' else 'dine_in' end;
  location_error text;
  unavailable jsonb;
  slug text := nullif(btrim(coalesce(p_qr_slug, '')), '');
begin
  -- A slug that was sent is final: falling back to the request header when it
  -- does not match could put the order on a different table.
  if slug is not null then
    select id into tid from public.dining_tables where qr_slug = slug and not archived;
  else
    tid := private.guest_table_id();
  end if;
  if tid is null then
    return jsonb_build_object('ok', false, 'error', 'table not found');
  end if;
  select * into tbl from public.dining_tables where id = tid for update;
  if tbl.id is null or tbl.archived then
    return jsonb_build_object('ok', false, 'error', 'table not found');
  end if;

  location_error := private.order_location_error(tbl.restaurant_id, p_lat, p_lng, p_accuracy_m);
  if location_error is not null then
    return jsonb_build_object('ok', false, 'error', location_error);
  end if;

  insert into public.carts (table_id, restaurant_id)
  values (tid, tbl.restaurant_id)
  on conflict (table_id) do update set restaurant_id = excluded.restaurant_id;

  if p_lines is not null and jsonb_typeof(p_lines) = 'array' and jsonb_array_length(p_lines) > 0 then
    if jsonb_array_length(p_lines) > 100 then
      return jsonb_build_object('ok', false, 'error', 'too_many_lines');
    end if;
    delete from public.cart_lines where table_id = tid;
    insert into public.cart_lines (table_id, restaurant_id, menu_item_id, name, qty, unit_price)
    select tid, tbl.restaurant_id, item.id, coalesce(nullif(item.name_en, ''), item.name_it), x.qty, 0
    from jsonb_to_recordset(p_lines) as x(menu_item_id uuid, qty integer)
    join public.menu_items item on item.id = x.menu_item_id
    where item.restaurant_id = tbl.restaurant_id and x.qty > 0;
  end if;

  select count(*) into line_count from public.cart_lines where table_id = tid;
  if line_count = 0 then
    return jsonb_build_object('ok', false, 'error', 'cart is empty');
  end if;

  if exists (select 1 from public.cart_lines where table_id = tid and qty > 99) then
    return jsonb_build_object('ok', false, 'error', 'qty_too_large');
  end if;

  -- A dish can be switched off after the guest put it in the cart. Refuse the
  -- whole send and name the dishes, so the guest decides what to do instead.
  select coalesce(jsonb_agg(distinct coalesce(nullif(item.name_en, ''), item.name_it)), '[]'::jsonb)
    into unavailable
  from public.cart_lines cl
  join public.menu_items item on item.id = cl.menu_item_id
  where cl.table_id = tid and (not item.available or item.sold_out);
  if jsonb_array_length(unavailable) > 0 then
    return jsonb_build_object('ok', false, 'error', 'items_unavailable', 'items', unavailable);
  end if;

  select * into ord
  from public.orders
  where table_id = tid and status <> 'paid'
  order by created_at desc
  limit 1
  for update;
  if not found then
    insert into public.orders (restaurant_id, table_id, status, service_type)
    values (tbl.restaurant_id, tid, 'received', service)
    returning * into ord;
    next_round := 1;
  else
    select coalesce(max(round), 0) + 1 into next_round from public.order_lines where order_id = ord.id;
    update public.orders set status = 'received' where id = ord.id;
  end if;

  insert into public.order_lines (order_id, restaurant_id, menu_item_id, name, qty, unit_price, list_unit_price, round)
  select ord.id, tbl.restaurant_id, cl.menu_item_id, cl.name, cl.qty, cl.unit_price, cl.list_unit_price, next_round
  from public.cart_lines cl
  where cl.table_id = tid;
  delete from public.cart_lines where table_id = tid;
  if ord.service_type <> 'takeout' and tbl.status = 'free' then
    update public.dining_tables
      set status = 'dining',
          guests = case when guests = 0 then seats else guests end
      where id = tid;
  end if;
  return jsonb_build_object('ok', true, 'order_id', ord.id, 'round', next_round, 'service_type', ord.service_type);
end;
$$;

create or replace function public.guest_location_rule(
  p_qr_slug text,
  p_lat double precision default null,
  p_lng double precision default null,
  p_accuracy_m double precision default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  rid uuid;
  enabled boolean;
  radius_m integer;
  cafe_lat double precision;
  cafe_lng double precision;
  location_error text;
  slug text := nullif(btrim(coalesce(p_qr_slug, '')), '');
begin
  if slug is not null then
    select t.restaurant_id into rid from public.dining_tables t where t.qr_slug = slug and not t.archived;
  else
    select restaurant_id into rid from public.dining_tables where id = private.guest_table_id();
  end if;
  if rid is null then
    return jsonb_build_object('enabled', false, 'radius_m', 100);
  end if;

  select location_check_enabled, location_radius_m, location_lat, location_lng
    into enabled, radius_m, cafe_lat, cafe_lng
  from public.restaurants
  where id = rid;

  enabled := coalesce(enabled, false) and cafe_lat is not null and cafe_lng is not null;
  if p_lat is null or p_lng is null or not enabled then
    return jsonb_build_object('enabled', enabled, 'radius_m', coalesce(radius_m, 100));
  end if;

  location_error := private.order_location_error(rid, p_lat, p_lng, p_accuracy_m);
  return jsonb_build_object(
    'enabled', true,
    'radius_m', coalesce(radius_m, 100),
    'status', coalesce(location_error, 'allowed')
  );
end;
$$;

-- ------------------------------------------------------------ settle

-- Same as 20261002150000_settle_row_lock.sql except the amount due: only lines
-- sent to the kitchen are charged. Unsent cart lines are cleared, not billed.
create or replace function public.settle_cash(
  p_table_id uuid,
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
  rid uuid := private.cashier_restaurant_id();
  admin_rid uuid := private.current_restaurant_id();
  actor uuid := coalesce(rid, admin_rid);
  ord public.orders%rowtype;
  due numeric;
  rate numeric;
  shift public.shifts%rowtype;
  cid uuid;
  type_id uuid;
  yymm text;
  day_key text;
  shift_n integer;
  month_n integer;
  shift_label text;
  month_label text;
  assigned jsonb;
begin
  if actor is null then
    return jsonb_build_object('ok', false, 'error', 'sign in as a cashier first');
  end if;
  select * into ord
  from public.orders
  where table_id = p_table_id
    and restaurant_id = actor
    and status <> 'paid'
  order by created_at desc
  limit 1
  for update;
  if not found or ord.status = 'paid' then
    return jsonb_build_object('ok', false, 'error', 'no open bill');
  end if;
  if ord.status is distinct from 'served' then
    return jsonb_build_object('ok', false, 'error', 'order is not served');
  end if;
  type_id := coalesce(p_payment_type_id, ord.payment_type_id);
  if type_id is not null and not exists (
    select 1 from public.payment_types where id = type_id and restaurant_id = actor
  ) then
    type_id := null;
  end if;
  select coalesce(sum(qty * unit_price), 0) into due
  from public.order_lines
  where order_id = ord.id;
  select service_charge_rate into rate from public.restaurants where id = actor;
  if p_apply_service then
    due := round(due * (1 + coalesce(rate, 0)), 2);
  else
    due := round(due, 2);
  end if;
  if p_cash_received < due then
    return jsonb_build_object('ok', false, 'error', 'insufficient cash');
  end if;
  cid := private.session_cashier_id();
  if cid is null then
    return jsonb_build_object('ok', false, 'error', 'session expired, sign in again');
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

  day_key := to_char(now() at time zone 'Africa/Tripoli', 'YYMMDD');
  if ord.shift_order_number is null or ord.number_day is distinct from day_key then
    assigned := public.assign_shift_order_number(ord.id);
    if coalesce(assigned->>'ok', 'false') <> 'true' then
      return assigned;
    end if;
    select * into ord from public.orders where id = ord.id;
  end if;
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
    actor, ord.id, p_table_id, due, p_cash_received, p_cash_received - due, cid, shift.id, type_id,
    yymm, shift_n, month_n, shift_label, month_label
  );
  update public.orders set status = 'paid', payment_type_id = type_id where id = ord.id;
  update public.dining_tables set status = 'free', guests = 0 where id = p_table_id;
  delete from public.cart_lines where table_id = p_table_id;
  delete from public.carts where table_id = p_table_id;
  update public.staff_calls set resolved = true where table_id = p_table_id and resolved = false;
  update public.shifts
    set cash_sales = cash_sales + due,
        transaction_count = transaction_count + 1
    where id = shift.id;
  return jsonb_build_object('ok', true, 'total_due', due, 'year_month', yymm, 'shift_order_number', shift_n, 'monthly_order_number', month_n);
end;
$$;

-- ------------------------------------------------------------ orders

-- Moves an order one kitchen step forward. Only the status column changes; the
-- lines (and their prices) are left alone.
create or replace function public.set_order_status(p_order_id uuid, p_status text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := coalesce(private.cashier_restaurant_id(), private.current_restaurant_id());
  ord public.orders%rowtype;
  expected text;
begin
  if actor is null then
    return jsonb_build_object('ok', false, 'error', 'sign in as a cashier first');
  end if;
  select * into ord
  from public.orders
  where id = p_order_id and restaurant_id = actor
  for update;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'order not found');
  end if;
  if ord.status = p_status then
    return jsonb_build_object('ok', true, 'status', ord.status);
  end if;
  expected := case ord.status
    when 'received' then 'preparing'
    when 'preparing' then 'ready'
    when 'ready' then 'served'
    else null
  end;
  if expected is null or p_status is distinct from expected then
    return jsonb_build_object('ok', false, 'error', 'invalid status change', 'status', ord.status);
  end if;
  update public.orders set status = p_status where id = ord.id;
  return jsonb_build_object('ok', true, 'status', p_status);
end;
$$;

-- Removes one refused line from an unpaid order.
create or replace function public.remove_order_line(p_line_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := coalesce(private.cashier_restaurant_id(), private.current_restaurant_id());
  ord public.orders%rowtype;
begin
  if actor is null then
    return jsonb_build_object('ok', false, 'error', 'sign in as a cashier first');
  end if;
  select o.* into ord
  from public.orders o
  join public.order_lines l on l.order_id = o.id
  where l.id = p_line_id and o.restaurant_id = actor and o.status <> 'paid'
  for update of o;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'line not found');
  end if;
  delete from public.order_lines where id = p_line_id;
  return jsonb_build_object('ok', true, 'order_id', ord.id);
end;
$$;

-- Guest (by QR slug) or staff (by table id) asks for the bill: marks a dine-in
-- table as waiting for the bill and opens one bill call if none is open.
create or replace function public.request_bill(p_qr_slug text default null, p_table_id uuid default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  staff uuid := coalesce(private.cashier_restaurant_id(), private.current_restaurant_id());
  slug text := nullif(btrim(coalesce(p_qr_slug, '')), '');
  tbl public.dining_tables%rowtype;
  ord public.orders%rowtype;
begin
  if slug is not null then
    select * into tbl from public.dining_tables where qr_slug = slug and not archived for update;
  elsif p_table_id is not null and staff is not null then
    select * into tbl from public.dining_tables where id = p_table_id and restaurant_id = staff for update;
  else
    select * into tbl from public.dining_tables where id = private.guest_table_id() for update;
  end if;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'table not found');
  end if;
  select * into ord
  from public.orders
  where table_id = tbl.id and status <> 'paid'
  order by created_at desc
  limit 1;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'no open bill');
  end if;
  if ord.service_type is distinct from 'takeout' and tbl.status <> 'billRequested' then
    update public.dining_tables set status = 'billRequested' where id = tbl.id;
  end if;
  if not exists (
    select 1 from public.staff_calls
    where table_id = tbl.id and kind = 'bill' and not resolved
  ) then
    insert into public.staff_calls (restaurant_id, table_id, kind)
    values (tbl.restaurant_id, tbl.id, 'bill');
  end if;
  return jsonb_build_object('ok', true);
end;
$$;

-- ------------------------------------------------------------ shifts

-- Returns the signed-in cashier's open shift, opening one if needed. Only the
-- server touches cash_sales and transaction_count.
create or replace function public.open_shift()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  rid uuid := private.cashier_restaurant_id();
  cid uuid := private.session_cashier_id();
  shift public.shifts%rowtype;
begin
  if rid is null or cid is null then
    return jsonb_build_object('ok', false, 'error', 'session expired, sign in again');
  end if;
  perform pg_advisory_xact_lock(hashtext('open_shift:' || cid::text));
  select * into shift
  from public.shifts
  where cashier_id = cid and restaurant_id = rid and closed_at is null
  order by opened_at desc
  limit 1;
  if not found then
    insert into public.shifts (restaurant_id, cashier_id, opening_cash)
    values (rid, cid, 0)
    returning * into shift;
  end if;
  return jsonb_build_object('ok', true, 'shift_id', shift.id);
end;
$$;

create or replace function public.set_opening_cash(p_amount numeric)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  rid uuid := private.cashier_restaurant_id();
  cid uuid := private.session_cashier_id();
  sid uuid;
begin
  if rid is null or cid is null then
    return jsonb_build_object('ok', false, 'error', 'session expired, sign in again');
  end if;
  if p_amount is null or p_amount < 0 then
    return jsonb_build_object('ok', false, 'error', 'invalid');
  end if;
  update public.shifts
  set opening_cash = round(p_amount, 2)
  where id = (
    select id from public.shifts
    where cashier_id = cid and restaurant_id = rid and closed_at is null
    order by opened_at desc
    limit 1
  )
  returning id into sid;
  if sid is null then
    return jsonb_build_object('ok', false, 'error', 'no open shift');
  end if;
  return jsonb_build_object('ok', true, 'shift_id', sid);
end;
$$;

create or replace function public.close_shift(p_actual_cash numeric)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  rid uuid := private.cashier_restaurant_id();
  cid uuid := private.session_cashier_id();
  sid uuid;
begin
  if rid is null or cid is null then
    return jsonb_build_object('ok', false, 'error', 'session expired, sign in again');
  end if;
  if p_actual_cash is null or p_actual_cash < 0 then
    return jsonb_build_object('ok', false, 'error', 'invalid');
  end if;
  update public.shifts
  set actual_cash = round(p_actual_cash, 2),
      closed_at = now()
  where id = (
    select id from public.shifts
    where cashier_id = cid and restaurant_id = rid and closed_at is null
    order by opened_at desc
    limit 1
  )
  returning id into sid;
  if sid is null then
    return jsonb_build_object('ok', false, 'error', 'no open shift');
  end if;
  return jsonb_build_object('ok', true, 'shift_id', sid);
end;
$$;

-- Ends this device's cashier session on the server and clears out sessions
-- that expired more than a day ago.
create or replace function public.cashier_logout()
returns void
language sql
security definer
set search_path = ''
as $$
  delete from public.cashier_sessions
  where token_hash = encode(extensions.digest(coalesce(private.header('x-cashier-token'), ''), 'sha256'), 'hex')
     or expires_at < now() - interval '1 day';
$$;

revoke all on function public.set_order_status(uuid, text) from public;
revoke all on function public.remove_order_line(uuid) from public;
revoke all on function public.request_bill(text, uuid) from public;
revoke all on function public.open_shift() from public;
revoke all on function public.set_opening_cash(numeric) from public;
revoke all on function public.close_shift(numeric) from public;
revoke all on function public.cashier_logout() from public;
grant execute on function public.set_order_status(uuid, text) to anon, authenticated;
grant execute on function public.remove_order_line(uuid) to anon, authenticated;
grant execute on function public.request_bill(text, uuid) to anon, authenticated;
grant execute on function public.open_shift() to anon, authenticated;
grant execute on function public.set_opening_cash(numeric) to anon, authenticated;
grant execute on function public.close_shift(numeric) to anon, authenticated;
grant execute on function public.cashier_logout() to anon, authenticated;
