-- SYNTHETIC CONTROL ONLY: fresh PG17, after the identical 04, 05 and 09 setup.
-- Keep the history trigger and session guard active; remove only test rejection.
\set ON_ERROR_STOP on
CREATE OR REPLACE FUNCTION supabase_migrations.fixture_reject_target_version()
RETURNS trigger LANGUAGE plpgsql SET search_path = '' AS $history_guard$
BEGIN
  IF pg_catalog.current_database() <> 'salary_identity_isolated'
     OR pg_catalog.current_setting('salary_test.isolated', true) IS DISTINCT FROM 'disposable-pg17-only'
     OR pg_catalog.current_setting('server_version_num')::integer < 170000
     OR pg_catalog.current_setting('server_version_num')::integer >= 180000
     OR pg_catalog.current_setting('session_replication_role') <> 'origin'
     OR pg_catalog.inet_server_addr() IS DISTINCT FROM '127.0.0.1'::inet
     OR pg_catalog.inet_client_addr() IS DISTINCT FROM '127.0.0.1'::inet THEN
    RAISE EXCEPTION 'synthetic history session guard failed';
  END IF;
  RETURN NEW;
END
$history_guard$;
