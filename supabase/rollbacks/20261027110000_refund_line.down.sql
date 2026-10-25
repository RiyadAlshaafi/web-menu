-- Undoes 20261027110000_refund_line.sql: puts back void_payment, admin_sales_report and
-- admin_dish_sales from before refunds, then drops the refund function and columns.

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
  update public.shifts
    set cash_sales = greatest(cash_sales - pay.total_due, 0),
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
      select p.total_due, p.voided_at, p.payment_type_id, p.payment_type_name_en, p.payment_type_name_ar
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
      'void_total', coalesce((select sum(total_due) from sales where voided_at is not null), 0),
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
    dishes as (
      select l.menu_item_id,
             max(l.name) as name,
             sum(l.qty) as qty,
             sum(l.qty * l.unit_price) as total
      from public.order_lines l
      join sold s on s.order_id = l.order_id
      where l.restaurant_id = v_rid
      group by l.menu_item_id, case when l.menu_item_id is null then l.name end
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

drop function if exists public.refund_payment_line(uuid, uuid, integer, text);
drop function if exists private.is_cash_payment(uuid);
alter table public.payments drop column if exists refunds, drop column if exists refunded_total;
