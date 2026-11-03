-- Intentionally adversarial disposable test: no claim of real DB recovery.
\set ON_ERROR_STOP on
\set VERBOSITY verbose
DO $$ BEGIN
 IF current_database() IS DISTINCT FROM 'owner_sync_lab' OR current_user IS DISTINCT FROM 'postgres' THEN
  RAISE EXCEPTION 'wrong synthetic target'; END IF;
END $$;
CREATE TEMP TABLE old_stream AS SELECT * FROM lab_private.stream WHERE owner_id='00000000-0000-0000-0000-000000000005';
CREATE TEMP TABLE old_checkpoint AS SELECT * FROM lab_private.checkpoint WHERE owner_id='00000000-0000-0000-0000-000000000005';
DO $$ BEGIN
 IF (SELECT count(*) FROM old_stream) IS DISTINCT FROM 1 OR (SELECT count(*) FROM old_checkpoint) IS DISTINCT FROM 1 THEN
  RAISE EXCEPTION 'baseline fixture missing'; END IF;
END $$;
SET ROLE lab_authenticated;
SELECT pg_catalog.set_config('lab.owner','00000000-0000-0000-0000-000000000005',false);
DO $$ DECLARE s jsonb; applied jsonb; BEGIN
 s:=lab_api.read_current();
 IF s->>'status' IS DISTINCT FROM 'snapshot' OR (s->>'revision')::bigint IS DISTINCT FROM 0 THEN
  RAISE EXCEPTION 'baseline not healthy'; END IF;
 applied:=lab_api.apply_request('50000000-0000-0000-0000-000000000001',
  (s->>'generation')::uuid,0,s->>'digest','{"synthetic-debt":19}'::jsonb,'[]'::jsonb);
 IF applied->>'status' IS DISTINCT FROM 'applied' OR (applied->>'revision')::bigint IS DISTINCT FROM 1 THEN
  RAISE EXCEPTION 'update did not commit'; END IF;
END $$;
RESET ROLE;
DO $$ BEGIN
 IF (SELECT count(*) FROM lab_private.journal WHERE owner_id='00000000-0000-0000-0000-000000000005') IS DISTINCT FROM 1 OR
    (SELECT revision FROM lab_private.stream WHERE owner_id='00000000-0000-0000-0000-000000000005') IS DISTINCT FROM 1 THEN
  RAISE EXCEPTION 'pre-rollback state was not recorded'; END IF;
END $$;
-- Simulate all related rows being restored to one coherent older backup.
BEGIN;
DELETE FROM lab_private.journal WHERE owner_id='00000000-0000-0000-0000-000000000005';
UPDATE lab_private.stream s SET generation=t.generation,revision=t.revision,day_values=t.day_values,
 deleted_ids=t.deleted_ids,digest=t.digest FROM old_stream t WHERE s.owner_id=t.owner_id;
UPDATE lab_private.checkpoint c SET generation=t.generation,revision=t.revision,digest=t.digest,
 journal_count=t.journal_count,journal_head=t.journal_head,genesis_digest=t.genesis_digest
 FROM old_checkpoint t WHERE c.owner_id=t.owner_id;
DO $$ BEGIN
 IF (SELECT count(*) FROM lab_private.journal WHERE owner_id='00000000-0000-0000-0000-000000000005') IS DISTINCT FROM 0 OR
    (SELECT pg_catalog.to_jsonb(s) FROM lab_private.stream s WHERE owner_id='00000000-0000-0000-0000-000000000005')
      IS DISTINCT FROM (SELECT pg_catalog.to_jsonb(s) FROM old_stream s) OR
    (SELECT pg_catalog.to_jsonb(c) FROM lab_private.checkpoint c WHERE owner_id='00000000-0000-0000-0000-000000000005')
      IS DISTINCT FROM (SELECT pg_catalog.to_jsonb(c) FROM old_checkpoint c) THEN
  RAISE EXCEPTION 'coherent rollback injection did not reproduce baseline'; END IF;
END $$;
COMMIT;
SET ROLE lab_authenticated;
DO $$ DECLARE after_rollback jsonb; BEGIN
 after_rollback:=lab_api.read_current();
 IF after_rollback->>'status' IS DISTINCT FROM 'recovery_hold' THEN
   RAISE EXCEPTION 'coherent full database rollback not detected; result %', after_rollback->>'status';
 END IF;
END $$;
RESET ROLE;
