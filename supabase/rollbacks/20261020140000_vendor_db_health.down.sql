-- Undoes 20261020140000_vendor_db_health.sql: the vendor database health report is removed.
drop function if exists public.vendor_db_health(text);
