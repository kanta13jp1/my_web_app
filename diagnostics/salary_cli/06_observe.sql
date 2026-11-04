-- SYNTHETIC TEST ONLY. Intended only for a separate read-only connection
-- to the verified disposable synthetic PG17 fixture after the CLI has stopped.
-- There is no inference here that a failure occurred at the intended trigger.
\set ON_ERROR_STOP on
BEGIN READ ONLY;
DO $observe_guard$
BEGIN
  IF pg_catalog.current_database() <> 'salary_identity_isolated'
     OR pg_catalog.current_setting('salary_test.isolated', true)
          IS DISTINCT FROM 'disposable-pg17-only'
     OR pg_catalog.current_setting('server_version_num')::integer < 170000
     OR pg_catalog.current_setting('server_version_num')::integer >= 180000
     OR pg_catalog.current_setting('session_replication_role') <> 'origin'
     OR pg_catalog.inet_server_addr() IS DISTINCT FROM '127.0.0.1'::inet
     OR pg_catalog.inet_client_addr() IS DISTINCT FROM '127.0.0.1'::inet THEN
    RAISE EXCEPTION 'synthetic observation guard failed';
  END IF;
END
$observe_guard$;

\echo 'schemas and target object existence'
SELECT n.nspname, c.relname, c.relkind, c.relrowsecurity, c.relforcerowsecurity
FROM pg_catalog.pg_class c
JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
WHERE (n.nspname = 'public' AND c.relname IN ('cfo_assets', 'asset_balance_accounts'))
   OR (n.nspname = 'supabase_migrations' AND c.relname = 'schema_migrations')
ORDER BY n.nspname, c.relname;
SELECT pg_catalog.to_regnamespace('auth') IS NOT NULL AS auth_schema_present,
       pg_catalog.to_regnamespace('supabase_migrations') IS NOT NULL AS history_schema_present;

\echo 'target columns'
SELECT n.nspname, c.relname, a.attname,
       pg_catalog.format_type(a.atttypid, a.atttypmod) AS type,
       a.attnotnull
FROM pg_catalog.pg_attribute a
JOIN pg_catalog.pg_class c ON c.oid = a.attrelid
JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
WHERE a.attnum > 0 AND NOT a.attisdropped
  AND ((n.nspname = 'public' AND c.relname IN ('cfo_assets', 'asset_balance_accounts'))
    OR (n.nspname = 'supabase_migrations' AND c.relname = 'schema_migrations'))
ORDER BY n.nspname, c.relname, a.attnum;

\echo 'target constraints and policy definitions'
SELECT n.nspname, c.relname, con.conname, con.contype, con.convalidated,
       pg_catalog.pg_get_constraintdef(con.oid) AS definition
FROM pg_catalog.pg_constraint con
JOIN pg_catalog.pg_class c ON c.oid = con.conrelid
JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public' AND c.relname IN ('cfo_assets', 'asset_balance_accounts')
ORDER BY c.relname, con.conname;
SELECT schemaname, tablename, policyname, roles, cmd, qual, with_check
FROM pg_catalog.pg_policies
WHERE schemaname = 'public' AND tablename IN ('cfo_assets', 'asset_balance_accounts')
ORDER BY tablename, policyname;

\echo 'history table and injection trigger presence'
SELECT pg_catalog.to_regclass('supabase_migrations.schema_migrations') IS NOT NULL AS history_present \gset
\if :history_present
SELECT EXISTS (
  SELECT 1 FROM supabase_migrations.schema_migrations
  WHERE version = '20261104000001'
) AS target_history_version_present;
SELECT tgname, tgenabled, tgtype, tgfoid::regprocedure AS function_name FROM pg_catalog.pg_trigger
WHERE tgrelid = pg_catalog.to_regclass('supabase_migrations.schema_migrations')
  AND tgname = 'fixture_reject_target_version' AND NOT tgisinternal;
\else
\echo 'history table missing; version presence cannot be queried'
\endif
SELECT evtname, evtenabled, evtevent, evtfoid::regprocedure AS function_name FROM pg_catalog.pg_event_trigger
WHERE evtname = 'fixture_guard_ddl_start';
COMMIT;
-- Interpret together with the captured CLI exit/error. Do not repair, retry,
-- apply the migration, or remove objects based on any observed combination.
