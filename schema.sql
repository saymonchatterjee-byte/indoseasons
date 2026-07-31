-- ============================================================================
-- MODULE 1: Database Foundation, Authentication & RBAC
-- Manufacturing Enterprise Portal — Supabase (PostgreSQL) migration
-- Run this entire file once in Supabase SQL Editor (Database > SQL Editor)
-- ============================================================================

create extension if not exists "pgcrypto";

-- ----------------------------------------------------------------------------
-- 1. ROLES & PROFILES
-- ----------------------------------------------------------------------------

do $$ begin
  create type public.user_role as enum ('admin', 'worker');
exception when duplicate_object then null;
end $$;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  full_name text,
  role public.user_role not null default 'worker',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.profiles is 'One row per authenticated user, extends auth.users with role/RBAC data.';

-- ----------------------------------------------------------------------------
-- 2. LOOKUPS  (replaces the old "Settings" sheet: Type/Category, Status,
--    Registration, State/District, Products, Client Profile, Interest, etc.)
--    Using a single generic lookup table keeps admins able to manage all
--    dropdowns from one UI screen instead of hard-coding enums everywhere.
-- ----------------------------------------------------------------------------

create table if not exists public.lookups (
  id uuid primary key default gen_random_uuid(),
  list_name text not null,          -- e.g. 'type', 'category', 'status', 'state', 'district', 'registration', 'product', 'client_profile', 'interest'
  value text not null,
  parent_value text,                -- e.g. category -> parent 'type', district -> parent 'state'
  sort_order int not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (list_name, value, parent_value)
);

create index if not exists idx_lookups_list_name on public.lookups (list_name);

-- ----------------------------------------------------------------------------
-- 3. CUSTOMERS  (mirrors the real "Customer Master - Database" sheet columns)
-- ----------------------------------------------------------------------------

create table if not exists public.customers (
  id uuid primary key default gen_random_uuid(),
  legacy_id int,                          -- old sheet "ID" column, for migration traceability

  -- Identity
  name text not null,                     -- "Party A/c Name"
  trade_name text,
  contact_person text,

  -- Contact
  email text,
  mobile_1 text,
  mobile_2 text,
  whatsapp_no text,
  telephone_no text,

  -- Location
  address text,
  locality text,
  area text,
  city text,
  district text,
  state text,
  pincode text,
  map_link text,
  location_lat numeric(9,6),
  location_lng numeric(9,6),

  -- Classification (values validated against public.lookups at the app layer)
  type text,
  category text,
  registration text,
  registration_no text,
  client_profile text,
  interest_in_products text,

  -- Products dealt in (was 9 separate boolean columns C (Wool Ball) etc.)
  product_categories jsonb not null default '{}'::jsonb,

  -- Commercial / ops
  status text not null default 'Visit Pending',
  credit_limit numeric(12,2),
  transport text,
  beat text,
  reserve_option text,
  verified_on date,

  is_active boolean not null default true,

  created_by uuid references public.profiles(id),
  updated_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_customers_name on public.customers (name);
create index if not exists idx_customers_state_district on public.customers (state, district);
create index if not exists idx_customers_status on public.customers (status);
create index if not exists idx_customers_created_by on public.customers (created_by);

-- keep updated_at fresh on every write
create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_customers_updated_at on public.customers;
create trigger trg_customers_updated_at
  before update on public.customers
  for each row execute function public.set_updated_at();

drop trigger if exists trg_profiles_updated_at on public.profiles;
create trigger trg_profiles_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

-- ----------------------------------------------------------------------------
-- 4. AUTO-CREATE PROFILE ON SIGNUP
-- ----------------------------------------------------------------------------

create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, email, full_name, role)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'full_name', ''),
    -- First user ever created becomes admin automatically; everyone else
    -- starts as 'worker' and must be promoted by an existing admin.
    case when (select count(*) from public.profiles) = 0 then 'admin' else 'worker' end
  )
  on conflict (id) do nothing;
  return new;
end;
$$ language plpgsql security definer set search_path = public;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ----------------------------------------------------------------------------
-- 5. ROW LEVEL SECURITY
-- ----------------------------------------------------------------------------

alter table public.profiles enable row level security;
alter table public.customers enable row level security;
alter table public.lookups enable row level security;

-- Helper: is the current user an admin? (SECURITY DEFINER avoids RLS recursion)
create or replace function public.is_admin()
returns boolean as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin' and is_active = true
  );
$$ language sql security definer stable set search_path = public;

-- ---- profiles ----
drop policy if exists "profiles_select_own_or_admin" on public.profiles;
create policy "profiles_select_own_or_admin"
  on public.profiles for select
  using (id = auth.uid() or public.is_admin());

drop policy if exists "profiles_update_own_or_admin" on public.profiles;
create policy "profiles_update_own_or_admin"
  on public.profiles for update
  using (id = auth.uid() or public.is_admin())
  with check (
    -- workers may edit their own name, but never their own role
    (id = auth.uid() and role = (select role from public.profiles p where p.id = auth.uid()))
    or public.is_admin()
  );

drop policy if exists "profiles_admin_insert" on public.profiles;
create policy "profiles_admin_insert"
  on public.profiles for insert
  with check (public.is_admin());

drop policy if exists "profiles_admin_delete" on public.profiles;
create policy "profiles_admin_delete"
  on public.profiles for delete
  using (public.is_admin());

-- ---- customers ----
-- admin: full read/write on everything
drop policy if exists "customers_admin_all" on public.customers;
create policy "customers_admin_all"
  on public.customers for all
  using (public.is_admin())
  with check (public.is_admin());

-- worker: read all active customers
drop policy if exists "customers_worker_select" on public.customers;
create policy "customers_worker_select"
  on public.customers for select
  using (is_active = true or created_by = auth.uid());

-- worker: can create new customers, but only as themselves
drop policy if exists "customers_worker_insert" on public.customers;
create policy "customers_worker_insert"
  on public.customers for insert
  with check (created_by = auth.uid());

-- worker: can only edit records they created themselves, and only within 30 days
drop policy if exists "customers_worker_update" on public.customers;
create policy "customers_worker_update"
  on public.customers for update
  using (created_by = auth.uid() and created_at > now() - interval '30 days')
  with check (created_by = auth.uid());

-- workers cannot delete customers at all (no delete policy for them)

-- ---- lookups ----
drop policy if exists "lookups_select_all_authenticated" on public.lookups;
create policy "lookups_select_all_authenticated"
  on public.lookups for select
  using (auth.role() = 'authenticated');

drop policy if exists "lookups_admin_write" on public.lookups;
create policy "lookups_admin_write"
  on public.lookups for insert with check (public.is_admin());
drop policy if exists "lookups_admin_update" on public.lookups;
create policy "lookups_admin_update"
  on public.lookups for update using (public.is_admin());
drop policy if exists "lookups_admin_delete" on public.lookups;
create policy "lookups_admin_delete"
  on public.lookups for delete using (public.is_admin());

-- ============================================================================
-- Done. Next: create your first user via Supabase Auth (sign up normally) —
-- it will automatically become 'admin' via handle_new_user(). Every user
-- after that defaults to 'worker' and can be promoted from the Admin UI
-- (an admin running: update public.profiles set role = 'admin' where email = '...')
-- ============================================================================
