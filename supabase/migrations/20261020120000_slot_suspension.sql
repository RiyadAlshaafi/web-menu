-- Stop a cafe slot that has not paid. A suspended slot is blocked everywhere on the server:
--  * cashier sign-in is refused with a clear message, and existing sessions stop working,
--  * the admin account sees nothing (the cafe lookups used by every policy return null),
--  * guests scanning a QR code get "table not found", and guest ordering is closed.
-- Nothing is deleted; setting suspended_at back to null (vendor_set_suspended) restores it.
--
-- Only the vendor dashboard changes this, through vendor_set_suspended (developer password).
-- Tills that are offline keep working on their own saved data until they next reach the server.

alter table public.restaurants add column if not exists suspended_at timestamptz;

-- ------------------------------------------------ admins can't unsuspend themselves
create or replace function private.protect_restaurant_slot()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is not null and (
    new.slot is distinct from old.slot
    or new.slug is distinct from old.slug
    or new.active is distinct from old.active
    or new.suspended_at is distinct from old.suspended_at
  ) then
    raise exception 'slot, slug, active and suspension can only be changed from the dev tools';
  end if;
  return new;
end;
$$;

-- ------------------------------------------------ who is the cafe? Not a suspended one.
create or replace function private.current_restaurant_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select p.restaurant_id
  from public.profiles p
  join public.restaurants r on r.id = p.restaurant_id
  where p.id = auth.uid() and r.suspended_at is null;
$$;

create or replace function private.cashier_restaurant_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select s.restaurant_id
  from public.cashier_sessions s
  join public.restaurants r on r.id = s.restaurant_id
  where s.token_hash = encode(extensions.digest(coalesce(private.header('x-cashier-token'), ''), 'sha256'), 'hex')
    and s.expires_at > now()
    and r.suspended_at is null
  limit 1;
$$;

create or replace function private.session_cashier_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select s.cashier_id
  from public.cashier_sessions s
  join public.restaurants r on r.id = s.restaurant_id
  where s.token_hash = encode(extensions.digest(coalesce(private.header('x-cashier-token'), ''), 'sha256'), 'hex')
    and s.expires_at > now()
    and r.suspended_at is null
  limit 1;
$$;

-- ------------------------------------------------ guests
create or replace function private.guest_restaurant_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select t.restaurant_id
  from public.dining_tables t
  join public.restaurants r on r.id = t.restaurant_id
  where t.qr_slug = private.header('x-qr-slug') and not t.archived and r.suspended_at is null
  limit 1;
$$;

create or replace function private.guest_table_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select t.id
  from public.dining_tables t
  join public.restaurants r on r.id = t.restaurant_id
  where t.qr_slug = private.header('x-qr-slug') and not t.archived and r.suspended_at is null
  limit 1;
$$;

create or replace function private.table_for_slug(p_qr_slug text)
returns public.dining_tables
language sql
stable
security definer
set search_path = ''
as $$
  select t.*
  from public.dining_tables t
  join public.restaurants r on r.id = t.restaurant_id
  where t.qr_slug = nullif(btrim(coalesce(p_qr_slug, '')), '')
    and not t.archived
    and r.suspended_at is null
  limit 1;
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
    join public.restaurants r on r.id = p.restaurant_id
    where p.restaurant_id = p_restaurant_id
      and p.last_seen > now() - interval '75 seconds'
      and s.expires_at > now()
      and r.suspended_at is null
  );
$$;

-- ------------------------------------------------ cashier sign-in
create or replace function public.cashier_login(p_cashier_id uuid, p_pin text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  c public.cashiers%rowtype;
  raw_token text;
  lock_for interval;
  cafe_key text;
begin
  select * into c from public.cashiers where id = p_cashier_id and active for update;
  if not found then
    return jsonb_build_object('ok', false);
  end if;
  if exists (select 1 from public.restaurants r where r.id = c.restaurant_id and r.suspended_at is not null) then
    return jsonb_build_object(
      'ok', false,
      'code', 'suspended',
      'error', 'This cafe''s service is suspended. Please contact your provider.'
    );
  end if;
  if c.pin_locked_until > now() then
    return jsonb_build_object(
      'ok', false,
      'code', 'locked',
      'retry_after_seconds', ceil(extract(epoch from c.pin_locked_until - now()))::int
    );
  end if;
  cafe_key := 'pin_miss:' || c.restaurant_id::text;
  if private.rate_count(cafe_key, 0) >= 30 then
    return jsonb_build_object('ok', false, 'code', 'locked', 'retry_after_seconds', 60);
  end if;
  if c.pin_hash is distinct from extensions.crypt(coalesce(p_pin, ''), c.pin_hash) then
    perform private.rate_count(cafe_key, 1);
    -- Misses fade only after a full day without one; a correct PIN doesn't clear them.
    c.failed_pin_attempts := case
      when c.last_failed_pin_at is null or c.last_failed_pin_at < now() - interval '24 hours' then 1
      else c.failed_pin_attempts + 1
    end;
    if c.failed_pin_attempts % 5 = 0 then
      lock_for := least(
        interval '15 minutes' * power(2, c.failed_pin_attempts / 5 - 1),
        interval '24 hours'
      );
      update public.cashiers
        set failed_pin_attempts = c.failed_pin_attempts,
            last_failed_pin_at = now(),
            pin_locked_until = now() + lock_for
        where id = c.id;
      return jsonb_build_object(
        'ok', false,
        'code', 'locked',
        'retry_after_seconds', extract(epoch from lock_for)::int
      );
    end if;
    update public.cashiers
      set failed_pin_attempts = c.failed_pin_attempts, last_failed_pin_at = now()
      where id = c.id;
    return jsonb_build_object('ok', false);
  end if;
  update public.cashiers set pin_locked_until = null where id = c.id and pin_locked_until is not null;
  raw_token := encode(extensions.gen_random_bytes(32), 'hex');
  insert into public.cashier_sessions (cashier_id, restaurant_id, token_hash, expires_at)
  values (
    c.id,
    c.restaurant_id,
    encode(extensions.digest(raw_token, 'sha256'), 'hex'),
    now() + interval '12 hours'
  );
  return jsonb_build_object(
    'ok', true,
    'token', raw_token,
    'restaurant_id', c.restaurant_id,
    'cashier_id', c.id,
    'name', c.name,
    'initials', c.initials
  );
end;
$$;

-- ------------------------------------------------ heartbeats (the till signs out when told)
create or replace function public.cashier_heartbeat()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  sess public.cashier_sessions%rowtype;
begin
  select s.* into sess from public.cashier_sessions s
  join public.restaurants r on r.id = s.restaurant_id
  where s.token_hash = encode(extensions.digest(coalesce(private.header('x-cashier-token'), ''), 'sha256'), 'hex')
    and s.expires_at > now()
    and r.suspended_at is null
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
  select s.* into sess from public.cashier_sessions s
  join public.restaurants r on r.id = s.restaurant_id
  where s.token_hash = encode(extensions.digest(coalesce(private.header('x-cashier-token'), ''), 'sha256'), 'hex')
    and s.expires_at > now()
    and r.suspended_at is null
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

-- ------------------------------------------------ vendor switch
create or replace function public.vendor_set_suspended(p_password text, p_restaurant_id uuid, p_suspended boolean)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not private.dev_allowed(p_password) then
    return jsonb_build_object('ok', false);
  end if;
  update public.restaurants
  set suspended_at = case when p_suspended then coalesce(suspended_at, now()) else null end
  where id = p_restaurant_id;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'no such cafe');
  end if;
  if p_suspended then
    -- Signed-in tills are signed out at once (their sessions end, which also clears presence).
    delete from public.cashier_sessions where restaurant_id = p_restaurant_id;
  end if;
  return jsonb_build_object('ok', true, 'suspended', p_suspended);
end;
$$;

revoke all on function public.vendor_set_suspended(text, uuid, boolean) from public;
grant execute on function public.vendor_set_suspended(text, uuid, boolean) to anon, authenticated;

-- ------------------------------------------------ fleet list shows slot and suspension
create or replace function public.vendor_fleet(p_password text)
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

  return jsonb_build_object(
    'ok', true,
    'min_app_version', coalesce((select r.min_app_version from public.app_release r where r.id), '0.0.0'),
    'cafes', coalesce((
      select jsonb_agg(c order by c.slot nulls last, c.name)
      from (
        select
          r.id,
          r.name,
          r.slot,
          r.created_at,
          r.suspended_at is not null as suspended,
          coalesce(max(p.last_seen) > now() - interval '75 seconds', false) as online,
          max(p.last_seen) as last_seen,
          (array_agg(p.app_version order by p.last_seen desc) filter (where p.app_version is not null))[1] as app_version,
          count(distinct p.session_id) filter (where p.last_seen > now() - interval '75 seconds') as tills_online
        from public.restaurants r
        left join public.cashier_presence p on p.restaurant_id = r.id
        group by r.id
      ) c
    ), '[]'::jsonb)
  );
end;
$$;
