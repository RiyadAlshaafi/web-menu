-- Checks the dev screen's "Import logs" (dev_import_logs, with 20261020170000): it restores dine-in
-- and takeout receipts and expenses even when the cafe requires a cashier online and none is
-- signed in; a takeout needs no table; a dine-in receipt for an unknown table, a wrong password
-- and bad rows are refused and store nothing; and ordinary guests are still held back by the
-- cashier rule.
-- Run by tool/test_db.sh. Everything is rolled back; any failed check aborts with its message.

begin;

do $test$
declare
  r jsonb;
  rid uuid := (select id from public.restaurants where slot = 2);
  blocked boolean := false;
  before_payments integer;
  before_expenses integer;
begin
  insert into public.dev_access (password_hash)
  values (extensions.crypt('imp-pw', extensions.gen_salt('bf', 4)));
  -- The dev screen imports into the slot it has chosen, sent as this header.
  perform set_config('request.headers', '{"x-dev-slot": "2"}', true);
  assert private.dev_restaurant_id() = rid, 'the import targets the chosen slot';
  insert into public.cashiers (restaurant_id, name, initials, pin_hash) values (rid, 'Ali', 'A', 'x');
  insert into public.dining_tables (restaurant_id, number, qr_slug) values (rid, 'I1', 'imp-slug-1');
  update public.restaurants set require_cashier_online = true where id = rid;
  assert not private.cashier_online(rid), 'no till is signed in';

  -- ---------------------------------------------------------------- guests are still held back
  begin
    execute 'set local role anon';
    r := public.guest_call_staff('imp-slug-1');
    blocked := not coalesce((r->>'ok')::boolean, false);
  exception when others then
    blocked := true;
  end;
  execute 'reset role';
  assert blocked, 'a guest still cannot act while no cashier is online';

  before_payments := (select count(*) from public.payments where restaurant_id = rid);
  before_expenses := (select count(*) from public.shift_expenses where restaurant_id = rid);

  -- ---------------------------------------------------------------- refusals store nothing
  execute 'set local role anon';
  r := public.dev_import_logs('wrong', '[]'::jsonb, '[]'::jsonb);
  assert not (r->>'ok')::boolean, 'a wrong password does not import: ' || r::text;

  r := public.dev_import_logs('imp-pw', jsonb_build_array(jsonb_build_object(
    'paid_at', '2026-10-01T10:00:00Z', 'receipt', '1', 'monthly', '1', 'table', 'Nope', 'service', 'dine_in',
    'total_due', 5, 'lines', jsonb_build_array(jsonb_build_object('name', 'Tea', 'qty', 1, 'unit_price', 5)))), '[]'::jsonb);
  assert not (r->>'ok')::boolean and r->>'error' = 'No table named Nope.', 'a dine-in receipt needs a real table: ' || r::text;

  r := public.dev_import_logs('imp-pw', jsonb_build_array(jsonb_build_object(
    'paid_at', '2026-10-01T10:00:00Z', 'table', 'I1', 'service', 'dine_in', 'total_due', 5,
    'lines', jsonb_build_array(jsonb_build_object('name', '', 'qty', 1, 'unit_price', 5)))), '[]'::jsonb);
  assert not (r->>'ok')::boolean and r->>'error' = 'A receipt item is incomplete.', 'a bad line is refused: ' || r::text;
  execute 'reset role';
  assert (select count(*) from public.payments where restaurant_id = rid) = before_payments, 'refusals stored no receipt';

  -- ---------------------------------------------------------------- the import works
  execute 'set local role anon';
  r := public.dev_import_logs('imp-pw',
    jsonb_build_array(
      jsonb_build_object(
        'paid_at', '2026-10-01T10:00:00Z', 'receipt', '2510001', 'monthly', '2510009', 'table', 'I1',
        'service', 'dine_in', 'total_due', 7,
        'lines', jsonb_build_array(
          jsonb_build_object('name', 'Coffee', 'qty', 2, 'unit_price', 3.5))),
      jsonb_build_object(
        'paid_at', '2026-10-02T11:00:00Z', 'receipt', '2510002', 'monthly', '2510010', 'table', 'Takeout',
        'service', 'takeout', 'total_due', 12,
        'lines', jsonb_build_array(
          jsonb_build_object('name', 'Sandwich', 'qty', 1, 'unit_price', 8),
          jsonb_build_object('name', 'Juice', 'qty', 1, 'unit_price', 4)))),
    jsonb_build_array(jsonb_build_object(
      'created_at', '2026-10-02T12:00:00Z', 'amount', 4, 'description', 'milk', 'kind', 'cash_out', 'paid_to_cafe', true)));
  execute 'reset role';
  assert (r->>'ok')::boolean, 'the import works with the cashier rule on and no till signed in: ' || r::text;
  assert (r->>'receipts')::int = 2 and (r->>'expenses')::int = 1, 'counts are reported: ' || r::text;

  assert (select count(*) from public.payments where restaurant_id = rid) = before_payments + 2, 'two receipts stored';
  assert (select count(*) from public.shift_expenses where restaurant_id = rid) = before_expenses + 1, 'one expense stored';
  assert (select count(*) from public.order_lines l join public.orders o on o.id = l.order_id
          where o.restaurant_id = rid and l.name in ('Coffee', 'Sandwich', 'Juice')) = 3, 'all three lines stored';
  assert (select p.table_id is not null from public.payments p where p.shift_display_number = '2510001' and p.restaurant_id = rid),
    'the dine-in receipt keeps its table';
  assert (select p.table_id is null from public.payments p where p.shift_display_number = '2510002' and p.restaurant_id = rid),
    'the takeout receipt has no table';
  assert (select o.service_type = 'takeout' and o.table_id is null from public.orders o
          join public.payments p on p.order_id = o.id where p.shift_display_number = '2510002' and p.restaurant_id = rid),
    'the takeout order is a takeout without a table';
  assert (select monthly_display_number from public.payments where shift_display_number = '2510002' and restaurant_id = rid) = '2510010',
    'the original receipt numbers are kept';
end
$test$;

rollback;
