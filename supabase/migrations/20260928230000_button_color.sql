alter table public.restaurants
  add column if not exists button_color text not null default '';
