-- Checks 20261025100000_kitchens.sql: the admin adds kitchens and links categories to them; a
-- category can't point at another cafe's kitchen; a till reads its own cafe's kitchens only and
-- can't change them; deleting a kitchen frees its categories.
-- Run by tool/test_db.sh. Everything is rolled back; any failed check aborts with its message.

begin;

do $test$
declare
  rid_a uuid;
  rid_b uuid;
  admin_a uuid;
  cat_a uuid;
  pizza uuid;
  bar uuid;
  bar_b uuid;
  cid uuid;
  sid uuid;
  n integer;
  blocked boolean;
  linked uuid;
begin
  insert into public.restaurants (name) values ('kitchen cafe A') returning id into rid_a;
  insert into public.restaurants (name) values ('kitchen cafe B') returning id into rid_b;
  alter table auth.users disable trigger user;
  insert into auth.users (email) values ('a@kitchens.test') returning id into admin_a;
  alter table auth.users enable trigger user;
  insert into public.profiles (id, restaurant_id) values (admin_a, rid_a);
  insert into public.menu_categories (restaurant_id, name_en, name_ar) values (rid_a, 'Pizza', 'بيتزا') returning id into cat_a;
  insert into public.kitchens (restaurant_id, name) values (rid_b, 'B bar') returning id into bar_b;
  insert into public.cashiers (restaurant_id, name, initials, pin_hash) values (rid_a, 'K', 'K', 'x') returning id into cid;
  insert into public.cashier_sessions (cashier_id, restaurant_id, token_hash, expires_at)
    values (cid, rid_a, encode(extensions.digest('kitchen-token', 'sha256'), 'hex'), now() + interval '1 hour') returning id into sid;
  insert into public.cashier_presence (session_id, restaurant_id, last_seen) values (sid, rid_a, now());

  -- ---------------------------------------------------------------- the admin sets kitchens up
  perform set_config('request.jwt.claim.sub', admin_a::text, true);
  execute 'set local role authenticated';
  insert into public.kitchens (restaurant_id, name, sort_order) values (rid_a, 'Pizza oven', 0) returning id into pizza;
  insert into public.kitchens (restaurant_id, name, sort_order) values (rid_a, 'Bar', 1) returning id into bar;
  update public.menu_categories set kitchen_id = pizza where id = cat_a;
  select count(*) into n from public.kitchens;
  assert n = 2, 'the admin sees only their own 2 kitchens, got ' || n;

  blocked := false;
  begin
    update public.menu_categories set kitchen_id = bar_b where id = cat_a;
  exception when insufficient_privilege then blocked := true;
  end;
  assert blocked, 'a category must not point at another cafe''s kitchen';

  blocked := false;
  begin
    insert into public.kitchens (restaurant_id, name) values (rid_a, '   ');
  exception when check_violation then blocked := true;
  end;
  assert blocked, 'a kitchen needs a name';
  execute 'reset role';

  -- ---------------------------------------------------------------- a till reads, never writes
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('request.headers', json_build_object('x-cashier-token', 'kitchen-token')::text, true);
  execute 'set local role anon';
  select count(*) into n from public.kitchens;
  assert n = 2, 'a till reads its own cafe''s 2 kitchens, got ' || n;
  update public.kitchens set name = 'hacked' where id = pizza;
  get diagnostics n = row_count;
  assert n = 0, 'a till must not rename a kitchen';
  execute 'reset role';

  -- ---------------------------------------------------------------- deleting a kitchen frees its categories
  delete from public.kitchens where id = pizza;
  select kitchen_id into linked from public.menu_categories where id = cat_a;
  assert linked is null, 'a deleted kitchen leaves its categories without a kitchen';

  raise notice 'kitchens_test: all checks passed';
end $test$;

rollback;
