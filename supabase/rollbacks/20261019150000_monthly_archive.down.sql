-- Undoes 20261019150000_monthly_archive.sql. Months already archived stay in R2 only; restore
-- them before rolling back if the app must show them again.

drop function if exists public.archive_month_delete(uuid, text, text, text, bigint, text);
drop function if exists public.archive_month_export(uuid, text);
drop function if exists public.archive_due_months();
drop function if exists private.archive_month_rows(uuid, text);
drop function if exists private.archive_keep_from();
drop function if exists private.archive_month_bounds(text);
drop table if exists public.archived_months;
