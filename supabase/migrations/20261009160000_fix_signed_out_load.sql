-- A signed-out till (sign-in screen) loads the cafe as the anon role. The shift_expenses_cashier
-- policy calls private.session_cashier_id(), which anon could not execute, so the whole startup
-- load failed and the sign-in screen showed no cashiers. The function only reads the caller's own
-- cashier token (like private.cashier_restaurant_id, which anon can already run).
grant execute on function private.session_cashier_id() to anon, authenticated;
