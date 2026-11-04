-- SYNTHETIC TEST ONLY. Never run against a live or shared database.
-- Synthetic statement-timeout case ONLY; omit entirely in other cases.
-- Requires reviewed 04 / 05 / 09 / 10 in a fresh, isolated PG17 service.
-- Marker and event triggers are guardrails, not proof of isolation.
\set ON_ERROR_STOP on

DO $setup_guard$
BEGIN
  IF pg_catalog.current_database() <> 'salary_identity_isolated'
     OR pg_catalog.current_setting('salary_test.isolated', true) IS DISTINCT FROM 'disposable-pg17-only'
     OR pg_catalog.current_setting('server_version_num')::integer < 170000
     OR pg_catalog.current_setting('server_version_num')::integer >= 180000
     OR pg_catalog.current_setting('session_replication_role') <> 'origin'
     OR pg_catalog.inet_server_addr() IS DISTINCT FROM '127.0.0.1'::inet
     OR pg_catalog.inet_client_addr() IS DISTINCT FROM '127.0.0.1'::inet
     OR pg_catalog.to_regclass('public.cfo_assets') IS NULL
     OR pg_catalog.to_regclass('public.asset_balance_accounts') IS NOT NULL
     OR pg_catalog.to_regclass('supabase_migrations.fixture_ddl_audit') IS NULL
     OR NOT EXISTS (SELECT 1 FROM pg_catalog.pg_event_trigger
                    WHERE evtname = 'fixture_guard_ddl_start' AND evtenabled IN ('O', 'A')
                      AND evtevent = 'ddl_command_start'
                      AND evtfoid = pg_catalog.to_regprocedure('supabase_migrations.fixture_guard_ddl()'))
     OR NOT EXISTS (SELECT 1 FROM pg_catalog.pg_event_trigger
                    WHERE evtname = 'fixture_audit_ddl_start' AND evtenabled IN ('O', 'A')
                      AND evtevent = 'ddl_command_start'
                      AND evtfoid = pg_catalog.to_regprocedure('supabase_migrations.fixture_audit_ddl()')) THEN
    RAISE EXCEPTION 'unsafe or unexpected synthetic delay setup';
  END IF;
END
$setup_guard$;

CREATE FUNCTION supabase_migrations.fixture_delay_first_post_policy_alter()
RETURNS event_trigger LANGUAGE plpgsql SET search_path = '' AS $delay_guard$
BEGIN
  IF pg_catalog.current_database() <> 'salary_identity_isolated'
     OR pg_catalog.current_setting('salary_test.isolated', true) IS DISTINCT FROM 'disposable-pg17-only'
     OR pg_catalog.current_setting('server_version_num')::integer < 170000
     OR pg_catalog.current_setting('server_version_num')::integer >= 180000
     OR pg_catalog.current_setting('session_replication_role') <> 'origin'
     OR pg_catalog.inet_server_addr() IS DISTINCT FROM '127.0.0.1'::inet
     OR pg_catalog.inet_client_addr() IS DISTINCT FROM '127.0.0.1'::inet THEN
    RAISE EXCEPTION 'synthetic delay session guard failed';
  END IF;

  -- Only the unchanged, hash-verified candidate's expected order identifies
  -- this ALTER: TG_TAG alone does not identify the affected relation. The four
  -- policies are visible in the CLI's own still-uncommitted transaction.
  IF TG_TAG = 'ALTER TABLE'
     AND pg_catalog.current_setting('salary_test.delay_done', true) IS DISTINCT FROM '1'
     AND (SELECT count(*) FROM pg_catalog.pg_policy
          WHERE polrelid = pg_catalog.to_regclass('public.asset_balance_accounts')
            AND polname IN ('asset_balance_accounts_select_own',
                            'asset_balance_accounts_insert_own',
                            'asset_balance_accounts_update_own',
                            'asset_balance_accounts_delete_own')) = 4 THEN
    PERFORM pg_catalog.set_config('salary_test.delay_done', '1', true);
    RAISE LOG 'synthetic_delay_start pid=% lock_timeout=% statement_timeout=%',
      pg_catalog.pg_backend_pid(), pg_catalog.current_setting('lock_timeout'),
      pg_catalog.current_setting('statement_timeout');
    PERFORM pg_catalog.pg_sleep(28);
    RAISE LOG 'synthetic_delay_finished pid=%', pg_catalog.pg_backend_pid();
  END IF;
END
$delay_guard$;

CREATE EVENT TRIGGER fixture_delay_post_policy_alter_start
  ON ddl_command_start EXECUTE FUNCTION supabase_migrations.fixture_delay_first_post_policy_alter();

-- No migration, holder, retry, repair, cleanup, or DB connection is started.
-- A timeout can roll back the delay flag and audit rows. Server logs may be
-- needed to distinguish delay start from completion; absence proves neither.
-- Event triggers do not cover all commands, and marker values can be forged.
