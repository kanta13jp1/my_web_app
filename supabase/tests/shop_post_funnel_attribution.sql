-- psql integration test ONLY for a disposable PostgreSQL database.
-- The fixed database-name guard must pass before any fixture/schema writes.
-- No customer data, production connection, Stripe call, or persistent Supabase
-- environment belongs in this test. Run after review on a GitHub-hosted runner.
\set ON_ERROR_STOP on

do $$
begin
  if current_database() <> 'hexciv_attribution_ci' then
    raise exception 'Refusing: use a fresh disposable hexciv_attribution_ci database';
  end if;
end $$;

-- Minimal dependencies required by the exact legacy and new migrations. These
-- are not replacements for full-schema, PostgREST or real-auth E2E validation.
do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then
    create role service_role nologin bypassrls;
  end if;
end $$;
create schema auth;
create table auth.users (id uuid primary key);
create table public.shop_products (id text primary key);
grant usage on schema public to anon, authenticated, service_role;

\ir ../migrations/20260729020000_create_shop_funnel_events.sql
insert into public.shop_products values ('hexciv-ci-only');
insert into public.shop_funnel_events (visitor_id, product_id, source, stage)
values ('a1000000-0000-4000-8000-000000000001', 'hexciv-ci-only', 'x', 'product_view');

\ir ../migrations/20260912091100_shop_post_funnel_attribution.sql

begin;

set local role service_role;
insert into public.shop_post_funnel_events
  (visitor_id, product_id, source, campaign, content_id, stage, first_occurred_at)
values
  ('a1000000-0000-4000-8000-000000000001', 'hexciv-ci-only', 'x', 'launch', 'post-a', 'product_view', '2026-09-12 00:00:00+00'),
  ('a1000000-0000-4000-8000-000000000001', 'hexciv-ci-only', 'x', 'launch', 'post-b', 'product_view', '2026-09-12 00:01:00+00'),
  ('a1000000-0000-4000-8000-000000000001', 'hexciv-ci-only', 'x', 'other', 'post-a', 'product_view', '2026-09-12 00:02:00+00'),
  ('a1000000-0000-4000-8000-000000000001', 'hexciv-ci-only', 'x', 'launch', 'post-a', 'purchase_complete', '2026-09-12 00:03:00+00');

-- Repeat arrival must not rewrite the first timestamp or collapse other posts.
insert into public.shop_post_funnel_events
  (visitor_id, product_id, source, campaign, content_id, stage, first_occurred_at)
values ('a1000000-0000-4000-8000-000000000001', 'hexciv-ci-only', 'x', 'launch', 'post-a', 'product_view', '2026-09-12 01:00:00+00')
on conflict (visitor_id, product_id, source, campaign, content_id, stage) do nothing;
reset role;

do $$
begin
  if (select count(*) from public.shop_post_funnel_events) <> 4 then
    raise exception 'Post/campaign/stage separation or duplicate handling failed';
  end if;
  if (select first_occurred_at from public.shop_post_funnel_events
      where campaign = 'launch' and content_id = 'post-a' and stage = 'product_view')
      <> '2026-09-12 00:00:00+00'::timestamptz then
    raise exception 'Duplicate rewrote first occurrence';
  end if;
  if (select count(distinct visitor_id) from public.shop_post_funnel_events
      where stage = 'product_view') <> 1 then
    raise exception 'Visitor aggregate must use distinct sets, not sum post rows';
  end if;
  if (select count(*) from public.shop_funnel_events) <> 1 then
    raise exception 'Legacy rows were changed';
  end if;
  if not (select relrowsecurity from pg_class
          where oid = 'public.shop_post_funnel_events'::regclass) then
    raise exception 'RLS is not enabled';
  end if;
  if exists (select 1 from pg_policies
             where schemaname = 'public' and tablename = 'shop_post_funnel_events') then
    raise exception 'No client policy should exist';
  end if;
  if has_table_privilege('service_role', 'public.shop_post_funnel_events', 'UPDATE')
     or has_table_privilege('service_role', 'public.shop_post_funnel_events', 'DELETE') then
    raise exception 'Service role has unnecessary mutation grants';
  end if;
end $$;

-- Actual SQL access tests: deny SELECT/INSERT/UPDATE/DELETE for both clients.
do $$
declare
  actor text;
  statement text;
  denied boolean;
begin
  foreach actor in array array['anon', 'authenticated'] loop
    foreach statement in array array[
      'select * from public.shop_post_funnel_events',
      'insert into public.shop_post_funnel_events (visitor_id, product_id, stage) values (''a1000000-0000-4000-8000-000000000002'', ''hexciv-ci-only'', ''product_view'')',
      'update public.shop_post_funnel_events set campaign = ''forged''',
      'delete from public.shop_post_funnel_events'
    ] loop
      denied := false;
      execute format('set local role %I', actor);
      begin
        execute statement;
      exception when insufficient_privilege then
        denied := true;
      end;
      reset role;
      if not denied then
        raise exception 'Unexpected access for %: %', actor, statement;
      end if;
    end loop;
  end loop;
end $$;

-- Defense in depth: even a future accidental client grant must not expose rows.
grant select on public.shop_post_funnel_events to anon, authenticated;
set local role anon;
do $$ begin
  if (select count(*) from public.shop_post_funnel_events) <> 0 then
    raise exception 'Anon bypassed RLS';
  end if;
end $$;
set local role authenticated;
do $$ begin
  if (select count(*) from public.shop_post_funnel_events) <> 0 then
    raise exception 'Authenticated client bypassed RLS';
  end if;
end $$;
reset role;

-- Invalid values cannot alias a legitimate post or create a forged stage.
do $$
begin
  begin
    insert into public.shop_post_funnel_events (visitor_id, product_id, content_id, stage)
    values ('a1000000-0000-4000-8000-000000000002', 'hexciv-ci-only', repeat('a', 65), 'product_view');
    raise exception 'Overlength post accepted';
  exception when check_violation then null;
  end;
  begin
    insert into public.shop_post_funnel_events (visitor_id, product_id, content_id, stage)
    values ('a1000000-0000-4000-8000-000000000002', 'hexciv-ci-only', 'a/b', 'product_view');
    raise exception 'Invalid post accepted';
  exception when check_violation then null;
  end;
  begin
    insert into public.shop_post_funnel_events (visitor_id, product_id, stage)
    values ('a1000000-0000-4000-8000-000000000002', 'hexciv-ci-only', 'forged');
    raise exception 'Invalid stage accepted';
  exception when check_violation then null;
  end;
end $$;

-- Old writers retain their original onConflict contract after the migration.
insert into public.shop_funnel_events (visitor_id, product_id, source, stage)
values ('a1000000-0000-4000-8000-000000000001', 'hexciv-ci-only', 'x', 'product_view')
on conflict (visitor_id, product_id, source, stage) do nothing;

rollback;
\echo SHOP POST ATTRIBUTION SQL OK
