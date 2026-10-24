-- Undoes 20261025100000_kitchens.sql: categories lose their kitchen and every dish prints on the
-- till's one kitchen printer again.

drop trigger if exists zz_same_cafe on public.menu_categories;
drop index if exists public.menu_categories_kitchen_idx;
alter table public.menu_categories drop column if exists kitchen_id;
drop table if exists public.kitchens;
