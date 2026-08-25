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
  create role service_role nologin;
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
