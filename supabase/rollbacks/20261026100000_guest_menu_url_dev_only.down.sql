-- Undoes 20261026100000_guest_menu_url_dev_only.sql: admins can change the guest menu address
-- again. The function bodies are put back as 20261020120000_slot_suspension.sql and
-- 20261007100000_multi_cafe_slots.sql left them. No column changes.

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

create or replace function public.dev_list_slots(p_password text)
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
    'slots', coalesce((
      select jsonb_agg(jsonb_build_object(
        'slot', r.slot,
        'id', r.id,
        'slug', r.slug,
        'name', r.name,
        'active', r.active,
        'has_admin', exists (select 1 from public.profiles p where p.restaurant_id = r.id),
        'has_setup_code', exists (select 1 from public.restaurant_setup s where s.restaurant_id = r.id)
      ) order by r.slot)
      from public.restaurants r
      where r.slot is not null
    ), '[]'::jsonb)
  );
end;
$$;

drop function if exists public.dev_set_public_menu_url(text, uuid, text);
