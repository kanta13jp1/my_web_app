-- Migration for Issue #2658: Compute scale & GPU cost telemetry, daily/monthly aggregation, and threshold alerting

create table if not exists public.ai_compute_cost_telemetry (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  tool_name text not null
    check (char_length(trim(tool_name)) between 1 and 80),
  gpu_profile text not null default 'managed-api'
    check (
      gpu_profile in (
        'cpu-fallback',
        't4-inference',
        'l4-inference',
        'a100-cluster',
        'h100-cluster',
        'managed-api'
      )
    ),
  model_id text not null default 'gemini-2.5-flash'
    check (char_length(trim(model_id)) between 1 and 80),
  input_tokens integer not null default 0
    check (input_tokens >= 0),
  output_tokens integer not null default 0
    check (output_tokens >= 0),
  api_request_count integer not null default 1
    check (api_request_count >= 1),
  latency_ms integer not null default 0
    check (latency_ms >= 0),
  estimated_compute_cost_usd numeric(12,6) not null default 0.000000
    check (estimated_compute_cost_usd >= 0),
  cost_threshold_usd numeric(12,6) not null default 50.000000
    check (cost_threshold_usd > 0),
  threshold_alert_triggered boolean not null default false,
  recorded_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_ai_compute_cost_telemetry_recorded
  on public.ai_compute_cost_telemetry (recorded_at desc);

create index if not exists idx_ai_compute_cost_telemetry_user_recorded
  on public.ai_compute_cost_telemetry (user_id, recorded_at desc);

create index if not exists idx_ai_compute_cost_telemetry_tool_profile
  on public.ai_compute_cost_telemetry (tool_name, gpu_profile, recorded_at desc);

alter table public.ai_compute_cost_telemetry enable row level security;

revoke all on table public.ai_compute_cost_telemetry from public, anon, authenticated;
grant select, insert on table public.ai_compute_cost_telemetry to authenticated;
grant all on table public.ai_compute_cost_telemetry to service_role;

drop policy if exists "ai_compute_cost_telemetry_select_own_or_admin"
  on public.ai_compute_cost_telemetry;
create policy "ai_compute_cost_telemetry_select_own_or_admin"
  on public.ai_compute_cost_telemetry
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

drop policy if exists "ai_compute_cost_telemetry_insert_own"
  on public.ai_compute_cost_telemetry;
create policy "ai_compute_cost_telemetry_insert_own"
  on public.ai_compute_cost_telemetry
  for insert
  to authenticated
  with check (auth.uid() = user_id);

create or replace function public.guard_ai_compute_cost_telemetry_fields()
returns trigger
language plpgsql
security invoker
set search_path = public
as $guard$
declare
  jwt_role text;
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
      new.recorded_at := coalesce(new.recorded_at, timezone('utc', now()));
      new.threshold_alert_triggered :=
        (new.estimated_compute_cost_usd >= new.cost_threshold_usd);
    end if;
    return new;
  end if;

  if tg_op = 'INSERT' then
    if auth.uid() is null or new.user_id is distinct from auth.uid() then
      raise exception 'Authenticated owner user_id is required on telemetry insert'
        using errcode = '42501';
    end if;
    new.threshold_alert_triggered :=
      (new.estimated_compute_cost_usd >= new.cost_threshold_usd);
    new.recorded_at := timezone('utc', now());
    return new;
  end if;

  raise exception 'AI compute cost telemetry rows are append-only'
    using errcode = '42501';
end;
$guard$;

drop trigger if exists guard_ai_compute_cost_telemetry_fields
  on public.ai_compute_cost_telemetry;
create trigger guard_ai_compute_cost_telemetry_fields
  before insert or update or delete on public.ai_compute_cost_telemetry
  for each row
  execute function public.guard_ai_compute_cost_telemetry_fields();

create table if not exists public.ai_compute_cost_alert_settings (
  id text primary key default 'global'
    check (id = 'global'),
  daily_cost_threshold_usd numeric(12,6) not null default 50.000000
    check (daily_cost_threshold_usd > 0),
  monthly_cost_threshold_usd numeric(12,6) not null default 500.000000
    check (monthly_cost_threshold_usd >= daily_cost_threshold_usd),
  updated_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default timezone('utc', now())
);

insert into public.ai_compute_cost_alert_settings (
  id,
  daily_cost_threshold_usd,
  monthly_cost_threshold_usd
)
values ('global', 50.000000, 500.000000)
on conflict (id) do nothing;

alter table public.ai_compute_cost_alert_settings enable row level security;

revoke all on table public.ai_compute_cost_alert_settings from public, anon, authenticated;
grant select on table public.ai_compute_cost_alert_settings to authenticated;
grant all on table public.ai_compute_cost_alert_settings to service_role;

drop policy if exists "ai_compute_cost_alert_settings_select_authenticated"
  on public.ai_compute_cost_alert_settings;
create policy "ai_compute_cost_alert_settings_select_authenticated"
  on public.ai_compute_cost_alert_settings
  for select
  to authenticated
  using (true);

create or replace function public.update_ai_compute_cost_threshold(
  p_daily_threshold_usd numeric,
  p_monthly_threshold_usd numeric
)
returns public.ai_compute_cost_alert_settings
language plpgsql
security definer
set search_path = public, auth, pg_catalog, pg_temp
as $fn$
declare
  jwt_role text;
  caller_id uuid;
  caller_is_admin boolean;
  updated_row public.ai_compute_cost_alert_settings;
begin
  jwt_role := coalesce(
    nullif(auth.jwt() ->> 'role', ''),
    nullif(current_setting('request.jwt.claim.role', true), ''),
    ''
  );
  caller_id := auth.uid();

  if not (
    jwt_role = 'service_role'
    or (
      session_user in ('postgres', 'supabase_admin', 'supabase_auth_admin')
      and jwt_role = ''
    )
  ) then
    caller_is_admin := exists (
      select 1
      from public.user_profiles as up
      where up.user_id = caller_id
        and up.is_admin = true
    );
    if not caller_is_admin then
      raise exception 'Only administrators may update system AI compute cost thresholds'
        using errcode = '42501';
    end if;
  end if;

  if p_daily_threshold_usd is null or p_daily_threshold_usd <= 0 then
    raise exception 'Daily compute cost threshold must be positive'
      using errcode = '22023';
  end if;
  if p_monthly_threshold_usd is null or p_monthly_threshold_usd < p_daily_threshold_usd then
    raise exception 'Monthly compute cost threshold must be >= daily threshold'
      using errcode = '22023';
  end if;

  perform set_config('app.ai_compute_cost_threshold_rpc', 'on', true);
  begin
    update public.ai_compute_cost_alert_settings
    set daily_cost_threshold_usd = round(p_daily_threshold_usd, 6),
        monthly_cost_threshold_usd = round(p_monthly_threshold_usd, 6),
        updated_by = caller_id,
        updated_at = timezone('utc', now())
    where id = 'global'
    returning * into updated_row;
  exception
    when others then
      perform set_config('app.ai_compute_cost_threshold_rpc', 'off', true);
      raise;
  end;
  perform set_config('app.ai_compute_cost_threshold_rpc', 'off', true);

  return updated_row;
end;
$fn$;

revoke all on function public.update_ai_compute_cost_threshold(numeric, numeric) from public, anon;
grant execute on function public.update_ai_compute_cost_threshold(numeric, numeric) to authenticated, service_role;

create or replace function public.guard_ai_compute_cost_alert_settings()
returns trigger
language plpgsql
security invoker
set search_path = public, pg_catalog
as $guard$
declare
  jwt_role text;
  rpc_owner text;
  caller_is_rpc boolean;
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
    return coalesce(new, old);
  end if;

  select r.rolname
    into rpc_owner
  from pg_catalog.pg_proc as p
  join pg_catalog.pg_roles as r on r.oid = p.proowner
  where p.oid = pg_catalog.to_regprocedure('public.update_ai_compute_cost_threshold(numeric,numeric)');

  caller_is_rpc := (
    rpc_owner is not null
    and current_user = rpc_owner
    and current_user in ('postgres', 'supabase_admin', 'supabase_auth_admin')
    and nullif(current_setting('app.ai_compute_cost_threshold_rpc', true), '') = 'on'
  );

  if tg_op = 'UPDATE' and caller_is_rpc then
    if new.id is distinct from old.id then
      raise exception 'Singleton id cannot be altered'
        using errcode = '42501';
    end if;
    return new;
  end if;

  raise exception 'System compute cost settings must be updated via update_ai_compute_cost_threshold()'
    using errcode = '42501';
end;
$guard$;

drop trigger if exists guard_ai_compute_cost_alert_settings
  on public.ai_compute_cost_alert_settings;
create trigger guard_ai_compute_cost_alert_settings
  before insert or update or delete on public.ai_compute_cost_alert_settings
  for each row
  execute function public.guard_ai_compute_cost_alert_settings();

create or replace function public.get_ai_compute_cost_aggregates(
  p_days integer default 30
)
returns table (
  bucket_type text,
  bucket_key text,
  request_count bigint,
  total_input_tokens bigint,
  total_output_tokens bigint,
  avg_latency_ms numeric,
  total_estimated_cost_usd numeric
)
language sql
stable
security invoker
set search_path = public
as $$
  with scoped as (
    select *
    from public.ai_compute_cost_telemetry
    where recorded_at >= timezone('utc', now())
      - make_interval(days => greatest(1, least(coalesce(p_days, 30), 365)))
  )
  select
    'daily'::text as bucket_type,
    to_char(date_trunc('day', recorded_at at time zone 'UTC'), 'YYYY-MM-DD') as bucket_key,
    sum(api_request_count)::bigint as request_count,
    sum(input_tokens)::bigint as total_input_tokens,
    sum(output_tokens)::bigint as total_output_tokens,
    round(avg(latency_ms), 1) as avg_latency_ms,
    round(sum(estimated_compute_cost_usd), 6) as total_estimated_cost_usd
  from scoped
  group by 1, 2
  union all
  select
    'monthly'::text as bucket_type,
    to_char(date_trunc('month', recorded_at at time zone 'UTC'), 'YYYY-MM') as bucket_key,
    sum(api_request_count)::bigint as request_count,
    sum(input_tokens)::bigint as total_input_tokens,
    sum(output_tokens)::bigint as total_output_tokens,
    round(avg(latency_ms), 1) as avg_latency_ms,
    round(sum(estimated_compute_cost_usd), 6) as total_estimated_cost_usd
  from scoped
  group by 1, 2
  order by 1 asc, 2 desc;
$$;

revoke all on function public.get_ai_compute_cost_aggregates(integer) from public, anon;
grant execute on function public.get_ai_compute_cost_aggregates(integer) to authenticated, service_role;

comment on table public.ai_compute_cost_telemetry is
  'Stores per-invocation AI token consumption, request count, latency, and estimated GPU/API compute costs in USD (#2658).';
comment on table public.ai_compute_cost_alert_settings is
  'Stores global daily and monthly AI compute cost threshold limits for operations alerting (#2658).';
