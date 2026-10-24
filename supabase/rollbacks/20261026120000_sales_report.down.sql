-- Undoes 20261026120000_sales_report.sql. Nothing else uses the function.
drop function if exists public.admin_sales_report(date, date);
