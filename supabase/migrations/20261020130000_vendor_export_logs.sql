-- Backup of one cafe slot's logs for the vendor dashboard: receipts (with their lines) and
-- expenses paid or created inside a time window, in the same shape as dev_export_logs so the
-- dashboard can write the same CSV files the dev screen imports.
--
-- Unlike dev_export_logs it names the cafe, works for a suspended one too (an unpaid cafe's data
-- must stay backed up), and is limited to a window of at most 31 days so one call stays small
-- and quick; the dashboard walks the windows one after another.
-- Months older than the last two live in the archive (Cloudflare R2), not in this table.

create or replace function public.vendor_export_logs(
  p_password text,
  p_restaurant_id uuid,
  p_from timestamptz,
  p_to timestamptz
)
returns jsonb
language plpgsql
volatile -- the password check records failed attempts, so this cannot be stable
security definer
set search_path = ''
as $$
begin
  if not private.dev_allowed(p_password) then
    return jsonb_build_object('ok', false);
  end if;
  if p_from is null or p_to is null or p_to <= p_from or p_to - p_from > interval '31 days' then
    return jsonb_build_object('ok', false, 'error', 'use a window of at most 31 days');
  end if;
  if not exists (select 1 from public.restaurants r where r.id = p_restaurant_id) then
    return jsonb_build_object('ok', false, 'error', 'no such cafe');
  end if;

  return jsonb_build_object(
    'ok', true,
    'payments', coalesce((
      select jsonb_agg(to_jsonb(p))
      from (
        select
          pay.id,
          pay.paid_at,
          pay.total_due,
          pay.cash_received,
          pay.change_due,
          pay.shift_display_number,
          pay.monthly_display_number,
          ord.service_type,
          tbl.number as table_number,
          coalesce((
            select jsonb_agg(jsonb_build_object(
              'name', line.name,
              'qty', line.qty,
              'unit_price', line.unit_price
            ))
            from public.order_lines line
            where line.order_id = pay.order_id
          ), '[]'::jsonb) as lines
        from public.payments pay
        left join public.orders ord on ord.id = pay.order_id
        left join public.dining_tables tbl on tbl.id = pay.table_id
        where pay.restaurant_id = p_restaurant_id
          and pay.paid_at >= p_from and pay.paid_at < p_to
        order by pay.paid_at, pay.id
      ) p
    ), '[]'::jsonb),
    'expenses', coalesce((
      select jsonb_agg(to_jsonb(e))
      from (
        select id, created_at, amount, description, kind, paid_to_cafe
        from public.shift_expenses
        where restaurant_id = p_restaurant_id
          and created_at >= p_from and created_at < p_to
        order by created_at, id
      ) e
    ), '[]'::jsonb)
  );
end;
$$;

revoke all on function public.vendor_export_logs(text, uuid, timestamptz, timestamptz) from public;
grant execute on function public.vendor_export_logs(text, uuid, timestamptz, timestamptz) to anon, authenticated;
