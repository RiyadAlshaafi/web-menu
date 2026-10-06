-- Hidden developer tools. The password is stored only as a sha256 hex hash.
-- Destructive functions re-check that hash so they cannot be called by name alone.

create table public.dev_access (
  id uuid primary key default gen_random_uuid(),
  password_hash text not null,
  created_at timestamptz not null default now()
);

alter table public.dev_access enable row level security;

insert into public.dev_access (password_hash)
values (encode(extensions.digest('RomanRiyad#1', 'sha256'), 'hex'));

create or replace function public.check_dev_access(p_password text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.dev_access
    where password_hash = encode(extensions.digest(coalesce(p_password, ''), 'sha256'), 'hex')
  );
$$;

create or replace function private.dev_restaurant_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    private.actor_restaurant_id(),
    (select id from public.restaurants order by created_at limit 1)
  );
$$;

create or replace function private.dev_allowed(p_password text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.check_dev_access(p_password);
$$;

create or replace function public.dev_reset_admin(p_password text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := private.dev_restaurant_id();
  removed integer := 0;
begin
  if not private.dev_allowed(p_password) then
    return jsonb_build_object('ok', false);
  end if;
  if actor is null then
    return jsonb_build_object('ok', false, 'error', 'no restaurant');
  end if;
  delete from auth.users
  where id in (
    select id from public.profiles where restaurant_id = actor and role = 'admin'
  );
  get diagnostics removed = row_count;
  return jsonb_build_object('ok', true, 'removed', removed);
end;
$$;

create or replace function public.dev_export_logs(p_password text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  actor uuid := private.dev_restaurant_id();
begin
  if not private.dev_allowed(p_password) then
    return jsonb_build_object('ok', false);
  end if;
  if actor is null then
    return jsonb_build_object('ok', false, 'error', 'no restaurant');
  end if;
  return jsonb_build_object(
    'ok', true,
    'payments', coalesce((
      select jsonb_agg(to_jsonb(p))
      from (
        select
          pay.id,
          pay.paid_at,
          pay.total_due,
          pay.cash_received,
          pay.change_due,
          pay.shift_display_number,
          pay.monthly_display_number,
          ord.service_type,
          tbl.number as table_number,
          coalesce((
            select jsonb_agg(jsonb_build_object(
              'name', line.name,
              'qty', line.qty,
              'unit_price', line.unit_price
            ))
            from public.order_lines line
            where line.order_id = pay.order_id
          ), '[]'::jsonb) as lines
        from public.payments pay
        left join public.orders ord on ord.id = pay.order_id
        left join public.dining_tables tbl on tbl.id = pay.table_id
        where pay.restaurant_id = actor
        order by pay.paid_at
      ) p
    ), '[]'::jsonb),
    'expenses', coalesce((
      select jsonb_agg(to_jsonb(e))
      from (
        select id, created_at, amount, description, kind, paid_to_cafe
        from public.shift_expenses
        where restaurant_id = actor
        order by created_at
      ) e
    ), '[]'::jsonb)
  );
end;
$$;

create or replace function public.dev_wipe_logs(p_password text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := private.dev_restaurant_id();
begin
  if not private.dev_allowed(p_password) then
    return jsonb_build_object('ok', false);
  end if;
  if actor is null then
    return jsonb_build_object('ok', false, 'error', 'no restaurant');
  end if;
  delete from public.payments where restaurant_id = actor;
  delete from public.order_lines where restaurant_id = actor;
  delete from public.orders where restaurant_id = actor;
  delete from public.shift_expenses where restaurant_id = actor;
  delete from public.order_number_counters where restaurant_id = actor;
  return jsonb_build_object('ok', true);
end;
$$;

create or replace function public.dev_wipe_menu(p_password text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := private.dev_restaurant_id();
begin
  if not private.dev_allowed(p_password) then
    return jsonb_build_object('ok', false);
  end if;
  if actor is null then
    return jsonb_build_object('ok', false, 'error', 'no restaurant');
  end if;
  delete from public.menu_items where restaurant_id = actor;
  delete from public.menu_categories where restaurant_id = actor;
  return jsonb_build_object('ok', true);
end;
$$;

revoke all on function public.check_dev_access(text) from public;
revoke all on function public.dev_reset_admin(text) from public;
revoke all on function public.dev_export_logs(text) from public;
revoke all on function public.dev_wipe_logs(text) from public;
revoke all on function public.dev_wipe_menu(text) from public;
grant execute on function public.check_dev_access(text) to anon, authenticated;
grant execute on function public.dev_reset_admin(text) to anon, authenticated;
grant execute on function public.dev_export_logs(text) to anon, authenticated;
grant execute on function public.dev_wipe_logs(text) to anon, authenticated;
grant execute on function public.dev_wipe_menu(text) to anon, authenticated;
