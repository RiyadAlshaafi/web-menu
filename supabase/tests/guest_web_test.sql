-- Checks 20261014100000_guest_web_rpcs.sql as the guest web app calls it: the anon role with no
-- headers at all (the Next.js server passes the QR slug as an argument only). Each function must
-- return only the slug's own cafe and table, and nothing staff-only.
-- Run by tool/test_db.sh. Everything is rolled back; any failed check aborts with its message.

begin;

do $test$
declare
  r jsonb;
  rid uuid;
  other_rid uuid;
  tid uuid;
  cat uuid;
  hidden_cat uuid;
  ia uuid;
  ib uuid;
  ic uuid;
  ih uuid;
  other_item uuid;
  pt uuid;
  cid uuid;
  sid uuid;
  oid uuid;
  n integer;
begin
  insert into public.restaurants (name, service_charge_rate, header_color, location_lat, location_lng,
                                  location_radius_m, location_check_enabled, require_cashier_online)
  values ('web cafe', 0.10, '#112233', 32.9, 13.18, 30, true, true)
  returning id into rid;
  insert into public.restaurants (name) values ('other cafe') returning id into other_rid;
  insert into public.dining_tables (restaurant_id, number, qr_slug) values (rid, 'W1', 'web-slug-1') returning id into tid;
  insert into public.dining_tables (restaurant_id, number, qr_slug, archived) values (rid, 'W2', 'web-slug-2', true);
  insert into public.dining_tables (restaurant_id, number, qr_slug) values (other_rid, 'O1', 'other-slug-1');
  insert into public.menu_categories (restaurant_id, name_en, name_ar, sort_order) values (rid, 'Drinks', 'مشروبات', 1) returning id into cat;
  insert into public.menu_categories (restaurant_id, name_en, name_ar, visible) values (rid, 'Hidden', 'مخفي', false) returning id into hidden_cat;
  insert into public.menu_items (restaurant_id, category_id, name_en, name_it, price, sort_order)
    values (rid, cat, 'Tea', 'شاي', 5, 1) returning id into ia;
  insert into public.menu_items (restaurant_id, category_id, name_en, price, available) values (rid, cat, 'Off', 4, false) returning id into ib;
  insert into public.menu_items (restaurant_id, category_id, name_en, price, sold_out) values (rid, cat, 'Gone', 4, true) returning id into ic;
  insert into public.menu_items (restaurant_id, category_id, name_en, price) values (rid, hidden_cat, 'Secret', 9) returning id into ih;
  insert into public.menu_categories (restaurant_id, name_en, name_ar) values (other_rid, 'X', 'X') returning id into hidden_cat;
  insert into public.menu_items (restaurant_id, category_id, name_en, price) values (other_rid, hidden_cat, 'Elsewhere', 1) returning id into other_item;
  insert into public.payment_types (restaurant_id, name_en, name_ar) values (rid, 'Card', 'بطاقة') returning id into pt;
  insert into public.payment_types (restaurant_id, name_en, name_ar, enabled) values (rid, 'Off type', 'x', false);
  insert into public.payment_types (restaurant_id, name_en, name_ar, archived) values (rid, 'Old type', 'x', true);

  -- An online cashier, so ordering is open.
  insert into public.cashiers (restaurant_id, name, initials, pin_hash) values (rid, 'Ali', 'A', 'x') returning id into cid;
  insert into public.cashier_sessions (cashier_id, restaurant_id, token_hash, expires_at)
    values (cid, rid, 'web-test-hash', now() + interval '1 hour') returning id into sid;
  insert into public.cashier_presence (session_id, restaurant_id, last_seen) values (sid, rid, now());

  perform set_config('request.headers', '{}', true);
  execute 'set local role anon';

  -- ---------------------------------------------------------------- menu
  r := public.guest_menu('web-slug-1');
  assert (r->>'ok')::boolean, 'menu loads: ' || r::text;
  assert r->'cafe'->>'name' = 'web cafe' and r->'cafe'->>'header_color' = '#112233', 'cafe branding: ' || r::text;
  assert (r->'cafe'->>'service_charge_rate')::numeric = 0.10, 'service charge is shown for the bill';
  assert r->'table'->>'number' = 'W1', 'table number';
  assert not (r->'cafe' ? 'location_lat') and not (r->'cafe' ? 'require_cashier_online') and not (r->'cafe' ? 'slot'),
    'menu must not leak cafe settings: ' || (r->'cafe')::text;
  assert jsonb_array_length(r->'categories') = 1 and r->'categories'->0->>'name_ar' = 'مشروبات',
    'only visible categories: ' || (r->'categories')::text;
  assert jsonb_array_length(r->'items') = 3, 'three dishes in visible categories: ' || (r->'items')::text;
  assert not (r->'items' @> jsonb_build_array(jsonb_build_object('id', ih))), 'a hidden category''s dish is not listed';
  assert not (r->'items' @> jsonb_build_array(jsonb_build_object('id', other_item))), 'another cafe''s dish is not listed';
  assert r->'items' @> jsonb_build_array(jsonb_build_object('id', ia, 'name_ar', 'شاي', 'available', true)), 'Arabic name and available: ' || (r->'items')::text;
  assert r->'items' @> jsonb_build_array(jsonb_build_object('id', ib, 'available', false)), 'switched-off dish shows unavailable';
  assert r->'items' @> jsonb_build_array(jsonb_build_object('id', ic, 'available', false)), 'sold-out dish shows unavailable';
  assert r->'items' @> jsonb_build_array(jsonb_build_object('id', ia, 'sale_price', 5)), 'sale price without an offer is the price';
  assert r->'payment_types' @> jsonb_build_array(jsonb_build_object('id', pt)), 'enabled payment type listed';
  assert not (r->'payment_types' @> '[{"name_en": "Off type"}]'::jsonb) and not (r->'payment_types' @> '[{"name_en": "Old type"}]'::jsonb),
    'disabled and archived payment types are not listed: ' || (r->'payment_types')::text;

  r := public.guest_menu('web-slug-2');
  assert r = '{"ok": false, "error": "table not found"}'::jsonb, 'an archived table has no menu: ' || r::text;
  r := public.guest_menu('no-such-slug');
  assert r->>'error' = 'table not found', 'unknown slug';
  r := public.guest_menu(null);
  assert r->>'error' = 'table not found', 'missing slug';
  r := public.guest_menu('  web-slug-1  ');
  assert (r->>'ok')::boolean, 'surrounding spaces are ignored';
  r := public.guest_menu('other-slug-1');
  assert r->'cafe'->>'name' = 'other cafe' and jsonb_array_length(r->'items') = 1, 'each slug sees its own cafe only';

  -- ---------------------------------------------------------------- status
  r := public.guest_status('web-slug-1');
  assert (r->>'ordering_open')::boolean, 'open with a cashier online: ' || r::text;
  assert (r->'location'->>'enabled')::boolean and (r->'location'->>'radius_m')::int = 30, 'location rule: ' || r::text;
  assert not (r ? 'lat') and not (r->'location' ? 'lat'), 'status never gives the cafe''s coordinates';
  r := public.guest_status('other-slug-1');
  assert (r->>'ordering_open')::boolean and not (r->'location'->>'enabled')::boolean,
    'a cafe that does not need a cashier is open, with no location check: ' || r::text;
  r := public.guest_status('nope');
  assert r->>'error' = 'table not found', 'status: unknown slug';

  -- ---------------------------------------------------------------- tab (empty)
  r := public.guest_tab('web-slug-1');
  assert (r->>'ok')::boolean and r->'order' = 'null'::jsonb, 'no open order yet: ' || r::text;

  -- ---------------------------------------------------------------- call staff
  r := public.guest_call_staff('web-slug-1');
  assert r = '{"ok": true, "reused": false}'::jsonb, 'first call goes through: ' || r::text;
  r := public.guest_call_staff('web-slug-1');
  assert r = '{"ok": true, "reused": true}'::jsonb, 'a repeat tap re-uses the open call: ' || r::text;
  execute 'reset role';
  select count(*) into n from public.staff_calls where table_id = tid and kind = 'assistance' and not resolved;
  assert n = 1, 'one open assistance call per table, got ' || n;
  update public.staff_calls set resolved = true where table_id = tid;
  execute 'set local role anon';
  r := public.guest_call_staff('web-slug-1');
  assert r->>'reused' = 'false', 'after staff resolve it, a new call can be made';
  r := public.guest_call_staff('web-slug-2');
  assert r->>'error' = 'table not found', 'archived table cannot call staff';

  -- ---------------------------------------------------------------- refusal with no order
  r := public.guest_confirm_refusal('web-slug-1');
  assert r->>'error' = 'no open bill', 'nothing to confirm without an order: ' || r::text;

  -- ---------------------------------------------------------------- an order, then the tab
  -- The location check only guards send_table_cart; give a position inside the radius.
  r := public.send_table_cart('web-slug-1', jsonb_build_array(jsonb_build_object('menu_item_id', ia, 'qty', 2)),
                              'dine_in', 32.9, 13.18, 10);
  assert (r->>'ok')::boolean, 'order goes through: ' || r::text;
  oid := (r->>'order_id')::uuid;

  r := public.guest_tab('web-slug-1');
  assert r->'order'->>'id' = oid::text, 'tab shows the open order: ' || r::text;
  assert jsonb_array_length(r->'order'->'lines') = 1 and (r->'order'->'lines'->0->>'qty')::int = 2
    and (r->'order'->'lines'->0->>'unit_price')::numeric = 5, 'tab lines: ' || (r->'order'->'lines')::text;
  r := public.guest_tab('other-slug-1');
  assert r->'order' = 'null'::jsonb, 'another table never sees this order';

  -- ---------------------------------------------------------------- refusal, cashier offline
  execute 'reset role';
  update public.orders set awaiting_customer_confirmation = true, refusal_notice = 'Tea removed' where id = oid;
  update public.cashier_presence set last_seen = now() - interval '5 minutes' where session_id = sid;
  execute 'set local role anon';
  r := public.guest_status('web-slug-1');
  assert not (r->>'ordering_open')::boolean, 'closed with no cashier online: ' || r::text;
  r := public.guest_call_staff('web-slug-1');
  assert r = '{"ok": true, "reused": true}'::jsonb or r->>'error' = 'cashier_offline', 'call staff offline: ' || r::text;
  -- OK only clears the notice, so it works with no cashier online.
  r := public.guest_confirm_refusal('web-slug-1');
  assert r = '{"ok": true}'::jsonb, 'refusal OK offline: ' || r::text;
  r := public.guest_tab('web-slug-1');
  assert not (r->'order'->>'awaiting_confirmation')::boolean and r->'order'->>'refusal_notice' = ''
    and r->'table'->>'status' <> 'billRequested', 'notice cleared, no bill asked: ' || r::text;
  execute 'reset role';
  select count(*) into n from public.staff_calls where table_id = tid and kind = 'bill' and not resolved;
  assert n = 0, 'refusal OK opens no bill call, got ' || n;
  update public.cashier_presence set last_seen = now() where session_id = sid;
  execute 'set local role anon';

  -- ---------------------------------------------------------------- paid orders drop off the tab
  execute 'reset role';
  -- Settling is the cashier's job (tested elsewhere); skip its payment checks here.
  set local session_replication_role = replica;
  update public.orders set status = 'paid' where id = oid;
  set local session_replication_role = origin;
  execute 'set local role anon';
  r := public.guest_tab('web-slug-1');
  assert r->'order' = 'null'::jsonb, 'paid history is not shown: ' || r::text;

  -- ---------------------------------------------------------------- grants
  execute 'reset role';
  assert not has_function_privilege('anon', 'private.table_for_slug(text)', 'execute'), 'helper is not callable by anon';
  assert not has_function_privilege('authenticated', 'public.guest_menu(text)', 'execute'), 'guest functions are anon only';
  assert has_function_privilege('anon', 'public.guest_menu(text)', 'execute'), 'anon can read the menu';

  raise notice 'guest_web_test: all checks passed';
end $test$;

rollback;
