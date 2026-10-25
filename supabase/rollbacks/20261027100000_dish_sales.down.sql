-- Undoes 20261027100000_dish_sales.sql. Nothing else uses the function.
drop function if exists public.admin_dish_sales(date, date);
