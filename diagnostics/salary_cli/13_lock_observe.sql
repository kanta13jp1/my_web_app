-- SYNTHETIC TEST ONLY. Never run against a live or shared database.
-- Read-only observation for the reviewed synthetic fresh PG17 service only.
-- Holder session must be separately identified as salary_fixture_holder and
-- acquire ACCESS SHARE on public.cfo_assets before CLI starts. Do not infer
-- lock establishment from launch or elapsed time; check granted=true below.
\set ON_ERROR_STOP on
BEGIN READ ONLY;
DO $observe_guard$
BEGIN
  IF pg_catalog.current_database() <> 'salary_identity_isolated'
     OR pg_catalog.current_setting('salary_test.isolated', true) IS DISTINCT FROM 'disposable-pg17-only'
     OR pg_catalog.current_setting('server_version_num')::integer < 170000
     OR pg_catalog.current_setting('server_version_num')::integer >= 180000
     OR pg_catalog.current_setting('session_replication_role') <> 'origin'
     OR pg_catalog.inet_server_addr() IS DISTINCT FROM '127.0.0.1'::inet
     OR pg_catalog.inet_client_addr() IS DISTINCT FROM '127.0.0.1'::inet
     OR pg_catalog.to_regclass('public.cfo_assets') IS NULL THEN
    RAISE EXCEPTION 'synthetic lock observation guard failed';
  END IF;
END
$observe_guard$;

\echo 'synthetic target relation OID and holder sessions'
SELECT pg_catalog.to_regclass('public.cfo_assets')::oid AS target_relation_oid;
SELECT pid, datname, usename, application_name, backend_start,
       xact_start, query_start, state, wait_event_type, wait_event
FROM pg_catalog.pg_stat_activity
WHERE datname = pg_catalog.current_database()
  AND application_name = 'salary_fixture_holder'
ORDER BY pid;

\echo 'target relation locks, holder or waiter, and blockers'
SELECT l.pid, a.application_name, l.locktype, l.relation AS target_relation_oid,
       l.mode, l.granted, l.waitstart, a.query_start, a.state,
       a.wait_event_type, a.wait_event, pg_catalog.pg_blocking_pids(l.pid) AS blockers
FROM pg_catalog.pg_locks l
LEFT JOIN pg_catalog.pg_stat_activity a ON a.pid = l.pid
WHERE l.database = (SELECT oid FROM pg_catalog.pg_database WHERE datname = pg_catalog.current_database())
  AND l.relation = pg_catalog.to_regclass('public.cfo_assets')
ORDER BY l.granted DESC, l.pid, l.mode;

\echo 'explicit expected holder lock presence (false is not success)'
SELECT EXISTS (
  SELECT 1 FROM pg_catalog.pg_locks l
  JOIN pg_catalog.pg_stat_activity a ON a.pid = l.pid
  WHERE a.datname = pg_catalog.current_database()
    AND a.application_name = 'salary_fixture_holder'
    AND l.database = (SELECT oid FROM pg_catalog.pg_database WHERE datname = pg_catalog.current_database())
    AND l.relation = pg_catalog.to_regclass('public.cfo_assets')
    AND l.mode = 'AccessShareLock' AND l.granted
) AS holder_has_granted_access_share;
COMMIT;
-- The caller must verify one unique holder and preserve PID plus backend_start.
-- No waiter may be visible if it timed out before this snapshot: inconclusive.
-- Observer does not acquire/release the test lock, stop a process, or retry.
