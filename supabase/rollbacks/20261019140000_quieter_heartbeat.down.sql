-- Undoes 20261019140000_quieter_heartbeat.sql: back to the 45 second online window.

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

-- The developer screen's device list uses the same window for "online".
CREATE OR REPLACE FUNCTION public.dev_list_devices(p_password text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
$function$
;
