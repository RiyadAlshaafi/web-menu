-- Checks 20261027160000_cashier_back_ping.sql: the first heartbeat after a cafe was offline sends
-- one cashier_presence ping to the cafe topic; heartbeats while online send none.
-- Run by tool/test_db.sh against the realtime.send stand-in in supabase_stubs.sql.
-- Everything is rolled back; any failed check aborts with its message.

begin;

do $test$
declare
  r jsonb;
  rid uuid;
  cid uuid;
  sid uuid;
  n integer;
begin
  insert into public.restaurants (name) values ('back cafe') returning id into rid;
  insert into public.cashiers (restaurant_id, name, initials, pin_hash) values (rid, 'K', 'K', 'x') returning id into cid;
  insert into public.cashier_sessions (cashier_id, restaurant_id, token_hash, expires_at)
    values (cid, rid, encode(extensions.digest('back-token', 'sha256'), 'hex'), now() + interval '1 hour') returning id into sid;
  delete from realtime.sent_for_tests;
  perform set_config('request.headers', json_build_object('x-cashier-token', 'back-token')::text, true);
  execute 'set local role anon';

  -- ------------------------------------------------ first heartbeat: cafe comes online
  r := public.cashier_heartbeat_v2('1.0.0');
  assert (r->>'ok')::boolean, 'heartbeat: ' || r::text;
  execute 'reset role';
  select count(*) into n from realtime.sent_for_tests
    where topic = 'cafe:' || rid and payload = '{"table": "cashier_presence"}'::jsonb;
  assert n = 1, 'one ping when the cafe comes online, got ' || n;

  -- ------------------------------------------------ still online: no ping
  execute 'set local role anon';
  r := public.cashier_heartbeat_v2('1.0.0');
  execute 'reset role';
  select count(*) into n from realtime.sent_for_tests where payload->>'table' = 'cashier_presence';
  assert n = 1, 'no ping while already online, got ' || n;

  -- ------------------------------------------------ offline, then back
  update public.cashier_presence set last_seen = now() - interval '5 minutes' where session_id = sid;
  execute 'set local role anon';
  r := public.cashier_heartbeat_v2('1.0.0');
  execute 'reset role';
  select count(*) into n from realtime.sent_for_tests where payload->>'table' = 'cashier_presence';
  assert n = 2, 'a ping when the cashier comes back, got ' || n;

  raise notice 'cashier_back_ping_test: all checks passed';
end;
$test$;

rollback;
