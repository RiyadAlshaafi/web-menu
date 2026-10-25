-- Refund one dish (or some of its quantity) of a paid sale, instead of voiding the whole sale.
-- Same rules as void_payment: only the cashier who took the sale, while that shift is open, with
-- a reason. Each refund is kept on the payment (refunds, refunded_total), the shift's sales drop
-- by its amount, and a cash refund also leaves the drawer (cash_refunds).
--
-- The amount is the dish's share of what was paid, so a service charge is shared fairly; the
-- last dish refunded gets whatever is left, so the refunds never pass the total.
-- void_payment, admin_sales_report and admin_dish_sales are replaced to count refunds.
-- Undo with supabase/rollbacks/20261027110000_refund_line.down.sql.

alter table public.payments
  add column if not exists refunds jsonb not null default '[]'::jsonb,
  add column if not exists refunded_total numeric(12, 2) not null default 0;

-- A sale paid in cash: no payment type, or a type named Cash (as the app decides it).
create or replace function private.is_cash_payment(p_type_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_type_id is null
      or exists (select 1 from public.payment_types t where t.id = p_type_id and lower(btrim(t.name_en)) = 'cash');
$$;

revoke all on function private.is_cash_payment(uuid) from public, anon, authenticated;

create or replace function public.refund_payment_line(p_payment_id uuid, p_line_id uuid, p_qty integer, p_reason text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
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
$$;

revoke all on function public.refund_payment_line(uuid, uuid, integer, text) from public;
grant execute on function public.refund_payment_line(uuid, uuid, integer, text) to anon, authenticated;

create or replace function public.void_payment(p_payment_id uuid, p_reason text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
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
$$;

create or replace function public.admin_sales_report(p_from date, p_to date)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_rid uuid := private.current_restaurant_id();
  v_start timestamptz;
  v_end timestamptz;
  v_cafe_type uuid;
  v_withdrawal_type uuid;
begin
  if v_rid is null then
    return jsonb_build_object('ok', false, 'error', 'not allowed');
  end if;
  if p_from is null or p_to is null or p_to < p_from or p_to - p_from > 366 then
    return jsonb_build_object('ok', false, 'error', 'bad range');
  end if;
  v_start := p_from::timestamp at time zone 'Africa/Tripoli';
  v_end := (p_to + 1)::timestamp at time zone 'Africa/Tripoli';

  select c.id into v_cafe_type from public.expense_categories c
  where c.restaurant_id = v_rid and c.name_en = 'Café Expense' order by c.created_at limit 1;
  select c.id into v_withdrawal_type from public.expense_categories c
  where c.restaurant_id = v_rid and c.name_en = 'Cash Withdrawal' order by c.created_at limit 1;

  return (
    with sales as (
      select p.total_due - p.refunded_total as total_due, p.refunded_total, p.voided_at, p.payment_type_id, p.payment_type_name_en, p.payment_type_name_ar
      from public.payments p
      where p.restaurant_id = v_rid and p.paid_at >= v_start and p.paid_at < v_end
    ),
    kept as (
      select * from sales where voided_at is null
    ),
    methods as (
      select k.payment_type_id,
             coalesce(max(t.name_en), max(k.payment_type_name_en), '') as name_en,
             coalesce(max(t.name_ar), max(k.payment_type_name_ar), '') as name_ar,
             count(*) as n,
             sum(k.total_due) as total
      from kept k
      left join public.payment_types t on t.id = k.payment_type_id
      group by k.payment_type_id
    ),
    expenses as (
      select e.amount,
             e.paid_to_cafe,
             coalesce(e.expense_category_id, case when e.paid_to_cafe then v_cafe_type else v_withdrawal_type end) as type_id,
             e.category_name_en,
             e.category_name_ar,
             coalesce(e.paid_to_cashier_id, e.staff_id) as employee_id,
             coalesce(nullif(e.paid_to_cashier_name, ''), nullif(e.staff_name, '')) as employee_saved
      from public.shift_expenses e
      where e.restaurant_id = v_rid and not e.voided and e.created_at >= v_start and e.created_at < v_end
    ),
    groups as (
      select coalesce(x.type_id::text, case when x.paid_to_cafe then 'cafe' else 'withdrawal' end) as type_key,
             x.type_id,
             coalesce(max(c.name_en), max(x.category_name_en), case when bool_or(x.paid_to_cafe) then 'Café Expense' else 'Cash Withdrawal' end) as type_en,
             coalesce(max(c.name_ar), max(x.category_name_ar), '') as type_ar,
             x.employee_id,
             coalesce(max(s.name), max(x.employee_saved), '') as employee,
             count(*) as n,
             sum(x.amount) as total
      from expenses x
      left join public.expense_categories c on c.id = x.type_id
      left join public.cashiers s on s.id = x.employee_id
      group by 1, x.type_id, x.employee_id
    )
    select jsonb_build_object(
      'ok', true,
      'from', p_from,
      'to', p_to,
      'sales_count', (select count(*) from kept),
      'sales_total', coalesce((select sum(total_due) from kept), 0),
      'void_count', (select count(*) from sales where voided_at is not null),
      'void_total', coalesce((select sum(total_due + refunded_total) from sales where voided_at is not null), 0),
      'refund_count', (select count(*) from kept where refunded_total > 0),
      'refund_total', coalesce((select sum(refunded_total) from kept), 0),
      'by_method', coalesce((
        select jsonb_agg(jsonb_build_object('id', m.payment_type_id, 'name_en', m.name_en, 'name_ar', m.name_ar, 'count', m.n, 'total', m.total)
                         order by m.total desc)
        from methods m
      ), '[]'::jsonb),
      'expenses', coalesce((
        select jsonb_agg(jsonb_build_object(
                 'type_key', g.type_key, 'type_id', g.type_id, 'type_en', g.type_en, 'type_ar', g.type_ar,
                 'employee_id', g.employee_id, 'employee', g.employee, 'count', g.n, 'total', g.total)
                 order by g.total desc)
        from groups g
      ), '[]'::jsonb)
    )
  );
end;
$$;

create or replace function public.admin_dish_sales(p_from date, p_to date)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_rid uuid := private.current_restaurant_id();
  v_start timestamptz;
  v_end timestamptz;
begin
  if v_rid is null then
    return jsonb_build_object('ok', false, 'error', 'not allowed');
  end if;
  if p_from is null or p_to is null or p_to < p_from or p_to - p_from > 366 then
    return jsonb_build_object('ok', false, 'error', 'bad range');
  end if;
  v_start := p_from::timestamp at time zone 'Africa/Tripoli';
  v_end := (p_to + 1)::timestamp at time zone 'Africa/Tripoli';

  return (
    with sold as (
      select distinct p.order_id
      from public.payments p
      where p.restaurant_id = v_rid and p.voided_at is null and p.paid_at >= v_start and p.paid_at < v_end
    ),
    sold_lines as (
      select l.menu_item_id, l.name, l.qty, l.qty * l.unit_price as total
      from public.order_lines l
      join sold s on s.order_id = l.order_id
      where l.restaurant_id = v_rid
      union all
      -- A refunded dish was given back: it counts as not sold.
      select (r->>'menu_item_id')::uuid, r->>'name', -(r->>'qty')::int, -(r->>'amount')::numeric
      from public.payments p
      cross join lateral jsonb_array_elements(p.refunds) r
      where p.restaurant_id = v_rid and p.voided_at is null and p.paid_at >= v_start and p.paid_at < v_end
    ),
    dishes as (
      select menu_item_id,
             max(name) as name,
             sum(qty) as qty,
             sum(total) as total
      from sold_lines
      group by menu_item_id, case when menu_item_id is null then name end
      having sum(qty) > 0
    )
    select jsonb_build_object(
      'ok', true,
      'dishes', coalesce((
        select jsonb_agg(jsonb_build_object('id', d.menu_item_id, 'name', d.name, 'qty', d.qty, 'total', d.total)
                         order by d.qty desc, d.total desc)
        from dishes d
      ), '[]'::jsonb)
    )
  );
end;
$$;
