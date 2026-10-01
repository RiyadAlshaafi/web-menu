-- Publish the tables the app listens to. Skip any table already in supabase_realtime.
-- On the live project only menu_items was missing; the others were already published.

do $$
declare
  t text;
begin
  foreach t in array array[
    'orders',
    'order_lines',
    'carts',
    'cart_lines',
    'staff_calls',
    'menu_items',
    'dining_tables'
  ]
  loop
    if not exists (
      select 1
      from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = t
    ) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;
