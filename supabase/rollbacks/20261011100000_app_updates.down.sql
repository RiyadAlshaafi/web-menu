-- Undoes 20261011100000_app_updates.sql. Run it only if that migration must be taken back.
-- Nothing in it holds customer data: it removes the update helpers and the version column.
-- Tills on an app that calls these functions keep selling; their update check simply fails.

drop function if exists public.dev_set_min_app_version(text, text);
drop function if exists public.dev_list_devices(text);
drop function if exists public.confirm_uploads(uuid[]);
drop function if exists public.cashier_heartbeat_v2(text);
alter table public.cashier_presence drop column if exists app_version;
drop function if exists public.app_release_info();
drop table if exists public.app_release;
