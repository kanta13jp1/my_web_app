#!/usr/bin/env bash
set -euo pipefail
base=(docker exec -i -e PGPASSWORD=synthetic-only "$SYNTHETIC_DB_CONTAINER" psql -U postgres -d owner_sync_lab -X -qAt -v ON_ERROR_STOP=1)
pid_a=''; log="$RUNNER_TEMP/old_writer.log"; err="$RUNNER_TEMP/fence_error.log"
cleanup() { code=$?; if [ "$code" -ne 0 ]; then [ ! -f "$log" ] || cat "$log" >&2; [ ! -f "$err" ] || cat "$err" >&2; fi; [ -z "$pid_a" ] || wait "$pid_a" 2>/dev/null || true; exit "$code"; }
trap cleanup EXIT
"${base[@]}" -c "DO \$\$ BEGIN IF current_database() <> 'owner_sync_lab' OR current_user <> 'postgres' THEN RAISE EXCEPTION 'wrong synthetic database'; END IF; END \$\$"
"${base[@]}" -c "GRANT TRUNCATE ON public.asset_pref_mirror TO authenticated"
if "${base[@]}" < test/synthetic_owner_fence/candidate.sql >"$err" 2>&1; then echo 'preflight accepted effective TRUNCATE' >&2; exit 1; fi
grep -F 'TRUNCATE remains reachable' "$err" >/dev/null
policies=$("${base[@]}" -c "SELECT count(*) FROM pg_policies WHERE schemaname='public' AND tablename='asset_pref_mirror' AND policyname IN ('debt_day_block_insert','debt_day_block_update','debt_day_block_delete')")
test "$policies" = 0
"${base[@]}" -c "REVOKE TRUNCATE ON public.asset_pref_mirror FROM authenticated"
docker exec -i -e PGAPPNAME=old_writer -e PGPASSWORD=synthetic-only "$SYNTHETIC_DB_CONTAINER" psql -U postgres -d owner_sync_lab -X -qAt -v ON_ERROR_STOP=1 >"$log" 2>&1 <<'SQL' &
BEGIN; SET ROLE authenticated;
SELECT set_config('lab.owner','00000000-0000-0000-0000-000000000001',false);
DO $$ DECLARE n integer; BEGIN UPDATE public.asset_pref_mirror SET value='{"x":11}' WHERE pref_key='debt_payment_day_overrides'; GET DIAGNOSTICS n=ROW_COUNT; IF n <> 1 THEN RAISE EXCEPTION 'old writer changed % rows',n; END IF; END $$;
SELECT pg_sleep(20);
COMMIT;
SQL
pid_a=$!
ready=0
for i in $(seq 1 40); do
 status=$("${base[@]}" -c "SELECT count(*) FROM pg_stat_activity WHERE application_name='old_writer' AND wait_event='PgSleep' AND state='active'")
 if [ "$status" = 1 ]; then ready=1; break; fi
 sleep 0.1
done
if [ "$ready" != 1 ]; then echo 'in-flight old writer barrier absent' >&2; exit 1; fi
if "${base[@]}" < test/synthetic_owner_fence/candidate.sql >"$err" 2>&1; then echo 'fence acquired lock during old writer' >&2; exit 1; fi
grep -F 'could not obtain lock on relation' "$err" >/dev/null
policies=$("${base[@]}" -c "SELECT count(*) FROM pg_policies WHERE schemaname='public' AND tablename='asset_pref_mirror' AND policyname IN ('debt_day_block_insert','debt_day_block_update','debt_day_block_delete')")
test "$policies" = 0
wait "$pid_a"; pid_a=''
changed=$("${base[@]}" -c "SELECT count(*) FROM public.asset_pref_mirror WHERE user_id='00000000-0000-0000-0000-000000000001' AND pref_key='debt_payment_day_overrides' AND value='{\"x\":11}'::jsonb")
test "$changed" = 1
"${base[@]}" < test/synthetic_owner_fence/candidate.sql
policies=$("${base[@]}" -c "SELECT count(*) FROM pg_policies WHERE schemaname='public' AND tablename='asset_pref_mirror' AND policyname IN ('debt_day_block_insert','debt_day_block_update','debt_day_block_delete')")
test "$policies" = 3
echo 'Effective truncate rejected; inflight writer prevented NOWAIT fence; retry after commit installed all policies.'
