drop function if exists public.create_cashier(text, text, text, text);
drop function if exists public.list_pos_cashiers(uuid);

create or replace function public.list_pos_cashiers(p_restaurant_id uuid default null)
returns table (id uuid, name text, initials text)
language sql
stable
security definer
set search_path = ''
as $$
  select c.id, c.name, c.initials
  from public.cashiers c
  where p_restaurant_id is not null
    and c.restaurant_id = p_restaurant_id
    and c.active;
$$;
grant execute on function public.list_pos_cashiers(uuid) to anon, authenticated;

create or replace function public.create_cashier(p_name text, p_pin text, p_initials text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  rid uuid := private.current_restaurant_id();
  new_id uuid;
begin
  if rid is null or auth.uid() is null then
    raise exception 'admin sign-in required';
  end if;
  if p_pin !~ '^[0-9]{4}$' then
    raise exception 'PIN must be 4 digits';
  end if;
  insert into public.cashiers (restaurant_id, name, initials, pin_hash)
  values (rid, btrim(p_name), p_initials, extensions.crypt(p_pin, extensions.gen_salt('bf')))
  returning id into new_id;
  return new_id;
end;
$$;
revoke all on function public.create_cashier(text, text, text) from public;
grant execute on function public.create_cashier(text, text, text) to authenticated;

alter table public.cashiers drop column if exists role;
