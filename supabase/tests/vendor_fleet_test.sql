-- Checks 20261020100000_vendor_fleet.sql: the fleet list needs the developer password, lists
-- every cafe, reports a till seen just now as online with its app version, and never reports
-- sales or order figures.
-- Run by tool/test_db.sh. Everything is rolled back; any failed check aborts with its message.

begin;

do $test$
declare
  r jsonb;
  cafe jsonb;
  rid uuid := (select id from public.restaurants where slot = 2);
  cid uuid;
  sid uuid;
begin
  insert into public.dev_access (password_hash)
  values (extensions.crypt('fleet-test-pw', extensions.gen_salt('bf', 4)));

  -- ---------------------------------------------------------------- password gate
  execute 'set local role anon';
  r := public.vendor_fleet('wrong');
  execute 'reset role';
  assert not (r->>'ok')::boolean and not r ? 'cafes', 'a wrong password must get nothing: ' || r::text;

  execute 'set local role anon';
  r := public.vendor_fleet(null);
  execute 'reset role';
  assert not (r->>'ok')::boolean, 'no password must get nothing: ' || r::text;

  -- ---------------------------------------------------------------- every cafe is listed
  execute 'set local role anon';
  r := public.vendor_fleet('fleet-test-pw');
  execute 'reset role';
  assert (r->>'ok')::boolean, 'the right password must work: ' || r::text;
  assert jsonb_array_length(r->'cafes') = (select count(*) from public.restaurants),
    'every cafe must be listed: ' || r::text;

  cafe := (select c from jsonb_array_elements(r->'cafes') c where (c->>'id')::uuid = rid);
  assert not (cafe->>'online')::boolean, 'a cafe with no tills is offline: ' || cafe::text;
  assert not cafe ? 'orders_24h' and not cafe ? 'orders_7d', 'no sales figures are ever reported: ' || cafe::text;

  -- ---------------------------------------------------------------- online till
  insert into public.cashiers (restaurant_id, name, initials, pin_hash) values (rid, 'Ali', 'A', 'x') returning id into cid;
  insert into public.cashier_sessions (cashier_id, restaurant_id, token_hash, expires_at)
  values (cid, rid, encode(extensions.digest('fleet-token', 'sha256'), 'hex'), now() + interval '1 hour')
  returning id into sid;
  insert into public.cashier_presence (session_id, restaurant_id, last_seen, app_version)
  values (sid, rid, now(), '2.2.1');

  execute 'set local role anon';
  r := public.vendor_fleet('fleet-test-pw');
  execute 'reset role';
  cafe := (select c from jsonb_array_elements(r->'cafes') c where (c->>'id')::uuid = rid);
  assert (cafe->>'online')::boolean, 'a till seen just now means online: ' || cafe::text;
  assert cafe->>'app_version' = '2.2.1', 'the till version is shown: ' || cafe::text;
  assert (cafe->>'tills_online')::integer = 1, 'one till online: ' || cafe::text;

  -- ---------------------------------------------------------------- gone quiet
  update public.cashier_presence set last_seen = now() - interval '10 minutes' where session_id = sid;
  execute 'set local role anon';
  r := public.vendor_fleet('fleet-test-pw');
  execute 'reset role';
  cafe := (select c from jsonb_array_elements(r->'cafes') c where (c->>'id')::uuid = rid);
  assert not (cafe->>'online')::boolean, 'a till quiet for 10 minutes means offline: ' || cafe::text;
  assert (cafe->>'tills_online')::integer = 0, 'no tills online: ' || cafe::text;
end
$test$;

rollback;
