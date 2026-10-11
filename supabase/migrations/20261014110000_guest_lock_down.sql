-- Guests stop reading and writing tables directly. Everything a guest sees or does now goes
-- through functions: guest_menu, guest_status, guest_tab, guest_call_staff,
-- guest_confirm_refusal (20261014100000_guest_web_rpcs.sql), and send_table_cart, request_bill,
-- set_table_payment_type, guest_location_rule.
--
-- Apply only after every cafe's QR code opens the guest web app: the Flutter guest page reads
-- these tables directly and stops loading its menu once this runs. Cashier and admin access is
-- unchanged (their own policies stay).
-- Rollback: supabase/rollbacks/20261014110000_guest_lock_down.down.sql

drop policy if exists carts_guest on public.carts;
drop policy if exists cart_lines_guest on public.cart_lines;
drop policy if exists calls_guest_select on public.staff_calls;
drop policy if exists calls_guest_insert on public.staff_calls;
drop policy if exists calls_guest_update on public.staff_calls;
drop policy if exists tables_guest on public.dining_tables;
drop policy if exists categories_guest on public.menu_categories;
drop policy if exists items_guest on public.menu_items;
drop policy if exists orders_guest_select on public.orders;
drop policy if exists lines_guest_select on public.order_lines;
drop policy if exists restaurants_guest_select on public.restaurants;

-- Staff keep their branch; the guest branch goes.
drop policy if exists restaurants_select on public.restaurants;
create policy restaurants_select on public.restaurants
  for select to authenticated
  using (id = (select private.actor_restaurant_id()));

drop policy if exists payment_types_read on public.payment_types;
create policy payment_types_read on public.payment_types
  for select to anon, authenticated
  using (restaurant_id = (select private.actor_restaurant_id()));
