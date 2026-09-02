-- Voice AI consent, usage, and realtime latency governance.
-- Consent is intentionally kept out of public.user_profiles because that table
-- supports public profile reads and must not expose privacy preferences.

create table if not exists public.voice_ai_user_preferences (
  user_id uuid primary key references auth.users(id) on delete cascade,
  training_consent boolean not null default false,
  consent_updated_at timestamptz,
  created_at timestamptz not null default now()
);

alter table public.voice_ai_user_preferences enable row level security;

create or replace function public.set_voice_ai_consent_audit_fields()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    new.created_at := pg_catalog.now();
    new.consent_updated_at := pg_catalog.now();
  else
    new.user_id := old.user_id;
    new.created_at := old.created_at;
    if new.training_consent is distinct from old.training_consent then
      new.consent_updated_at := pg_catalog.now();
    else
      new.consent_updated_at := old.consent_updated_at;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists set_voice_ai_consent_audit_fields
  on public.voice_ai_user_preferences;
create trigger set_voice_ai_consent_audit_fields
  before insert or update on public.voice_ai_user_preferences
  for each row
  execute function public.set_voice_ai_consent_audit_fields();

drop policy if exists "voice ai preferences own select"
  on public.voice_ai_user_preferences;
create policy "voice ai preferences own select"
  on public.voice_ai_user_preferences
  for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "voice ai preferences own insert"
  on public.voice_ai_user_preferences;
create policy "voice ai preferences own insert"
  on public.voice_ai_user_preferences
  for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "voice ai preferences own update"
  on public.voice_ai_user_preferences;
create policy "voice ai preferences own update"
  on public.voice_ai_user_preferences
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "voice ai preferences admins select all"
  on public.voice_ai_user_preferences;
create policy "voice ai preferences admins select all"
  on public.voice_ai_user_preferences
  for select
  to authenticated
  using ((select public.is_user_admin((select auth.uid()))));

drop policy if exists "voice ai preferences service role all"
  on public.voice_ai_user_preferences;
create policy "voice ai preferences service role all"
  on public.voice_ai_user_preferences
  for all
  to service_role
  using (true)
  with check (true);

grant select on public.voice_ai_user_preferences to authenticated;
grant insert (user_id, training_consent)
  on public.voice_ai_user_preferences to authenticated;
grant update (training_consent)
  on public.voice_ai_user_preferences to authenticated;
grant select, insert, update, delete on public.voice_ai_user_preferences
  to service_role;

create table if not exists public.voice_ai_usage_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  provider text not null,
  feature text not null,
  metric_type text not null check (
    metric_type in (
      'tts_chars',
      'stt_seconds',
      'audio_bytes',
      'ttfa_ms',
      'chunk_latency_ms'
    )
  ),
  quantity numeric(14, 3) not null check (quantity >= 0),
  estimated_cost_usd numeric(14, 6) not null default 0 check (
    estimated_cost_usd >= 0
  ),
  consent_to_training boolean not null default false,
  zero_data_retention_requested boolean not null default true,
  blocked boolean not null default false,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists voice_ai_usage_events_user_created_idx
  on public.voice_ai_usage_events (user_id, created_at desc);

create index if not exists voice_ai_usage_events_provider_created_idx
  on public.voice_ai_usage_events (provider, created_at desc);

alter table public.voice_ai_usage_events enable row level security;

drop policy if exists "voice ai usage select own" on public.voice_ai_usage_events;
create policy "voice ai usage select own"
  on public.voice_ai_usage_events
  for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "voice ai usage service role all" on public.voice_ai_usage_events;
create policy "voice ai usage service role all"
  on public.voice_ai_usage_events
  for all
  to service_role
  using (true)
  with check (true);

drop policy if exists "voice ai usage admins select all" on public.voice_ai_usage_events;
create policy "voice ai usage admins select all"
  on public.voice_ai_usage_events
  for select
  to authenticated
  using ((select public.is_user_admin((select auth.uid()))));

grant select on public.voice_ai_usage_events to authenticated;
grant select, insert, update, delete on public.voice_ai_usage_events
  to service_role;

create or replace function public.record_voice_ai_usage(
  p_user_id uuid,
  p_provider text,
  p_feature text,
  p_metric_type text,
  p_quantity numeric,
  p_estimated_cost_usd numeric default 0,
  p_consent_to_training boolean default false,
  p_zero_data_retention_requested boolean default true,
  p_metadata jsonb default '{}'::jsonb,
  p_daily_limit numeric default null,
  p_monthly_limit numeric default null
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_day_start timestamptz := date_trunc('day', now());
  v_month_start timestamptz := date_trunc('month', now());
  v_quantity numeric := greatest(coalesce(p_quantity, 0), 0);
  v_estimated_cost numeric := greatest(coalesce(p_estimated_cost_usd, 0), 0);
  v_daily_existing numeric := 0;
  v_monthly_existing numeric := 0;
  v_daily_total numeric := 0;
  v_monthly_total numeric := 0;
  v_blocked boolean := false;
  v_event public.voice_ai_usage_events;
begin
  if p_user_id is null then
    raise exception 'p_user_id is required';
  end if;

  if coalesce(trim(p_provider), '') = '' then
    raise exception 'p_provider is required';
  end if;

  if coalesce(trim(p_feature), '') = '' then
    raise exception 'p_feature is required';
  end if;

  if p_metric_type not in (
    'tts_chars',
    'stt_seconds',
    'audio_bytes',
    'ttfa_ms',
    'chunk_latency_ms'
  ) then
    raise exception 'unsupported metric_type: %', p_metric_type;
  end if;

  perform pg_advisory_xact_lock(
    hashtext(p_user_id::text || ':' || p_provider || ':' || p_metric_type)
  );

  select coalesce(sum(quantity), 0)
    into v_daily_existing
    from public.voice_ai_usage_events
   where user_id = p_user_id
     and provider = p_provider
     and metric_type = p_metric_type
     and blocked = false
     and created_at >= v_day_start
     and created_at < v_day_start + interval '1 day';

  select coalesce(sum(quantity), 0)
    into v_monthly_existing
    from public.voice_ai_usage_events
   where user_id = p_user_id
     and provider = p_provider
     and metric_type = p_metric_type
     and blocked = false
     and created_at >= v_month_start
     and created_at < v_month_start + interval '1 month';

  v_daily_total := v_daily_existing + v_quantity;
  v_monthly_total := v_monthly_existing + v_quantity;
  v_blocked := (
    (p_daily_limit is not null and v_daily_total > p_daily_limit) or
    (p_monthly_limit is not null and v_monthly_total > p_monthly_limit)
  );

  insert into public.voice_ai_usage_events (
    user_id,
    provider,
    feature,
    metric_type,
    quantity,
    estimated_cost_usd,
    consent_to_training,
    zero_data_retention_requested,
    blocked,
    metadata
  ) values (
    p_user_id,
    p_provider,
    p_feature,
    p_metric_type,
    v_quantity,
    v_estimated_cost,
    coalesce(p_consent_to_training, false),
    coalesce(p_zero_data_retention_requested, true),
    v_blocked,
    coalesce(p_metadata, '{}'::jsonb) || jsonb_build_object(
      'daily_total', v_daily_total,
      'monthly_total', v_monthly_total,
      'daily_limit', p_daily_limit,
      'monthly_limit', p_monthly_limit
    )
  )
  returning * into v_event;

  return jsonb_build_object(
    'event_id', v_event.id,
    'blocked', v_blocked,
    'daily_total', v_daily_total,
    'monthly_total', v_monthly_total,
    'daily_limit', p_daily_limit,
    'monthly_limit', p_monthly_limit,
    'estimated_cost_usd', v_estimated_cost,
    'created_at', v_event.created_at
  );
end;
$$;

revoke all on function public.record_voice_ai_usage(
  uuid,
  text,
  text,
  text,
  numeric,
  numeric,
  boolean,
  boolean,
  jsonb,
  numeric,
  numeric
) from public, anon, authenticated;

grant execute on function public.record_voice_ai_usage(
  uuid,
  text,
  text,
  text,
  numeric,
  numeric,
  boolean,
  boolean,
  jsonb,
  numeric,
  numeric
) to service_role;

create or replace view public.voice_ai_usage_daily_summary
with (security_invoker = true)
as
select
  user_id,
  provider,
  date_trunc('day', created_at)::date as usage_date,
  sum(quantity) filter (where metric_type = 'tts_chars' and blocked = false) as tts_chars,
  sum(quantity) filter (where metric_type = 'stt_seconds' and blocked = false) as stt_seconds,
  sum(quantity) filter (where metric_type = 'audio_bytes' and blocked = false) as audio_bytes,
  avg(quantity) filter (where metric_type = 'ttfa_ms' and blocked = false) as avg_ttfa_ms,
  avg(quantity) filter (where metric_type = 'chunk_latency_ms' and blocked = false) as avg_chunk_latency_ms,
  sum(estimated_cost_usd) filter (where blocked = false) as estimated_cost_usd,
  count(*) as event_count,
  count(*) filter (where blocked = true) as blocked_event_count,
  max(created_at) as last_event_at
from public.voice_ai_usage_events
group by user_id, provider, date_trunc('day', created_at)::date;

grant select on public.voice_ai_usage_daily_summary to authenticated;
grant select on public.voice_ai_usage_daily_summary to service_role;

create or replace view public.voice_ai_usage_provider_daily_summary
with (security_invoker = true)
as
select
  provider,
  date_trunc('day', created_at)::date as usage_date,
  sum(quantity) filter (where metric_type = 'tts_chars' and blocked = false) as tts_chars,
  sum(quantity) filter (where metric_type = 'stt_seconds' and blocked = false) as stt_seconds,
  sum(quantity) filter (where metric_type = 'audio_bytes' and blocked = false) as audio_bytes,
  avg(quantity) filter (where metric_type = 'ttfa_ms' and blocked = false) as avg_ttfa_ms,
  avg(quantity) filter (where metric_type = 'chunk_latency_ms' and blocked = false) as avg_chunk_latency_ms,
  sum(estimated_cost_usd) filter (where blocked = false) as estimated_cost_usd,
  count(*) as event_count,
  count(*) filter (where blocked = true) as blocked_event_count,
  max(created_at) as last_event_at
from public.voice_ai_usage_events
group by provider, date_trunc('day', created_at)::date;

grant select on public.voice_ai_usage_provider_daily_summary to authenticated;
grant select on public.voice_ai_usage_provider_daily_summary to service_role;

comment on column public.voice_ai_usage_events.zero_data_retention_requested is
  'User privacy intent only. Actual provider ZDR is enforced only when its administrator-confirmed runtime flag is true.';
