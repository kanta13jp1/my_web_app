-- SYNTHETIC ONLY: read-only audit; failure-side audit writes may roll back.
\set ON_ERROR_STOP on
BEGIN READ ONLY;
DO $guard$
BEGIN
  IF pg_catalog.current_database() <> 'salary_identity_isolated'
     OR pg_catalog.current_setting('salary_test.isolated', true) IS DISTINCT FROM 'disposable-pg17-only'
     OR pg_catalog.current_setting('server_version_num')::integer < 170000
     OR pg_catalog.current_setting('server_version_num')::integer >= 180000
     OR pg_catalog.current_setting('session_replication_role') <> 'origin'
     OR pg_catalog.inet_server_addr() IS DISTINCT FROM '127.0.0.1'::inet
     OR pg_catalog.inet_client_addr() IS DISTINCT FROM '127.0.0.1'::inet THEN
    RAISE EXCEPTION 'synthetic audit observation guard failed';
  END IF;
END
$guard$;
SELECT sequence, command_tag, backend_pid, lock_timeout_value, statement_timeout_value
FROM supabase_migrations.fixture_ddl_audit ORDER BY sequence;
SELECT evtname, evtenabled, evtevent, evtfoid::regprocedure AS function_name
FROM pg_catalog.pg_event_trigger WHERE evtname IN ('fixture_guard_ddl_start', 'fixture_audit_ddl_start')
ORDER BY evtname;
COMMIT;
