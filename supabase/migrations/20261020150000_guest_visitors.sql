-- Unique visitors per day on the QR menu site, per cafe, without tracking anyone.
--
-- The guest page sends one visit call with a random id kept in that guest's own browser. The
-- database never stores the id: it keeps sha256(id + day) in guest_visits, only to tell whether
-- this guest was already counted today, and drops those rows after two days. What stays is a
-- count per cafe per day (guest_visit_days). No IP address, no user agent, nothing personal.
-- A day is the calendar day in Africa/Tripoli time, like the monthly archive.
--
-- The vendor dashboard reads the counts through vendor_visitors (developer password).

create table if not exists public.guest_visits (
  day date not null,
  restaurant_id uuid not null references public.restaurants (id) on delete cascade,
  visitor_hash text not null,
  primary key (day, restaurant_id, visitor_hash)
);

create table if not exists public.guest_visit_days (
  restaurant_id uuid not null references public.restaurants (id) on delete cascade,
  day date not null,
  visitors integer not null default 0,
  primary key (restaurant_id, day)
);

alter table public.guest_visits enable row level security;
alter table public.guest_visit_days enable row level security;
revoke all on public.guest_visits from anon, authenticated;
revoke all on public.guest_visit_days from anon, authenticated;

-- ------------------------------------------------ counting a visit
create or replace function public.guest_record_visit(p_qr_slug text, p_visitor text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  tbl public.dining_tables;
  d date := (now() at time zone 'Africa/Tripoli')::date;
  v text := btrim(coalesce(p_visitor, ''));
  added integer;
begin
  if v !~ '^[A-Za-z0-9-]{16,64}$' then
    return jsonb_build_object('ok', false, 'error', 'bad visitor');
  end if;
  -- Unknown, archived and suspended tables are not counted.
  tbl := private.table_for_slug(p_qr_slug);
  if tbl.id is null then
    return jsonb_build_object('ok', false, 'error', 'table not found');
  end if;
  -- Someone inventing visitor ids cannot grow a cafe's day beyond this.
  if coalesce((
    select s.visitors from public.guest_visit_days s where s.restaurant_id = tbl.restaurant_id and s.day = d
  ), 0) >= 20000 then
    return jsonb_build_object('ok', true);
  end if;

  insert into public.guest_visits (day, restaurant_id, visitor_hash)
  values (d, tbl.restaurant_id, encode(extensions.digest(v || ':' || d::text, 'sha256'), 'hex'))
  on conflict do nothing;
  get diagnostics added = row_count;
  if added > 0 then
    insert into public.guest_visit_days (restaurant_id, day, visitors)
    values (tbl.restaurant_id, d, 1)
    on conflict (restaurant_id, day) do update set visitors = public.guest_visit_days.visitors + 1;
  end if;

  -- Housekeeping: the per-guest rows are only needed for the day they were made.
  if random() < 0.02 then
    delete from public.guest_visits where day < d - 2;
  end if;
  return jsonb_build_object('ok', true);
end;
$$;

revoke all on function public.guest_record_visit(text, text) from public;
grant execute on function public.guest_record_visit(text, text) to anon, authenticated;

-- ------------------------------------------------ the vendor's view
create or replace function public.vendor_visitors(p_password text, p_days integer default 30)
returns jsonb
language plpgsql
volatile -- the password check records failed attempts, so this cannot be stable
security definer
set search_path = ''
as $$
declare
  span integer := least(greatest(coalesce(p_days, 30), 1), 90);
  today date := (now() at time zone 'Africa/Tripoli')::date;
begin
  if not private.dev_allowed(p_password) then
    return jsonb_build_object('ok', false);
  end if;

  return jsonb_build_object(
    'ok', true,
    'span_days', span,
    -- Unique visitors per day, every cafe together, oldest first, today last.
    'days', coalesce((
      select jsonb_agg(jsonb_build_object('day', g.day::date, 'visitors', coalesce(s.visitors, 0)) order by g.day)
      from generate_series(today - (span - 1), today, interval '1 day') as g(day)
      left join (
        select v.day, sum(v.visitors)::integer as visitors
        from public.guest_visit_days v
        where v.day > today - span
        group by v.day
      ) s on s.day = g.day::date
    ), '[]'::jsonb),
    'cafes', coalesce((
      select jsonb_agg(c order by c.slot nulls last, c.name)
      from (
        select
          r.id,
          r.name,
          r.slot,
          coalesce(sum(v.visitors) filter (where v.day = today), 0)::integer as visitors_today,
          coalesce(sum(v.visitors) filter (where v.day > today - 7), 0)::integer as visitors_7d,
          coalesce(sum(v.visitors), 0)::integer as visitors_period
        from public.restaurants r
        left join public.guest_visit_days v on v.restaurant_id = r.id and v.day > today - span
        group by r.id
      ) c
    ), '[]'::jsonb)
  );
end;
$$;

revoke all on function public.vendor_visitors(text, integer) from public;
grant execute on function public.vendor_visitors(text, integer) to anon, authenticated;
