-- Removes the clear_test_logs test helper. Any signed-in cashier could call it and wipe every
-- payment of the cafe, so it must not exist on a live database. The app no longer calls it.

drop function if exists public.clear_test_logs(text);
