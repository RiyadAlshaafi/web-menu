-- Three limits the server now enforces itself:
--   1. PIN guessing: a correct PIN no longer wipes the miss count (it fades after 24 hours without
--      a miss), so a guesser can't get 4 fresh tries every time the real cashier signs in. A cafe
--      with 30 wrong PINs in one minute pauses PIN sign-in for that minute, so spreading guesses
--      over many cashiers doesn't help.
--   2. Guest orders: at most 10 order sends per table per minute, even when the website's own
--      limit is skipped by calling the database directly.
--   3. Cashier devices can read dining tables but no longer add, edit or delete them (renaming,
--      new QR codes and archiving are admin work).

-- ------------------------------------------------------------ shared fixed-window counter

create table if not exists private.rate_windows (
  key text primary key,
  window_start timestamptz not null,
  hits integer not null
);
revoke all on private.rate_windows from public, anon, authenticated;

-- Adds [p_add] hits to [p_key] in the current minute and returns the minute's total.
create or replace function private.rate_count(p_key text, p_add integer)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  minute timestamptz := date_trunc('minute', clock_timestamp());
  total integer;
begin
  insert into private.rate_windows as w (key, window_start, hits)
  values (p_key, minute, p_add)
  on conflict (key) do update
    set hits = case when w.window_start = excluded.window_start then w.hits + excluded.hits else excluded.hits end,
        window_start = excluded.window_start
  returning hits into total;
  return total;
end;
$$;
revoke all on function private.rate_count(text, integer) from public, anon, authenticated;

-- ------------------------------------------------------------ 1. PIN sign-in

alter table public.cashiers add column if not exists last_failed_pin_at timestamptz;

create or replace function public.cashier_login(p_cashier_id uuid, p_pin text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  c public.cashiers%rowtype;
  raw_token text;
  lock_for interval;
  cafe_key text;
begin
  select * into c from public.cashiers where id = p_cashier_id and active for update;
  if not found then
    return jsonb_build_object('ok', false);
  end if;
  if c.pin_locked_until > now() then
    return jsonb_build_object(
      'ok', false,
      'code', 'locked',
      'retry_after_seconds', ceil(extract(epoch from c.pin_locked_until - now()))::int
    );
  end if;
  cafe_key := 'pin_miss:' || c.restaurant_id::text;
  if private.rate_count(cafe_key, 0) >= 30 then
    return jsonb_build_object('ok', false, 'code', 'locked', 'retry_after_seconds', 60);
  end if;
  if c.pin_hash is distinct from extensions.crypt(coalesce(p_pin, ''), c.pin_hash) then
    perform private.rate_count(cafe_key, 1);
    -- Misses fade only after a full day without one; a correct PIN doesn't clear them.
    c.failed_pin_attempts := case
      when c.last_failed_pin_at is null or c.last_failed_pin_at < now() - interval '24 hours' then 1
      else c.failed_pin_attempts + 1
    end;
    if c.failed_pin_attempts % 5 = 0 then
      lock_for := least(
        interval '15 minutes' * power(2, c.failed_pin_attempts / 5 - 1),
        interval '24 hours'
      );
      update public.cashiers
        set failed_pin_attempts = c.failed_pin_attempts,
            last_failed_pin_at = now(),
            pin_locked_until = now() + lock_for
        where id = c.id;
      return jsonb_build_object(
        'ok', false,
        'code', 'locked',
        'retry_after_seconds', extract(epoch from lock_for)::int
      );
    end if;
    update public.cashiers
      set failed_pin_attempts = c.failed_pin_attempts, last_failed_pin_at = now()
      where id = c.id;
    return jsonb_build_object('ok', false);
  end if;
  update public.cashiers set pin_locked_until = null where id = c.id and pin_locked_until is not null;
  raw_token := encode(extensions.gen_random_bytes(32), 'hex');
  insert into public.cashier_sessions (cashier_id, restaurant_id, token_hash, expires_at)
  values (
    c.id,
    c.restaurant_id,
    encode(extensions.digest(raw_token, 'sha256'), 'hex'),
    now() + interval '12 hours'
  );
  return jsonb_build_object(
    'ok', true,
    'token', raw_token,
    'restaurant_id', c.restaurant_id,
    'cashier_id', c.id,
    'name', c.name,
    'initials', c.initials
  );
end;
$$;

-- ------------------------------------------------------------ 2. guest order sends

-- One hit per table per insert statement: a guest send adds its whole round in one statement.
create or replace function private.guest_order_rate()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  t uuid;
begin
  if not private.is_guest() or current_setting('dev.import', true) = 'on' then
    return null;
  end if;
  for t in
    select distinct o.table_id from added a join public.orders o on o.id = a.order_id where o.table_id is not null
  loop
    if private.rate_count('guest_order:' || t::text, 1) > 10 then
      raise exception 'too_many_requests';
    end if;
  end loop;
  return null;
end;
$$;
revoke all on function private.guest_order_rate() from public, anon, authenticated;

drop trigger if exists zz_guest_order_rate on public.order_lines;
create trigger zz_guest_order_rate after insert on public.order_lines
  referencing new table as added
  for each statement execute function private.guest_order_rate();

-- ------------------------------------------------------------ 3. cashier devices read tables only

drop policy if exists tables_cashier on public.dining_tables;
create policy tables_cashier on public.dining_tables
  for select to anon
  using (restaurant_id = (select private.cashier_restaurant_id()));
