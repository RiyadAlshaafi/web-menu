-- Monthly archive: sales older than the last two months move from the database to Cloudflare R2,
-- so the database stays small. The archive Worker (archive-worker/) runs every night:
--   1. public.archive_due_months() lists cafe months that are ready (oldest first).
--   2. public.archive_month_export() returns one cafe month as JSON with a digest.
--   3. The Worker gzips it, stores it in R2 and reads it back.
--   4. public.archive_month_delete() deletes exactly those rows, but only if the month still
--      gives the same digest (nothing changed since the export), and records the archive.
-- Only the service role (the Worker) may call these; cafes read their archived months through
-- the Worker. A month is the calendar month in Africa/Tripoli time.
--
-- What a month holds: its payments (by paid_at) with their method changes and orders (with
-- lines), and the shifts closed by the end of that month whose remaining payments are all in it,
-- with their expenses. An order that still has a payment in another month is copied into the
-- file but kept in the database; the month of its last payment deletes it.

create table if not exists public.archived_months (
  restaurant_id uuid not null references public.restaurants(id) on delete cascade,
  year_month text not null check (year_month ~ '^\d{4}-\d{2}$'),
  object_key text not null,
  payments integer not null,
  sales_total numeric not null,
  bytes bigint not null,
  sha256 text not null,
  archived_at timestamptz not null default now(),
  -- Normally one file per month; a sale uploaded late into an archived month adds another.
  primary key (restaurant_id, object_key)
);
create index if not exists archived_months_month_idx on public.archived_months (restaurant_id, year_month);
alter table public.archived_months enable row level security;
revoke all on public.archived_months from anon, authenticated;
grant select on public.archived_months to anon, authenticated;

-- The app shows which months are in the archive.
drop policy if exists archived_months_staff on public.archived_months;
create policy archived_months_staff on public.archived_months
  for select to anon, authenticated
  using (restaurant_id = (select private.actor_restaurant_id()));

-- Start of [p_month] ('YYYY-MM') and of the month after, as instants in Tripoli time.
create or replace function private.archive_month_bounds(p_month text, out starts timestamptz, out ends timestamptz)
language sql
immutable
set search_path = ''
as $$
  select (p_month || '-01')::timestamp at time zone 'Africa/Tripoli',
         ((p_month || '-01')::date + interval '1 month')::timestamp at time zone 'Africa/Tripoli';
$$;

-- The first month that is never archived: the previous calendar month (so two months stay).
create or replace function private.archive_keep_from()
returns text
language sql
stable
set search_path = ''
as $$
  select to_char(date_trunc('month', now() at time zone 'Africa/Tripoli') - interval '1 month', 'YYYY-MM');
$$;

create or replace function public.archive_due_months()
returns table (restaurant_id uuid, year_month text)
language sql
stable
security definer
set search_path = ''
as $$
  select distinct p.restaurant_id, to_char(p.paid_at at time zone 'Africa/Tripoli', 'YYYY-MM') as year_month
  from public.payments p
  where p.paid_at < (select starts from private.archive_month_bounds(private.archive_keep_from()))
  union
  select distinct s.restaurant_id, to_char(s.closed_at at time zone 'Africa/Tripoli', 'YYYY-MM')
  from public.shifts s
  where s.closed_at < (select starts from private.archive_month_bounds(private.archive_keep_from()))
  order by 2, 1;
$$;

-- The rows of one cafe month, in a fixed order so the same data always gives the same digest.
create or replace function private.archive_month_rows(p_restaurant_id uuid, p_month text)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with bounds as (select * from private.archive_month_bounds(p_month)),
  pay as (
    select p.* from public.payments p, bounds b
    where p.restaurant_id = p_restaurant_id and p.paid_at >= b.starts and p.paid_at < b.ends
  ),
  ord as (
    select o.* from public.orders o where o.id in (select order_id from pay)
  ),
  sh as (
    -- Closed by the end of the month, with every payment it still has in this month (an earlier
    -- month not archived yet, or a later sale, keeps it waiting).
    select s.* from public.shifts s, bounds b
    where s.restaurant_id = p_restaurant_id and s.closed_at is not null and s.closed_at < b.ends
      and not exists (
        select 1 from public.payments p
        where p.shift_id = s.id and (p.paid_at >= b.ends or p.paid_at < b.starts)
      )
  )
  select jsonb_build_object(
    'format', 'tawla-archive-v1',
    'restaurant_id', p_restaurant_id,
    'year_month', p_month,
    'payments', coalesce((select jsonb_agg(to_jsonb(x) order by x.paid_at, x.id) from pay x), '[]'::jsonb),
    'payment_method_changes', coalesce((select jsonb_agg(to_jsonb(c) order by c.created_at, c.id)
      from public.payment_method_changes c where c.payment_id in (select id from pay)), '[]'::jsonb),
    'orders', coalesce((select jsonb_agg(to_jsonb(x) order by x.created_at, x.id) from ord x), '[]'::jsonb),
    'order_lines', coalesce((select jsonb_agg(to_jsonb(l) order by l.order_id, l.id)
      from public.order_lines l where l.order_id in (select id from ord)), '[]'::jsonb),
    'shifts', coalesce((select jsonb_agg(to_jsonb(x) order by x.opened_at, x.id) from sh x), '[]'::jsonb),
    'shift_expenses', coalesce((select jsonb_agg(to_jsonb(e) order by e.created_at, e.id)
      from public.shift_expenses e where e.shift_id in (select id from sh)), '[]'::jsonb)
  );
$$;

create or replace function public.archive_month_export(p_restaurant_id uuid, p_month text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  data jsonb;
begin
  if p_month !~ '^\d{4}-\d{2}$' or p_month >= private.archive_keep_from() then
    return jsonb_build_object('ok', false, 'error', 'month is too recent to archive');
  end if;
  data := private.archive_month_rows(p_restaurant_id, p_month);
  return jsonb_build_object(
    'ok', true,
    'digest', md5(data::text),
    'payments', jsonb_array_length(data -> 'payments'),
    'sales_total', coalesce((select sum((p ->> 'total_due')::numeric) from jsonb_array_elements(data -> 'payments') p
                             where p ->> 'voided_at' is null), 0),
    'data', data
  );
end;
$$;

create or replace function public.archive_month_delete(
  p_restaurant_id uuid, p_month text, p_digest text, p_object_key text, p_bytes bigint, p_sha256 text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  data jsonb;
  b record;
  pay_ids uuid[];
  order_ids uuid[];
  shift_ids uuid[];
begin
  if p_month !~ '^\d{4}-\d{2}$' or p_month >= private.archive_keep_from() then
    return jsonb_build_object('ok', false, 'error', 'month is too recent to archive');
  end if;
  if coalesce(p_bytes, 0) <= 0 or coalesce(p_sha256, '') !~ '^[0-9a-f]{64}$'
     or coalesce(p_object_key, '') not like 'archive/' || p_restaurant_id::text || '/' || p_month || '/%' then
    return jsonb_build_object('ok', false, 'error', 'the stored file is not described');
  end if;
  -- One archive run per cafe at a time, and nothing changes the month while it is checked.
  perform pg_advisory_xact_lock(hashtext('archive:' || p_restaurant_id::text));
  select * into b from private.archive_month_bounds(p_month);
  perform 1 from public.payments where restaurant_id = p_restaurant_id and paid_at >= b.starts and paid_at < b.ends for update;
  data := private.archive_month_rows(p_restaurant_id, p_month);
  if md5(data::text) is distinct from p_digest then
    return jsonb_build_object('ok', false, 'error', 'changed since export');
  end if;

  select coalesce(array_agg((x ->> 'id')::uuid), '{}') into pay_ids from jsonb_array_elements(data -> 'payments') x;
  select coalesce(array_agg((x ->> 'id')::uuid), '{}') into shift_ids from jsonb_array_elements(data -> 'shifts') x;
  -- Orders go only when none of their payments stays behind (deleting an order deletes its payments).
  select coalesce(array_agg((x ->> 'id')::uuid), '{}') into order_ids
  from jsonb_array_elements(data -> 'orders') x
  where not exists (
    select 1 from public.payments p where p.order_id = (x ->> 'id')::uuid and p.id <> all (pay_ids)
  );

  delete from public.payments where id = any (pay_ids);           -- method changes follow (cascade)
  delete from public.orders where id = any (order_ids);           -- lines follow (cascade)
  delete from public.shift_expenses where shift_id = any (shift_ids);
  delete from public.shifts s where s.id = any (shift_ids)
    and not exists (select 1 from public.payments p where p.shift_id = s.id);

  insert into public.archived_months (restaurant_id, year_month, object_key, payments, sales_total, bytes, sha256)
  values (
    p_restaurant_id, p_month, p_object_key, cardinality(pay_ids),
    coalesce((select sum((p ->> 'total_due')::numeric) from jsonb_array_elements(data -> 'payments') p
              where p ->> 'voided_at' is null), 0),
    p_bytes, p_sha256
  );
  return jsonb_build_object('ok', true, 'payments', cardinality(pay_ids), 'orders', cardinality(order_ids),
                            'shifts', cardinality(shift_ids));
end;
$$;

revoke all on function private.archive_month_bounds(text) from public, anon, authenticated;
revoke all on function private.archive_keep_from() from public, anon, authenticated;
revoke all on function private.archive_month_rows(uuid, text) from public, anon, authenticated;
revoke all on function public.archive_due_months() from public, anon, authenticated;
revoke all on function public.archive_month_export(uuid, text) from public, anon, authenticated;
revoke all on function public.archive_month_delete(uuid, text, text, text, bigint, text) from public, anon, authenticated;
grant execute on function public.archive_due_months() to service_role;
grant execute on function public.archive_month_export(uuid, text) to service_role;
grant execute on function public.archive_month_delete(uuid, text, text, text, bigint, text) to service_role;
