-- Checks 20261020150000_guest_visitors.sql: a guest is counted once per day per cafe, the raw
-- visitor id is never stored, unknown and suspended tables are not counted, the guest tables
-- cannot be read directly, per-guest rows are cleaned up while the daily counts stay, and the
-- vendor report needs the developer password.
-- Run by tool/test_db.sh. Everything is rolled back; any failed check aborts with its message.

begin;

do $test$
declare
  r jsonb;
  rid uuid := (select id from public.restaurants where slot = 2);
  other_rid uuid := (select id from public.restaurants where slot = 3);
  today date := (now() at time zone 'Africa/Tripoli')::date;
  denied boolean := false;
  ali constant text := 'visitor-ali-0000001';
  omar constant text := 'visitor-omar-000002';
  sara constant text := 'visitor-sara-000003';
begin
  insert into public.dev_access (password_hash)
  values (extensions.crypt('visit-pw', extensions.gen_salt('bf', 4)));
  insert into public.dining_tables (restaurant_id, number, qr_slug) values (rid, 'V1', 'visit-slug-1');
  insert into public.dining_tables (restaurant_id, number, qr_slug) values (other_rid, 'V1', 'visit-slug-other');

  -- ---------------------------------------------------------------- counting
  execute 'set local role anon';
  r := public.guest_record_visit('visit-slug-1', ali);
  assert (r->>'ok')::boolean, 'a visit is recorded: ' || r::text;
  perform public.guest_record_visit('visit-slug-1', ali);
  perform public.guest_record_visit('visit-slug-1', ali);
  perform public.guest_record_visit('visit-slug-1', omar);
  perform public.guest_record_visit('visit-slug-other', ali);
  execute 'reset role';

  assert (select visitors from public.guest_visit_days where restaurant_id = rid and day = today) = 2,
    'the same guest counts once a day, two guests count twice';
  assert (select visitors from public.guest_visit_days where restaurant_id = other_rid and day = today) = 1,
    'the same guest at another cafe counts there';
  assert not exists (select 1 from public.guest_visits where visitor_hash in (ali, omar)),
    'the visitor id itself is never stored';
  assert (select count(*) from public.guest_visits where restaurant_id = rid and day = today) = 2, 'two per-guest rows';

  -- ---------------------------------------------------------------- refusals
  execute 'set local role anon';
  r := public.guest_record_visit('visit-slug-1', 'short');
  assert not (r->>'ok')::boolean and r->>'error' = 'bad visitor', 'a malformed visitor id is refused: ' || r::text;
  r := public.guest_record_visit('visit-slug-1', 'has spaces and symbols!!!');
  assert not (r->>'ok')::boolean, 'an id with other characters is refused: ' || r::text;
  r := public.guest_record_visit('no-such-slug', sara);
  assert not (r->>'ok')::boolean and r->>'error' = 'table not found', 'an unknown table is not counted: ' || r::text;
  execute 'reset role';

  -- ---------------------------------------------------------------- guests cannot read the counts
  begin
    execute 'set local role anon';
    perform count(*) from public.guest_visit_days;
  exception when insufficient_privilege then
    denied := true;
  end;
  execute 'reset role';
  assert denied, 'guests cannot read the visit counts';

  -- ---------------------------------------------------------------- the vendor report
  execute 'set local role anon';
  r := public.vendor_visitors('wrong');
  execute 'reset role';
  assert not (r->>'ok')::boolean and not r ? 'days', 'a wrong password must get nothing: ' || r::text;

  execute 'set local role anon';
  r := public.vendor_visitors('visit-pw', 30);
  execute 'reset role';
  assert (r->>'ok')::boolean, 'the right password must work: ' || r::text;
  assert jsonb_array_length(r->'days') = 30, 'thirty days: ' || jsonb_array_length(r->'days');
  assert (r->'days'->29->>'day')::date = today, 'today is last';
  assert (r->'days'->29->>'visitors')::integer = 3, 'three unique visitors today, all cafes: ' || (r->'days'->29)::text;
  assert (select (c->>'visitors_today')::int from jsonb_array_elements(r->'cafes') c where (c->>'id')::uuid = rid) = 2,
    'cafe two had two visitors';
  assert (select (c->>'visitors_today')::int from jsonb_array_elements(r->'cafes') c where (c->>'id')::uuid = other_rid) = 1,
    'cafe three had one visitor';
  assert (select (c->>'visitors_7d')::int from jsonb_array_elements(r->'cafes') c where (c->>'id')::uuid = rid) = 2,
    'the seven-day total includes today';

  -- ---------------------------------------------------------------- suspended cafes are not counted
  perform public.vendor_set_suspended('visit-pw', rid, true);
  r := public.guest_record_visit('visit-slug-1', sara);
  assert not (r->>'ok')::boolean, 'a suspended cafe is not counted: ' || r::text;
  assert (select visitors from public.guest_visit_days where restaurant_id = rid and day = today) = 2, 'count unchanged';
  perform public.vendor_set_suspended('visit-pw', rid, false);

  -- ---------------------------------------------------------------- cleanup keeps the daily counts
  insert into public.guest_visits (day, restaurant_id, visitor_hash) values (today - 5, rid, 'old-hash');
  insert into public.guest_visit_days (restaurant_id, day, visitors) values (rid, today - 5, 9);
  for i in 1..1500 loop
    perform public.guest_record_visit('visit-slug-1', ali); -- a repeat visit, so nothing new is counted
    exit when not exists (select 1 from public.guest_visits where visitor_hash = 'old-hash');
  end loop;
  assert not exists (select 1 from public.guest_visits where visitor_hash = 'old-hash'),
    'old per-guest rows are cleaned up';
  assert (select visitors from public.guest_visit_days where restaurant_id = rid and day = today - 5) = 9,
    'the daily count of that old day stays';
  assert (select visitors from public.guest_visit_days where restaurant_id = rid and day = today) = 2,
    'repeat visits never changed today''s count';
end
$test$;

rollback;
