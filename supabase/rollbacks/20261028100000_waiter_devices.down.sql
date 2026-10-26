-- Undoes 20261028100000_waiter_devices.sql: only cashiers sign in, every session is a till again.
-- The function bodies below are the ones from before that migration.

CREATE OR REPLACE FUNCTION public.cashier_clear_table(p_table_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  actor uuid := coalesce(private.cashier_restaurant_id(), private.current_restaurant_id());
  tbl public.dining_tables%rowtype;
  removed integer;
begin
  if actor is null then
    return jsonb_build_object('ok', false, 'error', 'sign in as a cashier first');
  end if;
  select * into tbl from public.dining_tables
  where id = p_table_id and restaurant_id = actor and not archived
  for update;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'table not found');
  end if;
  with gone as (
    delete from public.orders where table_id = p_table_id and restaurant_id = actor and status <> 'paid'
    returning id
  )
  select count(*) into removed from gone;
  delete from public.cart_lines where table_id = p_table_id;
  delete from public.carts where table_id = p_table_id;
  update public.staff_calls set resolved = true where table_id = p_table_id and resolved = false;
  update public.dining_tables set status = 'free', guests = 0 where id = p_table_id;
  delete from public.table_claims where table_id = p_table_id;
  return jsonb_build_object('ok', true, 'cancelled_orders', removed);
end;
$function$
;

CREATE OR REPLACE FUNCTION public.cashier_heartbeat_v2(p_app_version text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  sess public.cashier_sessions%rowtype;
  v text := nullif(left(btrim(coalesce(p_app_version, '')), 32), '');
  was_online boolean;
begin
  select s.* into sess from public.cashier_sessions s
  join public.restaurants r on r.id = s.restaurant_id
  where s.token_hash = encode(extensions.digest(coalesce(private.header('x-cashier-token'), ''), 'sha256'), 'hex')
    and s.expires_at > now()
    and r.suspended_at is null
  limit 1;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'session expired, sign in again');
  end if;
  was_online := private.cashier_online(sess.restaurant_id);
  insert into public.cashier_presence (session_id, restaurant_id, last_seen, app_version)
  values (sess.id, sess.restaurant_id, now(), v)
  on conflict (session_id) do update set last_seen = now(), app_version = excluded.app_version;
  -- The cafe just came back online: tell guest phones at once instead of at their next check.
  -- Only on that change, so the usual heartbeat sends nothing.
  if not was_online then
    begin
      perform realtime.send(jsonb_build_object('table', 'cashier_presence'), 'change', 'cafe:' || sess.restaurant_id, false);
    exception when others then
      raise warning 'cashier back ping failed: %', sqlerrm;
    end;
  end if;
  return jsonb_build_object(
    'ok', true,
    'min_app_version', coalesce((select r.min_app_version from public.app_release r where r.id), '0.0.0')
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.cashier_login(p_cashier_id uuid, p_pin text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  c public.cashiers%rowtype;
  raw_token text;
  lock_for interval;
  cafe_key text;
begin
  select * into c from public.cashiers where id = p_cashier_id and active for update;
  if not found then
    return jsonb_build_object('ok', false);
  end if;
  if exists (select 1 from public.restaurants r where r.id = c.restaurant_id and r.suspended_at is not null) then
    return jsonb_build_object(
      'ok', false,
      'code', 'suspended',
      'error', 'This cafe''s service is suspended. Please contact your provider.'
    );
  end if;
  if c.pin_locked_until > now() then
    return jsonb_build_object(
      'ok', false,
      'code', 'locked',
      'retry_after_seconds', ceil(extract(epoch from c.pin_locked_until - now()))::int
    );
  end if;
  cafe_key := 'pin_miss:' || c.restaurant_id::text;
  if private.rate_count(cafe_key, 0) >= 30 then
    return jsonb_build_object('ok', false, 'code', 'locked', 'retry_after_seconds', 60);
  end if;
  if c.pin_hash is distinct from extensions.crypt(coalesce(p_pin, ''), c.pin_hash) then
    perform private.rate_count(cafe_key, 1);
    -- Misses fade only after a full day without one; a correct PIN doesn't clear them.
    c.failed_pin_attempts := case
      when c.last_failed_pin_at is null or c.last_failed_pin_at < now() - interval '24 hours' then 1
      else c.failed_pin_attempts + 1
    end;
    if c.failed_pin_attempts % 5 = 0 then
      lock_for := least(
        interval '15 minutes' * power(2, c.failed_pin_attempts / 5 - 1),
        interval '24 hours'
      );
      update public.cashiers
        set failed_pin_attempts = c.failed_pin_attempts,
            last_failed_pin_at = now(),
            pin_locked_until = now() + lock_for
        where id = c.id;
      return jsonb_build_object(
        'ok', false,
        'code', 'locked',
        'retry_after_seconds', extract(epoch from lock_for)::int
      );
    end if;
    update public.cashiers
      set failed_pin_attempts = c.failed_pin_attempts, last_failed_pin_at = now()
      where id = c.id;
    return jsonb_build_object('ok', false);
  end if;
  update public.cashiers set pin_locked_until = null where id = c.id and pin_locked_until is not null;
  raw_token := encode(extensions.gen_random_bytes(32), 'hex');
  insert into public.cashier_sessions (cashier_id, restaurant_id, token_hash, expires_at)
  values (
    c.id,
    c.restaurant_id,
    encode(extensions.digest(raw_token, 'sha256'), 'hex'),
    now() + interval '12 hours'
  );
  return jsonb_build_object(
    'ok', true,
    'token', raw_token,
    'restaurant_id', c.restaurant_id,
    'cashier_id', c.id,
    'name', c.name,
    'initials', c.initials
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.change_payment_type(p_payment_id uuid, p_type_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  rid uuid := private.cashier_restaurant_id();
  admin_rid uuid := private.current_restaurant_id();
  actor uuid := coalesce(rid, admin_rid);
  pay public.payments%rowtype;
  actor_name text;
  actor_role text;
begin
  if actor is null then
    return jsonb_build_object('ok', false, 'error', 'sign in first');
  end if;
  select * into pay from public.payments where id = p_payment_id and restaurant_id = actor;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'payment not found');
  end if;
  if not exists (
    select 1 from public.payment_types where id = p_type_id and restaurant_id = actor
  ) then
    return jsonb_build_object('ok', false, 'error', 'unknown payment type');
  end if;
  if pay.payment_type_id is not distinct from p_type_id then
    return jsonb_build_object('ok', true);
  end if;
  if rid is not null then
    actor_role := 'cashier';
    select c.name into actor_name
    from public.cashiers c
    join public.cashier_sessions s on s.cashier_id = c.id
    where s.token_hash = encode(extensions.digest(coalesce(private.header('x-cashier-token'), ''), 'sha256'), 'hex')
    limit 1;
  else
    actor_role := 'admin';
    actor_name := coalesce(auth.jwt() ->> 'email', 'Admin');
  end if;
  insert into public.payment_method_changes (
    restaurant_id, payment_id, old_type_id, new_type_id, actor_name, actor_role
  ) values (
    actor, pay.id, pay.payment_type_id, p_type_id, coalesce(actor_name, actor_role), actor_role
  );
  update public.payments set payment_type_id = p_type_id where id = pay.id;
  return jsonb_build_object('ok', true);
end;
$function$
;

CREATE OR REPLACE FUNCTION public.close_shift(p_actual_cash numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  rid uuid := private.cashier_restaurant_id();
  cid uuid := private.session_cashier_id();
  sid uuid;
  unpaid integer;
begin
  if rid is null or cid is null then
    return jsonb_build_object('ok', false, 'error', 'session expired, sign in again');
  end if;
  if p_actual_cash is null or p_actual_cash < 0 then
    return jsonb_build_object('ok', false, 'error', 'invalid');
  end if;
  select count(*) into unpaid
  from public.orders o
  where o.restaurant_id = rid
    and o.status <> 'paid'
    and exists (select 1 from public.order_lines l where l.order_id = o.id);
  if unpaid > 0 then
    return jsonb_build_object('ok', false, 'error', 'unpaid orders still open', 'unpaid_orders', unpaid);
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
$function$
;

CREATE OR REPLACE FUNCTION public.edit_cash_movement(p_id uuid, p_expense_category_id uuid, p_amount numeric, p_description text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
    amount, description, kind, display_number, edited_from, staff_id,
    expense_category_id, category_name_en, category_name_ar
  ) values (
    original.restaurant_id, original.shift_id, cid,
    case when cafe then null else coalesce(original.paid_to_cashier_id, cid) end,
    cafe, p_amount, btrim(p_description), 'cash_out', label, original.id, original.staff_id,
    category.id, category.name_en, category.name_ar
  )
  returning id into new_id;
  return jsonb_build_object('ok', true, 'id', new_id, 'display_number', label);
end;
$function$
;

CREATE OR REPLACE FUNCTION public.open_shift()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
$function$
;

CREATE OR REPLACE FUNCTION public.quick_takeout_receipt(p_lines jsonb, p_payment_type_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  rid uuid := private.cashier_restaurant_id();
  admin_rid uuid := private.current_restaurant_id();
  actor uuid := coalesce(rid, admin_rid);
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
  type_id := p_payment_type_id;
  if type_id is not null and not exists (select 1 from public.payment_types where id = type_id and restaurant_id = actor) then
    type_id := null;
  end if;
  insert into public.orders (restaurant_id, table_id, status, service_type, payment_type_id)
  values (actor, null, 'served', 'takeout', type_id)
  returning * into ord;
  insert into public.order_lines (order_id, restaurant_id, menu_item_id, name, qty, unit_price, round, choices)
  select ord.id, actor, item.id, coalesce(nullif(item.name_en, ''), item.name_it), x.qty, 0, 1,
         private.dish_choices(item.options, x."on", null)
  from jsonb_to_recordset(p_lines) as x(menu_item_id uuid, qty integer, "on" jsonb)
  join public.menu_items item on item.id = x.menu_item_id
  where item.restaurant_id = actor and item.available and not item.sold_out and x.qty > 0;
  get diagnostics line_count = row_count;
  if line_count = 0 then
    delete from public.orders where id = ord.id;
    return jsonb_build_object('ok', false, 'error', 'cart is empty');
  end if;
  select round(coalesce(sum(qty * unit_price), 0), 2) into due from public.order_lines where order_id = ord.id;
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
  select * into shift from public.shifts
  where cashier_id = cid and restaurant_id = actor and closed_at is null
  order by opened_at desc limit 1;
  if not found then
    insert into public.shifts (restaurant_id, cashier_id, opening_cash) values (actor, cid, 0) returning * into shift;
  end if;
  assigned := public.assign_shift_order_number(ord.id);
  if coalesce(assigned->>'ok', 'false') <> 'true' then
    return assigned;
  end if;
  select * into ord from public.orders where id = ord.id;
  yymm := to_char(now() at time zone 'Africa/Tripoli', 'YYMM');
  shift_n := ord.shift_order_number;
  shift_label := coalesce(ord.year_month, yymm)
    || case when length(shift_n::text) >= 3 then shift_n::text else lpad(shift_n::text, 3, '0') end;
  insert into public.order_number_counters as counters (restaurant_id, scope, last_value)
  values (actor, 'month:' || yymm, 1)
  on conflict (restaurant_id, scope) do update set last_value = counters.last_value + 1
  returning last_value into month_n;
  month_label := yymm || case when length(month_n::text) >= 3 then month_n::text else lpad(month_n::text, 3, '0') end;
  insert into public.payments (
    restaurant_id, order_id, table_id, total_due, cash_received, change_due, cashier_id, shift_id, payment_type_id,
    year_month, shift_order_number, monthly_order_number, shift_display_number, monthly_display_number
  ) values (
    actor, ord.id, null, due, due, 0, cid, shift.id, type_id, yymm, shift_n, month_n, shift_label, month_label
  );
  update public.orders set status = 'paid', payment_type_id = type_id, service_type = 'takeout' where id = ord.id;
  update public.shifts set cash_sales = cash_sales + due, transaction_count = transaction_count + 1 where id = shift.id;
  return jsonb_build_object('ok', true, 'order_id', ord.id, 'total_due', due, 'year_month', yymm,
    'shift_order_number', shift_n, 'monthly_order_number', month_n);
end;
$function$
;

CREATE OR REPLACE FUNCTION public.record_cash_movement(p_shift_id uuid, p_expense_category_id uuid, p_amount numeric, p_description text, p_paid_to uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  cid uuid := private.session_cashier_id();
  rid uuid := private.cashier_restaurant_id();
  shift public.shifts%rowtype;
  category public.expense_categories%rowtype;
  new_id uuid;
  label text;
  cafe boolean;
  payee uuid;
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
  payee := cid;
  if p_paid_to is not null and p_paid_to <> cid then
    select c.id into payee
    from public.cashiers c
    where c.id = p_paid_to and c.restaurant_id = rid and c.active and c.role <> 'cashier';
    if payee is null then
      return jsonb_build_object('ok', false, 'error', 'invalid');
    end if;
  end if;
  label := private.next_expense_number(rid);
  insert into public.shift_expenses (
    restaurant_id, shift_id, cashier_id, paid_to_cashier_id, paid_to_cafe,
    amount, description, kind, display_number, staff_id,
    expense_category_id, category_name_en, category_name_ar
  ) values (
    rid, shift.id, cid,
    case when cafe then null else payee end,
    cafe, p_amount, btrim(p_description), 'cash_out', label,
    case when cafe and p_paid_to is not null then payee else null end,
    category.id, category.name_en, category.name_ar
  )
  returning id into new_id;
  return jsonb_build_object('ok', true, 'id', new_id, 'display_number', label);
end;
$function$
;

CREATE OR REPLACE FUNCTION public.refund_payment_line(p_payment_id uuid, p_line_id uuid, p_qty integer, p_reason text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  cid uuid := private.session_cashier_id();
  rid uuid := private.cashier_restaurant_id();
  pay public.payments%rowtype;
  line public.order_lines%rowtype;
  done integer;
  done_all integer;
  lines_qty integer;
  lines_total numeric;
  amount numeric;
begin
  if cid is null or rid is null then
    return jsonb_build_object('ok', false, 'error', 'sign in as a cashier first');
  end if;
  if btrim(coalesce(p_reason, '')) = '' then
    return jsonb_build_object('ok', false, 'error', 'reason required');
  end if;
  if p_qty is null or p_qty < 1 then
    return jsonb_build_object('ok', false, 'error', 'too many');
  end if;
  -- An offline sale keeps its till-side id as client_id, so either id finds it.
  select * into pay
  from public.payments
  where (id = p_payment_id or client_id = p_payment_id)
    and restaurant_id = rid and cashier_id = cid
  for update;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'not_found');
  end if;
  if pay.voided_at is not null then
    return jsonb_build_object('ok', false, 'error', 'already voided');
  end if;
  if not exists (
    select 1 from public.shifts
    where id = pay.shift_id and cashier_id = cid and closed_at is null
  ) then
    return jsonb_build_object('ok', false, 'error', 'shift closed');
  end if;
  select * into line
  from public.order_lines
  where id = p_line_id and order_id = pay.order_id and restaurant_id = rid;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'not_found');
  end if;

  select coalesce(sum((r->>'qty')::int) filter (where r->>'line_id' = line.id::text), 0), coalesce(sum((r->>'qty')::int), 0)
    into done, done_all
  from jsonb_array_elements(pay.refunds) r;
  if done + p_qty > line.qty then
    return jsonb_build_object('ok', false, 'error', 'too many');
  end if;
  select coalesce(sum(l.qty), 0), coalesce(sum(l.qty * l.unit_price), 0) into lines_qty, lines_total
  from public.order_lines l where l.order_id = pay.order_id;

  if done_all + p_qty >= lines_qty then
    amount := pay.total_due - pay.refunded_total;
  elsif lines_total = 0 then
    amount := 0;
  else
    amount := least(round(line.unit_price * p_qty * pay.total_due / lines_total, 2), pay.total_due - pay.refunded_total);
  end if;

  update public.payments
    set refunds = refunds || jsonb_build_array(jsonb_build_object(
          'line_id', line.id, 'menu_item_id', line.menu_item_id, 'name', line.name, 'qty', p_qty,
          'amount', amount, 'reason', left(btrim(p_reason), 200), 'at', now(), 'by', cid)),
        refunded_total = refunded_total + amount
    where id = pay.id;
  update public.shifts
    set cash_sales = greatest(cash_sales - amount, 0),
        cash_refunds = cash_refunds + case when private.is_cash_payment(pay.payment_type_id) then amount else 0 end
    where id = pay.shift_id;
  return jsonb_build_object('ok', true, 'id', pay.id, 'amount', amount);
end;
$function$
;

CREATE OR REPLACE FUNCTION public.reserve_receipt_numbers(p_count integer DEFAULT 50)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  rid uuid := private.cashier_restaurant_id();
  cid uuid := private.session_cashier_id();
  n integer := least(greatest(coalesce(p_count, 50), 1), 200);
  yymm text := to_char(now() at time zone 'Africa/Tripoli', 'YYMM');
  day_key text := to_char(now() at time zone 'Africa/Tripoli', 'YYMMDD');
  m_last integer;
  d_last integer;
begin
  if rid is null or cid is null then
    return jsonb_build_object('ok', false, 'error', 'session expired, sign in again');
  end if;
  insert into public.order_number_counters as c (restaurant_id, scope, last_value)
  values (rid, 'month:' || yymm, n)
  on conflict (restaurant_id, scope) do update set last_value = c.last_value + n
  returning last_value into m_last;
  insert into public.order_number_counters as c (restaurant_id, scope, last_value)
  values (rid, 'day:' || day_key, n)
  on conflict (restaurant_id, scope) do update set last_value = c.last_value + n
  returning last_value into d_last;
  insert into public.receipt_blocks (restaurant_id, cashier_id, year_month, first_no, last_no, day_key, day_first, day_last)
  values (rid, cid, yymm, m_last - n + 1, m_last, day_key, d_last - n + 1, d_last);
  return jsonb_build_object('ok', true, 'year_month', yymm, 'first', m_last - n + 1, 'last', m_last,
    'day_key', day_key, 'day_first', d_last - n + 1, 'day_last', d_last);
end;
$function$
;

CREATE OR REPLACE FUNCTION public.reserve_receipt_numbers(p_month_count integer, p_day_count integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  rid uuid := private.cashier_restaurant_id();
  cid uuid := private.session_cashier_id();
  m integer := least(greatest(coalesce(p_month_count, 0), 0), 200);
  d integer := least(greatest(coalesce(p_day_count, 0), 0), 200);
  yymm text := to_char(now() at time zone 'Africa/Tripoli', 'YYMM');
  today text := to_char(now() at time zone 'Africa/Tripoli', 'YYMMDD');
  m_last integer;
  d_last integer;
begin
  if rid is null or cid is null then
    return jsonb_build_object('ok', false, 'error', 'session expired, sign in again');
  end if;
  if m = 0 and d = 0 then
    return jsonb_build_object('ok', false, 'error', 'nothing to reserve');
  end if;
  if m > 0 then
    insert into public.order_number_counters as c (restaurant_id, scope, last_value)
    values (rid, 'month:' || yymm, m)
    on conflict (restaurant_id, scope) do update set last_value = c.last_value + m
    returning last_value into m_last;
  end if;
  if d > 0 then
    insert into public.order_number_counters as c (restaurant_id, scope, last_value)
    values (rid, 'day:' || today, d)
    on conflict (restaurant_id, scope) do update set last_value = c.last_value + d
    returning last_value into d_last;
  end if;
  insert into public.receipt_blocks (restaurant_id, cashier_id, year_month, first_no, last_no, day_key, day_first, day_last)
  values (
    rid, cid, yymm,
    case when m > 0 then m_last - m + 1 end, case when m > 0 then m_last end,
    case when d > 0 then today end, case when d > 0 then d_last - d + 1 end, case when d > 0 then d_last end
  );
  return jsonb_build_object(
    'ok', true, 'year_month', yymm,
    'first', case when m > 0 then m_last - m + 1 end, 'last', case when m > 0 then m_last end,
    'day_key', case when d > 0 then today end,
    'day_first', case when d > 0 then d_last - d + 1 end, 'day_last', case when d > 0 then d_last end
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.set_opening_cash(p_amount numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
$function$
;

CREATE OR REPLACE FUNCTION public.settle_cash(p_table_id uuid, p_cash_received numeric, p_apply_service boolean DEFAULT true, p_payment_type_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
$function$
;

CREATE OR REPLACE FUNCTION public.settle_part(p_table_id uuid, p_lines jsonb, p_cash_received numeric, p_apply_service boolean DEFAULT true, p_payment_type_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
$function$
;

CREATE OR REPLACE FUNCTION public.sync_offline_expense(p_client_id uuid, p_cashier_id uuid, p_shift_id uuid, p_expense_category_id uuid, p_amount numeric, p_description text, p_created_at timestamp with time zone, p_paid_to uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  rid uuid := private.cashier_restaurant_id();
  cid uuid := private.session_cashier_id();
  shift public.shifts%rowtype;
  category public.expense_categories%rowtype;
  made_at timestamptz := least(coalesce(p_created_at, now()), now());
  label text;
  cafe boolean;
  payee uuid := cid;
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
  if p_paid_to is not null and p_paid_to <> cid then
    select c.id into payee
    from public.cashiers c
    where c.id = p_paid_to and c.restaurant_id = rid and c.active and c.role <> 'cashier';
    if payee is null then
      return jsonb_build_object('ok', false, 'error', 'invalid');
    end if;
  end if;
  label := private.next_expense_number(rid);
  insert into public.shift_expenses (
    restaurant_id, shift_id, cashier_id, paid_to_cashier_id, paid_to_cafe, amount, description, kind, display_number,
    staff_id, expense_category_id, category_name_en, category_name_ar, created_at, client_id
  ) values (
    rid, shift.id, cid, case when cafe then null else payee end, cafe, round(p_amount, 2), btrim(p_description),
    'cash_out', label, case when cafe and p_paid_to is not null then payee else null end, category.id, category.name_en, category.name_ar, made_at, p_client_id
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
  cid uuid := private.session_cashier_id();
  sid uuid;
begin
  if rid is null or cid is null then
    return jsonb_build_object('ok', false, 'error', 'session expired, sign in again');
  end if;
  if p_cashier_id is distinct from cid then
    return jsonb_build_object('ok', false, 'error', 'offline work belongs to another cashier');
  end if;
  if p_actual_cash is null or p_actual_cash < 0 or p_actual_cash > 100000000 then
    return jsonb_build_object('ok', false, 'error', 'invalid');
  end if;
  update public.shifts
  set actual_cash = round(p_actual_cash, 2),
      closed_at = greatest(least(coalesce(p_closed_at, now()), now()), opened_at)
  where id = (
    select id from public.shifts
    where restaurant_id = rid and cashier_id = cid
      and (id = p_client_id or client_id = p_client_id or closed_at is null)
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
  cid uuid := private.session_cashier_id();
  shift public.shifts%rowtype;
begin
  if rid is null or cid is null then
    return jsonb_build_object('ok', false, 'error', 'session expired, sign in again');
  end if;
  if p_cashier_id is distinct from cid then
    return jsonb_build_object('ok', false, 'error', 'offline work belongs to another cashier');
  end if;
  perform pg_advisory_xact_lock(hashtext('open_shift:' || cid::text));
  select * into shift from public.shifts where client_id = p_client_id and restaurant_id = rid and cashier_id = cid;
  if not found then
    select * into shift from public.shifts
    where cashier_id = cid and restaurant_id = rid and closed_at is null
    order by opened_at desc limit 1;
    -- merged into a shift already open on the server: remember the device's id so its sales find it
    if found and shift.client_id is null
       and not exists (select 1 from public.shifts where client_id = p_client_id) then
      update public.shifts set client_id = p_client_id where id = shift.id;
    end if;
  end if;
  if not found then
    insert into public.shifts (restaurant_id, cashier_id, opening_cash, opened_at, client_id)
    values (rid, cid, 0, least(coalesce(p_opened_at, now()), now()),
            case when exists (select 1 from public.shifts where client_id = p_client_id) then null else p_client_id end)
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
  cid uuid := private.session_cashier_id();
  ord public.orders%rowtype;
  shift public.shifts%rowtype;
  due numeric := 0;
  type_id uuid := p_payment_type_id;
  line_count integer := 0;
  reserved_at timestamptz;
  paid_at timestamptz;
  m_label text;
  d_label text;
begin
  if rid is null or cid is null then
    return jsonb_build_object('ok', false, 'error', 'session expired, sign in again');
  end if;
  -- A retry that overlaps a slow first upload waits here, then sees the first one as a duplicate.
  perform pg_advisory_xact_lock(hashtext('offline_upload:' || p_client_id::text));
  if exists (select 1 from public.payments where client_id = p_client_id and restaurant_id = rid) then
    return jsonb_build_object('ok', true, 'duplicate', true);
  end if;
  if p_cashier_id is distinct from cid then
    return jsonb_build_object('ok', false, 'error', 'offline work belongs to another cashier');
  end if;
  if p_lines is null or jsonb_typeof(p_lines) <> 'array' or jsonb_array_length(p_lines) = 0 then
    return jsonb_build_object('ok', false, 'error', 'cart is empty');
  end if;
  select min(b.created_at) into reserved_at
  from public.receipt_blocks b
  where b.restaurant_id = rid and b.year_month = p_year_month
    and p_monthly_no between b.first_no and b.last_no;
  if reserved_at is null then
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
  -- The sale happened after its number was reserved and not after this upload.
  paid_at := least(greatest(coalesce(p_paid_at, now()), reserved_at), now());

  shift := private.offline_shift(rid, cid, p_shift_id, paid_at);

  perform set_config('app.offline_sync', 'on', true);
  insert into public.orders (restaurant_id, table_id, status, service_type, payment_type_id, cashier_id,
                             created_at, client_id, year_month, shift_order_number, number_day)
  values (rid, null, 'served', 'takeout', type_id, cid, paid_at, p_client_id,
          p_year_month, p_day_no, case when p_day_no is null then null else p_day_key end)
  returning * into ord;

  insert into public.order_lines (order_id, restaurant_id, menu_item_id, name, qty, unit_price, list_unit_price, round, choices)
  select ord.id, rid, nullif(x.menu_item_id, '')::uuid, coalesce(nullif(x.name, ''), 'Item'), x.qty,
         round(greatest(coalesce(x.unit_price, 0), 0), 2), round(greatest(coalesce(x.list_unit_price, x.unit_price, 0), 0), 2), 1,
         coalesce(x.choices, '[]'::jsonb)
  from jsonb_to_recordset(p_lines)
    as x(menu_item_id text, name text, qty integer, unit_price numeric, list_unit_price numeric, choices jsonb)
  where x.qty > 0 and x.qty <= 1000;
  get diagnostics line_count = row_count;
  if line_count = 0 then
    raise exception 'cart is empty';
  end if;
  perform set_config('app.offline_sync', 'off', true);
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
    rid, ord.id, null, due, due, 0, cid, shift.id, type_id,
    paid_at, p_year_month, p_day_no, p_monthly_no, d_label, m_label,
    p_client_id, true, now()
  );
  update public.orders set status = 'paid' where id = ord.id;
  update public.shifts set cash_sales = cash_sales + due, transaction_count = transaction_count + 1 where id = shift.id;
  return jsonb_build_object('ok', true, 'order_id', ord.id, 'shift_id', shift.id, 'total_due', due);
end;
$function$
;

CREATE OR REPLACE FUNCTION public.void_payment(p_payment_id uuid, p_reason text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  cid uuid := private.session_cashier_id();
  rid uuid := private.cashier_restaurant_id();
  pay public.payments%rowtype;
begin
  if cid is null or rid is null then
    return jsonb_build_object('ok', false, 'error', 'sign in as a cashier first');
  end if;
  if btrim(coalesce(p_reason, '')) = '' then
    return jsonb_build_object('ok', false, 'error', 'reason required');
  end if;
  -- An offline sale keeps its till-side id as client_id, so either id finds it.
  select * into pay
  from public.payments
  where (id = p_payment_id or client_id = p_payment_id)
    and restaurant_id = rid and cashier_id = cid
  for update;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'not_found');
  end if;
  if pay.voided_at is not null then
    return jsonb_build_object('ok', false, 'error', 'already voided');
  end if;
  if not exists (
    select 1 from public.shifts
    where id = pay.shift_id and cashier_id = cid and closed_at is null
  ) then
    return jsonb_build_object('ok', false, 'error', 'shift closed');
  end if;
  update public.payments
    set voided_at = now(), voided_by = cid, void_reason = left(btrim(p_reason), 200)
    where id = pay.id;
  -- What was already refunded left the sales and, for cash, the drawer; the void takes the rest.
  update public.shifts
    set cash_sales = greatest(cash_sales - (pay.total_due - pay.refunded_total), 0),
        cash_refunds = greatest(cash_refunds - case when private.is_cash_payment(pay.payment_type_id) then pay.refunded_total else 0 end, 0),
        transaction_count = greatest(transaction_count - 1, 0)
    where id = pay.shift_id;
  return jsonb_build_object('ok', true, 'id', pay.id);
end;
$function$
;

CREATE OR REPLACE FUNCTION private.cashier_online(p_restaurant_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select exists (
    select 1
    from public.cashier_presence p
    join public.cashier_sessions s on s.id = p.session_id
    join public.restaurants r on r.id = p.restaurant_id
    where p.restaurant_id = p_restaurant_id
      and p.last_seen > now() - interval '75 seconds'
      and s.expires_at > now()
      and r.suspended_at is null
  );
$function$
;


drop function if exists public.create_cashier(text, text, text, text, boolean);
create or replace function public.create_cashier(
  p_name text, p_pin text, p_initials text, p_role text default 'cashier')
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  rid uuid := private.current_restaurant_id();
  new_id uuid;
  hash text;
begin
  if rid is null or auth.uid() is null then
    raise exception 'admin sign-in required';
  end if;
  if p_role not in ('cashier', 'chef', 'server', 'cleaner') then
    raise exception 'unknown role';
  end if;
  if p_role = 'cashier' then
    if p_pin !~ '^[0-9]{4}$' then
      raise exception 'PIN must be 4 digits';
    end if;
    hash := extensions.crypt(p_pin, extensions.gen_salt('bf'));
  else
    hash := extensions.crypt(gen_random_uuid()::text, extensions.gen_salt('bf'));
  end if;
  insert into public.cashiers (restaurant_id, name, initials, pin_hash, role)
  values (rid, btrim(p_name), p_initials, hash, p_role)
  returning id into new_id;
  return new_id;
end;
$$;
revoke all on function public.create_cashier(text, text, text, text) from public;
grant execute on function public.create_cashier(text, text, text, text) to authenticated;

drop function if exists public.list_pos_cashiers(uuid);
create or replace function public.list_pos_cashiers(p_restaurant_id uuid default null)
returns table (id uuid, name text, initials text, role text)
language sql
stable
security definer
set search_path = ''
as $$
  select c.id, c.name, c.initials, c.role
  from public.cashiers c
  where p_restaurant_id is not null
    and c.restaurant_id = p_restaurant_id
    and c.active;
$$;
grant execute on function public.list_pos_cashiers(uuid) to anon, authenticated;

drop function if exists public.waiter_clear_table(uuid);

drop policy if exists payments_not_waiter on public.payments;
drop policy if exists payment_changes_not_waiter on public.payment_method_changes;
drop policy if exists shifts_not_waiter on public.shifts;
drop policy if exists shift_expenses_not_waiter on public.shift_expenses;
drop policy if exists expense_categories_not_waiter on public.expense_categories;
drop policy if exists orders_waiter_no_delete on public.orders;

drop function if exists private.require_till();
drop function if exists private.session_is_waiter();
drop function if exists private.session_is_till();
drop function if exists private.session_kind();

-- Waiter sessions would become tills once the column is gone; end them first.
delete from public.cashier_sessions where kind = 'waiter';
alter table public.cashier_sessions drop column if exists kind;
alter table public.cashiers drop column if exists uses_device;
