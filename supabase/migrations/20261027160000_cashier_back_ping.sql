-- Guest phones learn at once that a cashier is back. The heartbeat now sends one live ping to
-- the cafe topic when the cafe goes from offline to online; guest pages already reload their
-- status on that ping. Before, nothing pinged, so a phone stayed "ordering paused" until its
-- 30-second status check. A heartbeat while already online sends nothing, as before.
-- Rollback: supabase/rollbacks/20261027160000_cashier_back_ping.down.sql

create or replace function public.cashier_heartbeat_v2(p_app_version text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  sess public.cashier_sessions%rowtype;
  v text := nullif(left(btrim(coalesce(p_app_version, '')), 32), '');
  was_online boolean;
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
  was_online := private.cashier_online(sess.restaurant_id);
  insert into public.cashier_presence (session_id, restaurant_id, last_seen, app_version)
  values (sess.id, sess.restaurant_id, now(), v)
  on conflict (session_id) do update set last_seen = now(), app_version = excluded.app_version;
  -- The cafe just came back online: tell guest phones at once instead of at their next check.
  -- Only on that change, so the usual heartbeat sends nothing.
  if not was_online then
    begin
      perform realtime.send(jsonb_build_object('table', 'cashier_presence'), 'change', 'cafe:' || sess.restaurant_id, false);
    exception when others then
      raise warning 'cashier back ping failed: %', sqlerrm;
    end;
  end if;
  return jsonb_build_object(
    'ok', true,
    'min_app_version', coalesce((select r.min_app_version from public.app_release r where r.id), '0.0.0')
  );
end;
$$;

revoke all on function public.cashier_heartbeat_v2(text) from public;
grant execute on function public.cashier_heartbeat_v2(text) to anon, authenticated;
