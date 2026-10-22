-- Removes the monthly archive (20261019150000_monthly_archive.sql). Sales now stay in the database
-- for good; backups come from the Supabase dashboard. Nothing was ever archived, so
-- archived_months is empty, and dropping archive_month_delete means nothing can delete old sales.

drop function if exists public.archive_month_delete(uuid, text, text, text, bigint, text);
drop function if exists public.archive_month_export(uuid, text);
drop function if exists public.archive_due_months();
drop function if exists private.archive_month_rows(uuid, text);
drop function if exists private.archive_keep_from();
drop function if exists private.archive_month_bounds(text);
drop table if exists public.archived_months;
