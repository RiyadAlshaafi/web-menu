-- Guests can always read the menu, but can only order, call staff or ask for the bill while a
-- cashier device is online. The cashier app reports in every 30 seconds; after 2 minutes of
-- silence the cafe counts as offline for guests.

create table if not exists public.cashier_presence (
  restaurant_id uuid primary key references public.restaurants(id) on delete cascade,
  last_seen timestamptz not null default now()
);
alter table public.cashier_presence enable row level security;
revoke all on public.cashier_presence from anon, authenticated;

create or replace function public.cashier_heartbeat()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  rid uuid := private.cashier_restaurant_id();
begin
  if rid is null then
    return jsonb_build_object('ok', false, 'error', 'session expired, sign in again');
  end if;
  insert into public.cashier_presence (restaurant_id, last_seen) values (rid, now())
  on conflict (restaurant_id) do update set last_seen = now();
  return jsonb_build_object('ok', true);
end;
$$;

create or replace function private.cashier_online(p_restaurant_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.cashier_presence
    where restaurant_id = p_restaurant_id and last_seen > now() - interval '2 minutes'
  );
$$;

-- For the guest page: is ordering open at this table right now?
create or replace function public.guest_ordering_open(p_qr_slug text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((
    select private.cashier_online(t.restaurant_id)
    from public.dining_tables t
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
  if private.is_guest() and not private.cashier_online(new.restaurant_id) then
    raise exception 'cashier_offline' using errcode = 'P0001';
  end if;
  return new;
end;
$$;

-- named to run after the existing stamp_* triggers, which fill restaurant_id
drop trigger if exists zz_guest_needs_cashier on public.order_lines;
create trigger zz_guest_needs_cashier before insert on public.order_lines
  for each row execute function private.guest_needs_cashier();
drop trigger if exists zz_guest_needs_cashier on public.staff_calls;
create trigger zz_guest_needs_cashier before insert on public.staff_calls
  for each row execute function private.guest_needs_cashier();
drop trigger if exists zz_guest_needs_cashier on public.cart_lines;
create trigger zz_guest_needs_cashier before insert on public.cart_lines
  for each row execute function private.guest_needs_cashier();

revoke execute on function public.cashier_heartbeat() from public;
revoke execute on function public.guest_ordering_open(text) from public;
grant execute on function public.cashier_heartbeat() to anon, authenticated;
grant execute on function public.guest_ordering_open(text) to anon, authenticated;
