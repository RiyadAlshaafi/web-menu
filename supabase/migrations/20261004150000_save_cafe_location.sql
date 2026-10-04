-- Admin location save goes through the signed-in restaurant, and guests
-- cannot read the raw coordinates.

revoke select (location_lat, location_lng) on table public.restaurants from anon;

create or replace function public.save_cafe_location(
  p_enabled boolean,
  p_lat double precision,
  p_lng double precision,
  p_radius_m integer
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  rid uuid := private.current_restaurant_id();
begin
  if rid is null then
    return jsonb_build_object('ok', false, 'error', 'sign in first');
  end if;
  if p_radius_m is null or p_radius_m < 30 or p_radius_m > 500 then
    return jsonb_build_object('ok', false, 'error', 'invalid radius');
  end if;
  if coalesce(p_enabled, false) and (p_lat is null or p_lng is null or p_lat < -90 or p_lat > 90 or p_lng < -180 or p_lng > 180) then
    return jsonb_build_object('ok', false, 'error', 'need point');
  end if;
  update public.restaurants
  set location_check_enabled = coalesce(p_enabled, false),
      location_lat = p_lat,
      location_lng = p_lng,
      location_radius_m = p_radius_m
  where id = rid;
  return jsonb_build_object('ok', true);
end;
$$;

revoke all on function public.save_cafe_location(boolean, double precision, double precision, integer) from public;
grant execute on function public.save_cafe_location(boolean, double precision, double precision, integer) to authenticated;
