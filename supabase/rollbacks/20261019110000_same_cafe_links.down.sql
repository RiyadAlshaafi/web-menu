-- Undoes 20261019110000_same_cafe_links.sql: removes the same-cafe link checks and the paid-order freeze.

drop trigger if exists zz_same_cafe on public.order_lines;
drop trigger if exists zz_same_cafe on public.orders;
drop trigger if exists zz_same_cafe on public.menu_items;
drop trigger if exists zz_same_cafe on public.shifts;
drop trigger if exists zz_same_cafe on public.staff_calls;
drop trigger if exists zz_same_cafe on public.payments;
drop trigger if exists zz_same_cafe on public.shift_expenses;
drop trigger if exists freeze_paid_order on public.order_lines;
drop trigger if exists freeze_paid_order on public.orders;
drop function if exists private.check_same_cafe();
drop function if exists private.freeze_paid_order();
