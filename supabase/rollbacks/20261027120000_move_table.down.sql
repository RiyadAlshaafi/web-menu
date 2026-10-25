-- Undoes 20261027120000_move_table.sql. Nothing else uses the function.
drop function if exists public.cashier_move_table(uuid, uuid);
