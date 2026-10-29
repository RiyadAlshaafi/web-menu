-- Checks 20261029100000_guest_menu_layout.sql: a cafe starts on the list layout, guest_menu hands
-- the layout to the guest page, the cafe's admin can switch to the photo grid, and nothing but
-- 'list' or 'grid' is stored.
-- Run by tool/test_db.sh. Everything is rolled back; any failed check aborts with its message.

begin;

do $test$
declare
  r jsonb;
  rid uuid;
  admin_id uuid;
  blocked boolean;
begin
  insert into public.restaurants (name) values ('layout cafe') returning id into rid;
  insert into public.dining_tables (restaurant_id, number, qr_slug) values (rid, 'L1', 'layout-slug-1');
  alter table auth.users disable trigger user;
  insert into auth.users (email) values ('admin@menu-layout.test') returning id into admin_id;
  alter table auth.users enable trigger user;
  insert into public.profiles (id, restaurant_id) values (admin_id, rid);

  -- ---------------------------------------------------------------- a new cafe uses the list
  perform set_config('request.headers', '{}', true);
  execute 'set local role anon';
  r := public.guest_menu('layout-slug-1');
  assert r->'cafe'->>'menu_layout' = 'list', 'a new cafe shows the list: ' || r::text;
  execute 'reset role';

  -- ---------------------------------------------------------------- the admin picks the grid
  perform set_config('request.jwt.claim.sub', admin_id::text, true);
  execute 'set local role authenticated';
  update public.restaurants set guest_menu_layout = 'grid' where id = rid;
  execute 'reset role';

  execute 'set local role anon';
  r := public.guest_menu('layout-slug-1');
  assert r->'cafe'->>'menu_layout' = 'grid', 'the guest page gets the grid: ' || r::text;
  execute 'reset role';

  -- ---------------------------------------------------------------- only known layouts
  blocked := false;
  begin
    update public.restaurants set guest_menu_layout = 'carousel' where id = rid;
  exception when check_violation then blocked := true;
  end;
  assert blocked, 'an unknown layout is refused';

  raise notice 'guest_menu_layout_test: all checks passed';
end;
$test$;

rollback;
