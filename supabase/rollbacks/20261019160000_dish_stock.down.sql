-- Undoes 20261019160000_dish_stock.sql: dishes are no longer counted.
drop trigger if exists take_dish_stock on public.order_lines;
drop trigger if exists dish_stock_sold_out on public.menu_items;
drop function if exists private.take_dish_stock();
drop function if exists private.dish_stock_sold_out();
alter table public.menu_items drop column if exists stock_qty;
