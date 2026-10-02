create table public.shift_expenses (
  id uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null references public.restaurants (id) on delete cascade,
  shift_id uuid not null references public.shifts (id) on delete cascade,
  cashier_id uuid not null references public.cashiers (id),
  paid_to_cashier_id uuid references public.cashiers (id),
  paid_to_cafe boolean not null default false,
  amount numeric(12, 2) not null check (amount > 0),
  description text not null,
  kind text not null default 'cash_out',
  created_at timestamptz not null default now(),
  constraint shift_expenses_payee check (
    (paid_to_cafe and paid_to_cashier_id is null)
    or (not paid_to_cafe and paid_to_cashier_id is not null)
  )
);

alter table public.shift_expenses enable row level security;

create policy shift_expenses_cashier on public.shift_expenses
  for all to anon
  using (restaurant_id = private.cashier_restaurant_id())
  with check (restaurant_id = private.cashier_restaurant_id());

create policy shift_expenses_staff on public.shift_expenses
  for all to authenticated
  using (restaurant_id = private.actor_restaurant_id())
  with check (restaurant_id = private.actor_restaurant_id());

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'shift_expenses'
  ) then
    alter publication supabase_realtime add table public.shift_expenses;
  end if;
end $$;
