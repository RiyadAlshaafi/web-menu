-- Fix: since 20261018100000_dish_choices.sql an admin could not save any dish. The menu_items check
-- constraint calls private.valid_dish_options as the signed-in role, but execute on it was revoked,
-- so every direct insert/update of a dish failed with "permission denied for function".
-- The function only checks the shape of a JSON value, so the app roles may run it.

grant execute on function private.valid_dish_options(jsonb) to anon, authenticated;
