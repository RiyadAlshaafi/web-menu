-- Staff roles: the cashiers table also holds chefs, servers and cleaners.
-- Only cashiers have a PIN and can sign in; the others get an unguessable
-- placeholder hash so cashier_login can never match them.
alter table public.cashiers
  add column if not exists role text not null default 'cashier'
  check (role in ('cashier', 'chef', 'server', 'cleaner'));

drop function if exists public.create_cashier(text, text, text);

create or replace function public.create_cashier(
  p_name text, p_pin text, p_initials text, p_role text default 'cashier')
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  rid uuid := private.current_restaurant_id();
  new_id uuid;
  hash text;
begin
  if rid is null or auth.uid() is null then
    raise exception 'admin sign-in required';
  end if;
  if p_role not in ('cashier', 'chef', 'server', 'cleaner') then
    raise exception 'unknown role';
  end if;
  if p_role = 'cashier' then
    if p_pin !~ '^[0-9]{4}$' then
      raise exception 'PIN must be 4 digits';
    end if;
    hash := extensions.crypt(p_pin, extensions.gen_salt('bf'));
  else
    hash := extensions.crypt(gen_random_uuid()::text, extensions.gen_salt('bf'));
  end if;
  insert into public.cashiers (restaurant_id, name, initials, pin_hash, role)
  values (rid, btrim(p_name), p_initials, hash, p_role)
  returning id into new_id;
  return new_id;
end;
$$;
revoke all on function public.create_cashier(text, text, text, text) from public;
grant execute on function public.create_cashier(text, text, text, text) to authenticated;

drop function if exists public.list_pos_cashiers(uuid);
create or replace function public.list_pos_cashiers(p_restaurant_id uuid default null)
returns table (id uuid, name text, initials text, role text)
language sql
stable
security definer
set search_path = ''
as $$
  select c.id, c.name, c.initials, c.role
  from public.cashiers c
  where p_restaurant_id is not null
    and c.restaurant_id = p_restaurant_id
    and c.active;
$$;
grant execute on function public.list_pos_cashiers(uuid) to anon, authenticated;
