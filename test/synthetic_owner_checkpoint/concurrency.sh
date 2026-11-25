#!/usr/bin/env bash
set -euo pipefail
base=(timeout 60s docker exec -i -e PGCONNECT_TIMEOUT=5 -e "PGOPTIONS=-c statement_timeout=40s -c lock_timeout=25s -c idle_in_transaction_session_timeout=35s" -e PGPASSWORD=synthetic-only "$SYNTHETIC_DB_CONTAINER" psql -U postgres -d owner_sync_lab -X -qAt -v ON_ERROR_STOP=1)
log_a="$RUNNER_TEMP/checkpoint_writer_a.log"; log_b="$RUNNER_TEMP/checkpoint_writer_b.log"
pid_a=''; pid_b=''
cleanup() {
  code=$?
  if [ "$code" -ne 0 ]; then
    echo 'Synthetic concurrency failed; logs follow' >&2
    [ ! -f "$log_a" ] || cat "$log_a" >&2
    [ ! -f "$log_b" ] || cat "$log_b" >&2
  fi
  [ -z "$pid_b" ] || wait "$pid_b" 2>/dev/null || true
  [ -z "$pid_a" ] || wait "$pid_a" 2>/dev/null || true
  exit "$code"
}
trap cleanup EXIT
digest=$("${base[@]}" -c "SELECT digest FROM lab_private.stream WHERE owner_id='00000000-0000-0000-0000-000000000002'")
[[ "$digest" =~ ^[0-9a-f]{64}$ ]]
timeout 60s docker exec -i -e PGCONNECT_TIMEOUT=5 -e "PGOPTIONS=-c statement_timeout=40s -c lock_timeout=25s -c idle_in_transaction_session_timeout=35s" -e PGAPPNAME=checkpoint_a -e PGPASSWORD=synthetic-only "$SYNTHETIC_DB_CONTAINER" psql -U postgres -d owner_sync_lab -X -qAt -v ON_ERROR_STOP=1 >"$log_a" 2>&1 <<SQL &
BEGIN;
SET ROLE lab_authenticated;
SELECT set_config('lab.owner','00000000-0000-0000-0000-000000000002',false);
SELECT lab_api.apply_request('30000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000002',0,'$digest','{"x":10}','[]');
SELECT pg_sleep(15);
COMMIT;
SQL
pid_a=$!
ready=0
for i in $(seq 1 60); do
 status=$("${base[@]}" -c "SELECT count(*) FROM pg_stat_activity WHERE application_name='checkpoint_a' AND wait_event='PgSleep' AND state='active'")
 if [ "$status" = 1 ]; then ready=1; break; fi
 sleep 0.1
done
if [ "$ready" != 1 ]; then echo 'synthetic writer A barrier absent' >&2; exit 1; fi
timeout 60s docker exec -i -e PGCONNECT_TIMEOUT=5 -e "PGOPTIONS=-c statement_timeout=40s -c lock_timeout=25s -c idle_in_transaction_session_timeout=35s" -e PGAPPNAME=checkpoint_b -e PGPASSWORD=synthetic-only "$SYNTHETIC_DB_CONTAINER" psql -U postgres -d owner_sync_lab -X -qAt -v ON_ERROR_STOP=1 >"$log_b" 2>&1 <<SQL &
BEGIN;
SET ROLE lab_authenticated;
SELECT set_config('lab.owner','00000000-0000-0000-0000-000000000002',false);
SELECT lab_api.apply_request('30000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000002',0,'$digest','{"x":11}','[]');
COMMIT;
SQL
pid_b=$!
blocked=0
for i in $(seq 1 60); do
 status=$("${base[@]}" -c "SELECT count(*) FROM pg_stat_activity b JOIN pg_stat_activity a ON a.application_name='checkpoint_a' AND a.pid=ANY(pg_blocking_pids(b.pid)) WHERE b.application_name='checkpoint_b' AND b.wait_event_type='Lock'")
 if [ "$status" = 1 ]; then blocked=1; break; fi
 sleep 0.1
done
if [ "$blocked" != 1 ]; then echo 'synthetic B not observed blocked by A' >&2; exit 1; fi
wait "$pid_a"; pid_a=''; wait "$pid_b"; pid_b=''
"${base[@]}" <<'SQL'
DO $$ DECLARE s lab_private.stream%ROWTYPE; c lab_private.checkpoint%ROWTYPE; n integer; BEGIN
 SELECT * INTO STRICT s FROM lab_private.stream WHERE owner_id='00000000-0000-0000-0000-000000000002';
 SELECT * INTO STRICT c FROM lab_private.checkpoint WHERE owner_id=s.owner_id;
 IF s.revision IS DISTINCT FROM 1 OR s.day_values IS DISTINCT FROM '{"x":10}'::jsonb OR c.journal_count IS DISTINCT FROM 2 OR
    lab_private.valid_journal(s.owner_id,s.generation,s.revision,s.digest,c.journal_count,c.journal_head,c.genesis_digest) IS DISTINCT FROM true THEN
  RAISE EXCEPTION 'concurrent final state/checkpoint invalid'; END IF;
 SELECT count(*) INTO n FROM lab_private.journal WHERE owner_id=s.owner_id AND
  ((request_id='30000000-0000-0000-0000-000000000001' AND outcome->>'status'='applied') OR
   (request_id='30000000-0000-0000-0000-000000000002' AND outcome->>'status'='conflict'));
 IF n IS DISTINCT FROM 2 THEN RAISE EXCEPTION 'missing or incorrect concurrent outcomes'; END IF;
END $$;
SQL
echo 'PASS: fake-auth two-connection lock, one applied and one conflict'
