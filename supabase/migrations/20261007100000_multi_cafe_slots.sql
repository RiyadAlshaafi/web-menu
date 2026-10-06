-- Eight cafe slots in one database.
--
-- A slot is a row in public.restaurants. Data was already scoped by
-- restaurant_id everywhere; this migration adds the missing pieces around it:
-- slot numbers, a per-slot admin setup code, per-slot admin check, and dev
-- tools that act on a chosen slot instead of "the oldest restaurant".
--
-- DEPLOY TOGETHER WITH THE MATCHING APP RELEASE. After this runs, creating an
-- admin needs a slot number and a setup code (issued from the dev screen), so
-- an app build that does not send them can no longer create an admin.

-- ---------------------------------------------------------------- slots

alter table public.restaurants
  add column if not exists slot smallint,
  add column if not exists slug text,
  add column if not exists active boolean not null default false;

alter table public.restaurants
  add constraint restaurants_slot_range check (slot is null or slot between 1 and 8);

create unique index if not exists restaurants_slot_key
  on public.restaurants (slot) where slot is not null;
create unique index if not exists restaurants_slug_key
  on public.restaurants (lower(slug)) where slug is not null;

-- Existing cafes take the first free slots, oldest first (at most 8).
with ranked as (
  select id, row_number() over (order by created_at, id) as n
  from public.restaurants
  where slot is null
)
update public.restaurants r
set slot = ranked.n::smallint,
    slug = coalesce(r.slug, 'cafe-' || ranked.n),
    active = exists (select 1 from public.profiles p where p.restaurant_id = r.id)
from ranked
where r.id = ranked.id and ranked.n <= 8;

-- Create the remaining empty slots.
insert into public.restaurants (name, slot, slug, active)
select '', n, 'cafe-' || n, false
from generate_series(1, 8) as n
where not exists (select 1 from public.restaurants r where r.slot = n);

-- Admins must not move themselves to another slot or flip activation.
create or replace function private.protect_restaurant_slot()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is not null and (
    new.slot is distinct from old.slot
    or new.slug is distinct from old.slug
    or new.active is distinct from old.active
  ) then
    raise exception 'slot, slug and active can only be changed from the dev tools';
  end if;
  return new;
end;
$$;

drop trigger if exists restaurants_protect_slot on public.restaurants;
create trigger restaurants_protect_slot
  before update on public.restaurants
  for each row execute function private.protect_restaurant_slot();

-- ------------------------------------------------------- setup codes

-- One-time codes that let an admin account be created for a slot. Kept in its
-- own table with RLS on and no policies, so only security definer code reads it.
create table if not exists public.restaurant_setup (
  restaurant_id uuid primary key references public.restaurants (id) on delete cascade,
  code_hash text not null,
  created_at timestamptz not null default now()
);

alter table public.restaurant_setup enable row level security;
revoke all on table public.restaurant_setup from anon, authenticated;

-- ------------------------------------------------ defaults per cafe

create or replace function private.seed_restaurant_defaults(p_restaurant_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.payment_types (restaurant_id, name_en, name_ar, sort_order)
  select p_restaurant_id, seed.name_en, seed.name_ar, seed.sort_order
  from (values
    ('Cash', 'نقداً', 0),
    ('Card', 'بطاقة', 1),
    ('Bank Transfer', 'تحويل مصرفي', 2),
    ('Mobile Wallet', 'محفظة', 3)
  ) as seed(name_en, name_ar, sort_order)
  where not exists (select 1 from public.payment_types t where t.restaurant_id = p_restaurant_id);

  insert into public.expense_categories (restaurant_id, name_en, name_ar, sort_order)
  select p_restaurant_id, seed.name_en, seed.name_ar, seed.sort_order
  from (values
    ('Café Expense', 'مصروف المقهى', 0),
    ('Cash Withdrawal', 'سحب نقدي', 1)
  ) as seed(name_en, name_ar, sort_order)
  where not exists (select 1 from public.expense_categories c where c.restaurant_id = p_restaurant_id);
end;
$$;

select private.seed_restaurant_defaults(id) from public.restaurants;

-- -------------------------------------------- admin creation is gated

create or replace function private.handle_new_admin()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  want_slot integer;
  code text := coalesce(new.raw_user_meta_data ->> 'setup_code', '');
  rid uuid;
  stored text;
begin
  begin
    want_slot := (new.raw_user_meta_data ->> 'slot')::integer;
  exception when others then
    want_slot := null;
  end;
  if want_slot is null then
    raise exception 'A cafe slot and setup code are required to create an admin.';
  end if;

  select r.id into rid from public.restaurants r where r.slot = want_slot;
  if rid is null then
    raise exception 'Unknown cafe slot.';
  end if;
  if exists (select 1 from public.profiles p where p.restaurant_id = rid) then
    raise exception 'This cafe already has an admin.';
  end if;

  select s.code_hash into stored from public.restaurant_setup s where s.restaurant_id = rid;
  if stored is null or stored <> extensions.crypt(code, stored) then
    raise exception 'The setup code is not valid.';
  end if;

  insert into public.profiles (id, restaurant_id, role, display_name)
  values (new.id, rid, 'admin', coalesce(new.email, ''));
  delete from public.restaurant_setup where restaurant_id = rid;
  update public.restaurants set active = true where id = rid;
  return new;
end;
$$;

-- ------------------------------------------------ per-slot discovery

drop function if exists public.has_any_admin();

-- With a restaurant id: whether that cafe has an admin. Without one it keeps
-- the old global meaning so a stale client still routes sensibly.
create or replace function public.has_any_admin(p_restaurant_id uuid default null)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.profiles p
    where p_restaurant_id is null or p.restaurant_id = p_restaurant_id
  );
$$;

-- Older app builds ask for cashiers without naming a cafe. Keep them working
-- by answering with slot 1 (the original cafe). New builds always send the id
-- of the cafe they are linked to, and send nothing when unlinked.
create or replace function public.list_pos_cashiers(p_restaurant_id uuid default null)
returns table (id uuid, name text, initials text)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  rid uuid := p_restaurant_id;
begin
  if rid is null then
    select r.id into rid from public.restaurants r where r.slot = 1;
  end if;
  if rid is null then
    return;
  end if;
  return query
    select c.id, c.name, c.initials
    from public.cashiers c
    where c.restaurant_id = rid and c.active;
end;
$$;

-- What an install needs to know about its slot before anyone logs in.
create or replace function public.restaurant_for_slot(p_slot integer)
returns table (id uuid, slot smallint, slug text, name text, active boolean, has_admin boolean)
language sql
stable
security definer
set search_path = ''
as $$
  select r.id, r.slot, r.slug, r.name, r.active,
         exists (select 1 from public.profiles p where p.restaurant_id = r.id)
  from public.restaurants r
  where r.slot = p_slot;
$$;

-- Same lookup by the short name used in /c/<slug> links.
create or replace function public.restaurant_for_slug(p_slug text)
returns table (id uuid, slot smallint, slug text, name text, active boolean, has_admin boolean)
language sql
stable
security definer
set search_path = ''
as $$
  select r.id, r.slot, r.slug, r.name, r.active,
         exists (select 1 from public.profiles p where p.restaurant_id = r.id)
  from public.restaurants r
  where r.slot is not null and lower(r.slug) = lower(p_slug);
$$;

revoke all on function public.has_any_admin(uuid) from public;
revoke all on function public.restaurant_for_slot(integer) from public;
revoke all on function public.restaurant_for_slug(text) from public;
grant execute on function public.has_any_admin(uuid) to anon, authenticated;
grant execute on function public.restaurant_for_slot(integer) to anon, authenticated;
grant execute on function public.restaurant_for_slug(text) to anon, authenticated;

-- --------------------------------------------------- dev tools by slot

-- The dev screen sends the slot it is working on in the x-dev-slot header.
-- No header and no login means no cafe (the old fallback was "oldest cafe").
create or replace function private.dev_restaurant_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (
      select r.id from public.restaurants r
      where private.header('x-dev-slot') ~ '^[1-8]$'
        and r.slot = private.header('x-dev-slot')::integer
    ),
    private.actor_restaurant_id()
  );
$$;

create or replace function public.dev_list_slots(p_password text)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
begin
  if not private.dev_allowed(p_password) then
    return jsonb_build_object('ok', false);
  end if;
  return jsonb_build_object(
    'ok', true,
    'slots', coalesce((
      select jsonb_agg(jsonb_build_object(
        'slot', r.slot,
        'id', r.id,
        'slug', r.slug,
        'name', r.name,
        'active', r.active,
        'has_admin', exists (select 1 from public.profiles p where p.restaurant_id = r.id),
        'has_setup_code', exists (select 1 from public.restaurant_setup s where s.restaurant_id = r.id)
      ) order by r.slot)
      from public.restaurants r
      where r.slot is not null
    ), '[]'::jsonb)
  );
end;
$$;

-- Issues a fresh one-time admin setup code for a slot. The code is returned
-- once and only its hash is stored. Use it after "reset admin" too.
create or replace function public.dev_issue_setup_code(p_password text, p_slot integer)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  rid uuid;
  alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  code text := '';
  i integer;
begin
  if not private.dev_allowed(p_password) then
    return jsonb_build_object('ok', false);
  end if;
  select r.id into rid from public.restaurants r where r.slot = p_slot;
  if rid is null then
    return jsonb_build_object('ok', false, 'error', 'unknown slot');
  end if;
  if exists (select 1 from public.profiles p where p.restaurant_id = rid) then
    return jsonb_build_object('ok', false, 'error', 'this cafe already has an admin');
  end if;
  -- 12 symbols from a 32-symbol alphabet (60 bits) using a cryptographic source.
  for i in 0..11 loop
    code := code || substr(alphabet, 1 + (get_byte(extensions.gen_random_bytes(1), 0) % 32), 1);
  end loop;
  insert into public.restaurant_setup (restaurant_id, code_hash)
  values (rid, extensions.crypt(code, extensions.gen_salt('bf', 8)))
  on conflict (restaurant_id) do update
    set code_hash = excluded.code_hash, created_at = now();
  perform private.seed_restaurant_defaults(rid);
  return jsonb_build_object('ok', true, 'slot', p_slot, 'code', code);
end;
$$;

revoke all on function public.dev_list_slots(text) from public;
revoke all on function public.dev_issue_setup_code(text, integer) from public;
grant execute on function public.dev_list_slots(text) to anon, authenticated;
grant execute on function public.dev_issue_setup_code(text, integer) to anon, authenticated;
