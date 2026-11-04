-- SYNTHETIC TEST ONLY. Never run against a live or shared database.
-- Intended only AFTER reviewed 04 fixture in a fresh disposable PG17 cluster.
-- This additional layer is not a security boundary or proof of isolation.
\set ON_ERROR_STOP on

DO $setup_guard$
BEGIN
  IF pg_catalog.current_database() <> 'salary_identity_isolated'
     OR pg_catalog.current_setting('salary_test.isolated', true)
          IS DISTINCT FROM 'disposable-pg17-only'
     OR pg_catalog.current_setting('server_version_num')::integer < 170000
     OR pg_catalog.current_setting('server_version_num')::integer >= 180000
     OR pg_catalog.current_setting('session_replication_role') <> 'origin'
     OR pg_catalog.inet_server_addr() IS DISTINCT FROM '127.0.0.1'::inet
     OR pg_catalog.inet_client_addr() IS DISTINCT FROM '127.0.0.1'::inet
     OR pg_catalog.to_regclass('public.cfo_assets') IS NULL
     OR pg_catalog.to_regclass('public.asset_balance_accounts') IS NOT NULL
     OR pg_catalog.to_regclass('supabase_migrations.schema_migrations') IS NULL
     OR pg_catalog.to_regprocedure('supabase_migrations.fixture_reject_target_version()') IS NULL
     OR NOT EXISTS (
       SELECT 1 FROM pg_catalog.pg_trigger
       WHERE tgrelid = pg_catalog.to_regclass('supabase_migrations.schema_migrations')
         AND tgname = 'fixture_reject_target_version' AND NOT tgisinternal
         AND tgenabled IN ('O', 'A') AND tgtype = 7
         AND tgfoid = pg_catalog.to_regprocedure('supabase_migrations.fixture_reject_target_version()')
     ) THEN
    RAISE EXCEPTION 'unsafe or unexpected synthetic setup';
  END IF;
END
$setup_guard$;

-- This is a database-level mutation on a specifically named disposable DB.
-- Subsequent new sessions should receive this default even after RESET ALL;
-- per-role overrides and connection options must also be independently ruled out.
ALTER DATABASE salary_identity_isolated
  SET salary_test.isolated = 'disposable-pg17-only';

-- Retain the setup session marker while installing the event trigger. Existing
-- sessions do not automatically get a new ALTER DATABASE default.
SELECT pg_catalog.set_config('salary_test.isolated', 'disposable-pg17-only', false);

CREATE FUNCTION supabase_migrations.fixture_guard_ddl()
RETURNS event_trigger LANGUAGE plpgsql SET search_path = ''
AS $ddl_guard$
BEGIN
  IF pg_catalog.current_database() <> 'salary_identity_isolated'
     OR pg_catalog.current_setting('salary_test.isolated', true)
          IS DISTINCT FROM 'disposable-pg17-only'
     OR pg_catalog.current_setting('server_version_num')::integer < 170000
     OR pg_catalog.current_setting('server_version_num')::integer >= 180000
     OR pg_catalog.current_setting('session_replication_role') <> 'origin'
     OR pg_catalog.inet_server_addr() IS DISTINCT FROM '127.0.0.1'::inet
     OR pg_catalog.inet_client_addr() IS DISTINCT FROM '127.0.0.1'::inet THEN
    RAISE EXCEPTION 'synthetic DDL session guard failed';
  END IF;
END
$ddl_guard$;

CREATE EVENT TRIGGER fixture_guard_ddl_start
ON ddl_command_start EXECUTE FUNCTION supabase_migrations.fixture_guard_ddl();

-- Replace the existing 04 trigger function only: the existing trigger keeps
-- its binding. Only target version 20261104000001 receives an injected error.
CREATE OR REPLACE FUNCTION supabase_migrations.fixture_reject_target_version()
RETURNS trigger LANGUAGE plpgsql SET search_path = ''
AS $history_guard$
BEGIN
  IF pg_catalog.current_database() <> 'salary_identity_isolated'
     OR pg_catalog.current_setting('salary_test.isolated', true)
          IS DISTINCT FROM 'disposable-pg17-only'
     OR pg_catalog.current_setting('server_version_num')::integer < 170000
     OR pg_catalog.current_setting('server_version_num')::integer >= 180000
     OR pg_catalog.current_setting('session_replication_role') <> 'origin'
     OR pg_catalog.inet_server_addr() IS DISTINCT FROM '127.0.0.1'::inet
     OR pg_catalog.inet_client_addr() IS DISTINCT FROM '127.0.0.1'::inet THEN
    RAISE EXCEPTION 'synthetic history session guard failed';
  END IF;
  IF NEW.version = '20261104000001' THEN
    RAISE EXCEPTION USING ERRCODE = 'P0001',
      MESSAGE = 'synthetic_history_insert_rejected_20261104000001';
  END IF;
  RETURN NEW;
END
$history_guard$;

-- Does not cover every SQL command, other databases, role/database/event-trigger
-- DDL, disabled triggers or privileged sessions, and marker is forgeable.
-- No CLI launch, retry, migration, repair, rollback, or cleanup is performed.
