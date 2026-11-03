#!/usr/bin/env bash
set -euo pipefail
base=(docker exec -i -e PGPASSWORD=synthetic-only "$SYNTHETIC_DB_CONTAINER" psql -U postgres -d owner_sync_lab -X -qAt -v ON_ERROR_STOP=1)
log_a="$RUNNER_TEMP/owner_writer_a.log"
log_b="$RUNNER_TEMP/owner_writer_b.log"
pid_a=''; pid_b=''
cleanup() {
  code=$?
  if [ "$code" -ne 0 ]; then
    echo 'Synthetic concurrency failed; captured logs:' >&2
    [ ! -f "$log_a" ] || cat "$log_a" >&2
    [ ! -f "$log_b" ] || cat "$log_b" >&2
  fi
  [ -z "$pid_b" ] || wait "$pid_b" 2>/dev/null || true
  [ -z "$pid_a" ] || wait "$pid_a" 2>/dev/null || true
  exit "$code"
}
trap cleanup EXIT
"${base[@]}" -c "SELECT 1" >/dev/null
# Writer A holds the row lock while sleeping; wait for the server's PgSleep event.
docker exec -i -e PGAPPNAME=lab_writer_a -e PGPASSWORD=synthetic-only "$SYNTHETIC_DB_CONTAINER" psql -U postgres -d owner_sync_lab -X -qAt -v ON_ERROR_STOP=1 >"$log_a" 2>&1 <<'SQL' &
BEGIN;
SET ROLE lab_authenticated;
SELECT set_config('lab.owner','00000000-0000-0000-0000-000000000004',false);
SELECT lab_sync.apply_days('20000000-0000-0000-0000-000000000001',0,'{"x":10}','[]');
SELECT pg_sleep(20);
COMMIT;
SQL
pid_a=$!
ready=0
for i in $(seq 1 40); do
  status=$("${base[@]}" -c "SELECT count(*) FROM pg_stat_activity WHERE application_name='lab_writer_a' AND wait_event='PgSleep' AND state='active'")
  if [ "$status" = 1 ]; then ready=1; break; fi
  sleep 0.1
done
if [ "$ready" != 1 ]; then cat "$log_a"; wait "$pid_a" || true; echo 'synthetic concurrency barrier absent' >&2; exit 1; fi
docker exec -i -e PGAPPNAME=lab_writer_b -e PGPASSWORD=synthetic-only "$SYNTHETIC_DB_CONTAINER" psql -U postgres -d owner_sync_lab -X -qAt -v ON_ERROR_STOP=1 >"$log_b" 2>&1 <<'SQL' &
BEGIN;
SET ROLE lab_authenticated;
SELECT set_config('lab.owner','00000000-0000-0000-0000-000000000004',false);
SELECT lab_sync.apply_days('20000000-0000-0000-0000-000000000002',0,'{"x":11}','[]');
COMMIT;
SQL
pid_b=$!
blocked=0
for i in $(seq 1 60); do
  status=$("${base[@]}" -c "SELECT count(*) FROM pg_stat_activity b JOIN pg_stat_activity a ON a.application_name='lab_writer_a' AND a.pid=ANY(pg_blocking_pids(b.pid)) WHERE b.application_name='lab_writer_b' AND b.wait_event_type='Lock'")
  if [ "$status" = 1 ]; then blocked=1; break; fi
  sleep 0.1
done
if [ "$blocked" != 1 ]; then echo 'synthetic B was not observed blocked by A' >&2; exit 1; fi
echo 'Verified writer B blocked on writer A in PostgreSQL.'
wait "$pid_a"; pid_a=''
wait "$pid_b"; pid_b=''
cat "$log_a" "$log_b"
"${base[@]}" <<'SQL'
DO $$ DECLARE s lab_sync.payment_state%ROWTYPE; n integer; BEGIN
SELECT * INTO STRICT s FROM lab_sync.payment_state WHERE owner_id='00000000-0000-0000-0000-000000000004';
IF s.revision <> 1 OR s.day_values <> '{"x":10}'::jsonb THEN RAISE EXCEPTION 'concurrent state mismatch'; END IF;
SELECT count(*) INTO n FROM lab_sync.request_journal WHERE owner_id=s.owner_id AND ((request_id='20000000-0000-0000-0000-000000000001' AND outcome='{"status":"applied","revision":1}'::jsonb) OR (request_id='20000000-0000-0000-0000-000000000002' AND outcome='{"status":"conflict","revision":1}'::jsonb));
IF n <> 2 THEN RAISE EXCEPTION 'concurrent outcomes mismatch: %', n; END IF;
END $$;
SQL
