-- Daily status tables for cross-device history persistence.
-- Run this script in Supabase SQL Editor.

create table if not exists public.home_daily_status (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  status_date date not null,
  morning_briefing_done boolean not null default false,
  balance_check_done boolean not null default false,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  unique (user_id, status_date)
);

create table if not exists public.abstinence_daily_status (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  status_date date not null,
  item_id text not null,
  is_enabled boolean not null default false,
  slip_count integer not null default 0 check (slip_count >= 0),
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  unique (user_id, status_date, item_id)
);

create index if not exists idx_home_daily_status_user_date
  on public.home_daily_status (user_id, status_date);

create index if not exists idx_abstinence_daily_status_user_date
  on public.abstinence_daily_status (user_id, status_date);

create or replace function public.set_daily_status_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_home_daily_status_updated_at on public.home_daily_status;
create trigger trg_home_daily_status_updated_at
before update on public.home_daily_status
for each row execute function public.set_daily_status_updated_at();

drop trigger if exists trg_abstinence_daily_status_updated_at on public.abstinence_daily_status;
create trigger trg_abstinence_daily_status_updated_at
before update on public.abstinence_daily_status
for each row execute function public.set_daily_status_updated_at();

alter table public.home_daily_status enable row level security;
alter table public.abstinence_daily_status enable row level security;

drop policy if exists "home_daily_status_select_own" on public.home_daily_status;
drop policy if exists "home_daily_status_insert_own" on public.home_daily_status;
drop policy if exists "home_daily_status_update_own" on public.home_daily_status;
drop policy if exists "home_daily_status_delete_own" on public.home_daily_status;

create policy "home_daily_status_select_own"
on public.home_daily_status for select
using (auth.uid() = user_id);

create policy "home_daily_status_insert_own"
on public.home_daily_status for insert
with check (auth.uid() = user_id);

create policy "home_daily_status_update_own"
on public.home_daily_status for update
using (auth.uid() = user_id);

create policy "home_daily_status_delete_own"
on public.home_daily_status for delete
using (auth.uid() = user_id);

drop policy if exists "abstinence_daily_status_select_own" on public.abstinence_daily_status;
drop policy if exists "abstinence_daily_status_insert_own" on public.abstinence_daily_status;
drop policy if exists "abstinence_daily_status_update_own" on public.abstinence_daily_status;
drop policy if exists "abstinence_daily_status_delete_own" on public.abstinence_daily_status;

create policy "abstinence_daily_status_select_own"
on public.abstinence_daily_status for select
using (auth.uid() = user_id);

create policy "abstinence_daily_status_insert_own"
on public.abstinence_daily_status for insert
with check (auth.uid() = user_id);

create policy "abstinence_daily_status_update_own"
on public.abstinence_daily_status for update
using (auth.uid() = user_id);

create policy "abstinence_daily_status_delete_own"
on public.abstinence_daily_status for delete
using (auth.uid() = user_id);
