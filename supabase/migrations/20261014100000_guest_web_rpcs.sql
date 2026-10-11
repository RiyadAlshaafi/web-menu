-- Guest web app (guest-web/, Next.js): one server function per guest screen or action.
--
-- The guest web app calls Supabase only from its server, with the publishable (anon) key, and
-- only through functions. Each function finds the table from the QR slug it is given (never from
-- anything else), and returns only what a guest screen shows:
--   guest_menu            cafe name, logo, colours, visible categories, their dishes, payment types
--   guest_status          is ordering open (cashier online), is the location check on
--   guest_tab             the table's open order only (not its paid history)
--   guest_call_staff      one open "assistance" call per table; repeat taps re-use it
--   guest_confirm_refusal clears the "item removed" notice and asks for the bill, in one step
-- Orders, bills and payment methods keep using send_table_cart, request_bill and
-- set_table_payment_type, unchanged.
--
-- Additive only: nothing existing changes, so the Flutter guest page keeps working alongside.
-- The direct guest table access is removed later by 20261014110000_guest_lock_down.sql.
-- Rollback: supabase/rollbacks/20261014100000_guest_web_rpcs.down.sql

-- The non-archived table a QR slug names, or null.
create or replace function private.table_for_slug(p_qr_slug text)
returns public.dining_tables
language sql
stable
security definer
set search_path = ''
as $$
  select t.*
  from public.dining_tables t
  where t.qr_slug = nullif(btrim(coalesce(p_qr_slug, '')), '')
    and not t.archived
  limit 1;
$$;
revoke all on function private.table_for_slug(text) from public, anon, authenticated;

-- Menu, branding and payment types for the slug's cafe. Only display columns: the cafe's
-- coordinates, slot, setup and gate settings are not returned.
create or replace function public.guest_menu(p_qr_slug text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  tbl public.dining_tables;
  cafe public.restaurants%rowtype;
begin
  tbl := private.table_for_slug(p_qr_slug);
  if tbl.id is null then
    return jsonb_build_object('ok', false, 'error', 'table not found');
  end if;
  select * into cafe from public.restaurants where id = tbl.restaurant_id;

  return jsonb_build_object(
    'ok', true,
    'cafe', jsonb_build_object(
      'id', cafe.id,
      'name', cafe.name,
      'locale', cafe.locale,
      'logo_url', cafe.logo_url,
      'header_color', cafe.header_color,
      'button_color', cafe.button_color,
      'background_color', cafe.background_color,
      'service_charge_rate', cafe.service_charge_rate
    ),
    'table', jsonb_build_object('number', tbl.number),
    'categories', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', c.id,
        'name_en', c.name_en,
        'name_ar', c.name_ar,
        'sort_order', c.sort_order
      ) order by c.sort_order, c.created_at)
      from public.menu_categories c
      where c.restaurant_id = tbl.restaurant_id and c.visible
    ), '[]'::jsonb),
    'items', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', i.id,
        'category_id', i.category_id,
        'name_en', i.name_en,
        'name_ar', i.name_it,
        'description', i.description,
        'price', i.price,
        'sale_price', private.menu_sale_price(i.id),
        'image_url', i.image_url,
        'available', i.available and not i.sold_out,
        'featured', i.featured,
        'sort_order', i.sort_order
      ) order by i.sort_order, i.created_at)
      from public.menu_items i
      join public.menu_categories c on c.id = i.category_id and c.visible
      where i.restaurant_id = tbl.restaurant_id
    ), '[]'::jsonb),
    'payment_types', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', p.id,
        'name_en', p.name_en,
        'name_ar', p.name_ar
      ) order by p.sort_order, p.created_at)
      from public.payment_types p
      where p.restaurant_id = tbl.restaurant_id and p.enabled and not p.archived
    ), '[]'::jsonb)
  );
end;
$$;

-- Whether this table can order right now, and whether the location check is on.
create or replace function public.guest_status(p_qr_slug text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  tbl public.dining_tables;
  cafe public.restaurants%rowtype;
begin
  tbl := private.table_for_slug(p_qr_slug);
  if tbl.id is null then
    return jsonb_build_object('ok', false, 'error', 'table not found');
  end if;
  select * into cafe from public.restaurants where id = tbl.restaurant_id;
  return jsonb_build_object(
    'ok', true,
    'ordering_open', (not cafe.require_cashier_online) or private.cashier_online(cafe.id),
    'location', jsonb_build_object(
      'enabled', cafe.location_check_enabled and cafe.location_lat is not null and cafe.location_lng is not null,
      'radius_m', cafe.location_radius_m
    )
  );
end;
$$;

-- The table and its open order (with lines), or a null order. Paid orders are not returned.
create or replace function public.guest_tab(p_qr_slug text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  tbl public.dining_tables;
  ord public.orders%rowtype;
begin
  tbl := private.table_for_slug(p_qr_slug);
  if tbl.id is null then
    return jsonb_build_object('ok', false, 'error', 'table not found');
  end if;
  select * into ord
  from public.orders
  where table_id = tbl.id and status <> 'paid'
  order by created_at desc
  limit 1;

  return jsonb_build_object(
    'ok', true,
    'table', jsonb_build_object('number', tbl.number, 'status', tbl.status),
    'order', case when ord.id is null then null else jsonb_build_object(
      'id', ord.id,
      'status', ord.status,
      'created_at', ord.created_at,
      'order_number', ord.shift_order_number,
      'service_type', ord.service_type,
      'awaiting_confirmation', ord.awaiting_customer_confirmation,
      'refusal_notice', ord.refusal_notice,
      'payment_type_id', ord.payment_type_id,
      'lines', coalesce((
        select jsonb_agg(jsonb_build_object(
          'id', l.id,
          'menu_item_id', l.menu_item_id,
          'name', l.name,
          'qty', l.qty,
          'unit_price', l.unit_price,
          'list_unit_price', l.list_unit_price,
          'round', l.round
        ) order by l.round, l.id)
        from public.order_lines l
        where l.order_id = ord.id
      ), '[]'::jsonb)
    ) end
  );
end;
$$;

-- Calls staff to the table. While an assistance call is still open, a repeat tap re-uses it.
-- Refused while the cafe needs a cashier online and none is (trigger zz_guest_needs_cashier).
create or replace function public.guest_call_staff(p_qr_slug text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  tbl public.dining_tables;
begin
  tbl := private.table_for_slug(p_qr_slug);
  if tbl.id is null then
    return jsonb_build_object('ok', false, 'error', 'table not found');
  end if;
  -- One open call per table: lock the table row so two taps can't both insert.
  perform 1 from public.dining_tables where id = tbl.id for update;
  if exists (
    select 1 from public.staff_calls
    where table_id = tbl.id and kind = 'assistance' and not resolved
  ) then
    return jsonb_build_object('ok', true, 'reused', true);
  end if;
  begin
    insert into public.staff_calls (restaurant_id, table_id, kind)
    values (tbl.restaurant_id, tbl.id, 'assistance');
  exception when raise_exception then
    if sqlerrm = 'cashier_offline' then
      return jsonb_build_object('ok', false, 'error', 'cashier_offline');
    end if;
    raise;
  end;
  return jsonb_build_object('ok', true, 'reused', false);
end;
$$;

-- The guest saw "item removed" and confirms: clear the notice and ask for the bill, as the
-- Flutter guest page does with confirm_order_refusal followed by request_bill.
create or replace function public.guest_confirm_refusal(p_qr_slug text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  tbl public.dining_tables;
  ord public.orders%rowtype;
  result jsonb;
begin
  tbl := private.table_for_slug(p_qr_slug);
  if tbl.id is null then
    return jsonb_build_object('ok', false, 'error', 'table not found');
  end if;
  select * into ord
  from public.orders
  where table_id = tbl.id and status <> 'paid'
  order by created_at desc
  limit 1
  for update;
  if ord.id is null then
    return jsonb_build_object('ok', false, 'error', 'no open bill');
  end if;
  update public.orders
    set awaiting_customer_confirmation = false,
        refusal_notice = ''
    where id = ord.id;
  -- A refused bill call (cashier offline) lands in the handler below, which also undoes the
  -- update above, so the notice stays until the bill request goes through.
  result := public.request_bill(tbl.qr_slug, null);
  return result;
exception when raise_exception then
  if sqlerrm = 'cashier_offline' then
    return jsonb_build_object('ok', false, 'error', 'cashier_offline');
  end if;
  raise;
end;
$$;

do $$
declare
  f text;
begin
  foreach f in array array[
    'public.guest_menu(text)',
    'public.guest_status(text)',
    'public.guest_tab(text)',
    'public.guest_call_staff(text)',
    'public.guest_confirm_refusal(text)'
  ] loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
    execute format('grant execute on function %s to anon', f);
  end loop;
end $$;
