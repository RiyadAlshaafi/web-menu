-- The "guests can only order while a cashier is online" rule is a per-cafe switch, off by default,
-- so nothing changes for a cafe until its admin turns it on (Settings) after the tills are updated.
-- Cashier devices on the old version don't report in, so turning it on too early would stop guests ordering.

alter table public.restaurants add column if not exists require_cashier_online boolean not null default false;

create or replace function public.guest_ordering_open(p_qr_slug text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((
    select (not r.require_cashier_online) or private.cashier_online(t.restaurant_id)
    from public.dining_tables t
    join public.restaurants r on r.id = t.restaurant_id
    where t.qr_slug = btrim(p_qr_slug) and not t.archived
    limit 1
  ), false);
$$;

create or replace function private.guest_needs_cashier()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if private.is_guest()
     and exists (select 1 from public.restaurants r where r.id = new.restaurant_id and r.require_cashier_online)
     and not private.cashier_online(new.restaurant_id) then
    raise exception 'cashier_offline' using errcode = 'P0001';
  end if;
  return new;
end;
$$;
