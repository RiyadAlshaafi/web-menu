-- Vendor fleet view: one row per cafe for the private vendor dashboard (separate desktop app,
-- never part of the customer installer). Read-only and gated by the developer password, like
-- the other dev_* functions. It deliberately reports nothing about sales or orders.
--
-- Status comes from cashier_presence (a till reports every 30 s): a cafe is online when any
-- of its tills was seen in the last 75 seconds.

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
      select jsonb_agg(c order by c.name)
      from (
        select
          r.id,
          r.name,
          r.created_at,
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

revoke all on function public.vendor_fleet(text) from public;
grant execute on function public.vendor_fleet(text) to anon, authenticated;
