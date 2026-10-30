-- Receipt numbers never repeat: the monthly counter can no longer hand out a number a sale
-- already has, or one a till holds in a reserved block for offline sales.
--
-- Why: a cafe's 'month:YYMM' counter was found at 6 while its till held the block 11–60 and had
-- printed receipts 11–31 from it. Table sales then took 1, 2, 3… from the counter, so receipts
-- went out of order, and the 11th table sale would hit payments_monthly_number_key and fail.
--
-- How: every write to a 'month:' counter (each settle, takeout, offline sync or block reserve
-- adds to it with insert … on conflict do update … returning) is lifted above the highest
-- number already taken that month, keeping the size of the step. One sale still gets one
-- number and a block of n still gets n numbers in a row, only never ones already used.

create or replace function private.lift_month_counter()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  yymm text;
  step integer;
  taken integer;
begin
  if new.scope not like 'month:%' then
    return new;
  end if;
  yymm := substr(new.scope, 7);
  step := new.last_value - case when tg_op = 'UPDATE' then old.last_value else 0 end;
  if step <= 0 then
    return new;
  end if;
  select greatest(
    coalesce((select max(p.monthly_order_number) from public.payments p
              where p.restaurant_id = new.restaurant_id and p.year_month = yymm), 0),
    coalesce((select max(b.last_no) from public.receipt_blocks b
              where b.restaurant_id = new.restaurant_id and b.year_month = yymm), 0)
  ) into taken;
  new.last_value := greatest(new.last_value, taken + step);
  return new;
end;
$$;

revoke all on function private.lift_month_counter() from public, anon, authenticated;

-- Finding the highest reserved block of a month stays quick.
create index if not exists receipt_blocks_restaurant_month_idx
  on public.receipt_blocks (restaurant_id, year_month, last_no);

-- Mend counters that are already behind: lift each to the highest number taken in its month.
-- This runs before the trigger exists, which would otherwise add the step again.
update public.order_number_counters c
set last_value = t.taken
from (
  select restaurant_id, 'month:' || year_month as scope, max(n) as taken
  from (
    select restaurant_id, year_month, monthly_order_number as n
    from public.payments where monthly_order_number is not null
    union all
    select restaurant_id, year_month, last_no
    from public.receipt_blocks where last_no is not null
  ) used
  group by restaurant_id, year_month
) t
where c.restaurant_id = t.restaurant_id and c.scope = t.scope and c.last_value < t.taken;

drop trigger if exists order_number_counters_lift_month on public.order_number_counters;
create trigger order_number_counters_lift_month
  before insert or update of last_value on public.order_number_counters
  for each row execute function private.lift_month_counter();
