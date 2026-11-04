-- Extra Supabase projects ("servers") the tills can be set up on, each with its own 8 cafe slots.
-- Lives on the main project only (server 1). The owner adds a row per new project in the dashboard:
--   insert into public.servers (id, name, url, publishable_key)
--   values (2, 'Server 2', 'https://<ref>.supabase.co', 'sb_publishable_...');
-- Server 1 is the main project itself and is built into the app, so it is not listed here.
-- Only publishable keys go here: they are public by design. Never a secret/service key.

create table if not exists public.servers (
  id smallint primary key check (id between 2 and 99),
  name text not null check (length(trim(name)) between 1 and 60),
  url text not null check (url ~ '^https://[a-z0-9-]+\.supabase\.co$'),
  publishable_key text not null check (publishable_key ~ '^sb_publishable_[A-Za-z0-9_-]+$'),
  active boolean not null default true,
  created_at timestamptz not null default now()
);

-- No direct table access for app users; reads go through list_servers().
alter table public.servers enable row level security;
revoke all on table public.servers from anon, authenticated;

-- The servers the setup and the guest menu may pick from.
create or replace function public.list_servers()
returns table (id smallint, name text, url text, publishable_key text)
language sql
stable
security definer
set search_path = ''
as $$
  select s.id, s.name, s.url, s.publishable_key
  from public.servers s
  where s.active
  order by s.id;
$$;

revoke all on function public.list_servers() from public;
grant execute on function public.list_servers() to anon, authenticated;
