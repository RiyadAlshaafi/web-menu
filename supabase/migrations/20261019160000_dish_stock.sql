-- Dish stock: an admin can say "13 of this dish are left". Every sold dish lowers the count and at
-- 0 the dish turns sold out, on every till and on the guest menu. Null (the default) means no limit.
--
-- The count falls when a dish is put on an order (a table round, a quick takeout or an offline sale
-- uploaded later), because that is when it leaves the kitchen. It never goes below 0: a sale made
-- offline already happened, so it is recorded even when the count ran out meanwhile.
-- Rollback: drop the two triggers and functions, then the column.

alter table public.menu_items
  add column if not exists stock_qty integer
  constraint menu_items_stock_qty_check check (stock_qty is null or (stock_qty >= 0 and stock_qty <= 100000));

-- A dish with none left stays sold out, even when a till saves an older copy of it.
create or replace function private.dish_stock_sold_out()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.stock_qty = 0 then
    new.sold_out := true;
  end if;
  return new;
end;
$$;

create or replace trigger dish_stock_sold_out before insert or update on public.menu_items
  for each row execute function private.dish_stock_sold_out();

-- Runs as the owner: a guest's order may lower the count, though guests cannot edit dishes.
create or replace function private.take_dish_stock()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.menu_item_id is null or coalesce(new.qty, 0) <= 0 then
    return null;
  end if;
  update public.menu_items
    set stock_qty = greatest(stock_qty - new.qty, 0)
    where id = new.menu_item_id
      and restaurant_id = new.restaurant_id
      and stock_qty is not null;
  return null;
end;
$$;

create or replace trigger take_dish_stock after insert on public.order_lines
  for each row execute function private.take_dish_stock();

revoke all on function private.dish_stock_sold_out() from public, anon, authenticated;
revoke all on function private.take_dish_stock() from public, anon, authenticated;
