-- Undoes 20261030100000_receipt_counter_floor.sql: drops the trigger, its function and the index.
-- Counters it lifted stay lifted; lowering them would hand out used receipt numbers again.

drop trigger if exists order_number_counters_lift_month on public.order_number_counters;
drop function if exists private.lift_month_counter();
drop index if exists public.receipt_blocks_restaurant_month_idx;
