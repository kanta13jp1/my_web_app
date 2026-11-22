create role anon nologin;
create role authenticated nologin;
create schema auth;
create table auth.users(id uuid primary key);
create function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid;
$$;
grant usage on schema auth, public to anon, authenticated;
grant execute on function auth.uid() to anon, authenticated;
create table public.wealth_struggles(id bigint primary key, user_id uuid references auth.users, amount numeric);
alter table public.wealth_struggles enable row level security;
grant select on public.wealth_struggles to authenticated;
create policy own_flow on public.wealth_struggles for select to authenticated using (user_id = (select auth.uid()));
