-- Fixes from docs/AUDIT_PLAN.md section 1.1. Safe to apply twice.
--
-- B-08  restaurants.public_menu_url: the address printed in table QR codes,
--       saved per cafe instead of one address built into the app.
-- B-11  has_any_admin() without a cafe no longer answers for the whole
--       database; an unlinked device is told "no admin" and asked to link.
-- B-12  new cafes start without a service charge.
-- B-13  assign_shift_order_numbers(): numbers many open orders in one call.
-- B-14  cashier_sessions are purged daily with pg_cron (when available).
-- B-15  list_pos_cashiers() without a cafe no longer lists slot 1's cashiers.

-- B-08 -----------------------------------------------------------------------
-- Cafes that already exist were printing QR codes for this address (it was
-- built into the app), so they keep it. New cafes start empty. The backfill
-- runs only when the column is first added, so a second run changes nothing.
do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'restaurants' and column_name = 'public_menu_url'
  ) then
    alter table public.restaurants add column public_menu_url text not null default '';
    update public.restaurants set public_menu_url = 'https://web-menu-akakus.vercel.app';
  end if;
end $$;

-- B-12 -----------------------------------------------------------------------
alter table public.restaurants alter column service_charge_rate set default 0;

-- B-11 -----------------------------------------------------------------------
create or replace function public.has_any_admin(p_restaurant_id uuid default null)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_restaurant_id is not null and exists (
    select 1 from public.profiles p where p.restaurant_id = p_restaurant_id
  );
$$;
grant execute on function public.has_any_admin(uuid) to anon, authenticated;

-- B-15 -----------------------------------------------------------------------
create or replace function public.list_pos_cashiers(p_restaurant_id uuid default null)
returns table (id uuid, name text, initials text)
language sql
stable
security definer
set search_path = ''
as $$
  select c.id, c.name, c.initials
  from public.cashiers c
  where p_restaurant_id is not null
    and c.restaurant_id = p_restaurant_id
    and c.active;
$$;
grant execute on function public.list_pos_cashiers(uuid) to anon, authenticated;

-- B-13 -----------------------------------------------------------------------
-- Same rules as assign_shift_order_number, one order after another, in one
-- request. Stops at the first refusal so an expired session is reported once.
create or replace function public.assign_shift_order_numbers(p_order_ids uuid[])
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  order_id uuid;
  result jsonb;
  numbered integer := 0;
begin
  if p_order_ids is null or cardinality(p_order_ids) = 0 then
    return jsonb_build_object('ok', true, 'numbered', 0);
  end if;
  if cardinality(p_order_ids) > 200 then
    return jsonb_build_object('ok', false, 'error', 'too many orders');
  end if;
  foreach order_id in array p_order_ids loop
    result := public.assign_shift_order_number(order_id);
    if coalesce((result ->> 'ok')::boolean, false) then
      numbered := numbered + 1;
    elsif result ->> 'error' = 'no open bill' then
      -- Paid or gone since the device looked; nothing to number.
      continue;
    else
      return result;
    end if;
  end loop;
  return jsonb_build_object('ok', true, 'numbered', numbered);
end;
$$;
revoke execute on function public.assign_shift_order_numbers(uuid[]) from public;
grant execute on function public.assign_shift_order_numbers(uuid[]) to anon, authenticated;

-- B-14 -----------------------------------------------------------------------
-- pg_cron exists on Supabase (free tier included) but not on a plain local
-- Postgres, so the schedule is only created where the extension is available.
do $$
begin
  if exists (select 1 from pg_available_extensions where name = 'pg_cron') then
    create extension if not exists pg_cron;
    if exists (select 1 from cron.job where jobname = 'purge-expired-cashier-sessions') then
      perform cron.unschedule('purge-expired-cashier-sessions');
    end if;
    perform cron.schedule(
      'purge-expired-cashier-sessions',
      '17 3 * * *',
      'select private.purge_expired_sessions()'
    );
  end if;
end $$;
