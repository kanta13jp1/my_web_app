-- Batch 79 (#2663): External AI tool webhook receiver (n8n/Zapier/analytics), hashed API keys, strict RLS & Realtime.

create extension if not exists pgcrypto with schema extensions;

create table if not exists public.external_ai_webhook_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  source_tool text not null default 'custom'
    check (source_tool in ('n8n', 'zapier', 'analytics', 'custom')),
  event_type text not null
    check (char_length(trim(event_type)) between 1 and 120),
  external_event_id text not null default ''
    check (char_length(external_event_id) <= 120),
  payload jsonb not null default '{}'::jsonb
    check (jsonb_typeof(payload) = 'object' and length(payload::text) <= 32768),
  auth_method text not null default 'jwt'
    check (auth_method in ('api_key', 'jwt')),
  processing_status text not null default 'received'
    check (processing_status in ('received', 'processed', 'failed')),
  error_message text not null default ''
    check (char_length(error_message) <= 1000),
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_external_ai_webhook_events_user_created
  on public.external_ai_webhook_events (user_id, created_at desc);

create index if not exists idx_external_ai_webhook_events_source_created
  on public.external_ai_webhook_events (user_id, source_tool, created_at desc);

create table if not exists public.external_ai_webhook_keys (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  label text not null
    check (char_length(trim(label)) between 1 and 80),
  key_prefix text not null
    check (char_length(trim(key_prefix)) between 4 and 24),
  key_hash text not null
    check (key_hash ~ '^[0-9a-f]{64}$'),
  is_active boolean not null default true,
  last_used_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  unique (user_id, key_hash)
);

create index if not exists idx_external_ai_webhook_keys_active_hash
  on public.external_ai_webhook_keys (key_hash)
  where is_active = true;

create index if not exists idx_external_ai_webhook_keys_user_created
  on public.external_ai_webhook_keys (user_id, created_at desc);

alter table public.external_ai_webhook_events enable row level security;
alter table public.external_ai_webhook_keys enable row level security;

revoke all on table public.external_ai_webhook_events from public, anon;
grant select, insert, update on table public.external_ai_webhook_events to authenticated;
grant all on table public.external_ai_webhook_events to service_role;

revoke all on table public.external_ai_webhook_keys from public, anon;
grant select, insert, update on table public.external_ai_webhook_keys to authenticated;
grant all on table public.external_ai_webhook_keys to service_role;

drop policy if exists "external_ai_webhook_events_select_own_or_admin"
  on public.external_ai_webhook_events;
create policy "external_ai_webhook_events_select_own_or_admin"
  on public.external_ai_webhook_events
  for select
  to authenticated
  using (
    user_id = (select auth.uid())
    or exists (
      select 1
      from public.user_profiles as up
      where up.user_id = (select auth.uid())
        and up.is_admin = true
    )
  );

drop policy if exists "external_ai_webhook_events_insert_own"
  on public.external_ai_webhook_events;
create policy "external_ai_webhook_events_insert_own"
  on public.external_ai_webhook_events
  for insert
  to authenticated
  with check (user_id = (select auth.uid()));

drop policy if exists "external_ai_webhook_events_update_own_or_admin"
  on public.external_ai_webhook_events;
create policy "external_ai_webhook_events_update_own_or_admin"
  on public.external_ai_webhook_events
  for update
  to authenticated
  using (
    user_id = (select auth.uid())
    or exists (
      select 1
      from public.user_profiles as up
      where up.user_id = (select auth.uid())
        and up.is_admin = true
    )
  )
  with check (
    user_id = (select auth.uid())
    or exists (
      select 1
      from public.user_profiles as up
      where up.user_id = (select auth.uid())
        and up.is_admin = true
    )
  );

drop policy if exists "external_ai_webhook_keys_select_own_or_admin"
  on public.external_ai_webhook_keys;
create policy "external_ai_webhook_keys_select_own_or_admin"
  on public.external_ai_webhook_keys
  for select
  to authenticated
  using (
    user_id = (select auth.uid())
    or exists (
      select 1
      from public.user_profiles as up
      where up.user_id = (select auth.uid())
        and up.is_admin = true
    )
  );

drop policy if exists "external_ai_webhook_keys_insert_own"
  on public.external_ai_webhook_keys;
create policy "external_ai_webhook_keys_insert_own"
  on public.external_ai_webhook_keys
  for insert
  to authenticated
  with check (user_id = (select auth.uid()));

drop policy if exists "external_ai_webhook_keys_update_own_or_admin"
  on public.external_ai_webhook_keys;
create policy "external_ai_webhook_keys_update_own_or_admin"
  on public.external_ai_webhook_keys
  for update
  to authenticated
  using (
    user_id = (select auth.uid())
    or exists (
      select 1
      from public.user_profiles as up
      where up.user_id = (select auth.uid())
        and up.is_admin = true
    )
  )
  with check (
    user_id = (select auth.uid())
    or exists (
      select 1
      from public.user_profiles as up
      where up.user_id = (select auth.uid())
        and up.is_admin = true
    )
  );

create or replace function public.guard_external_ai_webhook_events()
returns trigger
language plpgsql
security invoker
set search_path = public, auth, pg_catalog, pg_temp
as $guard_events$
declare
  v_jwt_role text;
  v_is_service boolean;
  v_is_admin boolean;
begin
  v_jwt_role := coalesce(
    nullif(auth.jwt() ->> 'role', ''),
    nullif(current_setting('request.jwt.claim.role', true), ''),
    ''
  );
  v_is_service := (v_jwt_role = 'service_role')
    or (
      v_jwt_role = ''
      and session_user in ('postgres', 'supabase_admin', 'supabase_auth_admin')
    );
  v_is_admin := exists (
    select 1
    from public.user_profiles as up
    where up.user_id = auth.uid()
      and up.is_admin = true
  );

  if v_is_service or v_is_admin then
    if tg_op = 'INSERT' then
      new.created_at := coalesce(new.created_at, timezone('utc', now()));
    end if;
    return new;
  end if;

  if tg_op = 'INSERT' then
    if auth.uid() is null or new.user_id is distinct from auth.uid() then
      raise exception 'Authenticated owner user_id is required on webhook event insert'
        using errcode = '42501';
    end if;
    if new.auth_method <> 'jwt' then
      raise exception 'Direct client inserts cannot spoof api_key auth_method'
        using errcode = '42501';
    end if;
    new.created_at := timezone('utc', now());
    return new;
  end if;

  if tg_op = 'UPDATE' then
    if new.id is distinct from old.id
       or new.user_id is distinct from old.user_id
       or new.source_tool is distinct from old.source_tool
       or new.auth_method is distinct from old.auth_method
       or new.created_at is distinct from old.created_at then
      raise exception 'External webhook event provenance and identity are immutable'
        using errcode = '42501';
    end if;
    return new;
  end if;

  return new;
end;
$guard_events$;

drop trigger if exists guard_external_ai_webhook_events
  on public.external_ai_webhook_events;
create trigger guard_external_ai_webhook_events
  before insert or update on public.external_ai_webhook_events
  for each row
  execute function public.guard_external_ai_webhook_events();

create or replace function public.guard_external_ai_webhook_keys()
returns trigger
language plpgsql
security invoker
set search_path = public, auth, pg_catalog, pg_temp
as $guard_keys$
declare
  v_jwt_role text;
  v_is_service boolean;
  v_is_admin boolean;
begin
  v_jwt_role := coalesce(
    nullif(auth.jwt() ->> 'role', ''),
    nullif(current_setting('request.jwt.claim.role', true), ''),
    ''
  );
  v_is_service := (v_jwt_role = 'service_role')
    or (
      v_jwt_role = ''
      and session_user in ('postgres', 'supabase_admin', 'supabase_auth_admin')
    );
  v_is_admin := exists (
    select 1
    from public.user_profiles as up
    where up.user_id = auth.uid()
      and up.is_admin = true
  );

  if v_is_service or v_is_admin then
    new.key_hash := lower(new.key_hash);
    if tg_op = 'INSERT' then
      new.created_at := coalesce(new.created_at, timezone('utc', now()));
    end if;
    return new;
  end if;

  if tg_op = 'INSERT' then
    if auth.uid() is null or new.user_id is distinct from auth.uid() then
      raise exception 'Authenticated owner user_id is required on webhook key insert'
        using errcode = '42501';
    end if;
    new.key_hash := lower(new.key_hash);
    new.last_used_at := null;
    new.created_at := timezone('utc', now());
    return new;
  end if;

  if tg_op = 'UPDATE' then
    if new.id is distinct from old.id
       or new.user_id is distinct from old.user_id
       or new.key_prefix is distinct from old.key_prefix
       or new.key_hash is distinct from old.key_hash
       or new.last_used_at is distinct from old.last_used_at
       or new.created_at is distinct from old.created_at then
      raise exception 'Webhook key hash and immutable metadata cannot be changed'
        using errcode = '42501';
    end if;
    return new;
  end if;

  return new;
end;
$guard_keys$;

drop trigger if exists guard_external_ai_webhook_keys
  on public.external_ai_webhook_keys;
create trigger guard_external_ai_webhook_keys
  before insert or update on public.external_ai_webhook_keys
  for each row
  execute function public.guard_external_ai_webhook_keys();

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'external_ai_webhook_events'
  ) then
    alter publication supabase_realtime
      add table public.external_ai_webhook_events;
  end if;
end;
$$;

comment on table public.external_ai_webhook_events is
  'Incoming webhook events from external AI/automation tools (n8n, Zapier, analytics) streamed via Realtime (#2663).';

comment on table public.external_ai_webhook_keys is
  'Hashed external webhook API keys (SHA-256 hex only; never stores plaintext secrets) (#2663).';
