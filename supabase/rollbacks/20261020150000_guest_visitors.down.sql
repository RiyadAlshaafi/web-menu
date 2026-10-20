-- Undoes 20261020150000_guest_visitors.sql: visitor counting and its report are removed.
drop function if exists public.vendor_visitors(text, integer);
drop function if exists public.guest_record_visit(text, text);
drop table if exists public.guest_visit_days;
drop table if exists public.guest_visits;
