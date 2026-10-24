-- The guest menu address (restaurants.public_menu_url, used in table QR codes) is set by the
-- developer only. A signed-in admin can no longer change it; the developer sets it with
-- dev_set_public_menu_url (developer password). The SQL editor still can.
--
-- Empty means "not set": the app then uses its default guest address, so the QR codes of a
-- new cafe work before the developer sets one.
--
-- Old app versions keep working: "Save cafe info" sends the address unchanged, which passes.
-- Only a changed address is refused. Safe to run twice.

-- ------------------------------------------------ admins can't change the guest address
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
  -- The flag is set only inside dev_set_public_menu_url, after the password check.
  if auth.uid() is not null
    and new.public_menu_url is distinct from old.public_menu_url
    and coalesce(current_setting('app.dev_menu_url', true), '') <> 'on'
  then
    raise exception 'the guest menu address can only be changed from the dev tools';
  end if;
  return new;
end;
$$;

-- ------------------------------------------------ the developer sets it
-- p_url is a plain https:// address with no path (the guest app serves /t/<slug> at its root),
-- or empty to fall back to the app's default.
create or replace function public.dev_set_public_menu_url(p_password text, p_restaurant_id uuid, p_url text)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_url text := regexp_replace(btrim(coalesce(p_url, '')), '/+$', '');
  v_rows integer;
begin
  if not private.dev_allowed(p_password) then
    return jsonb_build_object('ok', false);
  end if;
  if v_url <> '' and (length(v_url) > 200 or v_url !~ '^https://[A-Za-z0-9.-]+(:[0-9]+)?$') then
    return jsonb_build_object('ok', false, 'error', 'The address must look like https://menu.example.com');
  end if;
  perform set_config('app.dev_menu_url', 'on', true);
  update public.restaurants set public_menu_url = v_url where id = p_restaurant_id;
  get diagnostics v_rows = row_count;
  perform set_config('app.dev_menu_url', '', true);
  if v_rows = 0 then
    return jsonb_build_object('ok', false, 'error', 'no such cafe');
  end if;
  return jsonb_build_object('ok', true, 'public_menu_url', v_url);
end;
$$;

revoke all on function public.dev_set_public_menu_url(text, uuid, text) from public;
grant execute on function public.dev_set_public_menu_url(text, uuid, text) to anon, authenticated;

-- ------------------------------------------------ the dev screen shows the current address
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
        'public_menu_url', r.public_menu_url,
        'has_admin', exists (select 1 from public.profiles p where p.restaurant_id = r.id),
        'has_setup_code', exists (select 1 from public.restaurant_setup s where s.restaurant_id = r.id)
      ) order by r.slot)
      from public.restaurants r
      where r.slot is not null
    ), '[]'::jsonb)
  );
end;
$$;
