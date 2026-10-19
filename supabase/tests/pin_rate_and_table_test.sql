-- Checks 20261019130000_pin_rate_and_table_limits.sql: a correct PIN doesn't clear earlier misses,
-- misses fade after a day, a cafe flooded with wrong PINs pauses sign-in, a guest table can't send
-- more than 10 orders a minute, and a cashier device can't add, edit or delete tables.
-- Run by tool/test_db.sh. Everything is rolled back; any failed check aborts with its message.

begin;

do $test$
declare
  r jsonb;
  rid uuid;
  cat uuid;
  tea uuid;
  cid uuid;
  sid uuid;
  tid uuid;
  i integer;
  n integer;
  blocked boolean;
begin
  insert into public.restaurants (name) values ('limits cafe') returning id into rid;
  insert into public.menu_categories (restaurant_id, name_en, name_ar) values (rid, 'C', 'C') returning id into cat;
  insert into public.menu_items (restaurant_id, category_id, name_en, price) values (rid, cat, 'Tea', 5) returning id into tea;
  insert into public.dining_tables (restaurant_id, number, qr_slug) values (rid, 'L1', 'limits-slug-1') returning id into tid;
  insert into public.cashiers (restaurant_id, name, initials, pin_hash)
  values (rid, 'P', 'P', extensions.crypt('1234', extensions.gen_salt('bf'))) returning id into cid;

  -- ------------------------------------------------ a correct PIN keeps earlier misses
  execute 'set local role anon';
  for i in 1..4 loop
    r := public.cashier_login(cid, '0000');
    assert not (r->>'ok')::boolean and r->>'code' is null, 'miss ' || i || ' must be a plain refusal: ' || r::text;
  end loop;
  r := public.cashier_login(cid, '1234');
  assert (r->>'ok')::boolean, 'the right PIN signs in: ' || r::text;
  r := public.cashier_login(cid, '0000');
  assert r->>'code' = 'locked', 'the 5th miss locks even after a correct PIN in between: ' || r::text;
  execute 'reset role';

  -- ------------------------------------------------ misses fade after a day without one
  update public.cashiers
  set failed_pin_attempts = 4, last_failed_pin_at = now() - interval '25 hours', pin_locked_until = null
  where id = cid;
  execute 'set local role anon';
  r := public.cashier_login(cid, '0000');
  execute 'reset role';
  assert r->>'code' is null, 'an old miss streak must not lock on a new miss: ' || r::text;
  select failed_pin_attempts into n from public.cashiers where id = cid;
  assert n = 1, 'the miss count starts over after a quiet day, got ' || n;

  -- ------------------------------------------------ a flooded cafe pauses PIN sign-in
  insert into private.rate_windows (key, window_start, hits)
  values ('pin_miss:' || rid::text, date_trunc('minute', clock_timestamp()), 30)
  on conflict (key) do update set window_start = excluded.window_start, hits = 30;
  execute 'set local role anon';
  r := public.cashier_login(cid, '1234');
  execute 'reset role';
  assert r->>'code' = 'locked', 'even the right PIN waits while the cafe is flooded: ' || r::text;
  delete from private.rate_windows where key = 'pin_miss:' || rid::text;

  -- ------------------------------------------------ guest order sends per table
  insert into public.cashier_sessions (cashier_id, restaurant_id, token_hash, expires_at)
    values (cid, rid, 'limits-test-hash', now() + interval '1 hour') returning id into sid;
  insert into public.cashier_presence (session_id, restaurant_id, last_seen) values (sid, rid, now());
  perform set_config('request.headers', '{}', true);
  execute 'set local role anon';
  for i in 1..10 loop
    r := public.send_table_cart('limits-slug-1', jsonb_build_array(jsonb_build_object('menu_item_id', tea, 'qty', 1)),
                                'dine_in', null, null, null);
    assert (r->>'ok')::boolean, 'send ' || i || ' must go through: ' || r::text;
  end loop;
  blocked := false;
  begin
    r := public.send_table_cart('limits-slug-1', jsonb_build_array(jsonb_build_object('menu_item_id', tea, 'qty', 1)),
                                'dine_in', null, null, null);
  exception when raise_exception then
    blocked := sqlerrm = 'too_many_requests';
  end;
  execute 'reset role';
  assert blocked, 'the 11th send in a minute must be refused';
  select count(*) into n from public.order_lines l join public.orders o on o.id = l.order_id where o.table_id = tid;
  assert n = 10, 'only the 10 allowed sends are saved, got ' || n;

  -- ------------------------------------------------ cashier devices read tables only
  insert into public.cashier_sessions (cashier_id, restaurant_id, token_hash, expires_at)
  values (cid, rid, encode(extensions.digest('limits-token', 'sha256'), 'hex'), now() + interval '1 hour');
  perform set_config('request.headers', json_build_object('x-cashier-token', 'limits-token')::text, true);
  execute 'set local role anon';
  select count(*) into n from public.dining_tables where id = tid;
  assert n = 1, 'a cashier still sees the tables';
  update public.dining_tables set qr_slug = 'stolen' where id = tid;
  delete from public.dining_tables where id = tid;
  blocked := false;
  begin
    insert into public.dining_tables (restaurant_id, number, qr_slug) values (rid, 'X', 'limits-x');
  exception when insufficient_privilege then blocked := true;
  end;
  execute 'reset role';
  assert blocked, 'a cashier must not add tables';
  select count(*) into n from public.dining_tables where id = tid and qr_slug = 'limits-slug-1';
  assert n = 1, 'a cashier must not change a QR code or delete a table';

  raise notice 'pin_rate_and_table_test: all checks passed';
end;
$test$;

rollback;
