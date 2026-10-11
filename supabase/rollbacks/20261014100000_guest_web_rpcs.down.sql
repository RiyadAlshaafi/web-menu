-- Undoes 20261014100000_guest_web_rpcs.sql. No data is touched: it only removes the guest web
-- app's functions. The Flutter guest page does not use them and keeps working.
-- Roll back 20261014110000_guest_lock_down.sql first if it was applied, or guests lose access.

drop function if exists public.guest_confirm_refusal(text);
drop function if exists public.guest_call_staff(text);
drop function if exists public.guest_tab(text);
drop function if exists public.guest_status(text);
drop function if exists public.guest_menu(text);
drop function if exists private.table_for_slug(text);
