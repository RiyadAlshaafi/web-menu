-- Checks 20261030100000_receipt_counter_floor.sql: a monthly counter that fell behind skips the
-- numbers a till reserved and the numbers sales already have, a block of n still gets n new
-- numbers, daily counters and a counter that is ahead are left alone.
-- Run by tool/test_db.sh. Everything is rolled back; any failed check aborts with its message.

begin;

do $test$
declare
  rid uuid;
  cid uuid;
  sid uuid;
  ord uuid;
  n integer;
begin
  insert into public.restaurants (name) values ('counter cafe') returning id into rid;
  insert into public.cashiers (restaurant_id, name, initials, pin_hash) values (rid, 'Sara', 'S', 'x') returning id into cid;
  insert into public.shifts (restaurant_id, cashier_id, opening_cash) values (rid, cid, 0) returning id into sid;

  -- The bug: the till holds 11–60, the counter is back at 6.
  insert into public.receipt_blocks (restaurant_id, cashier_id, year_month, first_no, last_no)
  values (rid, cid, '2610', 11, 60);
  delete from public.order_number_counters where restaurant_id = rid;
  alter table public.order_number_counters disable trigger order_number_counters_lift_month;
  insert into public.order_number_counters (restaurant_id, scope, last_value) values (rid, 'month:2610', 6);
  alter table public.order_number_counters enable trigger order_number_counters_lift_month;

  -- ------------------------------------------------------------ one sale skips the reserved block
  insert into public.order_number_counters as c (restaurant_id, scope, last_value)
  values (rid, 'month:2610', 1)
  on conflict (restaurant_id, scope) do update set last_value = c.last_value + 1
  returning last_value into n;
  assert n = 61, 'a sale takes the number after the reserved block, got ' || n;

  -- ------------------------------------------------------------ a number a sale already has
  insert into public.orders (restaurant_id, table_id, status, service_type) values (rid, null, 'paid', 'takeout') returning id into ord;
  insert into public.payments (restaurant_id, order_id, total_due, cash_received, change_due, cashier_id, shift_id, client_id, year_month, monthly_order_number)
  values (rid, ord, 5, 5, 0, cid, sid, gen_random_uuid(), '2610', 70);
  insert into public.order_number_counters as c (restaurant_id, scope, last_value)
  values (rid, 'month:2610', 1)
  on conflict (restaurant_id, scope) do update set last_value = c.last_value + 1
  returning last_value into n;
  assert n = 71, 'a sale skips numbers sales already have, got ' || n;

  -- ------------------------------------------------------------ a block of 5 keeps its size
  insert into public.order_number_counters as c (restaurant_id, scope, last_value)
  values (rid, 'month:2610', 5)
  on conflict (restaurant_id, scope) do update set last_value = c.last_value + 5
  returning last_value into n;
  assert n = 76, 'a block of 5 after 71 ends at 76, got ' || n;

  -- ------------------------------------------------------------ a new month starts above its own block
  insert into public.receipt_blocks (restaurant_id, cashier_id, year_month, first_no, last_no)
  values (rid, cid, '2611', 1, 50);
  insert into public.order_number_counters as c (restaurant_id, scope, last_value)
  values (rid, 'month:2611', 1)
  on conflict (restaurant_id, scope) do update set last_value = c.last_value + 1
  returning last_value into n;
  assert n = 51, 'the first counted number of a month skips its block, got ' || n;

  -- ------------------------------------------------------------ an ordinary month counts on
  insert into public.order_number_counters as c (restaurant_id, scope, last_value)
  values (rid, 'month:2612', 1)
  on conflict (restaurant_id, scope) do update set last_value = c.last_value + 1
  returning last_value into n;
  assert n = 1, 'a month with nothing taken starts at 1, got ' || n;
  insert into public.order_number_counters as c (restaurant_id, scope, last_value)
  values (rid, 'month:2612', 1)
  on conflict (restaurant_id, scope) do update set last_value = c.last_value + 1
  returning last_value into n;
  assert n = 2, 'then 2, got ' || n;

  -- ------------------------------------------------------------ daily order numbers are untouched
  insert into public.order_number_counters as c (restaurant_id, scope, last_value)
  values (rid, 'day:261030', 1)
  on conflict (restaurant_id, scope) do update set last_value = c.last_value + 1
  returning last_value into n;
  assert n = 1, 'daily counters are not lifted, got ' || n;

  raise notice 'receipt counter floor: all checks passed';
end;
$test$;

rollback;
