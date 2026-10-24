-- Undoes 20261024100000_category_image.sql.
alter table public.menu_categories drop column if exists image_url;
