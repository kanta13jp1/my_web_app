-- Migration for Issue #2661: Synthetic Media Ethics Pledge, Track-and-Trace & Video Audit Moderation

create table if not exists public.synthetic_media_videos (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  title text not null check (char_length(trim(title)) between 1 and 200),
  video_url text not null check (video_url ~* '^https://'),
  source_provider text not null default 'd_id'
    check (source_provider in ('d_id', 'notebooklm', 'hybrid', 'custom')),
  copyright_consent_status text not null default 'pending'
    check (copyright_consent_status in ('pending', 'verified', 'rejected')),
  likeness_consent_status text not null default 'pending'
    check (likeness_consent_status in ('pending', 'verified', 'rejected')),
  commercial_watermark_present boolean not null default false,
  celebrity_likeness_cleared boolean not null default false,
  track_and_trace_provider text not null default 'none'
    check (track_and_trace_provider in ('none', 'c2pa', 'digital_watermark', 'custom')),
  track_and_trace_id text
    check (track_and_trace_id is null or char_length(trim(track_and_trace_id)) <= 200),
  track_and_trace_metadata jsonb not null default '{}'::jsonb,
  moderation_status text not null default 'pending'
    check (moderation_status in ('pending', 'approved', 'rejected')),
  is_approved boolean not null default false,
  reviewed_by uuid references auth.users (id) on delete set null,
  reviewed_at timestamptz,
  review_note text check (review_note is null or char_length(trim(review_note)) <= 1000),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  check ((moderation_status = 'approved') = is_approved),
  check (
    moderation_status <> 'rejected'
    or (review_note is not null and char_length(trim(review_note)) > 0)
  )
);

create index if not exists idx_synthetic_media_videos_status_created
  on public.synthetic_media_videos (moderation_status, is_approved, created_at desc);

create index if not exists idx_synthetic_media_videos_user_created
  on public.synthetic_media_videos (user_id, created_at desc);

create table if not exists public.synthetic_media_audit_logs (
  id uuid primary key default gen_random_uuid(),
  video_id uuid not null references public.synthetic_media_videos (id) on delete cascade,
  actor_id uuid references auth.users (id) on delete set null,
  action text not null check (action in ('submitted', 'approved', 'rejected', 'metadata_updated')),
  previous_status text
    check (previous_status is null or previous_status in ('pending', 'approved', 'rejected')),
  new_status text not null check (new_status in ('pending', 'approved', 'rejected')),
  reason text check (reason is null or char_length(trim(reason)) <= 1000),
  track_and_trace_snapshot jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_synthetic_media_audit_logs_video_created
  on public.synthetic_media_audit_logs (video_id, created_at desc);

alter table public.synthetic_media_videos enable row level security;
alter table public.synthetic_media_audit_logs enable row level security;

revoke all on table public.synthetic_media_videos from public, anon, authenticated;
grant select on table public.synthetic_media_videos to authenticated;
grant all on table public.synthetic_media_videos to service_role;

revoke all on table public.synthetic_media_audit_logs from public, anon, authenticated;
grant select on table public.synthetic_media_audit_logs to authenticated;
grant all on table public.synthetic_media_audit_logs to service_role;

-- General authenticated users may read strictly approved videos only.
drop policy if exists "synthetic_media_videos_select_approved"
  on public.synthetic_media_videos;
create policy "synthetic_media_videos_select_approved"
  on public.synthetic_media_videos
  for select
  to authenticated
  using (is_approved = true and moderation_status = 'approved');

drop policy if exists "synthetic_media_videos_select_admin"
  on public.synthetic_media_videos;
create policy "synthetic_media_videos_select_admin"
  on public.synthetic_media_videos
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.user_profiles up
      where up.user_id = auth.uid()
        and up.is_admin = true
    )
  );

drop policy if exists "synthetic_media_audit_logs_select_admin"
  on public.synthetic_media_audit_logs;
create policy "synthetic_media_audit_logs_select_admin"
  on public.synthetic_media_audit_logs
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.user_profiles up
      where up.user_id = auth.uid()
        and up.is_admin = true
    )
  );

create or replace function public.guard_synthetic_media_audit_logs_immutable()
returns trigger
language plpgsql
security invoker
set search_path = public, pg_catalog, pg_temp
as $guard$
begin
  raise exception 'synthetic_media_audit_logs is append-only; UPDATE and DELETE are forbidden'
    using errcode = '42501';
end;
$guard$;

drop trigger if exists guard_synthetic_media_audit_logs_immutable
  on public.synthetic_media_audit_logs;
create trigger guard_synthetic_media_audit_logs_immutable
  before update or delete on public.synthetic_media_audit_logs
  for each row
  execute function public.guard_synthetic_media_audit_logs_immutable();

create or replace function public.guard_synthetic_media_videos_fields()
returns trigger
language plpgsql
security invoker
set search_path = public, auth, pg_catalog, pg_temp
as $guard$
declare
  v_jwt_role text := coalesce(
    nullif(auth.jwt() ->> 'role', ''),
    nullif(current_setting('request.jwt.claim.role', true), ''),
    ''
  );
  v_is_service boolean := (v_jwt_role = 'service_role')
    or (
      v_jwt_role = ''
      and session_user in ('postgres', 'supabase_admin', 'supabase_auth_admin')
    );
  v_rpc_active boolean :=
    coalesce(current_setting('app.synthetic_media_rpc_active', true), '') = 'on';
begin
  if TG_OP = 'DELETE' then
    if not v_is_service then
      raise exception 'synthetic_media_videos records cannot be deleted directly'
        using errcode = '42501';
    end if;
    return old;
  end if;

  if not v_is_service and not v_rpc_active then
    raise exception 'synthetic_media_videos mutations must go through audited RPCs'
      using errcode = '42501';
  end if;

  if TG_OP = 'INSERT' then
    if not v_is_service then
      if new.moderation_status is distinct from 'pending'
        or new.is_approved is distinct from false
        or new.reviewed_by is not null
        or new.reviewed_at is not null then
        raise exception 'new synthetic media submissions must start pending and unapproved'
          using errcode = '42501';
      end if;
    end if;
    new.created_at := coalesce(new.created_at, timezone('utc', now()));
    new.updated_at := timezone('utc', now());
    return new;
  end if;

  -- UPDATE path: enforce bidirectional immutability on identity and creation timestamp.
  if new.id is distinct from old.id
    or new.user_id is distinct from old.user_id
    or new.created_at is distinct from old.created_at then
    raise exception 'id, user_id, and created_at are immutable'
      using errcode = '42501';
  end if;

  if not v_is_service and not v_rpc_active then
    if new.moderation_status is distinct from old.moderation_status
      or new.is_approved is distinct from old.is_approved
      or new.reviewed_by is distinct from old.reviewed_by
      or new.reviewed_at is distinct from old.reviewed_at
      or new.review_note is distinct from old.review_note then
      raise exception 'moderation state is managed exclusively by review RPC or service_role'
        using errcode = '42501';
    end if;
  end if;

  new.updated_at := timezone('utc', now());
  return new;
end;
$guard$;

drop trigger if exists guard_synthetic_media_videos_fields
  on public.synthetic_media_videos;
create trigger guard_synthetic_media_videos_fields
  before insert or update or delete on public.synthetic_media_videos
  for each row
  execute function public.guard_synthetic_media_videos_fields();

create or replace function public.submit_synthetic_media_video(
  p_title text,
  p_video_url text,
  p_source_provider text default 'd_id',
  p_copyright_consent_status text default 'pending',
  p_likeness_consent_status text default 'pending',
  p_commercial_watermark_present boolean default false,
  p_celebrity_likeness_cleared boolean default false,
  p_track_and_trace_provider text default 'none',
  p_track_and_trace_id text default null,
  p_track_and_trace_metadata jsonb default '{}'::jsonb
)
returns public.synthetic_media_videos
language plpgsql
security definer
set search_path = public, auth, pg_catalog, pg_temp
as $fn$
declare
  v_actor_id uuid := auth.uid();
  v_created public.synthetic_media_videos;
  v_snapshot jsonb;
begin
  if v_actor_id is null then
    raise exception 'authenticated user required to submit synthetic media video'
      using errcode = '42501';
  end if;

  v_snapshot := jsonb_build_object(
    'provider', coalesce(p_track_and_trace_provider, 'none'),
    'id', p_track_and_trace_id,
    'watermark', coalesce(p_commercial_watermark_present, false),
    'celebrity_cleared', coalesce(p_celebrity_likeness_cleared, false),
    'copyright_consent', coalesce(p_copyright_consent_status, 'pending'),
    'likeness_consent', coalesce(p_likeness_consent_status, 'pending'),
    'metadata', coalesce(p_track_and_trace_metadata, '{}'::jsonb)
  );

  perform set_config('app.synthetic_media_rpc_active', 'on', true);

  insert into public.synthetic_media_videos (
    user_id,
    title,
    video_url,
    source_provider,
    copyright_consent_status,
    likeness_consent_status,
    commercial_watermark_present,
    celebrity_likeness_cleared,
    track_and_trace_provider,
    track_and_trace_id,
    track_and_trace_metadata,
    moderation_status,
    is_approved
  ) values (
    v_actor_id,
    trim(p_title),
    trim(p_video_url),
    coalesce(nullif(trim(p_source_provider), ''), 'd_id'),
    coalesce(nullif(trim(p_copyright_consent_status), ''), 'pending'),
    coalesce(nullif(trim(p_likeness_consent_status), ''), 'pending'),
    coalesce(p_commercial_watermark_present, false),
    coalesce(p_celebrity_likeness_cleared, false),
    coalesce(nullif(trim(p_track_and_trace_provider), ''), 'none'),
    nullif(trim(coalesce(p_track_and_trace_id, '')), ''),
    coalesce(p_track_and_trace_metadata, '{}'::jsonb),
    'pending',
    false
  )
  returning * into v_created;

  insert into public.synthetic_media_audit_logs (
    video_id,
    actor_id,
    action,
    previous_status,
    new_status,
    reason,
    track_and_trace_snapshot
  ) values (
    v_created.id,
    v_actor_id,
    'submitted',
    null,
    'pending',
    'submitted for synthetic media ethics review',
    v_snapshot
  );

  perform set_config('app.synthetic_media_rpc_active', 'off', true);
  return v_created;
exception
  when others then
    perform set_config('app.synthetic_media_rpc_active', 'off', true);
    raise;
end;
$fn$;

revoke all on function public.submit_synthetic_media_video(
  text, text, text, text, text, boolean, boolean, text, text, jsonb
) from public, anon;
grant execute on function public.submit_synthetic_media_video(
  text, text, text, text, text, boolean, boolean, text, text, jsonb
) to authenticated, service_role;

create or replace function public.review_synthetic_media_video(
  p_video_id uuid,
  p_decision text,
  p_review_note text default null
)
returns public.synthetic_media_videos
language plpgsql
security definer
set search_path = public, auth, pg_catalog, pg_temp
as $fn$
declare
  v_jwt_role text := coalesce(
    nullif(auth.jwt() ->> 'role', ''),
    nullif(current_setting('request.jwt.claim.role', true), ''),
    ''
  );
  v_is_service boolean := (v_jwt_role = 'service_role')
    or (
      v_jwt_role = ''
      and session_user in ('postgres', 'supabase_admin', 'supabase_auth_admin')
    );
  v_actor_id uuid := auth.uid();
  v_is_admin boolean := false;
  v_target public.synthetic_media_videos;
  v_updated public.synthetic_media_videos;
  v_clean_note text := nullif(trim(coalesce(p_review_note, '')), '');
  v_snapshot jsonb;
begin
  if not v_is_service then
    if v_actor_id is null then
      raise exception 'admin authentication required to review synthetic media video'
        using errcode = '42501';
    end if;
    select exists (
      select 1
      from public.user_profiles up
      where up.user_id = v_actor_id
        and up.is_admin = true
    )
      into v_is_admin;
    if not v_is_admin then
      raise exception 'admin privileges required to review synthetic media video'
        using errcode = '42501';
    end if;
  end if;

  if p_decision not in ('approved', 'rejected') then
    raise exception 'decision must be approved or rejected'
      using errcode = '22023';
  end if;

  if p_decision = 'rejected' and v_clean_note is null then
    raise exception 'review_note is required when rejecting synthetic media video'
      using errcode = '22023';
  end if;

  select *
    into v_target
  from public.synthetic_media_videos
  where id = p_video_id
  for update;

  if not found then
    raise exception 'synthetic media video % not found', p_video_id
      using errcode = 'P0002';
  end if;

  if p_decision = 'approved' then
    if v_target.copyright_consent_status <> 'verified'
      or v_target.likeness_consent_status <> 'verified'
      or v_target.celebrity_likeness_cleared <> true
      or v_target.commercial_watermark_present <> true then
      raise exception 'cannot approve synthetic media video without verified copyright/likeness consent, celebrity clearance, and commercial watermark'
        using errcode = '23514';
    end if;
  end if;

  v_snapshot := jsonb_build_object(
    'provider', v_target.track_and_trace_provider,
    'id', v_target.track_and_trace_id,
    'watermark', v_target.commercial_watermark_present,
    'celebrity_cleared', v_target.celebrity_likeness_cleared,
    'copyright_consent', v_target.copyright_consent_status,
    'likeness_consent', v_target.likeness_consent_status,
    'metadata', v_target.track_and_trace_metadata
  );

  perform set_config('app.synthetic_media_rpc_active', 'on', true);

  update public.synthetic_media_videos
  set
    moderation_status = p_decision,
    is_approved = (p_decision = 'approved'),
    reviewed_by = coalesce(v_actor_id, v_target.reviewed_by),
    reviewed_at = timezone('utc', now()),
    review_note = coalesce(v_clean_note, review_note),
    updated_at = timezone('utc', now())
  where id = p_video_id
  returning * into v_updated;

  insert into public.synthetic_media_audit_logs (
    video_id,
    actor_id,
    action,
    previous_status,
    new_status,
    reason,
    track_and_trace_snapshot
  ) values (
    v_updated.id,
    v_actor_id,
    p_decision,
    v_target.moderation_status,
    v_updated.moderation_status,
    coalesce(v_clean_note, case when p_decision = 'approved' then 'ethics pledge verified and approved' else null end),
    v_snapshot
  );

  perform set_config('app.synthetic_media_rpc_active', 'off', true);
  return v_updated;
exception
  when others then
    perform set_config('app.synthetic_media_rpc_active', 'off', true);
    raise;
end;
$fn$;

revoke all on function public.review_synthetic_media_video(uuid, text, text) from public, anon;
grant execute on function public.review_synthetic_media_video(uuid, text, text) to authenticated, service_role;

comment on table public.synthetic_media_videos is
  'Synthetic media video ethics moderation queue with consent, commercial watermark, celebrity clearance, and Track-and-Trace provenance (#2661).';
comment on table public.synthetic_media_audit_logs is
  'Immutable append-only audit log for synthetic media video submissions and moderation decisions (#2661).';
