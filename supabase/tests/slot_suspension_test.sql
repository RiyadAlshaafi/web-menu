-- Checks 20261020120000_slot_suspension.sql: only the vendor password can suspend a slot; a
-- suspended slot refuses cashier sign-in, drops signed-in tills, hides the cafe from its admin
-- and from guests, and an admin cannot lift the suspension; unsuspending restores everything.
-- Run by tool/test_db.sh. Everything is rolled back; any failed check aborts with its message.

begin;

do $test$
declare
  r jsonb;
  rid uuid := (select id from public.restaurants where slot = 2);
  admin_rid uuid := (select id from public.restaurants where slot = 1);
  admin_id uuid := (select id from public.profiles where restaurant_id = (select id from public.restaurants where slot = 1) limit 1);
  other_rid uuid := (select id from public.restaurants where slot = 3);
  cid uuid;
  tok text;
begin
  insert into public.dev_access (password_hash)
  values (extensions.crypt('susp-pw', extensions.gen_salt('bf', 4)));
  insert into public.cashiers (restaurant_id, name, initials, pin_hash)
  values (rid, 'Ali', 'A', extensions.crypt('1234', extensions.gen_salt('bf', 4))) returning id into cid;
  insert into public.dining_tables (restaurant_id, number, qr_slug) values (rid, 'S1', 'susp-slug-1');
  insert into public.dining_tables (restaurant_id, number, qr_slug) values (other_rid, 'S1', 'susp-slug-other');

  -- ---------------------------------------------------------------- everything works at first
  r := public.cashier_login(cid, '1234');
  assert (r->>'ok')::boolean, 'sign-in works for an active slot: ' || r::text;
  tok := r->>'token';
  perform set_config('request.headers', json_build_object('x-cashier-token', tok, 'x-qr-slug', 'susp-slug-1')::text, true);
  assert private.cashier_restaurant_id() = rid, 'the session identifies the cafe';
  assert private.session_cashier_id() = cid, 'the session identifies the cashier';
  assert (public.cashier_heartbeat_v2('2.2.1')->>'ok')::boolean, 'the heartbeat works';
  assert private.cashier_online(rid), 'the till is online';
  assert (private.table_for_slug('susp-slug-1')).id is not null, 'guests find the table';
  assert private.guest_restaurant_id() = rid and private.guest_table_id() is not null, 'guest helpers work';
  perform set_config('request.jwt.claim.sub', admin_id::text, true);
  assert private.current_restaurant_id() = admin_rid, 'the admin sees their cafe';
  perform set_config('request.jwt.claim.sub', '', true); -- the vendor dashboard has no signed-in user

  -- ---------------------------------------------------------------- only the vendor can suspend
  r := public.vendor_set_suspended('wrong', rid, true);
  assert not (r->>'ok')::boolean, 'a wrong password must not suspend: ' || r::text;
  assert (select suspended_at is null from public.restaurants where id = rid), 'slot still active';

  -- ---------------------------------------------------------------- suspended: blocked everywhere
  r := public.vendor_set_suspended('susp-pw', rid, true);
  assert (r->>'ok')::boolean and (r->>'suspended')::boolean, 'suspend works: ' || r::text;
  assert not exists (select 1 from public.cashier_sessions where restaurant_id = rid), 'signed-in tills are signed out';
  assert private.cashier_restaurant_id() is null and private.session_cashier_id() is null, 'old token is dead';
  assert not (public.cashier_heartbeat_v2('2.2.1')->>'ok')::boolean, 'heartbeat is refused';
  assert not (public.cashier_heartbeat()->>'ok')::boolean, 'old heartbeat is refused';
  assert not private.cashier_online(rid), 'no till counts as online';
  assert (private.table_for_slug('susp-slug-1')).id is null, 'guests no longer find the table';
  assert private.guest_restaurant_id() is null and private.guest_table_id() is null, 'guest helpers are blocked';
  r := public.cashier_login(cid, '1234');
  assert not (r->>'ok')::boolean and r->>'code' = 'suspended', 'sign-in is refused: ' || r::text;
  assert r->>'error' like '%suspended%', 'the cashier is told why: ' || r::text;
  assert not exists (select 1 from public.cashier_sessions where restaurant_id = rid), 'no session was created';

  -- another slot is untouched
  assert (private.table_for_slug('susp-slug-other')).id is not null, 'other slots keep working';

  -- ---------------------------------------------------------------- admin of a suspended slot
  r := public.vendor_set_suspended('susp-pw', admin_rid, true);
  assert (r->>'ok')::boolean, 'suspend slot 1: ' || r::text;
  perform set_config('request.jwt.claim.sub', admin_id::text, true);
  assert private.current_restaurant_id() is null, 'the admin sees nothing while suspended';

  begin
    execute 'set local role authenticated';
    update public.restaurants set suspended_at = null where id = admin_rid;
  exception when others then
    null; -- refused by the trigger; either way it must not have changed
  end;
  execute 'reset role';
  assert (select suspended_at is not null from public.restaurants where id = admin_rid),
    'an admin cannot lift the suspension';
  perform set_config('request.jwt.claim.sub', '', true);

  -- ---------------------------------------------------------------- lifted: back to normal
  r := public.vendor_set_suspended('susp-pw', rid, false);
  assert (r->>'ok')::boolean and not (r->>'suspended')::boolean, 'unsuspend works: ' || r::text;
  r := public.vendor_set_suspended('susp-pw', admin_rid, false);
  perform set_config('request.jwt.claim.sub', admin_id::text, true);
  assert private.current_restaurant_id() = admin_rid, 'the admin sees their cafe again';
  perform set_config('request.jwt.claim.sub', '', true);
  assert (private.table_for_slug('susp-slug-1')).id is not null, 'guests find the table again';
  r := public.cashier_login(cid, '1234');
  assert (r->>'ok')::boolean, 'sign-in works again: ' || r::text;

  -- ---------------------------------------------------------------- a live session dies by itself
  tok := r->>'token';
  perform set_config('request.headers', json_build_object('x-cashier-token', tok)::text, true);
  assert private.cashier_restaurant_id() = rid, 'new session works';
  update public.restaurants set suspended_at = now() where id = rid; -- not through the vendor function
  assert private.cashier_restaurant_id() is null, 'a live session stops working when the slot is suspended';
  assert not (public.cashier_heartbeat_v2('2.2.1')->>'ok')::boolean, 'its heartbeat is refused too';

  -- ---------------------------------------------------------------- the fleet list shows it
  r := public.vendor_fleet('susp-pw');
  assert (select (c->>'suspended')::boolean from jsonb_array_elements(r->'cafes') c where (c->>'id')::uuid = rid),
    'the fleet list flags the suspended slot: ' || r::text;
  assert (select (c->>'slot')::int from jsonb_array_elements(r->'cafes') c where (c->>'id')::uuid = rid) = 2,
    'the fleet list carries the slot number';
end
$test$;

rollback;
