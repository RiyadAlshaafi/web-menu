-- Checks 20261020130000_vendor_export_logs.sql: the vendor log backup needs the developer password,
-- returns one cafe's receipts (with lines) and expenses inside the window only, refuses a window
-- over 31 days or an unknown cafe, and still works for a suspended cafe.
-- Run by tool/test_db.sh. Everything is rolled back; any failed check aborts with its message.

begin;

do $test$
declare
  r jsonb;
  rid uuid := (select id from public.restaurants where slot = 2);
  other_rid uuid := (select id from public.restaurants where slot = 3);
  cid uuid;
  ocid uuid;
  sid uuid;
  osid uuid;
  ord uuid;
  oord uuid;
  cat uuid;
  ocat uuid;
begin
  insert into public.dev_access (password_hash)
  values (extensions.crypt('export-pw', extensions.gen_salt('bf', 4)));

  -- Slot 2: one receipt with a line and one expense, now.
  insert into public.cashiers (restaurant_id, name, initials, pin_hash) values (rid, 'Ali', 'A', 'x') returning id into cid;
  insert into public.shifts (restaurant_id, cashier_id, opening_cash) values (rid, cid, 0) returning id into sid;
  insert into public.orders (restaurant_id, table_id, status, service_type) values (rid, null, 'served', 'takeout') returning id into ord;
  perform set_config('dev.import', 'on', true); -- lets a test line exist without a menu item
  insert into public.order_lines (order_id, restaurant_id, name, qty, unit_price) values (ord, rid, 'Espresso', 2, 3.5);
  insert into public.payments (restaurant_id, order_id, total_due, cash_received, change_due, cashier_id, shift_id, client_id)
  values (rid, ord, 7, 10, 3, cid, sid, gen_random_uuid());
  insert into public.expense_categories (restaurant_id, name_en, name_ar) values (rid, 'Supplies', 'Supplies') returning id into cat;
  insert into public.shift_expenses (restaurant_id, shift_id, cashier_id, paid_to_cafe, amount, description, kind, expense_category_id, client_id)
  values (rid, sid, cid, true, 4, 'milk', 'cash_out', cat, gen_random_uuid());

  -- Slot 3: its own receipt, which must never show up in slot 2's backup.
  insert into public.cashiers (restaurant_id, name, initials, pin_hash) values (other_rid, 'Omar', 'O', 'x') returning id into ocid;
  insert into public.shifts (restaurant_id, cashier_id, opening_cash) values (other_rid, ocid, 0) returning id into osid;
  insert into public.orders (restaurant_id, table_id, status, service_type) values (other_rid, null, 'served', 'takeout') returning id into oord;
  insert into public.payments (restaurant_id, order_id, total_due, cash_received, change_due, cashier_id, shift_id, client_id)
  values (other_rid, oord, 99, 99, 0, ocid, osid, gen_random_uuid());
  insert into public.expense_categories (restaurant_id, name_en, name_ar) values (other_rid, 'Other', 'Other') returning id into ocat;

  -- ---------------------------------------------------------------- password gate
  execute 'set local role anon';
  r := public.vendor_export_logs('wrong', rid, now() - interval '1 day', now() + interval '1 day');
  execute 'reset role';
  assert not (r->>'ok')::boolean and not r ? 'payments', 'a wrong password must get nothing: ' || r::text;

  -- ---------------------------------------------------------------- the window
  execute 'set local role anon';
  r := public.vendor_export_logs('export-pw', rid, now() - interval '1 day', now() + interval '1 day');
  execute 'reset role';
  assert (r->>'ok')::boolean, 'the right password must work: ' || r::text;
  assert jsonb_array_length(r->'payments') = 1, 'one receipt in the window: ' || r::text;
  assert (r->'payments'->0->>'total_due')::numeric = 7, 'it is this cafe''s receipt, not the other slot''s: ' || r::text;
  assert r->'payments'->0->'lines'->0->>'name' = 'Espresso' and (r->'payments'->0->'lines'->0->>'qty')::int = 2,
    'the receipt carries its lines: ' || r::text;
  assert jsonb_array_length(r->'expenses') = 1 and (r->'expenses'->0->>'description') = 'milk', 'one expense: ' || r::text;

  r := public.vendor_export_logs('export-pw', rid, now() - interval '10 days', now() - interval '5 days');
  assert jsonb_array_length(r->'payments') = 0 and jsonb_array_length(r->'expenses') = 0,
    'a window with nothing in it is empty: ' || r::text;

  -- the window end is exclusive, the start inclusive
  r := public.vendor_export_logs('export-pw', rid, (select paid_at from public.payments where order_id = ord), now() + interval '1 day');
  assert jsonb_array_length(r->'payments') = 1, 'the window start is inclusive: ' || r::text;
  r := public.vendor_export_logs('export-pw', rid, now() - interval '1 day', (select paid_at from public.payments where order_id = ord));
  assert jsonb_array_length(r->'payments') = 0, 'the window end is exclusive: ' || r::text;

  -- ---------------------------------------------------------------- refusals
  r := public.vendor_export_logs('export-pw', rid, now() - interval '40 days', now());
  assert not (r->>'ok')::boolean and r->>'error' like '%31 days%', 'a window over 31 days is refused: ' || r::text;
  r := public.vendor_export_logs('export-pw', rid, now(), now() - interval '1 day');
  assert not (r->>'ok')::boolean, 'a backwards window is refused: ' || r::text;
  r := public.vendor_export_logs('export-pw', rid, null, now());
  assert not (r->>'ok')::boolean, 'a missing window is refused: ' || r::text;
  r := public.vendor_export_logs('export-pw', gen_random_uuid(), now() - interval '1 day', now());
  assert not (r->>'ok')::boolean and r->>'error' = 'no such cafe', 'an unknown cafe is refused: ' || r::text;

  -- ---------------------------------------------------------------- suspended cafes stay backed up
  perform public.vendor_set_suspended('export-pw', rid, true);
  r := public.vendor_export_logs('export-pw', rid, now() - interval '1 day', now() + interval '1 day');
  assert (r->>'ok')::boolean and jsonb_array_length(r->'payments') = 1, 'a suspended cafe can still be backed up: ' || r::text;
end
$test$;

rollback;
