-- Take a one-time copy of existing guest colors before POS and QR saves diverge.
alter table public.restaurants
  add column if not exists pos_card_color text not null default '',
  add column if not exists qr_theme jsonb
    check (jsonb_typeof(qr_theme) = 'object');

update public.restaurants
set qr_theme = jsonb_build_object(
  'header', header_color,
  'background', background_color,
  'button', button_color
)
where qr_theme is null;

alter table public.restaurants
  alter column qr_theme set default '{}'::jsonb,
  alter column qr_theme set not null;

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
      'header_color', coalesce(cafe.qr_theme->>'header', ''),
      'button_color', coalesce(cafe.qr_theme->>'button', ''),
      'background_color', coalesce(cafe.qr_theme->>'background', ''),
      'bottom_bar_color', coalesce(cafe.qr_theme->>'bottomBar', ''),
      'card_color', coalesce(cafe.qr_theme->>'card', ''),
      'service_charge_rate', cafe.service_charge_rate,
      'menu_layout', cafe.guest_menu_layout
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
