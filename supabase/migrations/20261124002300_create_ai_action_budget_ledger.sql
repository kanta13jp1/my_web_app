-- Migration for Issue #2609: Per-action AI token/USD budget ledger and monthly cap auto-pause guard
-- Complements #2612 (public.ai_quota_pause_state per-tool telemetry) with per-user, per-action token/USD accounting.

create table if not exists public.ai_action_budget_configs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade unique,
  monthly_usd_cap numeric(10, 4) not null default 50.0000
    check (monthly_usd_cap > 0 and monthly_usd_cap <= 100000),
  warning_threshold_pct numeric(5, 2) not null default 80.00
    check (warning_threshold_pct > 0 and warning_threshold_pct < hard_stop_pct),
  hard_stop_pct numeric(5, 2) not null default 100.00
    check (hard_stop_pct > 0 and hard_stop_pct <= 200),
  is_paused boolean not null default false,
  paused_at timestamptz,
  resumed_by uuid references auth.users(id) on delete set null,
  resumed_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_ai_action_budget_configs_paused
  on public.ai_action_budget_configs (is_paused, updated_at desc);

create table if not exists public.ai_action_budget_ledger (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  action_name text not null
    check (char_length(trim(action_name)) between 1 and 120),
  model_id text not null
    check (char_length(trim(model_id)) between 1 and 120),
  input_tokens integer not null default 0
    check (input_tokens >= 0),
  output_tokens integer not null default 0
    check (output_tokens >= 0),
  estimated_usd numeric(12, 6) not null default 0
    check (estimated_usd >= 0),
  billing_month text not null
    check (billing_month ~ '^[0-9]{4}-[0-9]{2}$'),
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_ai_action_budget_ledger_user_month
  on public.ai_action_budget_ledger (user_id, billing_month, created_at desc);

alter table public.ai_action_budget_configs enable row level security;
alter table public.ai_action_budget_ledger enable row level security;

revoke all on table public.ai_action_budget_configs from public, anon;
revoke all on table public.ai_action_budget_ledger from public, anon;

grant select, insert, update, delete on table public.ai_action_budget_configs to authenticated;
grant all on table public.ai_action_budget_configs to service_role;

grant select, insert, delete on table public.ai_action_budget_ledger to authenticated;
grant all on table public.ai_action_budget_ledger to service_role;

drop policy if exists "ai_action_budget_configs_select_own_or_admin"
  on public.ai_action_budget_configs;
create policy "ai_action_budget_configs_select_own_or_admin"
  on public.ai_action_budget_configs
  for select
  to authenticated
  using (
    auth.uid() = user_id
    or exists (
      select 1
      from public.user_profiles as up
      where up.user_id = auth.uid()
        and up.is_admin = true
    )
  );

drop policy if exists "ai_action_budget_configs_insert_own"
  on public.ai_action_budget_configs;
create policy "ai_action_budget_configs_insert_own"
  on public.ai_action_budget_configs
  for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "ai_action_budget_configs_update_own_or_admin"
  on public.ai_action_budget_configs;
create policy "ai_action_budget_configs_update_own_or_admin"
  on public.ai_action_budget_configs
  for update
  to authenticated
  using (
    auth.uid() = user_id
    or exists (
      select 1
      from public.user_profiles as up
      where up.user_id = auth.uid()
        and up.is_admin = true
    )
  )
  with check (
    auth.uid() = user_id
    or exists (
      select 1
      from public.user_profiles as up
      where up.user_id = auth.uid()
        and up.is_admin = true
    )
  );

drop policy if exists "ai_action_budget_configs_delete_own_or_admin"
  on public.ai_action_budget_configs;
create policy "ai_action_budget_configs_delete_own_or_admin"
  on public.ai_action_budget_configs
  for delete
  to authenticated
  using (
    auth.uid() = user_id
    or exists (
      select 1
      from public.user_profiles as up
      where up.user_id = auth.uid()
        and up.is_admin = true
    )
  );

drop policy if exists "ai_action_budget_ledger_select_own_or_admin"
  on public.ai_action_budget_ledger;
create policy "ai_action_budget_ledger_select_own_or_admin"
  on public.ai_action_budget_ledger
  for select
  to authenticated
  using (
    auth.uid() = user_id
    or exists (
      select 1
      from public.user_profiles as up
      where up.user_id = auth.uid()
        and up.is_admin = true
    )
  );

drop policy if exists "ai_action_budget_ledger_insert_own"
  on public.ai_action_budget_ledger;
create policy "ai_action_budget_ledger_insert_own"
  on public.ai_action_budget_ledger
  for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "ai_action_budget_ledger_delete_own_or_admin"
  on public.ai_action_budget_ledger;
create policy "ai_action_budget_ledger_delete_own_or_admin"
  on public.ai_action_budget_ledger
  for delete
  to authenticated
  using (
    auth.uid() = user_id
    or exists (
      select 1
      from public.user_profiles as up
      where up.user_id = auth.uid()
        and up.is_admin = true
    )
  );

create or replace function public.guard_ai_action_budget_config_fields()
returns trigger
language plpgsql
security invoker
set search_path = public
as $guard$
declare
  jwt_role text;
  caller_is_admin boolean;
begin
  jwt_role := coalesce(
    nullif(auth.jwt() ->> 'role', ''),
    nullif(current_setting('request.jwt.claim.role', true), ''),
    ''
  );

  if jwt_role = 'service_role'
     or (
       session_user in ('postgres', 'supabase_admin', 'supabase_auth_admin')
       and jwt_role = ''
     ) then
    if tg_op = 'INSERT' then
      new.created_at := coalesce(new.created_at, timezone('utc', now()));
    end if;
    new.updated_at := timezone('utc', now());
    return new;
  end if;

  caller_is_admin := exists (
    select 1
    from public.user_profiles as up
    where up.user_id = auth.uid()
      and up.is_admin = true
  );

  if tg_op = 'INSERT' then
    if auth.uid() is null or new.user_id is distinct from auth.uid() then
      raise exception 'Authenticated owner user_id is required on config insert'
        using errcode = '42501';
    end if;
    if new.is_paused is distinct from false
       or new.paused_at is not null
       or new.resumed_by is not null
       or new.resumed_at is not null then
      raise exception 'New budget configs must start unpaused without resume metadata'
        using errcode = '42501';
    end if;
    new.created_at := timezone('utc', now());
    new.updated_at := timezone('utc', now());
    return new;
  end if;

  if tg_op = 'UPDATE' then
    if new.id is distinct from old.id
       or new.user_id is distinct from old.user_id
       or new.created_at is distinct from old.created_at then
      raise exception 'Immutable identity and timestamp fields cannot be modified'
        using errcode = '42501';
    end if;
    if not caller_is_admin then
      if old.user_id is distinct from auth.uid() then
        raise exception 'Only owner or admin may update budget config'
          using errcode = '42501';
      end if;
      if old.is_paused = true and new.is_paused is distinct from true then
        raise exception 'Only admins may clear auto-pause state'
          using errcode = '42501';
      end if;
      if old.is_paused = true and new.monthly_usd_cap > old.monthly_usd_cap then
        raise exception 'Only admins may raise monthly_usd_cap while paused'
          using errcode = '42501';
      end if;
      if new.resumed_by is distinct from old.resumed_by
         or new.resumed_at is distinct from old.resumed_at then
        raise exception 'Only admins may set resume audit fields'
          using errcode = '42501';
      end if;
    else
      if old.is_paused = true and new.is_paused = false then
        new.resumed_by := coalesce(new.resumed_by, auth.uid());
        new.resumed_at := coalesce(new.resumed_at, timezone('utc', now()));
      end if;
    end if;
    if old.is_paused = false and new.is_paused = true and new.paused_at is null then
      new.paused_at := timezone('utc', now());
    end if;
    new.updated_at := timezone('utc', now());
  end if;

  return new;
end;
$guard$;

drop trigger if exists guard_ai_action_budget_config_fields
  on public.ai_action_budget_configs;
create trigger guard_ai_action_budget_config_fields
  before insert or update on public.ai_action_budget_configs
  for each row
  execute function public.guard_ai_action_budget_config_fields();

create or replace function public.guard_ai_action_budget_ledger_fields()
returns trigger
language plpgsql
security invoker
set search_path = public
as $guard$
declare
  jwt_role text;
  config_paused boolean;
begin
  jwt_role := coalesce(
    nullif(auth.jwt() ->> 'role', ''),
    nullif(current_setting('request.jwt.claim.role', true), ''),
    ''
  );

  if jwt_role = 'service_role'
     or (
       session_user in ('postgres', 'supabase_admin', 'supabase_auth_admin')
       and jwt_role = ''
     ) then
    if tg_op = 'INSERT' then
      new.created_at := coalesce(new.created_at, timezone('utc', now()));
    end if;
    return new;
  end if;

  if tg_op = 'INSERT' then
    if auth.uid() is null or new.user_id is distinct from auth.uid() then
      raise exception 'Authenticated owner user_id is required on ledger insert'
        using errcode = '42501';
    end if;
    select cfg.is_paused
      into config_paused
      from public.ai_action_budget_configs as cfg
      where cfg.user_id = new.user_id
      limit 1;
    if coalesce(config_paused, false) = true then
      raise exception 'Monthly AI budget is paused; action execution blocked'
        using errcode = '42501';
    end if;
    new.created_at := timezone('utc', now());
    return new;
  end if;

  if tg_op = 'UPDATE' then
    raise exception 'AI action budget ledger entries are append-only'
      using errcode = '42501';
  end if;

  return new;
end;
$guard$;

drop trigger if exists guard_ai_action_budget_ledger_fields
  on public.ai_action_budget_ledger;
create trigger guard_ai_action_budget_ledger_fields
  before insert or update on public.ai_action_budget_ledger
  for each row
  execute function public.guard_ai_action_budget_ledger_fields();

comment on table public.ai_action_budget_configs is
  'Per-user monthly USD AI budget threshold and auto-pause configuration (#2609).';
comment on table public.ai_action_budget_ledger is
  'Append-only per-action AI token and estimated USD cost ledger blocked when auto-paused (#2609).';
