#!/usr/bin/env bash
set -euo pipefail
base=(timeout 60s docker exec -i -e PGCONNECT_TIMEOUT=5 -e 'PGOPTIONS=-c statement_timeout=40s -c lock_timeout=25s -c idle_in_transaction_session_timeout=35s' -e PGPASSWORD=synthetic-only "$SYNTHETIC_DB_CONTAINER" psql -U postgres -d owner_sync_lab -X -qAt -v ON_ERROR_STOP=1)
log="$RUNNER_TEMP/checkpoint_snapshot_writer.log"; pid=''
cleanup() {
 code=$?
 if [ "$code" -ne 0 ]; then [ ! -f "$log" ] || cat "$log" >&2; fi
 [ -z "$pid" ] || wait "$pid" 2>/dev/null || true
 exit "$code"
}
trap cleanup EXIT
owner='00000000-0000-0000-0000-000000000002'
generation='10000000-0000-0000-0000-000000000002'
anchor=$("${base[@]}" -F '|' -c "SELECT s.revision,s.digest,c.journal_count,c.journal_head FROM lab_private.stream s JOIN lab_private.checkpoint c USING(owner_id) WHERE s.owner_id='$owner'")
IFS='|' read -r revision digest count head <<< "$anchor"
[[ "$revision" = 1 && "$count" = 2 && "$digest" =~ ^[0-9a-f]{64}$ && "$head" =~ ^[0-9a-f]{64}$ ]]
query="SET ROLE lab_authenticated; SET lab.owner='$owner'; SET lab.synthetic_read_sleep='on'; WITH q AS MATERIALIZED (SELECT lab_api.read_checked_v1('$owner','$generation',1,'$digest',2,'$head') AS r) SELECT (r->>'status')||':'||(r->>'revision')||':'||(r->>'journalCount') FROM q;"
timeout 60s docker exec -i -e PGCONNECT_TIMEOUT=5 -e 'PGOPTIONS=-c statement_timeout=40s -c lock_timeout=25s' -e PGAPPNAME=checkpoint_snapshot_reader -e PGPASSWORD=synthetic-only "$SYNTHETIC_DB_CONTAINER" psql -U postgres -d owner_sync_lab -X -qAt -v ON_ERROR_STOP=1 -c "$query" >"$log" 2>&1 &
pid=$!
ready=0
for i in $(seq 1 60); do
 status=$("${base[@]}" -c "SELECT count(*) FROM pg_stat_activity WHERE application_name='checkpoint_snapshot_reader' AND wait_event='PgSleep' AND state='active'")
 if [ "$status" = 1 ]; then ready=1; break; fi
 sleep 0.1
done
if [ "$ready" != 1 ]; then echo 'reader snapshot barrier absent' >&2; exit 1; fi
applied=$("${base[@]}" -c "SET ROLE lab_authenticated; SET lab.owner='$owner'; SELECT lab_api.apply_request('30000000-0000-0000-0000-000000000003','$generation',1,'$digest','{\"x\":12}','[]')->>'status';")
[[ "$applied" = 'applied' ]]
still_waiting=$("${base[@]}" -c "SELECT count(*) FROM pg_stat_activity WHERE application_name='checkpoint_snapshot_reader' AND wait_event='PgSleep' AND state='active'")
[[ "$still_waiting" = 1 ]]
wait "$pid"; pid=''
before=$(cat "$log")
[[ "$before" = 'snapshot:1:2' ]]
after=$("${base[@]}" -c "SET ROLE lab_authenticated; SET lab.owner='$owner'; WITH q AS MATERIALIZED (SELECT lab_api.read_checked_v1('$owner','$generation',1,'$digest',2,'$head') AS r) SELECT (r->>'status')||':'||(r->>'revision')||':'||(r->>'journalCount') FROM q;")
[[ "$after" = 'snapshot:2:3' ]]
echo 'PASS: read begun before a concurrent commit stayed consistent and next read saw new snapshot'
