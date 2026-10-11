-- Undoes 20261014110000_guest_lock_down.sql: guests can read their own table's rows directly
-- again, as the Flutter guest page needs. Policies are restored exactly as they were before.

create policy carts_guest on public.carts
  for all to anon
  using (table_id = (select (select private.guest_table_id())))
  with check (table_id = (select (select private.guest_table_id())));
create policy cart_lines_guest on public.cart_lines
  for all to anon
  using (table_id = (select (select private.guest_table_id())))
  with check (table_id = (select (select private.guest_table_id())));
create policy calls_guest_select on public.staff_calls
  for select to anon
  using (table_id = (select (select private.guest_table_id())));
create policy calls_guest_insert on public.staff_calls
  for insert to anon
  with check (table_id = (select (select private.guest_table_id()))
              and restaurant_id = (select (select private.guest_restaurant_id())));
create policy calls_guest_update on public.staff_calls
  for update to anon
  using (table_id = (select (select private.guest_table_id())))
  with check (table_id = (select (select private.guest_table_id()))
              and restaurant_id = (select (select private.guest_restaurant_id())));
create policy tables_guest on public.dining_tables
  for select to anon
  using (id = (select private.guest_table_id()));
create policy categories_guest on public.menu_categories
  for select to anon
  using (restaurant_id = (select private.guest_restaurant_id()) and visible);
create policy items_guest on public.menu_items
  for select to anon
  using (restaurant_id = (select private.guest_restaurant_id()));
create policy orders_guest_select on public.orders
  for select to anon
  using (table_id = (select private.guest_table_id()));
create policy lines_guest_select on public.order_lines
  for select to anon
  using (order_id in (select orders.id from public.orders where orders.table_id = (select private.guest_table_id())));
create policy restaurants_guest_select on public.restaurants
  for select to anon
  using (id = (select private.guest_restaurant_id()));

drop policy if exists restaurants_select on public.restaurants;
create policy restaurants_select on public.restaurants
  for select to authenticated
  using (id = (select private.actor_restaurant_id()) or id = (select private.guest_restaurant_id()));

drop policy if exists payment_types_read on public.payment_types;
create policy payment_types_read on public.payment_types
  for select to anon, authenticated
  using (restaurant_id = (select private.actor_restaurant_id())
         or (restaurant_id = (select private.guest_restaurant_id()) and enabled));
