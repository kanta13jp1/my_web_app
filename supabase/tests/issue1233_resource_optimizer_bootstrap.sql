-- Minimal Supabase-owned roles and auth helpers required to execute the
-- Issue #1233 resource-optimizer migrations in vanilla PostgreSQL.
create schema if not exists auth;

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

create or replace function auth.role()
returns text
language sql
stable
set search_path = ''
as $$
  select coalesce(
    nullif(current_setting('request.jwt.claim.role', true), ''),
    current_user
  )
$$;

grant usage on schema auth, public to anon, authenticated, service_role;
grant execute on function auth.uid(), auth.role()
  to anon, authenticated, service_role;
