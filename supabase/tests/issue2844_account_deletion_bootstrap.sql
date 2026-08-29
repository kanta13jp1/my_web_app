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

create schema if not exists storage;

create table if not exists storage.objects (
  id uuid primary key default gen_random_uuid(),
  bucket_id text not null,
  name text not null,
  owner_id text,
  owner uuid
);

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
