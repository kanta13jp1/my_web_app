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
revoke all on table public.ai_action_budget_ledger from public, anon, authenticated;

grant select, insert, update, delete on table public.ai_action_budget_configs to authenticated;
grant all on table public.ai_action_budget_configs to service_role;

grant select on table public.ai_action_budget_ledger to authenticated;
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
drop policy if exists "ai_action_budget_configs_delete_admin"
  on public.ai_action_budget_configs;
create policy "ai_action_budget_configs_delete_admin"
  on public.ai_action_budget_configs
  for delete
  to authenticated
  using (
    exists (
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

-- Direct client INSERT/DELETE on ai_action_budget_ledger are revoked from authenticated;
-- all budget ledger inserts must go through record_ai_action_usage_tx().
drop policy if exists "ai_action_budget_ledger_insert_own"
  on public.ai_action_budget_ledger;
drop policy if exists "ai_action_budget_ledger_delete_own_or_admin"
  on public.ai_action_budget_ledger;

create or replace function public.guard_ai_action_budget_config_fields()
returns trigger
language plpgsql
security invoker
set search_path = public, auth, pg_catalog, pg_temp
as $guard$
declare
  jwt_role text;
  v_rpc_owner name;
  v_is_service boolean;
  v_is_tx_rpc boolean;
  caller_is_admin boolean;
begin
  jwt_role := coalesce(
    nullif(auth.jwt() ->> 'role', ''),
    nullif(current_setting('request.jwt.claim.role', true), ''),
    ''
  );

  select pg_catalog.pg_get_userbyid(proc.proowner)
    into v_rpc_owner
    from pg_catalog.pg_proc as proc
   where proc.oid = pg_catalog.to_regprocedure(
     'public.record_ai_action_usage_tx(text,text,integer,integer,numeric,text)'
   );

  v_is_service := (
    jwt_role = 'service_role'
    or (
      session_user in ('postgres', 'supabase_admin', 'supabase_auth_admin')
      and jwt_role = ''
    )
  );
  v_is_tx_rpc := (
    coalesce(current_setting('app.ai_action_budget_tx_rpc', true), '') = 'on'
    and (
      current_user in ('postgres', 'supabase_admin', 'supabase_auth_admin')
      or (v_rpc_owner is not null and current_user = v_rpc_owner)
    )
  );

  if v_is_service or v_is_tx_rpc then
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
      if new.is_paused is distinct from old.is_paused
         or new.paused_at is distinct from old.paused_at then
        raise exception 'Only admins may modify auto-pause state or timestamp'
          using errcode = '42501';
      end if;
      if new.warning_threshold_pct is distinct from old.warning_threshold_pct
         or new.hard_stop_pct is distinct from old.hard_stop_pct then
        raise exception 'Only admins may modify warning or hard-stop threshold percentages'
          using errcode = '42501';
      end if;
      if new.resumed_by is distinct from old.resumed_by
         or new.resumed_at is distinct from old.resumed_at then
        raise exception 'Only admins may set resume audit fields'
          using errcode = '42501';
      end if;
      if old.is_paused = true
         and new.monthly_usd_cap is distinct from old.monthly_usd_cap then
        raise exception 'Only admins may modify monthly_usd_cap while paused'
          using errcode = '42501';
      end if;
    else
      if old.is_paused = true and new.is_paused = false then
        new.resumed_by := coalesce(new.resumed_by, auth.uid());
        new.resumed_at := coalesce(new.resumed_at, timezone('utc', now()));
      end if;
      if old.is_paused = false and new.is_paused = true and new.paused_at is null then
        new.paused_at := timezone('utc', now());
      end if;
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
set search_path = public, auth, pg_catalog, pg_temp
as $guard$
declare
  jwt_role text;
  v_rpc_owner name;
  v_is_service boolean;
  v_is_tx_rpc boolean;
  config_paused boolean;
begin
  jwt_role := coalesce(
    nullif(auth.jwt() ->> 'role', ''),
    nullif(current_setting('request.jwt.claim.role', true), ''),
    ''
  );

  select pg_catalog.pg_get_userbyid(proc.proowner)
    into v_rpc_owner
    from pg_catalog.pg_proc as proc
   where proc.oid = pg_catalog.to_regprocedure(
     'public.record_ai_action_usage_tx(text,text,integer,integer,numeric,text)'
   );

  v_is_service := (
    jwt_role = 'service_role'
    or (
      session_user in ('postgres', 'supabase_admin', 'supabase_auth_admin')
      and jwt_role = ''
    )
  );
  v_is_tx_rpc := (
    coalesce(current_setting('app.ai_action_budget_tx_rpc', true), '') = 'on'
    and (
      current_user in ('postgres', 'supabase_admin', 'supabase_auth_admin')
      or (v_rpc_owner is not null and current_user = v_rpc_owner)
    )
  );

  if v_is_service then
    if tg_op = 'INSERT' then
      new.created_at := coalesce(new.created_at, timezone('utc', now()));
      return new;
    end if;
    if tg_op = 'DELETE' then
      return old;
    end if;
    return new;
  end if;

  if tg_op = 'INSERT' then
    if not v_is_tx_rpc then
      raise exception 'Direct inserts into ai_action_budget_ledger are disabled; use record_ai_action_usage_tx'
        using errcode = '42501';
    end if;
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

  if tg_op = 'DELETE' then
    raise exception 'AI action budget ledger entries cannot be deleted directly'
      using errcode = '42501';
  end if;

  return new;
end;
$guard$;

drop trigger if exists guard_ai_action_budget_ledger_fields
  on public.ai_action_budget_ledger;
create trigger guard_ai_action_budget_ledger_fields
  before insert or update or delete on public.ai_action_budget_ledger
  for each row
  execute function public.guard_ai_action_budget_ledger_fields();

-- Drop legacy RPC name if present in local/staging DBs; double-quoted to prevent
-- supabase/cli v2.84.2 pkg/parser/state.go:46-52 from matching unquoted ATOMIC as BEGIN ATOMIC.
drop function if exists public."record_ai_action_usage_atomic"(text, text, integer, integer, numeric, text);

create or replace function public.record_ai_action_usage_tx(
  p_action_name text,
  p_model_id text,
  p_input_tokens integer,
  p_output_tokens integer,
  p_estimated_usd numeric,
  p_billing_month text
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_catalog, pg_temp
as $fn$
declare
  v_uid uuid;
  v_previous_guard text;
  v_cfg public.ai_action_budget_configs%rowtype;
  v_entry public.ai_action_budget_ledger%rowtype;
  v_total_usd numeric(12, 6);
  v_usage_pct numeric(10, 4);
  v_should_pause boolean;
begin
  v_uid := auth.uid();
  if v_uid is null then
    raise exception 'Authenticated caller is required'
      using errcode = '42501';
  end if;

  v_previous_guard := current_setting('app.ai_action_budget_tx_rpc', true);
  perform set_config('app.ai_action_budget_tx_rpc', 'on', true);

  begin
    insert into public.ai_action_budget_configs (user_id, monthly_usd_cap)
    values (v_uid, 50.0000)
    on conflict (user_id) do nothing;

    select *
      into v_cfg
      from public.ai_action_budget_configs
      where user_id = v_uid
      for update;

    if v_cfg.is_paused then
      raise exception 'Monthly AI budget is paused; action execution blocked'
        using errcode = '42501';
    end if;

    insert into public.ai_action_budget_ledger (
      user_id,
      action_name,
      model_id,
      input_tokens,
      output_tokens,
      estimated_usd,
      billing_month
    )
    values (
      v_uid,
      p_action_name,
      p_model_id,
      p_input_tokens,
      p_output_tokens,
      p_estimated_usd,
      p_billing_month
    )
    returning * into v_entry;

    select coalesce(sum(estimated_usd), 0)::numeric(12, 6)
      into v_total_usd
      from public.ai_action_budget_ledger
      where user_id = v_uid
        and billing_month = p_billing_month;

    v_usage_pct := case
      when v_cfg.monthly_usd_cap > 0 then
        (v_total_usd / v_cfg.monthly_usd_cap) * 100.0
      else 100.0
    end;
    v_should_pause := (v_usage_pct >= v_cfg.hard_stop_pct);

    if v_should_pause then
      update public.ai_action_budget_configs
         set is_paused = true,
             paused_at = coalesce(paused_at, timezone('utc', now())),
             updated_at = timezone('utc', now())
       where id = v_cfg.id
       returning * into v_cfg;
    end if;
  exception
    when others then
      perform set_config(
        'app.ai_action_budget_tx_rpc',
        coalesce(v_previous_guard, ''),
        true
      );
      raise;
  end;

  perform set_config(
    'app.ai_action_budget_tx_rpc',
    coalesce(v_previous_guard, ''),
    true
  );

  return jsonb_build_object(
    'entry', to_jsonb(v_entry),
    'config', to_jsonb(v_cfg),
    'triggered_pause', v_should_pause
  );
end;
$fn$;

revoke all on function public.record_ai_action_usage_tx(text, text, integer, integer, numeric, text) from public, anon;
grant execute on function public.record_ai_action_usage_tx(text, text, integer, integer, numeric, text) to authenticated, service_role;

comment on table public.ai_action_budget_configs is
  'Per-user monthly USD AI budget threshold and auto-pause configuration (#2609).';
comment on table public.ai_action_budget_ledger is
  'Append-only per-action AI token and estimated USD cost ledger written exclusively via record_ai_action_usage_tx() (#2609).';
