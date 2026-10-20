-- Undoes 20261020130000_vendor_export_logs.sql: the vendor log backup is removed.
drop function if exists public.vendor_export_logs(text, uuid, timestamptz, timestamptz);
