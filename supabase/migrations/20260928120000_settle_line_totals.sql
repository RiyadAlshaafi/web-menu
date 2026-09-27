-- Charge every open line at qty * unit price, then clear only that table's cart
-- after the payment row exists.

create or replace function public.settle_cash(p_table_id uuid, p_cash_received numeric)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  rid uuid := private.cashier_restaurant_id();
  admin_rid uuid := private.current_restaurant_id();
  actor uuid := coalesce(rid, admin_rid);
  ord public.orders%rowtype;
  due numeric;
  shift public.shifts%rowtype;
  cid uuid;
begin
  if actor is null then
    return jsonb_build_object('ok', false, 'error', 'sign in as a cashier first');
  end if;
  select * into ord
  from public.orders
  where table_id = p_table_id
    and restaurant_id = actor
    and status <> 'paid'
  order by created_at desc
  limit 1;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'no open bill');
  end if;
  select coalesce((select sum(qty * unit_price) from public.order_lines where order_id = ord.id), 0)
    + coalesce((select sum(qty * unit_price) from public.cart_lines where table_id = p_table_id), 0)
  into due;
  due := round(due * (1 + (select service_charge_rate from public.restaurants where id = actor)), 2);
  if p_cash_received < due then
    return jsonb_build_object('ok', false, 'error', 'insufficient cash');
  end if;
  cid := coalesce(
    (select cashier_id from public.cashier_sessions s
      where s.token_hash = encode(extensions.digest(coalesce(private.header('x-cashier-token'), ''), 'sha256'), 'hex')
        and s.expires_at > now()
      limit 1),
    (select id from public.cashiers where restaurant_id = actor order by created_at limit 1)
  );
  if cid is null then
    return jsonb_build_object('ok', false, 'error', 'sign in as a cashier first');
  end if;
  select * into shift
  from public.shifts
  where cashier_id = cid and restaurant_id = actor and closed_at is null
  order by opened_at desc
  limit 1;
  if not found then
    insert into public.shifts (restaurant_id, cashier_id, opening_cash)
    values (actor, cid, 0)
    returning * into shift;
  end if;
  insert into public.payments (
    restaurant_id, order_id, table_id, total_due, cash_received, change_due, cashier_id, shift_id
  ) values (
    actor, ord.id, p_table_id, due, p_cash_received, p_cash_received - due, cid, shift.id
  );
  update public.orders set status = 'paid' where id = ord.id;
  update public.dining_tables set status = 'free', guests = 0 where id = p_table_id;
  delete from public.cart_lines where table_id = p_table_id;
  delete from public.carts where table_id = p_table_id;
  update public.staff_calls set resolved = true where table_id = p_table_id and resolved = false;
  update public.shifts
    set cash_sales = cash_sales + due,
        transaction_count = transaction_count + 1
    where id = shift.id;
  return jsonb_build_object('ok', true, 'total_due', due);
end;
$$;

do $$
begin
  alter publication supabase_realtime add table public.carts;
exception
  when duplicate_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.cart_lines;
exception
  when duplicate_object then null;
end $$;
