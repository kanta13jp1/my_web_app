-- Migration for Issue #2605: Cross-device voice & prompt handoff sessions for mobile PWA verification.

create table if not exists public.cross_device_voice_sessions (
  id uuid primary key default gen_random_uuid(),
  session_key text not null
    check (char_length(trim(session_key)) between 1 and 120),
  user_id uuid not null references auth.users(id) on delete cascade,
  source_device text not null
    check (
      source_device in (
        'ios_safari_tab',
        'ios_pwa_standalone',
        'android_pwa',
        'desktop_web',
        'mobile_webview',
        'unknown'
      )
    ),
  browser_environment text not null default 'unknown'
    check (char_length(trim(browser_environment)) between 1 and 120),
  transcript_draft text not null default '',
  prompt_state_json jsonb not null default '{}'::jsonb,
  revision bigint not null default 1 check (revision >= 1),
  sync_status text not null default 'synced'
    check (
      sync_status in (
        'draft_local',
        'queued_offline',
        'synced',
        'conflict_resolved',
        'handed_off'
      )
    ),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, session_key)
);

create index if not exists idx_cross_device_voice_sessions_user_updated
  on public.cross_device_voice_sessions (user_id, updated_at desc);

alter table public.cross_device_voice_sessions enable row level security;

drop policy if exists "cross_device_voice_sessions_select_own"
  on public.cross_device_voice_sessions;
create policy "cross_device_voice_sessions_select_own"
  on public.cross_device_voice_sessions
  for select
  using ((select auth.uid()) = user_id);

drop policy if exists "cross_device_voice_sessions_insert_own"
  on public.cross_device_voice_sessions;
create policy "cross_device_voice_sessions_insert_own"
  on public.cross_device_voice_sessions
  for insert
  with check ((select auth.uid()) = user_id);

drop policy if exists "cross_device_voice_sessions_update_own"
  on public.cross_device_voice_sessions;
create policy "cross_device_voice_sessions_update_own"
  on public.cross_device_voice_sessions
  for update
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "cross_device_voice_sessions_delete_own"
  on public.cross_device_voice_sessions;
create policy "cross_device_voice_sessions_delete_own"
  on public.cross_device_voice_sessions
  for delete
  using ((select auth.uid()) = user_id);

do $$
begin
  if exists (
    select 1
    from pg_publication
    where pubname = 'supabase_realtime'
  ) and not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'cross_device_voice_sessions'
  ) then
    alter publication supabase_realtime
      add table public.cross_device_voice_sessions;
  end if;
end
$$;
