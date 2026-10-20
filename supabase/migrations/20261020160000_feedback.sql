-- Feedback from cafes to the vendor. A signed-in cafe (admin or cashier) sends a short message
-- from the app's Settings; the vendor reads and files it in the dashboard (developer password).
--
-- A cafe can send at most 10 messages per day, each up to 2000 characters. A suspended cafe
-- cannot send (its sessions are dead). Nobody but the vendor functions can read the table.

create table if not exists public.feedback (
  id uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null references public.restaurants (id) on delete cascade,
  kind text not null check (kind in ('problem', 'idea', 'question', 'other')),
  message text not null check (char_length(message) between 1 and 2000),
  app_version text,
  sender text not null default '' check (sender in ('', 'admin', 'cashier')),
  status text not null default 'new' check (status in ('new', 'read', 'done')),
  created_at timestamptz not null default now()
);
create index if not exists feedback_status_idx on public.feedback (status, created_at desc);
create index if not exists feedback_restaurant_idx on public.feedback (restaurant_id, created_at desc);

alter table public.feedback enable row level security;
revoke all on public.feedback from anon, authenticated;

-- ------------------------------------------------ sending (from the cafe app)
create or replace function public.send_feedback(p_kind text, p_message text, p_app_version text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  rid uuid := private.actor_restaurant_id();
  msg text := btrim(coalesce(p_message, ''));
  v text := nullif(left(btrim(coalesce(p_app_version, '')), 32), '');
begin
  if rid is null then
    return jsonb_build_object('ok', false, 'error', 'session expired, sign in again');
  end if;
  if p_kind is null or p_kind not in ('problem', 'idea', 'question', 'other') then
    return jsonb_build_object('ok', false, 'error', 'bad kind');
  end if;
  if msg = '' then
    return jsonb_build_object('ok', false, 'error', 'message required');
  end if;
  if char_length(msg) > 2000 then
    return jsonb_build_object('ok', false, 'error', 'message too long');
  end if;
  if (select count(*) from public.feedback f
      where f.restaurant_id = rid and f.created_at > now() - interval '24 hours') >= 10 then
    return jsonb_build_object('ok', false, 'error', 'too many today');
  end if;

  insert into public.feedback (restaurant_id, kind, message, app_version, sender)
  values (rid, p_kind, msg, v, case when private.current_restaurant_id() is not null then 'admin' else 'cashier' end);
  return jsonb_build_object('ok', true);
end;
$$;

revoke all on function public.send_feedback(text, text, text) from public;
grant execute on function public.send_feedback(text, text, text) to anon, authenticated;

-- ------------------------------------------------ reading (vendor dashboard)
create or replace function public.vendor_feedback(p_password text, p_status text default null, p_limit integer default 100)
returns jsonb
language plpgsql
volatile -- the password check records failed attempts, so this cannot be stable
security definer
set search_path = ''
as $$
declare
  cap integer := least(greatest(coalesce(p_limit, 100), 1), 300);
begin
  if not private.dev_allowed(p_password) then
    return jsonb_build_object('ok', false);
  end if;
  if p_status is not null and p_status not in ('new', 'read', 'done') then
    return jsonb_build_object('ok', false, 'error', 'bad status');
  end if;

  return jsonb_build_object(
    'ok', true,
    'new_count', (select count(*) from public.feedback f where f.status = 'new'),
    'items', coalesce((
      select jsonb_agg(i order by i.created_at desc)
      from (
        select
          f.id,
          f.kind,
          f.message,
          f.app_version,
          f.sender,
          f.status,
          f.created_at,
          r.name as cafe_name,
          r.slot as cafe_slot
        from public.feedback f
        join public.restaurants r on r.id = f.restaurant_id
        where p_status is null or f.status = p_status
        order by f.created_at desc
        limit cap
      ) i
    ), '[]'::jsonb)
  );
end;
$$;

revoke all on function public.vendor_feedback(text, text, integer) from public;
grant execute on function public.vendor_feedback(text, text, integer) to anon, authenticated;

create or replace function public.vendor_set_feedback_status(p_password text, p_id uuid, p_status text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not private.dev_allowed(p_password) then
    return jsonb_build_object('ok', false);
  end if;
  if p_status is null or p_status not in ('new', 'read', 'done') then
    return jsonb_build_object('ok', false, 'error', 'bad status');
  end if;
  update public.feedback set status = p_status where id = p_id;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'no such message');
  end if;
  return jsonb_build_object('ok', true, 'status', p_status);
end;
$$;

revoke all on function public.vendor_set_feedback_status(text, uuid, text) from public;
grant execute on function public.vendor_set_feedback_status(text, uuid, text) to anon, authenticated;

-- ------------------------------------------------ the fleet list carries the unread count
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
    'new_feedback', (select count(*) from public.feedback f where f.status = 'new'),
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
