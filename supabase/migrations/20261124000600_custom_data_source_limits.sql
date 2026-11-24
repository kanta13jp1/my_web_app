-- Issue #2701: Plan-based custom data source limits and per-user data source cap trigger.
create table if not exists public.user_custom_data_source_limits (
  plan text primary key
    check (plan in ('free', 'pro', 'enterprise')),
  max_sources integer not null
    check (max_sources > 0 and max_sources <= 20000),
  max_context_units integer not null
    check (max_context_units > 0 and max_context_units <= 2000000),
  updated_at timestamptz not null default now()
);

insert into public.user_custom_data_source_limits (
  plan,
  max_sources,
  max_context_units
)
values
  ('free', 20, 1000000),
  ('pro', 500, 1000000),
  ('enterprise', 20000, 1000000)
on conflict (plan) do nothing;

alter table public.user_custom_data_source_limits enable row level security;

drop policy if exists "user_custom_data_source_limits_select_all"
  on public.user_custom_data_source_limits;
create policy "user_custom_data_source_limits_select_all"
  on public.user_custom_data_source_limits
  for select
  to authenticated, anon
  using (true);

create table if not exists public.user_custom_data_sources (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null
    check (char_length(btrim(name)) >= 1 and char_length(name) <= 120),
  source_type text not null default 'text'
    check (source_type in ('text', 'markdown', 'csv', 'json', 'url', 'repository')),
  estimated_units integer not null default 0
    check (estimated_units >= 0 and estimated_units <= 1000000),
  created_at timestamptz not null default now()
);

create index if not exists user_custom_data_sources_user_created_idx
  on public.user_custom_data_sources (user_id, created_at desc);

alter table public.user_custom_data_sources enable row level security;

drop policy if exists "user_custom_data_sources_select_own"
  on public.user_custom_data_sources;
create policy "user_custom_data_sources_select_own"
  on public.user_custom_data_sources
  for select
  using (user_id = (select auth.uid()));

drop policy if exists "user_custom_data_sources_insert_own"
  on public.user_custom_data_sources;
create policy "user_custom_data_sources_insert_own"
  on public.user_custom_data_sources
  for insert
  with check (user_id = (select auth.uid()));

drop policy if exists "user_custom_data_sources_delete_own"
  on public.user_custom_data_sources;
create policy "user_custom_data_sources_delete_own"
  on public.user_custom_data_sources
  for delete
  using (user_id = (select auth.uid()));

create or replace function public.enforce_custom_data_source_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_plan text := 'free';
  v_max_sources integer := 20;
  v_current_count integer := 0;
begin
  perform pg_advisory_xact_lock(hashtext(new.user_id::text));

  select coalesce(
    (
      select lower(btrim(us.plan))
      from public.user_subscriptions us
      where us.user_id = new.user_id
        and us.status in ('active', 'trialing')
      order by us.updated_at desc nulls last
      limit 1
    ),
    (
      select lower(btrim(up.subscription_plan))
      from public.user_profiles up
      where up.user_id = new.user_id
      limit 1
    ),
    'free'
  )
  into v_plan;

  if v_plan not in ('free', 'pro', 'enterprise') then
    v_plan := 'free';
  end if;

  select l.max_sources
  into v_max_sources
  from public.user_custom_data_source_limits l
  where l.plan = v_plan;

  if v_max_sources is null then
    v_max_sources := 20;
  end if;

  select count(*)::integer
  into v_current_count
  from public.user_custom_data_sources s
  where s.user_id = new.user_id;

  if v_current_count >= v_max_sources then
    raise exception 'custom_data_source_limit_exceeded'
      using errcode = 'P0001',
            detail = format('count=%s max=%s plan=%s', v_current_count, v_max_sources, v_plan);
  end if;

  return new;
end;
$$;

drop trigger if exists trg_enforce_custom_data_source_limit
  on public.user_custom_data_sources;
create trigger trg_enforce_custom_data_source_limit
  before insert on public.user_custom_data_sources
  for each row
  execute function public.enforce_custom_data_source_limit();
