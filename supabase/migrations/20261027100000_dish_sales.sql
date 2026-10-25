-- Dishes sold in a range of days, for the best and slow sellers on the admin's summary report.
-- Kept apart from admin_sales_report so the report still prints on a server without it.
--
-- Rules, the same as the app's:
--   - p_from and p_to are Africa/Tripoli calendar days, both included, as in admin_sales_report.
--   - Only orders with a kept (not voided) sale in the range count; each order counts once, even
--     when more than one payment settled it.
--   - Lines group by dish; a line whose dish was deleted groups by its saved name.
-- Only the signed-in admin's own cafe, at most 366 days at a time. Nothing is changed.

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

revoke all on function public.admin_dish_sales(date, date) from public, anon;
grant execute on function public.admin_dish_sales(date, date) to authenticated;
