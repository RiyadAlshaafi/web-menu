-- Which takeout counter the cafe uses: 'cards' (category cards) or 'classic' (all dishes + category bar).
alter table public.restaurants
  add column if not exists takeout_layout text not null default 'cards'
  check (takeout_layout in ('cards', 'classic'));
