-- Checks 20261021100000_table_claims.sql: the first phone at a table may order and the others only
-- look, a claim ends after 5 minutes without an order but stays once an order was sent, paying
-- frees the table, the raw phone id is never stored, and the cashier can clear a table (after
-- which the unpaid orders are gone) while a guest or another cafe's cashier cannot.
-- Run by tool/test_db.sh. Everything is rolled back; any failed check aborts with its message.

begin;

do $test$
declare
  r jsonb;
  rid uuid;
  other_rid uuid;
  cat uuid;
  tea uuid;
  cid uuid;
  other_cid uuid;
  sid uuid;
  shid uuid;
  tid uuid;
  tid2 uuid;
  tid3 uuid;
  n integer;
  blocked boolean;
  ali constant text := 'phone-ali-00000001';
  omar constant text := 'phone-omar-0000002';
  lines jsonb;
begin
  insert into public.restaurants (name) values ('claims cafe') returning id into rid;
  insert into public.restaurants (name) values ('other claims cafe') returning id into other_rid;
  insert into public.menu_categories (restaurant_id, name_en, name_ar) values (rid, 'C', 'C') returning id into cat;
  insert into public.menu_items (restaurant_id, category_id, name_en, price) values (rid, cat, 'Tea', 5) returning id into tea;
  insert into public.dining_tables (restaurant_id, number, qr_slug) values (rid, 'C1', 'claims-slug-1') returning id into tid;
  insert into public.dining_tables (restaurant_id, number, qr_slug) values (rid, 'C2', 'claims-slug-2') returning id into tid2;
  insert into public.dining_tables (restaurant_id, number, qr_slug) values (rid, 'C3', 'claims-slug-3') returning id into tid3;
  insert into public.cashiers (restaurant_id, name, initials, pin_hash)
  values (rid, 'P', 'P', extensions.crypt('1234', extensions.gen_salt('bf'))) returning id into cid;
  insert into public.cashiers (restaurant_id, name, initials, pin_hash)
  values (other_rid, 'Q', 'Q', extensions.crypt('1234', extensions.gen_salt('bf'))) returning id into other_cid;
  -- A cashier device is online, so guests may order.
  insert into public.cashier_sessions (cashier_id, restaurant_id, token_hash, expires_at)
    values (cid, rid, 'claims-online-hash', now() + interval '1 hour') returning id into sid;
  insert into public.cashier_presence (session_id, restaurant_id, last_seen) values (sid, rid, now());
  lines := jsonb_build_array(jsonb_build_object('menu_item_id', tea, 'qty', 1));

  -- ---------------------------------------------------------------- the first phone owns the table
  perform set_config('request.headers', '{}', true);
  execute 'set local role anon';
  r := public.guest_claim_table('claims-slug-1', ali);
  assert (r->>'ok')::boolean and r->>'role' = 'owner', 'the first phone owns the table: ' || r::text;
  r := public.guest_claim_table('claims-slug-1', omar);
  assert (r->>'ok')::boolean and r->>'role' = 'viewer', 'a second phone only views: ' || r::text;
  r := public.guest_claim_table('claims-slug-1', ali);
  assert r->>'role' = 'owner', 'the owner stays the owner when it asks again: ' || r::text;
  execute 'reset role';
  assert not exists (select 1 from public.table_claims where claimed_by in (ali, omar)),
    'the phone id itself is never stored';

  -- ---------------------------------------------------------------- only the owner can order
  perform set_config('request.headers', json_build_object('x-guest-visitor', omar)::text, true);
  execute 'set local role anon';
  blocked := false;
  begin
    r := public.send_table_cart('claims-slug-1', lines, 'dine_in', null, null, null);
  exception when raise_exception then
    blocked := sqlerrm = 'not_table_owner';
  end;
  execute 'reset role';
  assert blocked, 'a viewer must not be able to order';

  perform set_config('request.headers', '{}', true);
  execute 'set local role anon';
  blocked := false;
  begin
    r := public.send_table_cart('claims-slug-1', lines, 'dine_in', null, null, null);
  exception when raise_exception then
    blocked := sqlerrm = 'not_table_owner';
  end;
  execute 'reset role';
  assert blocked, 'leaving the phone id out must not get round the claim';
  select count(*) into n from public.orders where table_id = tid;
  assert n = 0, 'a refused send leaves no order, got ' || n;

  perform set_config('request.headers', json_build_object('x-guest-visitor', ali)::text, true);
  execute 'set local role anon';
  r := public.send_table_cart('claims-slug-1', lines, 'dine_in', null, null, null);
  execute 'reset role';
  assert (r->>'ok')::boolean, 'the owner can order: ' || r::text;

  -- ---------------------------------------------------------------- a sent order keeps the claim
  update public.table_claims set claimed_at = now() - interval '30 minutes' where table_id = tid;
  perform set_config('request.headers', '{}', true);
  execute 'set local role anon';
  r := public.guest_claim_table('claims-slug-1', omar);
  assert r->>'role' = 'viewer', 'after an order the claim outlives 5 minutes: ' || r::text;
  execute 'reset role';
  perform set_config('request.headers', json_build_object('x-guest-visitor', ali)::text, true);
  execute 'set local role anon';
  r := public.send_table_cart('claims-slug-1', lines, 'dine_in', null, null, null);
  execute 'reset role';
  assert (r->>'ok')::boolean and (r->>'round')::int = 2, 'the owner can add a second round: ' || r::text;

  -- ---------------------------------------------------------------- paying frees the table
  insert into public.shifts (restaurant_id, cashier_id, opening_cash) values (rid, cid, 0) returning id into shid;
  insert into public.payments (restaurant_id, order_id, table_id, total_due, cash_received, change_due, cashier_id, shift_id)
  select o.restaurant_id, o.id, o.table_id, 5, 5, 0, cid, shid from public.orders o where o.table_id = tid;
  update public.orders set status = 'paid' where table_id = tid;
  update public.dining_tables set status = 'free', guests = 0 where id = tid;
  assert not exists (select 1 from public.table_claims where table_id = tid), 'a paid table has no claim';
  perform set_config('request.headers', '{}', true);
  execute 'set local role anon';
  r := public.guest_claim_table('claims-slug-1', omar);
  execute 'reset role';
  assert r->>'role' = 'owner', 'the next phone owns the freed table: ' || r::text;

  -- ---------------------------------------------------------------- no order for 5 minutes ends the claim
  execute 'set local role anon';
  r := public.guest_claim_table('claims-slug-2', ali);
  assert r->>'role' = 'owner', 'ali claims table 2: ' || r::text;
  execute 'reset role';
  update public.table_claims set claimed_at = now() - interval '4 minutes' where table_id = tid2;
  execute 'set local role anon';
  r := public.guest_claim_table('claims-slug-2', omar);
  assert r->>'role' = 'viewer', 'still held after 4 minutes: ' || r::text;
  execute 'reset role';
  update public.table_claims set claimed_at = now() - interval '6 minutes' where table_id = tid2;
  execute 'set local role anon';
  r := public.guest_claim_table('claims-slug-2', omar);
  assert r->>'role' = 'owner', 'free after 6 minutes without an order: ' || r::text;
  r := public.guest_claim_table('claims-slug-2', ali);
  execute 'reset role';
  assert r->>'role' = 'viewer', 'the first phone is now only a viewer: ' || r::text;

  -- ---------------------------------------------------------------- an expired owner may order again if nobody took over
  execute 'set local role anon';
  r := public.guest_claim_table('claims-slug-3', ali);
  execute 'reset role';
  update public.table_claims set claimed_at = now() - interval '10 minutes' where table_id = tid3;
  perform set_config('request.headers', json_build_object('x-guest-visitor', ali)::text, true);
  execute 'set local role anon';
  r := public.send_table_cart('claims-slug-3', lines, 'dine_in', null, null, null);
  execute 'reset role';
  assert (r->>'ok')::boolean, 'an expired owner can order if the table is still free: ' || r::text;
  perform set_config('request.headers', '{}', true);
  delete from public.orders where table_id = tid3;
  delete from public.table_claims where table_id = tid3;

  -- ---------------------------------------------------------------- bad input and no direct access
  execute 'set local role anon';
  r := public.guest_claim_table('claims-slug-1', 'short');
  assert not (r->>'ok')::boolean and r->>'error' = 'bad visitor', 'a malformed id is refused: ' || r::text;
  r := public.guest_claim_table('no-such-slug', ali);
  assert not (r->>'ok')::boolean and r->>'error' = 'table not found', 'an unknown table is refused: ' || r::text;
  blocked := false;
  begin
    perform count(*) from public.table_claims;
  exception when insufficient_privilege then
    blocked := true;
  end;
  execute 'reset role';
  assert blocked, 'guests cannot read the claims';

  -- ---------------------------------------------------------------- clearing a table
  perform set_config('request.headers', json_build_object('x-guest-visitor', ali)::text, true);
  delete from public.table_claims where table_id = tid;
  execute 'set local role anon';
  r := public.guest_claim_table('claims-slug-1', ali);
  r := public.send_table_cart('claims-slug-1', lines, 'dine_in', null, null, null);
  execute 'reset role';
  assert (r->>'ok')::boolean, 'ali orders at table 1 again: ' || r::text;
  insert into public.staff_calls (restaurant_id, table_id, kind) values (rid, tid, 'assistance');

  -- a guest cannot clear a table
  perform set_config('request.headers', '{}', true);
  execute 'set local role anon';
  r := public.cashier_clear_table(tid);
  execute 'reset role';
  assert not (r->>'ok')::boolean, 'a guest must not clear a table: ' || r::text;

  -- another cafe's cashier cannot clear it
  insert into public.cashier_sessions (cashier_id, restaurant_id, token_hash, expires_at)
  values (other_cid, other_rid, encode(extensions.digest('other-claims-token', 'sha256'), 'hex'), now() + interval '1 hour');
  perform set_config('request.headers', json_build_object('x-cashier-token', 'other-claims-token')::text, true);
  execute 'set local role anon';
  r := public.cashier_clear_table(tid);
  execute 'reset role';
  assert not (r->>'ok')::boolean and r->>'error' = 'table not found', 'another cafe cannot clear it: ' || r::text;
  select count(*) into n from public.orders where table_id = tid and status <> 'paid';
  assert n = 1, 'the order is untouched by the other cafe';

  -- this cafe's cashier can
  insert into public.cashier_sessions (cashier_id, restaurant_id, token_hash, expires_at)
  values (cid, rid, encode(extensions.digest('claims-token', 'sha256'), 'hex'), now() + interval '1 hour');
  perform set_config('request.headers', json_build_object('x-cashier-token', 'claims-token')::text, true);
  execute 'set local role anon';
  r := public.cashier_clear_table(tid);
  execute 'reset role';
  assert (r->>'ok')::boolean and (r->>'cancelled_orders')::int = 1, 'the cashier clears the table: ' || r::text;
  select count(*) into n from public.orders where table_id = tid and status <> 'paid';
  assert n = 0, 'the unpaid order is gone, got ' || n;
  assert exists (select 1 from public.orders where table_id = tid and status = 'paid'), 'paid history stays';
  select count(*) into n from public.order_lines l where l.restaurant_id = rid and l.order_id not in (select id from public.orders);
  assert n = 0, 'its lines are gone too';
  assert (select status from public.dining_tables where id = tid) = 'free', 'the table is free';
  assert (select guests from public.dining_tables where id = tid) = 0, 'no guests are left';
  assert not exists (select 1 from public.table_claims where table_id = tid), 'the claim is gone';
  assert not exists (select 1 from public.staff_calls where table_id = tid and not resolved), 'open calls are closed';

  perform set_config('request.headers', '{}', true);
  execute 'set local role anon';
  r := public.guest_claim_table('claims-slug-1', omar);
  execute 'reset role';
  assert r->>'role' = 'owner', 'the next phone owns the cleared table: ' || r::text;

  -- a cleared table never touches paid history
  insert into public.orders (restaurant_id, table_id, status) values (rid, tid2, 'paid');
  perform set_config('request.headers', json_build_object('x-cashier-token', 'claims-token')::text, true);
  execute 'set local role anon';
  r := public.cashier_clear_table(tid2);
  execute 'reset role';
  assert (r->>'ok')::boolean and (r->>'cancelled_orders')::int = 0, 'clearing leaves paid orders alone: ' || r::text;
  assert exists (select 1 from public.orders where table_id = tid2 and status = 'paid'), 'the paid order is still there';

  -- ---------------------------------------------------------------- only a phone at the cafe can take a free table
  insert into public.dining_tables (restaurant_id, number, qr_slug) values (rid, 'C4', 'claims-slug-4');
  update public.restaurants
    set location_lat = 32.9, location_lng = 13.18, location_radius_m = 100, location_check_enabled = true
    where id = rid;
  perform set_config('request.headers', '{}', true);
  execute 'set local role anon';
  r := public.guest_claim_table('claims-slug-4', ali);
  assert (r->>'ok')::boolean and r->>'role' = 'none' and r->>'reason' = 'location_required',
    'no position, no claim: ' || r::text;
  r := public.guest_claim_table('claims-slug-4', ali, 33.5, 13.18, 10);
  assert r->>'role' = 'none' and r->>'reason' = 'too_far', 'a phone far from the cafe cannot take the table: ' || r::text;
  execute 'reset role';
  assert not exists (select 1 from public.table_claims c join public.dining_tables t on t.id = c.table_id
                     where t.qr_slug = 'claims-slug-4'), 'a far phone leaves no claim';

  execute 'set local role anon';
  r := public.guest_claim_table('claims-slug-4', omar, 32.9001, 13.1801, 10);
  assert r->>'role' = 'owner', 'a phone at the cafe takes the table: ' || r::text;
  r := public.guest_claim_table('claims-slug-4', ali, 33.5, 13.18, 10);
  assert r->>'role' = 'viewer', 'a held table shows a far phone as a viewer: ' || r::text;
  r := public.guest_claim_table('claims-slug-4', omar);
  execute 'reset role';
  assert r->>'role' = 'owner', 'the owner stays the owner without sending a position again: ' || r::text;

  update public.restaurants set location_check_enabled = false where id = rid;
  delete from public.table_claims;
  execute 'set local role anon';
  r := public.guest_claim_table('claims-slug-4', ali);
  execute 'reset role';
  assert r->>'role' = 'owner', 'with the location check off any phone can take the table: ' || r::text;

  raise notice 'table_claims_test: all checks passed';
end;
$test$;

rollback;
