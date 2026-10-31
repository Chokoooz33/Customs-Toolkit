-- Customs Toolkit PWA — Supabase schema.
-- Run once in: Supabase Dashboard → SQL Editor → New query → paste → Run.
-- Every table is protected by Row Level Security: a signed-in user can only read/write their own rows.

-- ---------------------------------------------------------------- profiles (one row per user)
create table if not exists public.profiles (
  id           uuid primary key references auth.users (id) on delete cascade,
  email        text,
  full_name    text,
  role         text not null default 'user' check (role in ('user', 'admin')),
  created_at   timestamptz not null default now(),
  last_seen_at timestamptz
);
alter table public.profiles enable row level security;

drop policy if exists "profiles: read own" on public.profiles;
create policy "profiles: read own" on public.profiles
  for select using (auth.uid() = id);

drop policy if exists "profiles: update own" on public.profiles;
create policy "profiles: update own" on public.profiles
  for update using (auth.uid() = id) with check (auth.uid() = id);

-- Users may edit their name / activity stamp, but not promote themselves.
revoke update on public.profiles from authenticated;
grant update (full_name, last_seen_at) on public.profiles to authenticated;

-- Create the profile automatically when someone signs up.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, email, full_name)
  values (new.id, new.email, coalesce(new.raw_user_meta_data ->> 'full_name', ''))
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------- user settings
create table if not exists public.user_settings (
  user_id      uuid primary key references auth.users (id) on delete cascade default auth.uid(),
  language     text check (language in ('en', 'ar')),
  appearance   text check (appearance in ('system', 'light', 'dark')),
  service_area text check (service_area in ('air', 'sea')),
  updated_at   timestamptz not null default now()
);
alter table public.user_settings enable row level security;

drop policy if exists "settings: own" on public.user_settings;
create policy "settings: own" on public.user_settings
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ---------------------------------------------------------------- recent HS searches
create table if not exists public.recent_searches (
  id               bigint generated always as identity primary key,
  user_id          uuid not null references auth.users (id) on delete cascade default auth.uid(),
  query            text not null,
  normalized_query text not null,
  created_at       timestamptz not null default now(),
  unique (user_id, normalized_query)
);
alter table public.recent_searches enable row level security;

drop policy if exists "recent: own" on public.recent_searches;
create policy "recent: own" on public.recent_searches
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ---------------------------------------------------------------- air cargo board
create table if not exists public.cargo_shipments (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users (id) on delete cascade default auth.uid(),
  awb        text not null check (awb ~ '^[0-9]{11}$'),
  airline    text,
  state      text not null default 'unknown'
             check (state in ('unknown', 'in_transit', 'not_arrived', 'partial', 'arrived')),
  note       text check (char_length(note) <= 300),
  added_at   timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, awb)
);
alter table public.cargo_shipments enable row level security;

drop policy if exists "cargo: own" on public.cargo_shipments;
create policy "cargo: own" on public.cargo_shipments
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ---------------------------------------------------------------- saved calculations
create table if not exists public.saved_calculations (
  id         bigint generated always as identity primary key,
  user_id    uuid not null references auth.users (id) on delete cascade default auth.uid(),
  kind       text not null check (kind in ('duty', 'difference')),
  title      text not null,
  payload    jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
alter table public.saved_calculations enable row level security;

drop policy if exists "calcs: own" on public.saved_calculations;
create policy "calcs: own" on public.saved_calculations
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create index if not exists recent_searches_user_idx on public.recent_searches (user_id, created_at desc);
create index if not exists cargo_shipments_user_idx on public.cargo_shipments (user_id, added_at desc);
create index if not exists saved_calculations_user_idx on public.saved_calculations (user_id, created_at desc);
