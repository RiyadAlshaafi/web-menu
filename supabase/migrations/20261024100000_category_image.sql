-- A picture for each menu category (shown on the takeout counter).
alter table public.menu_categories add column if not exists image_url text not null default '';
