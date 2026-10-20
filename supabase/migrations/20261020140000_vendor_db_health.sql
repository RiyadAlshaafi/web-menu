-- Database health for the vendor dashboard: size, connections, cache hit rate, the biggest
-- tables with their write counts, file storage per bucket, and how many rows were written per
-- day over the last 14 days (all cafes combined). Read-only and gated by the developer password.
-- It reports system-wide totals only, never anything per cafe.

create or replace function public.vendor_db_health(p_password text)
returns jsonb
language plpgsql
volatile -- the password check records failed attempts, so this cannot be stable
security definer
set search_path = ''
as $$
declare
  conn_total integer;
  conn_active integer;
begin
  if not private.dev_allowed(p_password) then
    return jsonb_build_object('ok', false);
  end if;

  select count(*), count(*) filter (where state = 'active')
  into conn_total, conn_active
  from pg_stat_activity
  where datname = current_database();

  return jsonb_build_object(
    'ok', true,
    'database', jsonb_build_object(
      'size_bytes', pg_database_size(current_database()),
      'connections', conn_total,
      'active_connections', conn_active,
      'max_connections', current_setting('max_connections')::integer,
      'cache_hit_ratio', (
        select case when sum(heap_blks_hit + heap_blks_read) = 0 then null
                    else round(sum(heap_blks_hit)::numeric / sum(heap_blks_hit + heap_blks_read), 4) end
        from pg_statio_user_tables
      )
    ),
    'tables', coalesce((
      select jsonb_agg(t order by t.total_bytes desc)
      from (
        select
          s.relname as name,
          pg_total_relation_size(s.relid) as total_bytes,
          s.n_live_tup as live_rows,
          s.n_dead_tup as dead_rows,
          s.n_tup_ins as inserts,
          s.n_tup_upd as updates,
          s.n_tup_del as deletes
        from pg_stat_user_tables s
        where s.schemaname = 'public'
        order by pg_total_relation_size(s.relid) desc
        limit 12
      ) t
    ), '[]'::jsonb),
    'storage', jsonb_build_object(
      'total_bytes', coalesce((select sum(coalesce((o.metadata->>'size')::bigint, 0)) from storage.objects o), 0),
      'objects', (select count(*) from storage.objects),
      'buckets', coalesce((
        select jsonb_agg(b order by b.bytes desc)
        from (
          select o.bucket_id as id, count(*) as objects, sum(coalesce((o.metadata->>'size')::bigint, 0)) as bytes
          from storage.objects o
          group by o.bucket_id
        ) b
      ), '[]'::jsonb)
    ),
    'ingestion', coalesce((
      select jsonb_agg(d order by d.day)
      from (
        select
          g.day::date as day,
          (select count(*) from public.orders o
            where o.created_at >= (g.day at time zone 'utc') and o.created_at < (g.day at time zone 'utc') + interval '1 day') as orders,
          (select count(*) from public.payments p
            where p.paid_at >= (g.day at time zone 'utc') and p.paid_at < (g.day at time zone 'utc') + interval '1 day') as payments,
          (select count(*) from public.shift_expenses e
            where e.created_at >= (g.day at time zone 'utc') and e.created_at < (g.day at time zone 'utc') + interval '1 day') as expenses
        from generate_series(
               (now() at time zone 'utc')::date - 13,
               (now() at time zone 'utc')::date,
               interval '1 day') as g(day)
      ) d
    ), '[]'::jsonb)
  );
end;
$$;

revoke all on function public.vendor_db_health(text) from public;
grant execute on function public.vendor_db_health(text) to anon, authenticated;
