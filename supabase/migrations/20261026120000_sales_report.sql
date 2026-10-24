-- The admin's summary report for a range of days: sales (count and total), sales by payment
-- type, voids (count and amount), and expenses grouped by type and employee. The app prints it
-- and shows it on the Wages / Expenses cards, so totals no longer come from the recent sales
-- the app happens to have loaded.
--
-- Rules, the same as the app's:
--   - p_from and p_to are Africa/Tripoli calendar days, both included (a sale at 23:30 Tripoli
--     time belongs to that day).
--   - Voided sales count only under voids; voided expenses never count. Editing an expense voids
--     the old copy, so an edited expense counts once.
--   - An expense's type is its category; older rows without one count as the cafe's
--     "Café Expense" (paid to the cafe) or "Cash Withdrawal" type, as the app shows them.
--   - An expense's employee is whom a withdrawal paid, else the employee it is tagged with.
-- Only the signed-in admin's own cafe, at most 366 days at a time. Nothing is changed.

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

revoke all on function public.admin_sales_report(date, date) from public, anon;
grant execute on function public.admin_sales_report(date, date) to authenticated;
