alter table public.restaurants
  add column if not exists auto_print_receipt boolean not null default true;
