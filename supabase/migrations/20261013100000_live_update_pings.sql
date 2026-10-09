-- Live updates for cashiers and guests.
--
-- Why: cashier tills and guests are not Supabase Auth users. They prove who they are with request
-- headers (x-cashier-token, x-qr-slug) that the row-level security policies read from
-- request.headers. Realtime "postgres_changes" checks those same policies for each subscriber,
-- but Realtime only sets the role and the JWT claims, never request.headers, so every policy
-- sees no cashier and no guest table and every order event is dropped. Only admins (real
-- Supabase users) received changes; cashiers and guests waited for a reload.
--
-- Fix: after a change, the database broadcasts a ping with no row data to
--   cafe:<restaurant id>   heard by that cafe's cashier and admin devices
--   guest:<table qr slug>  heard only by guests at that table (the slug is already the
--                          guest's key to the table's data)
-- The app then reloads through the normal requests, where the policies apply as before.
-- A ping carries only the changed table's name, so no policy is weakened and no data leaks.
-- One ping per topic per transaction (an order with many lines sends one), and a failed ping
-- never blocks the change itself.
-- Rollback: supabase/rollbacks/20261013100000_live_update_pings.down.sql

create or replace function private.live_ping()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  row_data jsonb := to_jsonb(case when tg_op = 'DELETE' then old else new end);
  cafe uuid;
  table_row uuid;
  slug text;
  topic text;
  sent text := coalesce(current_setting('app.live_pinged', true), '');
begin
  cafe := case when tg_table_name = 'restaurants' then (row_data ->> 'id')::uuid
               else (row_data ->> 'restaurant_id')::uuid end;
  table_row := case tg_table_name
    when 'dining_tables' then (row_data ->> 'id')::uuid
    when 'order_lines' then (select o.table_id from public.orders o where o.id = (row_data ->> 'order_id')::uuid)
    else (row_data ->> 'table_id')::uuid
  end;
  if table_row is not null then
    select t.qr_slug into slug from public.dining_tables t where t.id = table_row;
  end if;

  foreach topic in array array[
    case when cafe is not null then 'cafe:' || cafe end,
    case when slug is not null then 'guest:' || slug end
  ] loop
    continue when topic is null or position(',' || topic || ',' in sent) > 0;
    begin
      perform realtime.send(jsonb_build_object('table', tg_table_name), 'change', topic, false);
      sent := sent || ',' || topic || ',';
    exception when others then
      -- The app's safety refresh catches a missed ping; it must never block a sale.
      raise warning 'live update ping to % failed: %', topic, sqlerrm;
    end;
  end loop;
  perform set_config('app.live_pinged', sent, true);
  return null;
end;
$$;
revoke all on function private.live_ping() from public, anon, authenticated;

-- Everything a cashier or guest screen shows. "zz_" runs it after the other triggers.
do $$
declare
  t text;
begin
  foreach t in array array[
    'orders', 'order_lines', 'carts', 'cart_lines', 'staff_calls', 'payments', 'dining_tables',
    'menu_items', 'menu_categories', 'shifts', 'shift_expenses', 'payment_types', 'expense_categories'
  ] loop
    execute format(
      'create or replace trigger zz_live_ping after insert or update or delete on public.%I '
      'for each row execute function private.live_ping()', t);
  end loop;
end $$;

create or replace trigger zz_live_ping after update on public.restaurants
  for each row execute function private.live_ping();
