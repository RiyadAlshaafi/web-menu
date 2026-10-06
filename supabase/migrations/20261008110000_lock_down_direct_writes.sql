-- Security fixes, part 2. APPLY ONLY AFTER the app build that uses the RPCs from
-- 20261008100000_security_and_money_fixes.sql is deployed: older builds still
-- write these tables directly and would break (status changes, bill requests,
-- closing a shift).
--
-- Cashier devices (PIN token, anon role) become read-only on orders, order
-- lines and shifts; every change goes through the RPCs, which only touch the
-- columns they own. That stops a cashier device from editing shift totals or a
-- line's unit price, and stops stale devices overwriting server totals.
--
-- Guests lose the direct-write policies that only existed before the RPCs:
-- updating their table row (any column), inserting orders, inserting lines.

drop policy if exists tables_guest_update on public.dining_tables;
drop policy if exists orders_guest_insert on public.orders;
drop policy if exists lines_guest_insert on public.order_lines;

drop policy if exists orders_cashier on public.orders;
create policy orders_cashier on public.orders
  for select to anon
  using (restaurant_id = (select private.cashier_restaurant_id()));

drop policy if exists lines_cashier on public.order_lines;
create policy lines_cashier on public.order_lines
  for select to anon
  using (restaurant_id = (select private.cashier_restaurant_id()));

drop policy if exists shifts_cashier on public.shifts;
create policy shifts_cashier on public.shifts
  for select to anon
  using (restaurant_id = (select private.cashier_restaurant_id()));
