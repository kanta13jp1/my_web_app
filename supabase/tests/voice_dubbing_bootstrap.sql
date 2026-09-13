-- Minimal Supabase-owned schemas required to execute Issue #1202 migrations
-- inside a disposable vanilla PostgreSQL Testcontainers instance.
create schema if not exists auth;
create schema if not exists storage;

do $$
begin
  create role anon nologin;
exception when duplicate_object then null;
end;
$$;

do $$
begin
  create role authenticated nologin;
exception when duplicate_object then null;
end;
$$;

do $$
begin
  create role service_role nologin bypassrls;
exception when duplicate_object then null;
end;
$$;

create table if not exists auth.users (
  id uuid primary key
);

create or replace function auth.uid()
returns uuid
language sql
stable
set search_path = ''
as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
$$;

create table if not exists storage.buckets (
  id text primary key,
  name text not null,
  public boolean not null default false,
  file_size_limit bigint,
  allowed_mime_types text[]
);

create table if not exists storage.objects (
  id uuid primary key default gen_random_uuid(),
  bucket_id text not null references storage.buckets(id),
  name text not null,
  owner_id uuid
);

alter table storage.objects enable row level security;

create or replace function storage.foldername(name text)
returns text[]
language sql
immutable
set search_path = ''
as $$
  select pg_catalog.string_to_array(name, '/')
$$;

grant usage on schema auth, storage to anon, authenticated, service_role;
grant execute on function auth.uid() to anon, authenticated, service_role;
grant execute on function storage.foldername(text)
  to anon, authenticated, service_role;
