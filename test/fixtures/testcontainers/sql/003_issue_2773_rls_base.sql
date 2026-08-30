create role anon nologin;
create role authenticated nologin;
create role service_role nologin bypassrls;

create schema auth;
create table auth.users (
  id uuid primary key
);

create function auth.uid()
returns uuid
language sql
stable
set search_path = ''
as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
$$;

grant usage on schema public, auth to anon, authenticated, service_role;
grant execute on function auth.uid() to anon, authenticated, service_role;

create table ab_experiments (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  status text not null default 'draft'
);

create table ab_assignments (
  id uuid primary key default gen_random_uuid(),
  experiment_id uuid not null references ab_experiments(id),
  user_id uuid not null,
  variant text not null,
  converted boolean default false,
  unique (experiment_id, user_id)
);

create table competitor_feature_status (
  id uuid primary key default gen_random_uuid(),
  competitor_id text not null,
  feature_name text not null,
  status text not null default 'notYet'
);

create table referral_tracking (
  id uuid primary key default gen_random_uuid(),
  referrer_user_id text not null,
  referred_user_id text not null,
  referral_code text not null,
  registered_at timestamptz not null default now()
);

create table viral_ad_generations (
  id uuid primary key default gen_random_uuid(),
  template_key text not null,
  status text not null default 'draft',
  created_at timestamptz not null default now()
);

create table ai_university_content (
  id uuid primary key default gen_random_uuid(),
  title text not null
);

grant all privileges on table
  public.ab_experiments,
  public.ab_assignments,
  public.competitor_feature_status,
  public.referral_tracking,
  public.viral_ad_generations
to anon, authenticated, service_role;
