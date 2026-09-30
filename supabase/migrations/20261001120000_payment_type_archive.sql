-- Hide a payment type that past sales still name, without changing those sales.
alter table public.payment_types
  add column if not exists archived boolean not null default false;
