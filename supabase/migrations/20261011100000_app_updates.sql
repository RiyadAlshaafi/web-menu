-- Safe updates for the Windows cashier app.
-- * Each till reports its app version with its heartbeat, so the developer screen shows which
--   tills still run an old version (old columns/functions are removed only after all updated).
-- * A minimum app version: a till older than it must update before it writes anything.
-- * Before installing an update a till asks the server to confirm every receipt and expense it
--   uploaded; the update only installs when the server has them all.
-- Only additions: tills on the previous app keep working unchanged.
-- Rollback: supabase/rollbacks/20261011100000_app_updates.down.sql

-- 1. Minimum app version (one row for the whole system).
create table if not exists public.app_release (
  id boolean primary key default true check (id),
  min_app_version text not null default '0.0.0' check (min_app_version ~ '^\d+\.\d+\.\d+$'),
  updated_at timestamptz not null default now()
);
insert into public.app_release (id) values (true) on conflict (id) do nothing;
alter table public.app_release enable row level security;
revoke all on public.app_release from anon, authenticated;

create or replace function public.app_release_info()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'min_app_version', coalesce((select r.min_app_version from public.app_release r where r.id), '0.0.0')
  );
$$;
revoke all on function public.app_release_info() from public;
grant execute on function public.app_release_info() to anon, authenticated;

-- 2. Heartbeat that also records the app version of the till.
alter table public.cashier_presence add column if not exists app_version text;

create or replace function public.cashier_heartbeat_v2(p_app_version text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  sess public.cashier_sessions%rowtype;
  v text := nullif(left(btrim(coalesce(p_app_version, '')), 32), '');
begin
  select * into sess from public.cashier_sessions s
  where s.token_hash = encode(extensions.digest(coalesce(private.header('x-cashier-token'), ''), 'sha256'), 'hex')
    and s.expires_at > now()
  limit 1;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'session expired, sign in again');
  end if;
  insert into public.cashier_presence (session_id, restaurant_id, last_seen, app_version)
  values (sess.id, sess.restaurant_id, now(), v)
  on conflict (session_id) do update set last_seen = now(), app_version = excluded.app_version;
  return jsonb_build_object(
    'ok', true,
    'min_app_version', coalesce((select r.min_app_version from public.app_release r where r.id), '0.0.0')
  );
end;
$$;
revoke all on function public.cashier_heartbeat_v2(text) from public;
grant execute on function public.cashier_heartbeat_v2(text) to anon, authenticated;

-- 3. Before an update: which of these uploads does the server have, and for how much?
-- The ids are random ids the till made itself, so only that till knows them.
create or replace function public.confirm_uploads(p_ids uuid[])
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with ids as (
    select distinct unnest(coalesce(p_ids, '{}'::uuid[])) as id limit 5000
  ),
  pay as (
    select count(*)::integer as n, coalesce(sum(p.total_due), 0) as total
    from public.payments p join ids on ids.id = p.client_id
  ),
  exp as (
    select count(*)::integer as n, coalesce(sum(e.amount), 0) as total
    from public.shift_expenses e join ids on ids.id = e.client_id
  )
  select jsonb_build_object(
    'ok', true,
    'receipts', pay.n, 'receipts_total', round(pay.total, 2),
    'expenses', exp.n, 'expenses_total', round(exp.total, 2)
  )
  from pay, exp;
$$;
revoke all on function public.confirm_uploads(uuid[]) from public;
grant execute on function public.confirm_uploads(uuid[]) to anon, authenticated;

-- 4. Developer screen: app version of every till of the selected cafe, and the minimum version.
create or replace function public.dev_list_devices(p_password text)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  rid uuid := private.dev_restaurant_id();
begin
  if not private.dev_allowed(p_password) then
    return jsonb_build_object('ok', false);
  end if;
  return jsonb_build_object(
    'ok', true,
    'min_app_version', coalesce((select r.min_app_version from public.app_release r where r.id), '0.0.0'),
    'devices', coalesce((
      select jsonb_agg(jsonb_build_object(
        'cashier', coalesce(c.name, ''),
        'app_version', coalesce(p.app_version, ''),
        'last_seen', p.last_seen,
        'online', p.last_seen > now() - interval '45 seconds'
      ) order by p.last_seen desc)
      from public.cashier_presence p
      join public.cashier_sessions s on s.id = p.session_id
      left join public.cashiers c on c.id = s.cashier_id
      where p.restaurant_id = rid and s.expires_at > now()
    ), '[]'::jsonb)
  );
end;
$$;

create or replace function public.dev_set_min_app_version(p_password text, p_version text)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
begin
  if not private.dev_allowed(p_password) then
    return jsonb_build_object('ok', false);
  end if;
  if p_version is null or p_version !~ '^\d+\.\d+\.\d+$' then
    return jsonb_build_object('ok', false, 'error', 'use a version like 1.2.0');
  end if;
  update public.app_release set min_app_version = p_version, updated_at = now() where id;
  return jsonb_build_object('ok', true, 'min_app_version', p_version);
end;
$$;
revoke all on function public.dev_list_devices(text) from public;
revoke all on function public.dev_set_min_app_version(text, text) from public;
grant execute on function public.dev_list_devices(text) to anon, authenticated;
grant execute on function public.dev_set_min_app_version(text, text) to anon, authenticated;
