-- Undoes 20261024110000_takeout_layout.sql.
alter table public.restaurants drop column if exists takeout_layout;
