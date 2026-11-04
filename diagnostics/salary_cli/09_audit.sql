-- SYNTHETIC ONLY: requires the reviewed 04 + 05 fixture in a fresh PG17 DB.
-- Runs under the already-enabled 05 DDL guard; test-only writes may affect timing.
\set ON_ERROR_STOP on
CREATE TABLE supabase_migrations.fixture_ddl_audit (
  sequence bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  command_tag text NOT NULL,
  backend_pid integer NOT NULL,
  lock_timeout_value text NOT NULL,
  statement_timeout_value text NOT NULL
);
CREATE FUNCTION supabase_migrations.fixture_audit_ddl()
RETURNS event_trigger LANGUAGE plpgsql SET search_path = '' AS $audit$
BEGIN
  IF pg_catalog.current_database() <> 'salary_identity_isolated'
     OR pg_catalog.current_setting('salary_test.isolated', true) IS DISTINCT FROM 'disposable-pg17-only'
     OR pg_catalog.current_setting('server_version_num')::integer < 170000
     OR pg_catalog.current_setting('server_version_num')::integer >= 180000
     OR pg_catalog.current_setting('session_replication_role') <> 'origin'
     OR pg_catalog.inet_server_addr() IS DISTINCT FROM '127.0.0.1'::inet
     OR pg_catalog.inet_client_addr() IS DISTINCT FROM '127.0.0.1'::inet THEN
    RAISE EXCEPTION 'synthetic audit session guard failed';
  END IF;
  INSERT INTO supabase_migrations.fixture_ddl_audit
    (command_tag, backend_pid, lock_timeout_value, statement_timeout_value)
  VALUES (TG_TAG, pg_catalog.pg_backend_pid(), pg_catalog.current_setting('lock_timeout'),
          pg_catalog.current_setting('statement_timeout'));
END
$audit$;
CREATE EVENT TRIGGER fixture_audit_ddl_start
  ON ddl_command_start EXECUTE FUNCTION supabase_migrations.fixture_audit_ddl();
