-- Cafe name, logo, public menu URL, and theme colors live on the restaurant.

alter table public.restaurants
  add column if not exists logo_url text not null default '',
  add column if not exists public_menu_url text not null default '',
  add column if not exists header_color text not null default '',
  add column if not exists sidebar_color text not null default '',
  add column if not exists background_color text not null default '';
