-- Checks 20261020160000_feedback.sql: only a signed-in cafe can send feedback, with a valid kind
-- and message, at most 10 a day; a suspended cafe cannot send; nobody can read the table except
-- through the vendor functions, which need the developer password; the vendor can list, filter
-- and file messages; and the fleet list carries the unread count.
-- Run by tool/test_db.sh. Everything is rolled back; any failed check aborts with its message.

begin;

do $test$
declare
  r jsonb;
  rid uuid := (select id from public.restaurants where slot = 2);
  admin_rid uuid := (select id from public.restaurants where slot = 1);
  admin_id uuid := (select id from public.profiles where restaurant_id = (select id from public.restaurants where slot = 1) limit 1);
  cid uuid;
  tok text;
  first_id uuid;
  denied boolean := false;
begin
  insert into public.dev_access (password_hash)
  values (extensions.crypt('fb-pw', extensions.gen_salt('bf', 4)));
  insert into public.cashiers (restaurant_id, name, initials, pin_hash)
  values (rid, 'Ali', 'A', extensions.crypt('1234', extensions.gen_salt('bf', 4))) returning id into cid;

  -- ---------------------------------------------------------------- not signed in
  execute 'set local role anon';
  r := public.send_feedback('idea', 'Please add dark mode', '2.2.1');
  execute 'reset role';
  assert not (r->>'ok')::boolean and r->>'error' like 'session expired%', 'no session, no feedback: ' || r::text;
  assert not exists (select 1 from public.feedback), 'nothing stored';

  -- ---------------------------------------------------------------- a cashier sends
  r := public.cashier_login(cid, '1234');
  tok := r->>'token';
  perform set_config('request.headers', json_build_object('x-cashier-token', tok)::text, true);
  execute 'set local role anon';
  r := public.send_feedback('problem', '  The printer stops after lunch  ', '2.2.1');
  execute 'reset role';
  assert (r->>'ok')::boolean, 'a signed-in cashier can send: ' || r::text;
  select f.id into first_id from public.feedback f where f.restaurant_id = rid;
  assert (select message from public.feedback where id = first_id) = 'The printer stops after lunch', 'message is trimmed';
  assert (select sender from public.feedback where id = first_id) = 'cashier', 'sender is recorded';
  assert (select app_version from public.feedback where id = first_id) = '2.2.1', 'version is recorded';
  assert (select status from public.feedback where id = first_id) = 'new', 'it starts as new';

  -- ---------------------------------------------------------------- an admin sends
  perform set_config('request.headers', '{}', true);
  perform set_config('request.jwt.claim.sub', admin_id::text, true);
  execute 'set local role authenticated';
  r := public.send_feedback('question', 'How do I export a month?', null);
  execute 'reset role';
  perform set_config('request.jwt.claim.sub', '', true);
  assert (r->>'ok')::boolean, 'an admin can send: ' || r::text;
  assert (select sender from public.feedback where restaurant_id = admin_rid) = 'admin', 'admin sender recorded';

  -- ---------------------------------------------------------------- validation
  perform set_config('request.headers', json_build_object('x-cashier-token', tok)::text, true);
  execute 'set local role anon';
  r := public.send_feedback('complaint', 'x', null);
  assert not (r->>'ok')::boolean and r->>'error' = 'bad kind', 'unknown kind: ' || r::text;
  r := public.send_feedback('idea', '   ', null);
  assert not (r->>'ok')::boolean and r->>'error' = 'message required', 'blank message: ' || r::text;
  r := public.send_feedback('idea', null, null);
  assert not (r->>'ok')::boolean and r->>'error' = 'message required', 'null message: ' || r::text;
  r := public.send_feedback('idea', repeat('x', 2001), null);
  assert not (r->>'ok')::boolean and r->>'error' = 'message too long', 'over 2000 characters: ' || r::text;
  r := public.send_feedback('idea', repeat('x', 2000), null);
  assert (r->>'ok')::boolean, '2000 characters is fine: ' || r::text;
  execute 'reset role';

  -- ---------------------------------------------------------------- ten a day
  execute 'set local role anon';
  for i in 1..8 loop
    r := public.send_feedback('other', 'message ' || i, null);
    assert (r->>'ok')::boolean, 'message ' || i || ' within the limit: ' || r::text;
  end loop;
  r := public.send_feedback('other', 'one too many', null);
  execute 'reset role';
  assert not (r->>'ok')::boolean and r->>'error' = 'too many today', 'the eleventh in a day is refused: ' || r::text;
  assert (select count(*) from public.feedback where restaurant_id = rid) = 10, 'ten stored for this cafe';
  assert (select count(*) from public.feedback where restaurant_id = admin_rid) = 1, 'the other cafe has its own allowance';

  -- ---------------------------------------------------------------- nobody reads the table
  begin
    execute 'set local role anon';
    perform count(*) from public.feedback;
  exception when insufficient_privilege then
    denied := true;
  end;
  execute 'reset role';
  assert denied, 'guests cannot read feedback';

  -- ---------------------------------------------------------------- the vendor's view
  execute 'set local role anon';
  r := public.vendor_feedback('wrong');
  execute 'reset role';
  assert not (r->>'ok')::boolean and not r ? 'items', 'a wrong password must get nothing: ' || r::text;

  execute 'set local role anon';
  r := public.vendor_feedback('fb-pw');
  execute 'reset role';
  assert (r->>'ok')::boolean and (r->>'new_count')::int = 11, 'eleven new messages: ' || (r->'new_count')::text;
  assert jsonb_array_length(r->'items') = 11, 'all listed';
  assert (r->'items'->0->>'created_at') >= (r->'items'->10->>'created_at'), 'newest first';
  assert exists (select 1 from jsonb_array_elements(r->'items') i where i->>'cafe_slot' = '2' and i->>'kind' = 'problem'),
    'the cafe slot and kind are shown';

  r := public.vendor_feedback('fb-pw', 'new', 3);
  assert jsonb_array_length(r->'items') = 3, 'the limit applies: ' || jsonb_array_length(r->'items');
  r := public.vendor_feedback('fb-pw', 'bogus');
  assert not (r->>'ok')::boolean and r->>'error' = 'bad status', 'a bad filter is refused: ' || r::text;

  r := public.vendor_set_feedback_status('fb-pw', first_id, 'read');
  assert (r->>'ok')::boolean, 'filing works: ' || r::text;
  r := public.vendor_feedback('fb-pw');
  assert (r->>'new_count')::int = 10, 'the unread count drops';
  assert jsonb_array_length(public.vendor_feedback('fb-pw', 'read')->'items') = 1, 'filter by read';
  r := public.vendor_set_feedback_status('wrong', first_id, 'done');
  assert not (r->>'ok')::boolean, 'a wrong password cannot file: ' || r::text;
  assert (select status from public.feedback where id = first_id) = 'read', 'status unchanged';
  r := public.vendor_set_feedback_status('fb-pw', first_id, 'archived');
  assert not (r->>'ok')::boolean and r->>'error' = 'bad status', 'bad status refused';
  r := public.vendor_set_feedback_status('fb-pw', gen_random_uuid(), 'done');
  assert not (r->>'ok')::boolean and r->>'error' = 'no such message', 'unknown message refused';

  -- ---------------------------------------------------------------- the fleet list
  r := public.vendor_fleet('fb-pw');
  assert (r->>'new_feedback')::int = 10, 'the fleet list carries the unread count: ' || r::text;

  -- ---------------------------------------------------------------- a suspended cafe cannot send
  perform public.vendor_set_suspended('fb-pw', rid, true);
  perform set_config('request.headers', json_build_object('x-cashier-token', tok)::text, true);
  execute 'set local role anon';
  r := public.send_feedback('idea', 'still here?', null);
  execute 'reset role';
  assert not (r->>'ok')::boolean, 'a suspended cafe cannot send: ' || r::text;
end
$test$;

rollback;
