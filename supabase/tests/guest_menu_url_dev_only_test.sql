-- Checks 20261026100000_guest_menu_url_dev_only.sql: an admin cannot change the guest menu
-- address, but the rest of the cafe info still saves (also when an old app sends the address
-- unchanged); the developer sets it with the developer password, including back to empty
-- (empty = the app's default guest address); a till can't change it.
-- Run by tool/test_db.sh. Everything is rolled back; any failed check aborts with its message.

begin;

do $test$
declare
  r jsonb;
  rid uuid := (select id from public.restaurants where slot = 4);
  admin_id uuid;
  cid uuid;
  n integer;
  blocked boolean;
  url text;
begin
  insert into public.dev_access (password_hash)
  values (extensions.crypt('menu-url-pw', extensions.gen_salt('bf', 4)));
  alter table auth.users disable trigger user;
  insert into auth.users (email) values ('admin@menu-url.test') returning id into admin_id;
  alter table auth.users enable trigger user;
  insert into public.profiles (id, restaurant_id) values (admin_id, rid);
  update public.restaurants set public_menu_url = '' where id = rid;
  insert into public.cashiers (restaurant_id, name, initials, pin_hash) values (rid, 'M', 'M', 'x') returning id into cid;
  insert into public.cashier_sessions (cashier_id, restaurant_id, token_hash, expires_at)
    values (cid, rid, encode(extensions.digest('menu-url-token', 'sha256'), 'hex'), now() + interval '1 hour');

  -- ---------------------------------------------------------------- a new cafe starts empty
  select public_menu_url into url from public.restaurants where id = rid;
  assert url = '', 'a new cafe has no address of its own, so the app uses its default; got ' || url;

  -- ---------------------------------------------------------------- the admin can't change it
  perform set_config('request.jwt.claim.sub', admin_id::text, true);
  execute 'set local role authenticated';
  blocked := false;
  begin
    update public.restaurants set public_menu_url = 'https://evil.example.com' where id = rid;
  exception when raise_exception then blocked := true;
  end;
  assert blocked, 'an admin must not change the guest menu address';

  -- the rest of the cafe info still saves: the new app leaves the address out ...
  update public.restaurants set name = 'Menu URL Cafe', logo_url = '' where id = rid;
  get diagnostics n = row_count;
  assert n = 1, 'the admin still saves the cafe name';
  -- ... and an old app sends it unchanged
  update public.restaurants set name = 'Menu URL Cafe 2', public_menu_url = '' where id = rid;
  get diagnostics n = row_count;
  assert n = 1, 'an old app saving the unchanged address still works';
  execute 'reset role';
  select public_menu_url into url from public.restaurants where id = rid;
  assert url = '', 'the address is unchanged after the admin saves, got ' || url;
  assert (select name from public.restaurants where id = rid) = 'Menu URL Cafe 2', 'the name was saved';

  -- ---------------------------------------------------------------- the developer sets it
  r := public.dev_set_public_menu_url('wrong', rid, 'https://menu.example.com');
  assert not (r->>'ok')::boolean, 'a wrong password must not set the address: ' || r::text;

  r := public.dev_set_public_menu_url('menu-url-pw', rid, 'menu.example.com');
  assert not (r->>'ok')::boolean, 'an address without https:// is refused: ' || r::text;
  r := public.dev_set_public_menu_url('menu-url-pw', rid, 'https://menu.example.com/t/x');
  assert not (r->>'ok')::boolean, 'an address with a path is refused: ' || r::text;

  -- from the dev screen while an admin is signed in on that device
  r := public.dev_set_public_menu_url('menu-url-pw', rid, ' https://menu.example.com/ ');
  assert (r->>'ok')::boolean, 'the developer sets the address: ' || r::text;
  select public_menu_url into url from public.restaurants where id = rid;
  assert url = 'https://menu.example.com', 'the address is trimmed and saved, got ' || url;

  -- the developer's permission ends with the call
  execute 'set local role authenticated';
  blocked := false;
  begin
    update public.restaurants set public_menu_url = 'https://evil.example.com' where id = rid;
  exception when raise_exception then blocked := true;
  end;
  assert blocked, 'after the dev call the admin is still blocked';
  execute 'reset role';

  r := public.dev_list_slots('menu-url-pw');
  assert (select s->>'public_menu_url' from jsonb_array_elements(r->'slots') s where (s->>'slot')::int = 4)
    = 'https://menu.example.com', 'the dev screen sees the address: ' || r::text;

  -- back to empty, so the app's default applies again; signed out works too
  perform set_config('request.jwt.claim.sub', '', true);
  r := public.dev_set_public_menu_url('menu-url-pw', rid, '');
  assert (r->>'ok')::boolean, 'the developer clears the address: ' || r::text;
  select public_menu_url into url from public.restaurants where id = rid;
  assert url = '', 'an empty address is saved as empty, got ' || url;

  r := public.dev_set_public_menu_url('menu-url-pw', gen_random_uuid(), 'https://menu.example.com');
  assert not (r->>'ok')::boolean, 'an unknown cafe is refused: ' || r::text;

  -- ---------------------------------------------------------------- a till can't change it
  perform set_config('request.headers', json_build_object('x-cashier-token', 'menu-url-token')::text, true);
  execute 'set local role anon';
  update public.restaurants set public_menu_url = 'https://evil.example.com' where id = rid;
  get diagnostics n = row_count;
  assert n = 0, 'a till must not change the address';
  execute 'reset role';

  raise notice 'guest_menu_url_dev_only_test: all checks passed';
end $test$;

rollback;
