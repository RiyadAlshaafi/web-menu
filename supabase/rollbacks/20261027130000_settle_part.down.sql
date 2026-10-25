-- Undoes 20261027130000_settle_part.sql. Nothing else uses the function.
drop function if exists public.settle_part(uuid, jsonb, numeric, boolean, uuid);
