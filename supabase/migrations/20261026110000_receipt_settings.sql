-- How the cafe's printouts look, the same on every till: cafe name and logo on or off, header
-- and footer text, and which lines show (order number, table, cashier, service charge...).
-- One json object the app reads and writes whole; keys it does not know are kept as they are.
-- Empty ({}) means the app's defaults, so old app versions and new cafes print as before.
-- Paper width is not here: it belongs to each till's printer and stays on the device.
-- Admins write it through the existing restaurants_update policy (their own cafe only).
-- Safe to run twice.

alter table public.restaurants
  add column if not exists receipt_settings jsonb not null default '{}'::jsonb;

alter table public.restaurants drop constraint if exists restaurants_receipt_settings_shape;
alter table public.restaurants
  add constraint restaurants_receipt_settings_shape
  check (jsonb_typeof(receipt_settings) = 'object' and pg_column_size(receipt_settings) <= 4000);
