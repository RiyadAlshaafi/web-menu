-- Counter takeout is placed by a signed-in cashier, so the guest GPS
-- check does not apply to that session.

create or replace function private.order_location_error(
  p_restaurant_id uuid,
  p_lat double precision,
  p_lng double precision,
  p_accuracy_m double precision
)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  enabled boolean;
  radius_m integer;
  cafe_lat double precision;
  cafe_lng double precision;
  distance double precision;
  allowance double precision;
begin
  if private.cashier_restaurant_id() is not null then
    return null;
  end if;
  select location_check_enabled, location_radius_m, location_lat, location_lng
    into enabled, radius_m, cafe_lat, cafe_lng
  from public.restaurants
  where id = p_restaurant_id;
  if not found or coalesce(enabled, false) = false or cafe_lat is null or cafe_lng is null then
    return null;
  end if;
  if p_lat is null or p_lng is null then
    return 'location_required';
  end if;
  distance := private.distance_m(cafe_lat, cafe_lng, p_lat, p_lng);
  allowance := least(coalesce(p_accuracy_m, 0), 50);
  if distance - allowance <= radius_m then
    return null;
  end if;
  return 'too_far';
end;
$$;
