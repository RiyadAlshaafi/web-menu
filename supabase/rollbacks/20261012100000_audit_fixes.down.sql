-- Undoes 20261012100000_audit_fixes.sql. Run it only if that migration must be taken back.

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron')
     and exists (select 1 from cron.job where jobname = 'purge-expired-cashier-sessions') then
    perform cron.unschedule('purge-expired-cashier-sessions');
  end if;
end $$;

drop function if exists public.assign_shift_order_numbers(uuid[]);

create or replace function public.list_pos_cashiers(p_restaurant_id uuid default null)
returns table (id uuid, name text, initials text)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  rid uuid := p_restaurant_id;
begin
  if rid is null then
    select r.id into rid from public.restaurants r where r.slot = 1;
  end if;
  if rid is null then
    return;
  end if;
  return query
    select c.id, c.name, c.initials
    from public.cashiers c
    where c.restaurant_id = rid and c.active;
end;
$$;

create or replace function public.has_any_admin(p_restaurant_id uuid default null)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.profiles p
    where p_restaurant_id is null or p.restaurant_id = p_restaurant_id
  );
$$;

alter table public.restaurants alter column service_charge_rate set default 0.10;
-- public_menu_url predates this migration (restaurant_branding), so it stays;
-- the addresses filled in here are left as they are.
