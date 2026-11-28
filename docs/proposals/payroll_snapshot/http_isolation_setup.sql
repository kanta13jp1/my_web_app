-- Run only on the temporary GitHub Actions payroll_contract database.
\set ON_ERROR_STOP on
do $guard$ begin
  if current_database() <> 'payroll_contract' then
    raise exception 'Disposable payroll_contract database required';
  end if;
  if current_setting('payroll_test.disposable_http', true)
      is distinct from 'explicit-synthetic-http-fixture' then
    raise exception 'Explicit disposable HTTP fixture opt-in required';
  end if;
end $guard$;
-- Session-local nonce is supplied by the CI fixture, never by app data.
select set_config('payroll_test.fixture_nonce', :'fixture_nonce', false) is not null as nonce_set \gset
do $guard$ begin
  if current_setting('payroll_test.fixture_nonce', true) !~ '^[0-9a-f]{64}$' then
    raise exception 'Valid disposable fixture nonce required';
  end if;
end $guard$;

-- PostgREST supplies request.jwt.claims; the contract test's minimal auth.uid()
-- only supplies request.jwt.claim.sub. This mimics both inputs, but is not a
-- substitute for a real Supabase Auth gateway or the deployed auth.uid().
create or replace function auth.uid() returns uuid language sql stable as $function$
  select coalesce(
    nullif(current_setting('request.jwt.claim.sub', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub')
  )::uuid;
$function$;
create role payroll_http_authenticator login noinherit password 'synthetic-http-only';
grant anon, authenticated to payroll_http_authenticator;
create table public.payroll_http_fixture_marker(nonce text not null);
insert into public.payroll_http_fixture_marker values (current_setting('payroll_test.fixture_nonce'));
alter table public.payroll_http_fixture_marker enable row level security;
revoke all on public.payroll_http_fixture_marker from public, anon, authenticated;
grant select on public.payroll_http_fixture_marker to authenticated;
create policy synthetic_http_fixture_marker on public.payroll_http_fixture_marker
  for select to authenticated using (true);
