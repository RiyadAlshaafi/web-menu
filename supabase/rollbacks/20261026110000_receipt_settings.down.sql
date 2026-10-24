-- Undoes 20261026110000_receipt_settings.sql. No function reads the column.
alter table public.restaurants drop constraint if exists restaurants_receipt_settings_shape;
alter table public.restaurants drop column if exists receipt_settings;
