-- Undoes 20261029100000_guest_menu_layout.sql: guest_menu as before that migration, then the column.

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
        'sort_order', i.sort_order,
        'options', i.options
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

alter table public.restaurants drop column if exists guest_menu_layout;
