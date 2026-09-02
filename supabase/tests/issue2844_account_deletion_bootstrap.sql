-- Minimal Supabase Auth/Storage catalog for the disposable PostgreSQL
-- container. Production already provides these schemas and roles.
create schema if not exists auth;

do $$ begin
  create role anon nologin;
exception when duplicate_object then null;
end $$;
do $$ begin
  create role authenticated nologin;
exception when duplicate_object then null;
end $$;
do $$ begin
  create role service_role nologin bypassrls;
exception when duplicate_object then null;
end $$;

create table if not exists auth.users (
  id uuid primary key
);

create table if not exists auth.sessions (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create schema if not exists storage;

create table if not exists storage.buckets (
  id text primary key,
  name text not null,
  public boolean not null default false,
  file_size_limit bigint,
  allowed_mime_types text[]
);

create table if not exists storage.objects (
  id uuid primary key default gen_random_uuid(),
  bucket_id text not null,
  name text not null,
  owner_id text,
  owner uuid
);

-- Production creates this service-role audit table in
-- 20260712013000_create_jibun_api_platform.sql. The focused Issue #2844
-- smoke applies only this bootstrap plus the account-deletion migration, so a
-- minimal shape is included to verify the explicit 90-day retention adapter.
create table if not exists public.user_api_audit_log (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  action text not null,
  status smallint not null,
  created_at timestamptz not null default now()
);

grant select on table public.user_api_audit_log to service_role;

insert into storage.buckets (id, name, public)
values
  ('avatars', 'avatars', false),
  ('attachments', 'attachments', false),
  ('ai-generated-images', 'ai-generated-images', true)
on conflict (id) do nothing;

-- Supabase provides auth.jwt() in production. The disposable PostgreSQL
-- contract uses the same request-claim setting as the other auth fixtures.
create or replace function auth.jwt()
returns jsonb
language sql
stable
set search_path = ''
as $$
  select jsonb_build_object(
    'role',
    coalesce(
      nullif(current_setting('request.jwt.claim.role', true), ''),
      current_user
    )
  )
$$;

grant execute on function auth.jwt() to anon, authenticated, service_role;
grant usage on schema auth, public, storage to anon, authenticated, service_role;
