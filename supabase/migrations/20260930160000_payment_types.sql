-- Customer-chosen payment types, stored on the order and copied onto the payment.
-- Later edits keep an audit row. Amounts stay on the existing numeric columns.

create table public.payment_types (
  id uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null references public.restaurants (id) on delete cascade,
  name_en text not null,
  name_ar text not null,
  enabled boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

create index payment_types_restaurant_idx on public.payment_types (restaurant_id, sort_order);

insert into public.payment_types (restaurant_id, name_en, name_ar, sort_order)
select r.id, seed.name_en, seed.name_ar, seed.sort_order
from public.restaurants r
cross join (values
  ('Cash', 'نقداً', 0),
  ('Card', 'بطاقة', 1),
  ('Bank Transfer', 'تحويل مصرفي', 2),
  ('Mobile Wallet', 'محفظة', 3)
) as seed(name_en, name_ar, sort_order);

alter table public.orders
  add column payment_type_id uuid references public.payment_types (id);

alter table public.payments
  add column payment_type_id uuid references public.payment_types (id);

create table public.payment_method_changes (
  id uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null references public.restaurants (id) on delete cascade,
  payment_id uuid not null references public.payments (id) on delete cascade,
  old_type_id uuid,
  new_type_id uuid,
  actor_name text not null,
  actor_role text not null,
  created_at timestamptz not null default now()
);

create index payment_method_changes_payment_idx
  on public.payment_method_changes (payment_id, created_at);

alter table public.payment_types enable row level security;
alter table public.payment_method_changes enable row level security;

create policy payment_types_read on public.payment_types
  for select to anon, authenticated
  using (
    restaurant_id = private.actor_restaurant_id()
    or (restaurant_id = private.guest_restaurant_id() and enabled)
  );

create policy payment_types_admin on public.payment_types
  for all to authenticated
  using (restaurant_id = private.current_restaurant_id())
  with check (restaurant_id = private.current_restaurant_id());

create policy payment_changes_read on public.payment_method_changes
  for select to anon, authenticated
  using (restaurant_id = private.actor_restaurant_id());

create function public.set_table_payment_type(p_qr_slug text, p_type_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  tid uuid;
  ord public.orders%rowtype;
begin
  tid := coalesce(
    (select id from public.dining_tables where qr_slug = nullif(btrim(coalesce(p_qr_slug, '')), '') limit 1),
    private.guest_table_id()
  );
  if tid is null then
    return jsonb_build_object('ok', false, 'error', 'table not found');
  end if;
  if not exists (
    select 1 from public.payment_types t
    join public.dining_tables d on d.restaurant_id = t.restaurant_id
    where t.id = p_type_id and t.enabled and d.id = tid
  ) then
    return jsonb_build_object('ok', false, 'error', 'unknown payment type');
  end if;
  select * into ord
  from public.orders
  where table_id = tid and status <> 'paid'
  order by created_at desc
  limit 1;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'no open bill');
  end if;
  update public.orders set payment_type_id = p_type_id where id = ord.id;
  return jsonb_build_object('ok', true);
end;
$$;

create function public.change_payment_type(p_payment_id uuid, p_type_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  rid uuid := private.cashier_restaurant_id();
  admin_rid uuid := private.current_restaurant_id();
  actor uuid := coalesce(rid, admin_rid);
  pay public.payments%rowtype;
  actor_name text;
  actor_role text;
begin
  if actor is null then
    return jsonb_build_object('ok', false, 'error', 'sign in first');
  end if;
  select * into pay from public.payments where id = p_payment_id and restaurant_id = actor;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'payment not found');
  end if;
  if not exists (
    select 1 from public.payment_types where id = p_type_id and restaurant_id = actor
  ) then
    return jsonb_build_object('ok', false, 'error', 'unknown payment type');
  end if;
  if pay.payment_type_id is not distinct from p_type_id then
    return jsonb_build_object('ok', true);
  end if;
  if rid is not null then
    actor_role := 'cashier';
    select c.name into actor_name
    from public.cashiers c
    join public.cashier_sessions s on s.cashier_id = c.id
    where s.token_hash = encode(extensions.digest(coalesce(private.header('x-cashier-token'), ''), 'sha256'), 'hex')
    limit 1;
  else
    actor_role := 'admin';
    actor_name := coalesce(auth.jwt() ->> 'email', 'Admin');
  end if;
  insert into public.payment_method_changes (
    restaurant_id, payment_id, old_type_id, new_type_id, actor_name, actor_role
  ) values (
    actor, pay.id, pay.payment_type_id, p_type_id, coalesce(actor_name, actor_role), actor_role
  );
  update public.payments set payment_type_id = p_type_id where id = pay.id;
  return jsonb_build_object('ok', true);
end;
$$;

drop function if exists public.settle_cash(uuid, numeric, boolean);

create function public.settle_cash(
  p_table_id uuid,
  p_cash_received numeric,
  p_apply_service boolean default true,
  p_payment_type_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  rid uuid := private.cashier_restaurant_id();
  admin_rid uuid := private.current_restaurant_id();
  actor uuid := coalesce(rid, admin_rid);
  ord public.orders%rowtype;
  due numeric;
  rate numeric;
  shift public.shifts%rowtype;
  cid uuid;
  type_id uuid;
begin
  if actor is null then
    return jsonb_build_object('ok', false, 'error', 'sign in as a cashier first');
  end if;
  select * into ord
  from public.orders
  where table_id = p_table_id
    and restaurant_id = actor
    and status <> 'paid'
  order by created_at desc
  limit 1;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'no open bill');
  end if;
  type_id := coalesce(p_payment_type_id, ord.payment_type_id);
  if type_id is not null and not exists (
    select 1 from public.payment_types where id = type_id and restaurant_id = actor
  ) then
    type_id := null;
  end if;
  select coalesce((select sum(qty * unit_price) from public.order_lines where order_id = ord.id), 0)
    + coalesce((select sum(qty * unit_price) from public.cart_lines where table_id = p_table_id), 0)
    into due;
  select service_charge_rate into rate from public.restaurants where id = actor;
  if p_apply_service then
    due := round(due * (1 + coalesce(rate, 0)), 2);
  else
    due := round(due, 2);
  end if;
  if p_cash_received < due then
    return jsonb_build_object('ok', false, 'error', 'insufficient cash');
  end if;
  cid := coalesce(
    (select cashier_id from public.cashier_sessions s
      where s.token_hash = encode(extensions.digest(coalesce(private.header('x-cashier-token'), ''), 'sha256'), 'hex')
        and s.expires_at > now()
      limit 1),
    (select id from public.cashiers where restaurant_id = actor order by created_at limit 1)
  );
  if cid is null then
    return jsonb_build_object('ok', false, 'error', 'sign in as a cashier first');
  end if;
  select * into shift
  from public.shifts
  where cashier_id = cid and restaurant_id = actor and closed_at is null
  order by opened_at desc
  limit 1;
  if not found then
    insert into public.shifts (restaurant_id, cashier_id, opening_cash)
    values (actor, cid, 0)
    returning * into shift;
  end if;
  insert into public.payments (
    restaurant_id, order_id, table_id, total_due, cash_received, change_due, cashier_id, shift_id, payment_type_id
  ) values (
    actor, ord.id, p_table_id, due, p_cash_received, p_cash_received - due, cid, shift.id, type_id
  );
  update public.orders set status = 'paid', payment_type_id = type_id where id = ord.id;
  update public.dining_tables set status = 'free', guests = 0 where id = p_table_id;
  delete from public.cart_lines where table_id = p_table_id;
  delete from public.carts where table_id = p_table_id;
  update public.staff_calls set resolved = true where table_id = p_table_id and resolved = false;
  update public.shifts
    set cash_sales = cash_sales + due,
        transaction_count = transaction_count + 1
    where id = shift.id;
  return jsonb_build_object('ok', true, 'total_due', due);
end;
$$;

grant execute on function public.set_table_payment_type(text, uuid) to anon, authenticated;
grant execute on function public.change_payment_type(uuid, uuid) to anon, authenticated;
grant execute on function public.settle_cash(uuid, numeric, boolean, uuid) to anon, authenticated;
