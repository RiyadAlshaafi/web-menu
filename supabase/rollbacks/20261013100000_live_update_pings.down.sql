-- Undoes 20261013100000_live_update_pings.sql. No data is touched: it only stops the pings.
-- Cashiers and guests then fall back to the app's periodic refresh.

do $$
declare
  t text;
begin
  foreach t in array array[
    'orders', 'order_lines', 'carts', 'cart_lines', 'staff_calls', 'payments', 'dining_tables',
    'menu_items', 'menu_categories', 'shifts', 'shift_expenses', 'payment_types', 'expense_categories',
    'restaurants'
  ] loop
    execute format('drop trigger if exists zz_live_ping on public.%I', t);
  end loop;
end $$;
drop function if exists private.live_ping();
