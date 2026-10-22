-- One phone orders per table, and a way for the cashier to clear a table.
--
-- The first phone to open a table's QR page claims the table. Its owner can order; every other
-- phone sees the menu but cannot order. A claim lasts 5 minutes while nothing was sent. Once an
-- order is sent (and not yet paid) the claim stays with that phone, and it ends when the table is
-- paid or cleared. An expired claim is simply ignored, so nothing has to run on a timer.
--
-- A phone is identified by a random id from its own browser, sent in the request header
-- x-guest-visitor (and as an argument to guest_claim_table). The database keeps only
-- sha256(id + table), never the id.
--
-- Claims live in their own table so a scan does not ping every cashier device the way a change to
-- dining_tables would.
--
-- When the cafe has the location check on, a phone must be at the cafe to take a free table, so
-- nobody far away can hold a table by scanning a photo of its QR code. A phone that is too far
-- (or sends no position) gets role 'none': it keeps browsing, and takes the table once it is near.
--
-- A phone that sends no id (an older client) can still order while nobody holds a claim, and is
-- refused while somebody does, so the rule cannot be skipped by leaving the header out.
--
-- cashier_clear_table frees a table for good: it cancels the unpaid orders, empties the cart,
-- closes the table's staff calls and drops the claim.
-- Rollback: supabase/rollbacks/20261021100000_table_claims.down.sql

create table if not exists public.table_claims (
  table_id uuid primary key references public.dining_tables (id) on delete cascade,
  restaurant_id uuid not null references public.restaurants (id) on delete cascade,
  claimed_by text not null,
  claimed_at timestamptz not null default now()
);

alter table public.table_claims enable row level security;
revoke all on public.table_claims from anon, authenticated;

-- The browser's id, hashed with the table so one phone has a different value at every table.
create or replace function private.visitor_hash(p_table_id uuid, p_visitor text)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when btrim(coalesce(p_visitor, '')) ~ '^[A-Za-z0-9-]{16,64}$'
      then encode(extensions.digest(btrim(p_visitor) || ':' || p_table_id::text, 'sha256'), 'hex')
  end;
$$;
revoke all on function private.visitor_hash(uuid, text) from public, anon, authenticated;

-- Who holds the table right now (the hash), or null when nobody does.
create or replace function private.claim_holder(p_table_id uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select c.claimed_by
  from public.table_claims c
  where c.table_id = p_table_id
    and (
      c.claimed_at > now() - interval '5 minutes'
      or exists (select 1 from public.orders o where o.table_id = p_table_id and o.status <> 'paid')
    );
$$;
revoke all on function private.claim_holder(uuid) from public, anon, authenticated;

create or replace function private.set_claim(p_table_id uuid, p_restaurant_id uuid, p_hash text)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into public.table_claims (table_id, restaurant_id, claimed_by, claimed_at)
  values (p_table_id, p_restaurant_id, p_hash, now())
  on conflict (table_id) do update
    set restaurant_id = excluded.restaurant_id, claimed_by = excluded.claimed_by, claimed_at = now();
$$;
revoke all on function private.set_claim(uuid, uuid, text) from public, anon, authenticated;

-- The guest page asks this when it opens, and again while it is view-only, to learn whether this
-- phone may order. A free table is claimed by the phone that asks first.
create or replace function public.guest_claim_table(
  p_qr_slug text,
  p_visitor text,
  p_lat double precision default null,
  p_lng double precision default null,
  p_accuracy_m double precision default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  tbl public.dining_tables;
  mine text;
  holder text;
  location_error text;
begin
  tbl := private.table_for_slug(p_qr_slug);
  if tbl.id is null then
    return jsonb_build_object('ok', false, 'error', 'table not found');
  end if;
  mine := private.visitor_hash(tbl.id, p_visitor);
  if mine is null then
    return jsonb_build_object('ok', false, 'error', 'bad visitor');
  end if;
  -- One phone at a time decides who holds the table.
  perform 1 from public.dining_tables where id = tbl.id for update;
  holder := private.claim_holder(tbl.id);
  if holder is null then
    location_error := private.order_location_error(tbl.restaurant_id, p_lat, p_lng, p_accuracy_m);
    if location_error is not null then
      return jsonb_build_object('ok', true, 'role', 'none', 'reason', location_error);
    end if;
    perform private.set_claim(tbl.id, tbl.restaurant_id, mine);
    return jsonb_build_object('ok', true, 'role', 'owner');
  end if;
  return jsonb_build_object('ok', true, 'role', case when holder = mine then 'owner' else 'viewer' end);
end;
$$;
revoke all on function public.guest_claim_table(text, text, double precision, double precision, double precision) from public;
grant execute on function public.guest_claim_table(text, text, double precision, double precision, double precision)
  to anon, authenticated;

-- Every guest send passes through here, so a phone that is not the owner cannot order even if it
-- calls the database directly.
create or replace function private.guest_table_claim()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  tid uuid;
  mine text;
  holder text;
begin
  if not private.is_guest() then
    return new;
  end if;
  select o.table_id into tid from public.orders o where o.id = new.order_id;
  if tid is null then
    return new; -- a takeout order has no table
  end if;
  mine := private.visitor_hash(tid, private.header('x-guest-visitor'));
  holder := private.claim_holder(tid);
  if holder is null then
    if mine is not null then
      perform private.set_claim(tid, new.restaurant_id, mine);
    end if;
    return new;
  end if;
  if holder is distinct from mine then
    raise exception 'not_table_owner' using errcode = 'P0001';
  end if;
  return new;
end;
$$;
revoke all on function private.guest_table_claim() from public, anon, authenticated;

-- named to run after zz_guest_needs_cashier
drop trigger if exists zz_guest_table_claim on public.order_lines;
create trigger zz_guest_table_claim before insert on public.order_lines
  for each row execute function private.guest_table_claim();

-- A table that goes back to free (paid, cleared) starts over with no owner.
create or replace function private.release_claim_when_free()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status = 'free' and old.status is distinct from 'free' then
    delete from public.table_claims where table_id = new.id;
  end if;
  return null;
end;
$$;
revoke all on function private.release_claim_when_free() from public, anon, authenticated;

drop trigger if exists release_claim_when_free on public.dining_tables;
create trigger release_claim_when_free after update of status on public.dining_tables
  for each row execute function private.release_claim_when_free();

-- Cashier or admin: frees the table whatever state it is in.
create or replace function public.cashier_clear_table(p_table_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := coalesce(private.cashier_restaurant_id(), private.current_restaurant_id());
  tbl public.dining_tables%rowtype;
  removed integer;
begin
  if actor is null then
    return jsonb_build_object('ok', false, 'error', 'sign in as a cashier first');
  end if;
  select * into tbl from public.dining_tables
  where id = p_table_id and restaurant_id = actor and not archived
  for update;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'table not found');
  end if;
  with gone as (
    delete from public.orders where table_id = p_table_id and restaurant_id = actor and status <> 'paid'
    returning id
  )
  select count(*) into removed from gone;
  delete from public.cart_lines where table_id = p_table_id;
  delete from public.carts where table_id = p_table_id;
  update public.staff_calls set resolved = true where table_id = p_table_id and resolved = false;
  update public.dining_tables set status = 'free', guests = 0 where id = p_table_id;
  delete from public.table_claims where table_id = p_table_id;
  return jsonb_build_object('ok', true, 'cancelled_orders', removed);
end;
$$;
revoke all on function public.cashier_clear_table(uuid) from public;
grant execute on function public.cashier_clear_table(uuid) to anon, authenticated;
