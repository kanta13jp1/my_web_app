-- Issue #2715: Explicit consent verification & system-level gate for custom AI voice cloning.
-- Enforces legal policy consent, spoken verification phrase audio evidence in private
-- storage, RLS + trigger guards, and fail-closed access control for voice clone generation.

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'voice-clone-consents',
  'voice-clone-consents',
  false,
  10485760,
  array['audio/webm', 'audio/mp4', 'audio/mpeg', 'audio/wav', 'audio/ogg']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "voice_clone_consents_owner_read"
  on storage.objects;
create policy "voice_clone_consents_owner_read"
  on storage.objects
  for select
  to authenticated
  using (
    bucket_id = 'voice-clone-consents'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create table if not exists public.voice_clone_consents (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid()
    references auth.users(id) on delete cascade,
  privacy_policy_version text not null
    check (char_length(btrim(privacy_policy_version)) between 1 and 40),
  terms_version text not null
    check (char_length(btrim(terms_version)) between 1 and 40),
  privacy_policy_accepted boolean not null default false,
  terms_accepted boolean not null default false,
  biometric_notice_accepted boolean not null default false,
  legal_consented_at timestamptz,
  verification_phrase text not null
    check (char_length(btrim(verification_phrase)) between 8 and 400),
  phrase_nonce text not null
    check (char_length(btrim(phrase_nonce)) between 6 and 64),
  recording_storage_path text
    check (
      recording_storage_path is null
      or char_length(btrim(recording_storage_path)) between 3 and 300
    ),
  recording_mime_type text
    check (
      recording_mime_type is null
      or recording_mime_type in (
        'audio/webm',
        'audio/mp4',
        'audio/mpeg',
        'audio/wav',
        'audio/ogg'
      )
    ),
  recording_byte_size integer not null default 0
    check (recording_byte_size >= 0),
  recording_duration_ms integer not null default 0
    check (recording_duration_ms >= 0),
  recording_sha256 text
    check (
      recording_sha256 is null
      or recording_sha256 ~ '^[0-9a-f]{64}$'
    ),
  microphone_permission_granted boolean not null default false,
  spoken_transcript text
    check (
      spoken_transcript is null
      or char_length(btrim(spoken_transcript)) <= 500
    ),
  consent_status text not null default 'pending_terms'
    check (
      consent_status in (
        'pending_terms',
        'terms_accepted',
        'recording_uploaded',
        'verified',
        'rejected',
        'revoked'
      )
    ),
  verified_at timestamptz,
  verified_by uuid references auth.users(id) on delete set null,
  revoked_at timestamptz,
  rejection_reason text
    check (
      rejection_reason is null
      or char_length(btrim(rejection_reason)) <= 500
    ),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (user_id),
  constraint chk_voice_clone_consents_verified_proof check (
    consent_status <> 'verified'
    or (
      privacy_policy_accepted = true
      and terms_accepted = true
      and biometric_notice_accepted = true
      and legal_consented_at is not null
      and microphone_permission_granted = true
      and recording_storage_path is not null
      and recording_sha256 is not null
      and recording_byte_size > 0
      and verified_at is not null
      and revoked_at is null
    )
  )
);

create index if not exists idx_voice_clone_consents_status_user
  on public.voice_clone_consents (consent_status, user_id);

create table if not exists public.voice_clone_consent_events (
  id uuid primary key default gen_random_uuid(),
  consent_id uuid not null
    references public.voice_clone_consents(id) on delete cascade,
  user_id uuid not null default auth.uid()
    references auth.users(id) on delete cascade,
  event_type text not null
    check (
      event_type in (
        'terms_accepted',
        'recording_uploaded',
        'verified',
        'rejected',
        'revoked',
        'generation_blocked',
        'generation_allowed'
      )
    ),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_voice_clone_consent_events_user_created
  on public.voice_clone_consent_events (user_id, created_at desc);

create table if not exists public.voice_clone_profiles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid()
    references auth.users(id) on delete cascade,
  consent_id uuid not null
    references public.voice_clone_consents(id) on delete restrict,
  voice_name text not null
    check (char_length(btrim(voice_name)) between 1 and 120),
  provider_voice_id text
    check (
      provider_voice_id is null
      or char_length(btrim(provider_voice_id)) <= 120
    ),
  is_enabled boolean not null default false,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_voice_clone_profiles_user_enabled
  on public.voice_clone_profiles (user_id, is_enabled, created_at desc);

alter table public.voice_clone_consents enable row level security;
alter table public.voice_clone_consent_events enable row level security;
alter table public.voice_clone_profiles enable row level security;

-- Authenticated clients may read their own consent state and audit events, but only
-- server-side Edge Functions (service_role) mutate verification status.
revoke all on table public.voice_clone_consents
  from public, anon, authenticated;
grant select on table public.voice_clone_consents to authenticated;
grant all on table public.voice_clone_consents to service_role;

revoke all on table public.voice_clone_consent_events
  from public, anon, authenticated;
grant select on table public.voice_clone_consent_events to authenticated;
grant all on table public.voice_clone_consent_events to service_role;

revoke all on table public.voice_clone_profiles from public, anon;
grant select, insert, update, delete
  on table public.voice_clone_profiles to authenticated;
grant all on table public.voice_clone_profiles to service_role;

create or replace function public.has_verified_voice_clone_consent(
  p_user_id uuid
)
returns boolean
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $fn$
declare
  caller_uid uuid := (select auth.uid());
begin
  if p_user_id is null then
    return false;
  end if;

  if current_setting('role', true) <> 'service_role' then
    if caller_uid is null or p_user_id is distinct from caller_uid then
      return false;
    end if;
  end if;

  return exists (
    select 1
    from public.voice_clone_consents as vcc
    where vcc.user_id = p_user_id
      and vcc.consent_status = 'verified'
      and vcc.privacy_policy_accepted = true
      and vcc.terms_accepted = true
      and vcc.biometric_notice_accepted = true
      and vcc.legal_consented_at is not null
      and vcc.microphone_permission_granted = true
      and vcc.recording_storage_path is not null
      and vcc.recording_sha256 is not null
      and vcc.recording_byte_size > 0
      and vcc.verified_at is not null
      and vcc.revoked_at is null
  );
end;
$fn$;

revoke all on function public.has_verified_voice_clone_consent(uuid)
  from public, anon;
grant execute on function public.has_verified_voice_clone_consent(uuid)
  to authenticated, service_role;

create or replace function public.set_voice_clone_updated_at()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $fn$
begin
  new.updated_at := timezone('utc', now());
  return new;
end;
$fn$;

drop trigger if exists trg_voice_clone_consents_updated_at
  on public.voice_clone_consents;
create trigger trg_voice_clone_consents_updated_at
  before update on public.voice_clone_consents
  for each row
  execute function public.set_voice_clone_updated_at();

drop trigger if exists trg_voice_clone_profiles_updated_at
  on public.voice_clone_profiles;
create trigger trg_voice_clone_profiles_updated_at
  before update on public.voice_clone_profiles
  for each row
  execute function public.set_voice_clone_updated_at();

create or replace function public.guard_voice_clone_profile_consent()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
begin
  if tg_op = 'UPDATE'
    and new.is_enabled = false
    and new.user_id = old.user_id
    and new.consent_id = old.consent_id
  then
    return new;
  end if;

  if not exists (
    select 1
    from public.voice_clone_consents as vcc
    where vcc.id = new.consent_id
      and vcc.user_id = new.user_id
      and vcc.consent_status = 'verified'
      and vcc.privacy_policy_accepted = true
      and vcc.terms_accepted = true
      and vcc.biometric_notice_accepted = true
      and vcc.recording_storage_path is not null
      and vcc.recording_sha256 is not null
      and vcc.verified_at is not null
      and vcc.revoked_at is null
  ) then
    raise exception using
      errcode = '42501',
      message = 'voice_clone_consent_required: verified explicit consent and voice sample evidence required';
  end if;

  return new;
end;
$fn$;

drop trigger if exists trg_guard_voice_clone_profile_consent
  on public.voice_clone_profiles;
create trigger trg_guard_voice_clone_profile_consent
  before insert or update on public.voice_clone_profiles
  for each row
  execute function public.guard_voice_clone_profile_consent();

drop policy if exists "voice_clone_consents_select_own"
  on public.voice_clone_consents;
create policy "voice_clone_consents_select_own"
  on public.voice_clone_consents
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "voice_clone_consent_events_select_own"
  on public.voice_clone_consent_events;
create policy "voice_clone_consent_events_select_own"
  on public.voice_clone_consent_events
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "voice_clone_profiles_select_own"
  on public.voice_clone_profiles;
create policy "voice_clone_profiles_select_own"
  on public.voice_clone_profiles
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "voice_clone_profiles_insert_verified"
  on public.voice_clone_profiles;
create policy "voice_clone_profiles_insert_verified"
  on public.voice_clone_profiles
  for insert
  to authenticated
  with check (
    (select auth.uid()) = user_id
    and public.has_verified_voice_clone_consent((select auth.uid()))
  );

drop policy if exists "voice_clone_profiles_update_verified"
  on public.voice_clone_profiles;
create policy "voice_clone_profiles_update_verified"
  on public.voice_clone_profiles
  for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check (
    (select auth.uid()) = user_id
    and public.has_verified_voice_clone_consent((select auth.uid()))
  );

drop policy if exists "voice_clone_profiles_delete_own"
  on public.voice_clone_profiles;
create policy "voice_clone_profiles_delete_own"
  on public.voice_clone_profiles
  for delete
  to authenticated
  using ((select auth.uid()) = user_id);
