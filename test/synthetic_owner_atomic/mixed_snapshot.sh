#!/usr/bin/env bash
set -euo pipefail
psql=(docker exec -i -e PGPASSWORD=synthetic-only "$SYNTHETIC_DB_CONTAINER" psql -U postgres -d owner_sync_lab -X -qAt -v ON_ERROR_STOP=1)
# Separate requests and isolated fake owner. This is NOT actual Supabase HTTP or Auth.
"${psql[@]}" <<'SQL'
INSERT INTO lab_sync.payment_state VALUES ('00000000-0000-0000-0000-000000000005', 0, '{"old":5}', '["new"]');
SQL
old_values=$("${psql[@]}" <<'SQL'
BEGIN;
SELECT day_values::text FROM lab_sync.payment_state WHERE owner_id='00000000-0000-0000-0000-000000000005';
COMMIT;
SQL
)
test "$old_values" = '{"old": 5}'
"${psql[@]}" <<'SQL'
BEGIN;
SET ROLE lab_authenticated;
SELECT set_config('lab.owner','00000000-0000-0000-0000-000000000005',false);
DO $$ DECLARE r jsonb; BEGIN
 r:=lab_sync.apply_days('30000000-0000-0000-0000-000000000001',0,'{"new":10}','["old"]');
 IF r <> '{"status":"applied","revision":1}'::jsonb THEN RAISE EXCEPTION 'writer outcome mismatch'; END IF;
END $$;
COMMIT;
SQL
new_deleted=$("${psql[@]}" <<'SQL'
BEGIN;
SELECT deleted_ids::text FROM lab_sync.payment_state WHERE owner_id='00000000-0000-0000-0000-000000000005';
COMMIT;
SQL
)
test "$new_deleted" = '["old"]'
"${psql[@]}" <<'SQL'
DO $$ DECLARE s lab_sync.payment_state%ROWTYPE; BEGIN
 SELECT * INTO STRICT s FROM lab_sync.payment_state WHERE owner_id='00000000-0000-0000-0000-000000000005';
 IF s.revision <> 1 OR s.day_values <> '{"new":10}'::jsonb OR s.deleted_ids <> '["old"]'::jsonb THEN
  RAISE EXCEPTION 'single row snapshot mismatch'; END IF;
END $$;
SQL
echo 'Separate reads observed old value with new deletion; single-row read is revision 1.'
