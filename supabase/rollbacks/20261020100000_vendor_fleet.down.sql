-- Undoes 20261020100000_vendor_fleet.sql: the vendor fleet list is removed.
drop function if exists public.vendor_fleet(text);
