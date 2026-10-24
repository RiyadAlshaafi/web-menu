-- Checks 20261026110000_receipt_settings.sql: a cafe starts with empty receipt settings (the
-- app's defaults); its admin saves them for their own cafe only; the value must be a small json
-- object; a till reads its own cafe's settings and can't change them.
-- Run by tool/test_db.sh. Everything is rolled back; any failed check aborts with its message.

begin;

do $test$
declare
  rid_a uuid;
  rid_b uuid;
  admin_a uuid;
  cid uuid;
  n integer;
  blocked boolean;
  saved jsonb;
begin
  insert into public.restaurants (name) values ('receipt cafe A') returning id into rid_a;
  insert into public.restaurants (name) values ('receipt cafe B') returning id into rid_b;
  alter table auth.users disable trigger user;
  insert into auth.users (email) values ('a@receipts.test') returning id into admin_a;
  alter table auth.users enable trigger user;
  insert into public.profiles (id, restaurant_id) values (admin_a, rid_a);
  insert into public.cashiers (restaurant_id, name, initials, pin_hash) values (rid_a, 'R', 'R', 'x') returning id into cid;
  insert into public.cashier_sessions (cashier_id, restaurant_id, token_hash, expires_at)
    values (cid, rid_a, encode(extensions.digest('receipt-token', 'sha256'), 'hex'), now() + interval '1 hour');

  select receipt_settings into saved from public.restaurants where id = rid_a;
  assert saved = '{}'::jsonb, 'a cafe starts with the app''s defaults, got ' || saved::text;

  -- ---------------------------------------------------------------- the admin saves their own
  perform set_config('request.jwt.claim.sub', admin_a::text, true);
  execute 'set local role authenticated';
  update public.restaurants
  set receipt_settings = '{"header": "Welcome", "footer": "See you", "showCashier": true, "showLogo": false}'
  where id = rid_a;
  get diagnostics n = row_count;
  assert n = 1, 'the admin saves the receipt settings';

  update public.restaurants set receipt_settings = '{"header": "hacked"}' where id = rid_b;
  get diagnostics n = row_count;
  assert n = 0, 'an admin must not change another cafe''s receipts';

  blocked := false;
  begin
    update public.restaurants set receipt_settings = '["not", "an", "object"]' where id = rid_a;
  exception when check_violation then blocked := true;
  end;
  assert blocked, 'the settings must be a json object';

  blocked := false;
  begin
    update public.restaurants set receipt_settings = jsonb_build_object('header', repeat('x', 5000)) where id = rid_a;
  exception when check_violation then blocked := true;
  end;
  assert blocked, 'oversized settings are refused';
  execute 'reset role';

  select receipt_settings into saved from public.restaurants where id = rid_a;
  assert saved->>'header' = 'Welcome' and (saved->>'showCashier')::boolean, 'the saved settings stay: ' || saved::text;
  assert (select receipt_settings from public.restaurants where id = rid_b) = '{}'::jsonb, 'cafe B is untouched';

  -- ---------------------------------------------------------------- a till reads, never writes
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('request.headers', json_build_object('x-cashier-token', 'receipt-token')::text, true);
  execute 'set local role anon';
  select receipt_settings into saved from public.restaurants where id = rid_a;
  assert saved->>'footer' = 'See you', 'a till reads its own cafe''s receipt settings';
  select count(*) into n from public.restaurants where id = rid_b;
  assert n = 0, 'a till does not see another cafe';
  update public.restaurants set receipt_settings = '{}' where id = rid_a;
  get diagnostics n = row_count;
  assert n = 0, 'a till must not change the receipt settings';
  execute 'reset role';

  raise notice 'receipt_settings_test: all checks passed';
end $test$;

rollback;
