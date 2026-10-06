-- Harden the hidden developer tools.
--
-- The original migration seeded a password that is visible in git history, so
-- every existing row is discarded here. Dev access stays OFF until a new
-- password is stored out-of-band (never commit it), for example in the SQL
-- editor:
--
--   insert into public.dev_access (password_hash)
--   values (extensions.crypt('<new password>', extensions.gen_salt('bf', 10)));
--
-- Passwords are now bcrypt-hashed, and repeated failures lock the check.

delete from public.dev_access;

alter table public.dev_access
  add column if not exists failed_attempts integer not null default 0,
  add column if not exists locked_until timestamptz;

create or replace function public.check_dev_access(p_password text)
returns boolean
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  rec public.dev_access%rowtype;
begin
  select * into rec
  from public.dev_access
  where password_hash like '$2%'
  order by created_at desc
  limit 1;

  if not found then
    return false;
  end if;

  if rec.locked_until is not null and rec.locked_until > now() then
    return false;
  end if;

  if rec.password_hash = extensions.crypt(coalesce(p_password, ''), rec.password_hash) then
    if rec.failed_attempts <> 0 or rec.locked_until is not null then
      update public.dev_access
      set failed_attempts = 0, locked_until = null
      where id = rec.id;
    end if;
    return true;
  end if;

  update public.dev_access
  set failed_attempts = case when failed_attempts + 1 >= 5 then 0 else failed_attempts + 1 end,
      locked_until = case when failed_attempts + 1 >= 5 then now() + interval '15 minutes' else locked_until end
  where id = rec.id;
  return false;
end;
$$;

create or replace function private.dev_allowed(p_password text)
returns boolean
language sql
volatile
security definer
set search_path = ''
as $$
  select public.check_dev_access(p_password);
$$;

-- These call dev_allowed, which now records failed attempts.
alter function public.dev_export_logs(text) volatile;

revoke all on table public.dev_access from anon, authenticated;
