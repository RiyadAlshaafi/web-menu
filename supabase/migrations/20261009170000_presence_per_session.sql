-- Guest ordering follows the cashier devices that are signed in and reporting in.
-- Presence is kept per signed-in device (cashier session) instead of per cafe, so
--  * signing out ends that device's presence at once (the session row is deleted and takes the
--    presence row with it),
--  * one device going quiet doesn't hide another that is still online, and
--  * the quiet period is short: 45 seconds without a heartbeat (devices report every 15 s).

drop table if exists public.cashier_presence;
create table public.cashier_presence (
  session_id uuid primary key references public.cashier_sessions(id) on delete cascade,
  restaurant_id uuid not null references public.restaurants(id) on delete cascade,
  last_seen timestamptz not null default now()
);
create index cashier_presence_restaurant_idx on public.cashier_presence (restaurant_id, last_seen desc);
alter table public.cashier_presence enable row level security;
revoke all on public.cashier_presence from anon, authenticated;

create or replace function public.cashier_heartbeat()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  sess public.cashier_sessions%rowtype;
begin
  select * into sess from public.cashier_sessions s
  where s.token_hash = encode(extensions.digest(coalesce(private.header('x-cashier-token'), ''), 'sha256'), 'hex')
    and s.expires_at > now()
  limit 1;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'session expired, sign in again');
  end if;
  insert into public.cashier_presence (session_id, restaurant_id, last_seen)
  values (sess.id, sess.restaurant_id, now())
  on conflict (session_id) do update set last_seen = now();
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
    select 1
    from public.cashier_presence p
    join public.cashier_sessions s on s.id = p.session_id
    where p.restaurant_id = p_restaurant_id
      and p.last_seen > now() - interval '45 seconds'
      and s.expires_at > now()
  );
$$;

revoke execute on function public.cashier_heartbeat() from public;
grant execute on function public.cashier_heartbeat() to anon, authenticated;
