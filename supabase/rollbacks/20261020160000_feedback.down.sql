-- Undoes 20261020160000_feedback.sql: feedback and its functions are removed, and the fleet list
-- goes back to the version without the unread count.
create or replace function public.vendor_fleet(p_password text)
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

drop function if exists public.vendor_set_feedback_status(text, uuid, text);
drop function if exists public.vendor_feedback(text, text, integer);
drop function if exists public.send_feedback(text, text, text);
drop table if exists public.feedback;
