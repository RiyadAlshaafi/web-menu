-- Demo cafes for the guest web app's browser tests and local runs (guest-web/e2e/local-stack.sh).
-- Fixed ids so tests can refer to them. Never applied to a real project.

insert into public.restaurants (id, name, locale, header_color, button_color, service_charge_rate, require_cashier_online)
values ('a0000000-0000-4000-8000-000000000001', 'Akakus Café', 'ar', '#1B3A4B', '#BA5333', 0.10, false);
insert into public.dining_tables (id, restaurant_id, number, qr_slug)
values ('a0000000-0000-4000-8000-0000000000a1', 'a0000000-0000-4000-8000-000000000001', '4', 'demotable0001'),
       ('a0000000-0000-4000-8000-0000000000a2', 'a0000000-0000-4000-8000-000000000001', '5', 'demotable0002');
insert into public.menu_categories (id, restaurant_id, name_en, name_ar, sort_order)
values ('a0000000-0000-4000-8000-0000000000c1', 'a0000000-0000-4000-8000-000000000001', 'Drinks', 'مشروبات', 1),
       ('a0000000-0000-4000-8000-0000000000c2', 'a0000000-0000-4000-8000-000000000001', 'Food', 'طعام', 2);
insert into public.menu_items (id, restaurant_id, category_id, name_en, name_it, description, price, featured, sold_out, available, discount_percent, discount_applied, sort_order)
values
  ('a0000000-0000-4000-8000-000000000101', 'a0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-0000000000c1', 'Mint Tea', 'شاي بالنعناع', 'Fresh mint, green tea.', 5, true, false, true, 0, false, 1),
  ('a0000000-0000-4000-8000-000000000102', 'a0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-0000000000c1', 'Cappuccino', 'كابتشينو', '', 8, false, false, true, 25, true, 2),
  ('a0000000-0000-4000-8000-000000000103', 'a0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-0000000000c1', 'Orange Juice', 'عصير برتقال', '', 6.5, false, false, false, 0, false, 3),
  ('a0000000-0000-4000-8000-000000000104', 'a0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-0000000000c2', 'Cheesecake', 'تشيز كيك', '', 12, false, true, true, 0, false, 1),
  ('a0000000-0000-4000-8000-000000000105', 'a0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-0000000000c2', 'Club Sandwich', 'كلوب ساندويتش', 'Chicken, egg, tomato.', 15, false, false, true, 0, false, 2);
insert into public.payment_types (restaurant_id, name_en, name_ar, sort_order)
select 'a0000000-0000-4000-8000-000000000001', 'Card', 'بطاقة', 9
where not exists (select 1 from public.payment_types where restaurant_id = 'a0000000-0000-4000-8000-000000000001' and name_en = 'Card');

-- Needs a cashier online, and none is.
insert into public.restaurants (id, name, require_cashier_online)
values ('b0000000-0000-4000-8000-000000000001', 'Offline Café', true);
insert into public.dining_tables (restaurant_id, number, qr_slug)
values ('b0000000-0000-4000-8000-000000000001', '1', 'offlinetable1');
insert into public.menu_categories (id, restaurant_id, name_en, name_ar)
values ('b0000000-0000-4000-8000-0000000000c1', 'b0000000-0000-4000-8000-000000000001', 'Drinks', 'مشروبات');
insert into public.menu_items (restaurant_id, category_id, name_en, name_it, price)
values ('b0000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-0000000000c1', 'Espresso', 'إسبريسو', 4);

-- Location check on: Martyrs' Square, Tripoli, 50 m.
insert into public.restaurants (id, name, location_check_enabled, location_lat, location_lng, location_radius_m)
values ('c0000000-0000-4000-8000-000000000001', 'Square Café', true, 32.8955, 13.1810, 50);
insert into public.dining_tables (restaurant_id, number, qr_slug)
values ('c0000000-0000-4000-8000-000000000001', '2', 'squaretable01');
insert into public.menu_categories (id, restaurant_id, name_en, name_ar)
values ('c0000000-0000-4000-8000-0000000000c1', 'c0000000-0000-4000-8000-000000000001', 'Drinks', 'مشروبات');
insert into public.menu_items (restaurant_id, category_id, name_en, name_it, price)
values ('c0000000-0000-4000-8000-000000000001', 'c0000000-0000-4000-8000-0000000000c1', 'Latte', 'لاتيه', 7);
