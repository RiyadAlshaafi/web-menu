-- Undoes 20261027160000_cashier_back_ping.sql: the heartbeat sends no ping again.

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

revoke all on function public.cashier_heartbeat_v2(text) from public;
grant execute on function public.cashier_heartbeat_v2(text) to anon, authenticated;
