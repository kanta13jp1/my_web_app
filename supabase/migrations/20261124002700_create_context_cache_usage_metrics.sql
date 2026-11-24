-- Migration for Issue #2656: Context Cache Usage & Cost Monitor (Anthropic / Gemini Prompt Caching)

create table if not exists public.context_cache_usage_metrics (
  id uuid primary key default gen_random_uuid(),
  request_id text not null
    check (char_length(trim(request_id)) between 1 and 120),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  workflow_key text not null
    check (char_length(trim(workflow_key)) between 1 and 100),
  provider text not null
    check (provider in ('anthropic', 'gemini', 'openai')),
  model_id text not null
    check (char_length(trim(model_id)) between 1 and 100),
  cache_write_tokens integer not null default 0
    check (cache_write_tokens >= 0),
  cache_read_tokens integer not null default 0
    check (cache_read_tokens >= 0),
  uncached_input_tokens integer not null default 0
    check (uncached_input_tokens >= 0),
  output_tokens integer not null default 0
    check (output_tokens >= 0),
  uncached_baseline_usd numeric(12,6) not null default 0
    check (uncached_baseline_usd >= 0),
  actual_estimated_usd numeric(12,6) not null default 0
    check (actual_estimated_usd >= 0),
  net_savings_usd numeric(12,6) not null default 0,
  savings_ratio numeric(8,4) not null default 0
    check (savings_ratio >= -1.0 and savings_ratio <= 1.0),
  cache_hit boolean not null default false,
  rate_card_version text not null default 'provider-ref-2026-11'
    check (char_length(trim(rate_card_version)) between 1 and 60),
  estimate_disclaimer text not null
    default 'Provider reference baseline estimate (~0.10x cached read); verify against live provider billing.',
  created_at timestamptz not null default timezone('utc', now()),
  unique (user_id, request_id)
);

create index if not exists idx_context_cache_usage_user_created
  on public.context_cache_usage_metrics (user_id, created_at desc);

create index if not exists idx_context_cache_usage_workflow_created
  on public.context_cache_usage_metrics (workflow_key, created_at desc);

alter table public.context_cache_usage_metrics enable row level security;

revoke all on table public.context_cache_usage_metrics from public, anon;
grant select, insert, delete on table public.context_cache_usage_metrics to authenticated;
grant all on table public.context_cache_usage_metrics to service_role;

drop policy if exists "context_cache_usage_select_own_or_admin"
  on public.context_cache_usage_metrics;
create policy "context_cache_usage_select_own_or_admin"
  on public.context_cache_usage_metrics
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

drop policy if exists "context_cache_usage_insert_own"
  on public.context_cache_usage_metrics;
create policy "context_cache_usage_insert_own"
  on public.context_cache_usage_metrics
  for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "context_cache_usage_delete_own_or_admin"
  on public.context_cache_usage_metrics;
create policy "context_cache_usage_delete_own_or_admin"
  on public.context_cache_usage_metrics
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

create or replace function public.guard_context_cache_usage_metric_fields()
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
      new.cache_hit := (new.cache_read_tokens > 0);
      new.net_savings_usd := round((new.uncached_baseline_usd - new.actual_estimated_usd)::numeric, 6);
      new.created_at := coalesce(new.created_at, timezone('utc', now()));
    end if;
    return new;
  end if;

  if tg_op = 'INSERT' then
    if auth.uid() is null or new.user_id is distinct from auth.uid() then
      raise exception 'Authenticated owner user_id is required on context cache metric insert'
        using errcode = '42501';
    end if;
    new.cache_hit := (new.cache_read_tokens > 0);
    new.net_savings_usd := round((new.uncached_baseline_usd - new.actual_estimated_usd)::numeric, 6);
    if new.uncached_baseline_usd > 0 then
      new.savings_ratio := greatest(
        -1.0000,
        least(
          1.0000,
          round(((new.uncached_baseline_usd - new.actual_estimated_usd) / new.uncached_baseline_usd)::numeric, 4)
        )
      );
    else
      new.savings_ratio := 0;
    end if;
    new.created_at := timezone('utc', now());
    return new;
  end if;

  if tg_op = 'UPDATE' then
    raise exception 'Context cache usage metrics are append-only'
      using errcode = '42501';
  end if;

  return new;
end;
$guard$;

drop trigger if exists guard_context_cache_usage_metric_fields
  on public.context_cache_usage_metrics;
create trigger guard_context_cache_usage_metric_fields
  before insert or update on public.context_cache_usage_metrics
  for each row
  execute function public.guard_context_cache_usage_metric_fields();

create or replace function public.get_context_cache_usage_summary(
  p_workflow_key text default null
)
returns table (
  workflow_key text,
  user_id uuid,
  request_count bigint,
  cache_hit_count bigint,
  total_cache_write_tokens bigint,
  total_cache_read_tokens bigint,
  total_uncached_baseline_usd numeric,
  total_actual_estimated_usd numeric,
  total_net_savings_usd numeric,
  weighted_savings_ratio numeric
)
language plpgsql
security invoker
set search_path = public
as $fn$
declare
  jwt_role text;
  cleaned_workflow text;
begin
  jwt_role := coalesce(
    nullif(auth.jwt() ->> 'role', ''),
    nullif(current_setting('request.jwt.claim.role', true), ''),
    ''
  );

  if auth.uid() is null and jwt_role <> 'service_role' then
    raise exception 'Authenticated caller is required'
      using errcode = '42501';
  end if;

  cleaned_workflow := nullif(trim(coalesce(p_workflow_key, '')), '');

  return query
  select
    m.workflow_key,
    m.user_id,
    count(*)::bigint as request_count,
    count(*) filter (where m.cache_hit)::bigint as cache_hit_count,
    coalesce(sum(m.cache_write_tokens), 0)::bigint as total_cache_write_tokens,
    coalesce(sum(m.cache_read_tokens), 0)::bigint as total_cache_read_tokens,
    coalesce(sum(m.uncached_baseline_usd), 0)::numeric as total_uncached_baseline_usd,
    coalesce(sum(m.actual_estimated_usd), 0)::numeric as total_actual_estimated_usd,
    coalesce(sum(m.net_savings_usd), 0)::numeric as total_net_savings_usd,
    case
      when coalesce(sum(m.uncached_baseline_usd), 0) > 0 then
        round((coalesce(sum(m.net_savings_usd), 0) / sum(m.uncached_baseline_usd))::numeric, 4)
      else 0::numeric
    end as weighted_savings_ratio
  from public.context_cache_usage_metrics as m
  where (cleaned_workflow is null or m.workflow_key = cleaned_workflow)
  group by m.workflow_key, m.user_id
  order by total_actual_estimated_usd desc, m.workflow_key asc;
end;
$fn$;

revoke all on function public.get_context_cache_usage_summary(text) from public, anon;
grant execute on function public.get_context_cache_usage_summary(text) to authenticated, service_role;

comment on table public.context_cache_usage_metrics is
  'Append-only prompt/context cache token usage and reference USD savings log (#2656).';
