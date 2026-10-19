-- Undoes 20261019130000_pin_rate_and_table_limits.sql: PIN sign-in, guest order sends and cashier
-- table access go back to how they were before it.

drop trigger if exists zz_guest_order_rate on public.order_lines;
drop function if exists private.guest_order_rate();

drop policy if exists tables_cashier on public.dining_tables;
create policy tables_cashier on public.dining_tables
  for all to anon
  using (restaurant_id = private.cashier_restaurant_id())
  with check (restaurant_id = private.cashier_restaurant_id());

CREATE OR REPLACE FUNCTION public.cashier_login(p_cashier_id uuid, p_pin text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  c public.cashiers%rowtype;
  raw_token text;
  lock_for interval;
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
  if c.pin_hash is distinct from extensions.crypt(coalesce(p_pin, ''), c.pin_hash) then
    c.failed_pin_attempts := c.failed_pin_attempts + 1;
    if c.failed_pin_attempts % 5 = 0 then
      lock_for := least(
        interval '15 minutes' * power(2, c.failed_pin_attempts / 5 - 1),
        interval '24 hours'
      );
      update public.cashiers
        set failed_pin_attempts = c.failed_pin_attempts,
            pin_locked_until = now() + lock_for
        where id = c.id;
      return jsonb_build_object(
        'ok', false,
        'code', 'locked',
        'retry_after_seconds', extract(epoch from lock_for)::int
      );
    end if;
    update public.cashiers set failed_pin_attempts = c.failed_pin_attempts where id = c.id;
    return jsonb_build_object('ok', false);
  end if;
  update public.cashiers set failed_pin_attempts = 0, pin_locked_until = null where id = c.id;
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
$function$
;

alter table public.cashiers drop column if exists last_failed_pin_at;
drop function if exists private.rate_count(text, integer);
drop table if exists private.rate_windows;
