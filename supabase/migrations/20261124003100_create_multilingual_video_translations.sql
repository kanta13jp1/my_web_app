-- Migration for Issue #2660: D-ID Video Translate Multilingual Lip-Sync Pipeline
-- Stores source video metadata, localized translation jobs/results, duration/cost caps,
-- and AI-generated provenance metadata with owner/admin RLS and trigger-enforced field locks.

create table if not exists public.multilingual_video_translations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  source_video_id text not null check (char_length(trim(source_video_id)) > 0),
  source_video_url text not null check (source_video_url ~* '^https://'),
  source_language text check (source_language is null or char_length(trim(source_language)) > 0),
  language_code text not null check (language_code ~ '^[a-z]{2}(-[A-Za-z0-9]{2,8})?$'),
  did_language_name text not null check (char_length(trim(did_language_name)) > 0),
  provider_name text not null default 'd-id' check (provider_name in ('d-id')),
  provider_job_id text check (provider_job_id is null or char_length(trim(provider_job_id)) > 0),
  provider_group_id text check (provider_group_id is null or char_length(trim(provider_group_id)) > 0),
  status text not null default 'queued'
    check (status in ('queued', 'validating', 'processing', 'done', 'rejected', 'error', 'dry_run')),
  result_url text check (result_url is null or result_url ~* '^https://'),
  subtitles_url text check (subtitles_url is null or subtitles_url ~* '^https://'),
  thumbnail_url text check (thumbnail_url is null or thumbnail_url ~* '^https://'),
  duration_seconds numeric(10, 2) not null
    check (duration_seconds > 0 and duration_seconds <= max_duration_cap_seconds),
  max_duration_cap_seconds integer not null default 120
    check (max_duration_cap_seconds > 0 and max_duration_cap_seconds <= 600),
  estimated_cost_usd numeric(12, 6) not null default 0
    check (estimated_cost_usd >= 0 and estimated_cost_usd <= max_cost_cap_usd),
  max_cost_cap_usd numeric(12, 6) not null default 5.000000
    check (max_cost_cap_usd >= 0 and max_cost_cap_usd <= 50.000000),
  ai_provenance_disclosure text not null default 'AI 生成・リップシンク翻訳動画',
  result_expires_at timestamptz,
  error_reason text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_multilingual_video_translations_video_lang_created
  on public.multilingual_video_translations (source_video_id, language_code, created_at desc);

create index if not exists idx_multilingual_video_translations_user_created
  on public.multilingual_video_translations (user_id, created_at desc);

create index if not exists idx_multilingual_video_translations_status_updated
  on public.multilingual_video_translations (status, updated_at desc);

alter table public.multilingual_video_translations enable row level security;

revoke all on table public.multilingual_video_translations from public, anon, authenticated;
grant select, insert, update on table public.multilingual_video_translations to authenticated;
grant all on table public.multilingual_video_translations to service_role;

drop policy if exists "multilingual_video_translations_select_own_or_admin"
  on public.multilingual_video_translations;
create policy "multilingual_video_translations_select_own_or_admin"
  on public.multilingual_video_translations
  for select
  to authenticated
  using (
    auth.uid() = user_id
    or exists (
      select 1
      from public.user_profiles up
      where up.user_id = auth.uid()
        and up.is_admin = true
    )
  );

drop policy if exists "multilingual_video_translations_insert_own"
  on public.multilingual_video_translations;
create policy "multilingual_video_translations_insert_own"
  on public.multilingual_video_translations
  for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "multilingual_video_translations_update_own_or_admin"
  on public.multilingual_video_translations;
create policy "multilingual_video_translations_update_own_or_admin"
  on public.multilingual_video_translations
  for update
  to authenticated
  using (
    auth.uid() = user_id
    or exists (
      select 1
      from public.user_profiles up
      where up.user_id = auth.uid()
        and up.is_admin = true
    )
  )
  with check (
    auth.uid() = user_id
    or exists (
      select 1
      from public.user_profiles up
      where up.user_id = auth.uid()
        and up.is_admin = true
    )
  );

create or replace function public.guard_multilingual_video_translation_fields()
returns trigger
language plpgsql
security invoker
set search_path = public, auth
as $guard$
declare
  v_jwt_role text := coalesce(
    nullif(auth.jwt() ->> 'role', ''),
    nullif(current_setting('request.jwt.claim.role', true), ''),
    ''
  );
  v_actor_id uuid := auth.uid();
  v_is_service boolean := (v_jwt_role = 'service_role')
    or (
      v_jwt_role = ''
      and session_user in ('postgres', 'supabase_admin', 'supabase_auth_admin')
    );
  v_is_admin boolean := false;
begin
  if v_actor_id is not null then
    select exists (
      select 1
      from public.user_profiles up
      where up.user_id = v_actor_id
        and up.is_admin = true
    )
      into v_is_admin;
  end if;

  if TG_OP = 'DELETE' then
    if not (v_is_service or v_is_admin) then
      raise exception 'multilingual_video_translations records cannot be deleted by non-admin users'
        using errcode = '42501';
    end if;
    return old;
  end if;

  if TG_OP = 'INSERT' then
    if not (v_is_service or v_is_admin) then
      if v_actor_id is null or new.user_id is distinct from v_actor_id then
        raise exception 'user_id must match authenticated auth.uid()'
          using errcode = '42501';
      end if;

      if new.status is distinct from 'queued'
        or new.provider_job_id is not null
        or new.provider_group_id is not null
        or new.result_url is not null
        or new.subtitles_url is not null
        or new.thumbnail_url is not null
        or new.result_expires_at is not null then
        raise exception 'status, provider_job_id, and result_url are managed exclusively by admin or service_role'
          using errcode = '42501';
      end if;
    elsif new.user_id is null then
      raise exception 'user_id must not be null'
        using errcode = '42501';
    end if;

    new.created_at := coalesce(new.created_at, timezone('utc', now()));
    new.updated_at := timezone('utc', now());
    return new;
  end if;

  -- UPDATE path: lock immutable identity & timestamp columns for every actor.
  if new.id is distinct from old.id
    or new.user_id is distinct from old.user_id
    or new.created_at is distinct from old.created_at then
    raise exception 'id, user_id, and created_at are immutable'
      using errcode = '42501';
  end if;

  if not (v_is_service or v_is_admin) then
    if new.status is distinct from old.status
      or new.provider_job_id is distinct from old.provider_job_id
      or new.provider_group_id is distinct from old.provider_group_id
      or new.result_url is distinct from old.result_url
      or new.subtitles_url is distinct from old.subtitles_url
      or new.thumbnail_url is distinct from old.thumbnail_url
      or new.result_expires_at is distinct from old.result_expires_at
      or new.estimated_cost_usd is distinct from old.estimated_cost_usd
      or new.max_duration_cap_seconds is distinct from old.max_duration_cap_seconds
      or new.max_cost_cap_usd is distinct from old.max_cost_cap_usd
      or new.duration_seconds is distinct from old.duration_seconds
      or new.source_video_id is distinct from old.source_video_id
      or new.source_video_url is distinct from old.source_video_url
      or new.language_code is distinct from old.language_code
      or new.did_language_name is distinct from old.did_language_name then
      raise exception 'provider status, job IDs, result URLs, and cost caps can only be updated by admin or service_role'
        using errcode = '42501';
    end if;
  end if;

  new.updated_at := timezone('utc', now());
  return new;
end;
$guard$;

drop trigger if exists guard_multilingual_video_translation_fields
  on public.multilingual_video_translations;
create trigger guard_multilingual_video_translation_fields
  before insert or update or delete on public.multilingual_video_translations
  for each row
  execute function public.guard_multilingual_video_translation_fields();

create or replace function public.get_multilingual_video_translation_summary(
  p_days integer default 30
)
returns table (
  total_jobs bigint,
  done_jobs bigint,
  active_jobs bigint,
  failed_jobs bigint,
  total_duration_seconds numeric,
  total_estimated_cost_usd numeric,
  distinct_languages bigint
)
language sql
stable
security invoker
set search_path = public
as $$
  with bounded as (
    select greatest(1, least(coalesce(p_days, 30), 365)) as window_days
  ),
  scoped as (
    select
      mvt.status,
      mvt.duration_seconds,
      mvt.estimated_cost_usd,
      mvt.language_code
    from public.multilingual_video_translations mvt
    cross join bounded b
    where mvt.created_at >= timezone('utc', now()) - make_interval(days => b.window_days)
  )
  select
    count(*)::bigint as total_jobs,
    count(*) filter (where status = 'done')::bigint as done_jobs,
    count(*) filter (where status in ('queued', 'validating', 'processing'))::bigint as active_jobs,
    count(*) filter (where status in ('rejected', 'error'))::bigint as failed_jobs,
    coalesce(sum(duration_seconds), 0)::numeric(12, 2) as total_duration_seconds,
    coalesce(sum(estimated_cost_usd), 0)::numeric(12, 6) as total_estimated_cost_usd,
    count(distinct language_code)::bigint as distinct_languages
  from scoped;
$$;

revoke all on function public.get_multilingual_video_translation_summary(integer) from public, anon;
grant execute on function public.get_multilingual_video_translation_summary(integer) to authenticated, service_role;

comment on table public.multilingual_video_translations is
  'D-ID Video Translate multilingual lip-sync jobs, localized playback URLs, and duration/cost caps (#2660).';
