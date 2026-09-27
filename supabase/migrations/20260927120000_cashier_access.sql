-- A cashier signs in with a PIN token, not a Supabase user account.
-- These policies let that token read and update only its own restaurant.

create policy restaurants_cashier on public.restaurants
  for select to anon
  using (id = private.cashier_restaurant_id());

create policy tables_cashier on public.dining_tables
  for all to anon
  using (restaurant_id = private.cashier_restaurant_id())
  with check (restaurant_id = private.cashier_restaurant_id());

create policy categories_cashier on public.menu_categories
  for select to anon
  using (restaurant_id = private.cashier_restaurant_id());

create policy items_cashier on public.menu_items
  for select to anon
  using (restaurant_id = private.cashier_restaurant_id());

create policy orders_cashier on public.orders
  for all to anon
  using (restaurant_id = private.cashier_restaurant_id())
  with check (restaurant_id = private.cashier_restaurant_id());

create policy lines_cashier on public.order_lines
  for all to anon
  using (restaurant_id = private.cashier_restaurant_id())
  with check (restaurant_id = private.cashier_restaurant_id());

create policy shifts_cashier on public.shifts
  for all to anon
  using (restaurant_id = private.cashier_restaurant_id())
  with check (restaurant_id = private.cashier_restaurant_id());

create policy payments_cashier on public.payments
  for select to anon
  using (restaurant_id = private.cashier_restaurant_id());
