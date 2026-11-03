-- Disposable fake-auth tests only; no production identity is exercised.
\set ON_ERROR_STOP on
DO $$ BEGIN
 IF current_database()  IS DISTINCT FROM  'owner_sync_lab' OR current_user  IS DISTINCT FROM  'postgres' THEN
  RAISE EXCEPTION 'wrong synthetic target';
 END IF;
END $$;
SET ROLE lab_anon;
DO $$ BEGIN
 BEGIN
  PERFORM lab_api.read_current();
  RAISE EXCEPTION 'anonymous unexpectedly reached RPC';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;
SET ROLE lab_authenticated;
SELECT pg_catalog.set_config('lab.owner','',false);
DO $$ BEGIN
 BEGIN
  PERFORM lab_api.read_current();
  RAISE EXCEPTION 'missing owner unexpectedly accepted';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN
  PERFORM * FROM lab_private.stream;
  RAISE EXCEPTION 'authenticated unexpectedly read private table';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
SELECT pg_catalog.set_config('lab.owner','00000000-0000-0000-0000-000000000099',false);
DO $$ BEGIN
 IF lab_api.read_current()->>'status'  IS DISTINCT FROM  'recovery_hold' THEN
  RAISE EXCEPTION 'missing owner must not be initialized'; END IF;
END $$;
SELECT pg_catalog.set_config('lab.owner','00000000-0000-0000-0000-000000000001',false);
DO $$ DECLARE s jsonb; first jsonb; again jsonb; wrong jsonb; b jsonb; BEGIN
 s:=lab_api.read_current();
 IF s->>'status' IS DISTINCT FROM 'snapshot' OR s->>'owner' IS DISTINCT FROM '00000000-0000-0000-0000-000000000001' OR
    (s->>'revision')::bigint IS DISTINCT FROM 0 THEN RAISE EXCEPTION 'bad owner A snapshot'; END IF;
 first:=lab_api.apply_request('20000000-0000-0000-0000-000000000001',
    (s->>'generation')::uuid,0,s->>'digest','{"synthetic-debt":10}'::jsonb,'[]'::jsonb);
 IF first->>'status' IS DISTINCT FROM 'applied' OR (first->>'revision')::bigint IS DISTINCT FROM 1 THEN RAISE EXCEPTION 'bad first apply'; END IF;
 again:=lab_api.apply_request('20000000-0000-0000-0000-000000000001',
    (s->>'generation')::uuid,0,s->>'digest','{"synthetic-debt":10}'::jsonb,'[]'::jsonb);
 IF again->>'status' IS DISTINCT FROM 'historical_receipt' OR again->'outcome' IS DISTINCT FROM first THEN RAISE EXCEPTION 'retry not immutable'; END IF;
 BEGIN
  PERFORM lab_api.apply_request('20000000-0000-0000-0000-000000000001',
    (s->>'generation')::uuid,0,s->>'digest','{"synthetic-debt":11}'::jsonb,'[]'::jsonb);
  RAISE EXCEPTION 'request ID reuse unexpectedly accepted';
 EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 wrong:=lab_api.apply_request('20000000-0000-0000-0000-000000000002',
    'ffffffff-ffff-ffff-ffff-ffffffffffff',0,s->>'digest','{}'::jsonb,'[]'::jsonb);
 IF wrong->>'status' IS DISTINCT FROM 'conflict' THEN RAISE EXCEPTION 'wrong generation not rejected'; END IF;
 PERFORM pg_catalog.set_config('lab.owner','00000000-0000-0000-0000-000000000002',false);
 b:=lab_api.read_current();
 IF b->>'owner' IS DISTINCT FROM '00000000-0000-0000-0000-000000000002' OR (b->>'revision')::bigint IS DISTINCT FROM 0 OR
    b->'values' IS DISTINCT FROM '{}'::jsonb THEN RAISE EXCEPTION 'owner B state leaked'; END IF;
 PERFORM pg_catalog.set_config('lab.owner','00000000-0000-0000-0000-000000000004',false);
 wrong:=lab_api.apply_request('40000000-0000-0000-0000-000000000001',
    (s->>'generation')::uuid,0,s->>'digest','{"synthetic-debt":15}'::jsonb,'[]'::jsonb);
 IF wrong->>'status' IS DISTINCT FROM 'conflict' THEN RAISE EXCEPTION 'foreign owner evidence accepted'; END IF;
 b:=lab_api.read_current();
 IF b->>'owner' IS DISTINCT FROM '00000000-0000-0000-0000-000000000004' OR
    (b->>'revision')::bigint IS DISTINCT FROM 0 OR b->'values' IS DISTINCT FROM '{}'::jsonb THEN
   RAISE EXCEPTION 'foreign owner evidence changed state'; END IF;
END $$;
RESET ROLE;
-- Test-only failure after state/checkpoint UPDATE and before journal INSERT.
CREATE FUNCTION lab_private.synthetic_journal_failure() RETURNS trigger LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
 IF pg_catalog.current_setting('lab.fail_journal',true)='on' THEN
  IF NEW.outcome->>'status' IS DISTINCT FROM 'applied' OR
     (SELECT count(*) FROM lab_private.stream s JOIN lab_private.checkpoint c USING(owner_id)
       WHERE s.owner_id=NEW.owner_id AND s.revision::text=NEW.outcome->>'revision' AND
         c.revision=s.revision AND c.digest=s.digest AND s.digest=NEW.outcome->>'digest') IS DISTINCT FROM 1 THEN
   RAISE EXCEPTION 'synthetic journal failure precondition missing';
  END IF;
  RAISE EXCEPTION 'synthetic journal failure';
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER synthetic_journal_failure BEFORE INSERT ON lab_private.journal
 FOR EACH ROW EXECUTE FUNCTION lab_private.synthetic_journal_failure();
SET ROLE lab_authenticated;
SELECT pg_catalog.set_config('lab.owner','00000000-0000-0000-0000-000000000001',false);
DO $$ DECLARE before_state jsonb; after_state jsonb; BEGIN
 before_state:=lab_api.read_current();
 IF before_state->>'status' IS DISTINCT FROM 'snapshot' THEN RAISE EXCEPTION 'failure fixture not healthy'; END IF;
 PERFORM pg_catalog.set_config('lab.fail_journal','on',true);
 BEGIN
  PERFORM lab_api.apply_request('20000000-0000-0000-0000-000000000004',
   (before_state->>'generation')::uuid,(before_state->>'revision')::bigint,before_state->>'digest,
   '{"synthetic-debt":14}'::jsonb,'[]'::jsonb);
  RAISE EXCEPTION 'expected synthetic journal failure did not happen';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM IS DISTINCT FROM 'synthetic journal failure' THEN RAISE; END IF;
 END;
 PERFORM pg_catalog.set_config('lab.fail_journal','off',true);
 after_state:=lab_api.read_current();
 IF after_state IS DISTINCT FROM before_state THEN RAISE EXCEPTION 'journal failure left partial state'; END IF;
END $$;
RESET ROLE;
DROP TRIGGER synthetic_journal_failure ON lab_private.journal;
DROP FUNCTION lab_private.synthetic_journal_failure();
DO $$ BEGIN
 IF EXISTS (SELECT 1 FROM pg_catalog.pg_trigger WHERE tgname='synthetic_journal_failure' AND NOT tgisinternal) THEN
  RAISE EXCEPTION 'synthetic trigger unexpectedly remains'; END IF;
END $$;
-- A full transaction rollback must undo state, checkpoint and receipt together.
CREATE TEMP TABLE rollback_stream AS SELECT * FROM lab_private.stream WHERE owner_id='00000000-0000-0000-0000-000000000001';
CREATE TEMP TABLE rollback_checkpoint AS SELECT * FROM lab_private.checkpoint WHERE owner_id='00000000-0000-0000-0000-000000000001';
BEGIN;
SET LOCAL ROLE lab_authenticated;
SELECT pg_catalog.set_config('lab.owner','00000000-0000-0000-0000-000000000001',true);
DO $$ DECLARE s jsonb; outcome jsonb; BEGIN
 s:=lab_api.read_current();
 outcome:=lab_api.apply_request('20000000-0000-0000-0000-000000000003',
  (s->>'generation')::uuid,(s->>'revision')::bigint,s->>'digest','{"synthetic-debt":12}'::jsonb,'[]'::jsonb);
 IF outcome->>'status' IS DISTINCT FROM 'applied' THEN RAISE EXCEPTION 'rollback fixture did not apply'; END IF;
END $$;
ROLLBACK;
DO $$ DECLARE n bigint; r bigint; BEGIN
 SELECT revision INTO r FROM lab_private.stream WHERE owner_id='00000000-0000-0000-0000-000000000001';
 SELECT count(*) INTO n FROM lab_private.journal WHERE owner_id='00000000-0000-0000-0000-000000000001'
  AND request_id='20000000-0000-0000-0000-000000000003';
 IF r IS DISTINCT FROM 1 OR n IS DISTINCT FROM 0 OR
  (SELECT pg_catalog.to_jsonb(x) FROM lab_private.stream x WHERE owner_id='00000000-0000-0000-0000-000000000001')
   IS DISTINCT FROM (SELECT pg_catalog.to_jsonb(x) FROM rollback_stream x) OR
  (SELECT pg_catalog.to_jsonb(x) FROM lab_private.checkpoint x WHERE owner_id='00000000-0000-0000-0000-000000000001')
   IS DISTINCT FROM (SELECT pg_catalog.to_jsonb(x) FROM rollback_checkpoint x)
 THEN RAISE EXCEPTION 'transaction rollback left partial state'; END IF;
END $$;
-- Privileged tampering models corruption only. Each is checked via fake-auth RPC.
CREATE TEMP TABLE saved_a AS SELECT * FROM lab_private.stream WHERE owner_id='00000000-0000-0000-0000-000000000001';
UPDATE lab_private.stream SET day_values='{"synthetic-debt":20}'::jsonb
 WHERE owner_id='00000000-0000-0000-0000-000000000001';
DO $$ BEGIN IF (SELECT count(*) FROM lab_private.stream WHERE owner_id='00000000-0000-0000-0000-000000000001'
 AND day_values='{"synthetic-debt":20}'::jsonb) IS DISTINCT FROM 1 THEN RAISE EXCEPTION 'state tamper missed target'; END IF; END $$;
SET ROLE lab_authenticated;
SELECT pg_catalog.set_config('lab.owner','00000000-0000-0000-0000-000000000001',false);
DO $$ BEGIN
 IF lab_api.read_current()->>'status' IS DISTINCT FROM 'recovery_hold' THEN RAISE EXCEPTION 'corrupt state not held'; END IF;
END $$;
RESET ROLE;
UPDATE lab_private.stream s SET generation=t.generation,revision=t.revision,day_values=t.day_values,
 deleted_ids=t.deleted_ids,digest=t.digest FROM saved_a t WHERE s.owner_id=t.owner_id;
DO $$ BEGIN
 IF (SELECT pg_catalog.to_jsonb(x) FROM lab_private.stream x WHERE owner_id='00000000-0000-0000-0000-000000000001')
    IS DISTINCT FROM (SELECT pg_catalog.to_jsonb(x) FROM saved_a x) THEN
   RAISE EXCEPTION 'restored A row/digest differs from saved record'; END IF;
END $$;
SET ROLE lab_authenticated;
DO $$ DECLARE s jsonb; BEGIN
 s:=lab_api.read_current();
 IF s->>'status' IS DISTINCT FROM 'snapshot' OR (s->>'revision')::bigint IS DISTINCT FROM 1 OR
    s->'values' IS DISTINCT FROM '{"synthetic-debt":10}'::jsonb THEN
  RAISE EXCEPTION 'restored A snapshot not healthy'; END IF;
END $$;
RESET ROLE;
-- Mutating only request ID must invalidate its chain entry.
UPDATE lab_private.journal SET request_id='ffffffff-0000-0000-0000-000000000001'
 WHERE owner_id='00000000-0000-0000-0000-000000000001' AND seq=1;
DO $$ BEGIN IF (SELECT count(*) FROM lab_private.journal WHERE owner_id='00000000-0000-0000-0000-000000000001'
 AND seq=1 AND request_id='ffffffff-0000-0000-0000-000000000001') IS DISTINCT FROM 1 THEN RAISE EXCEPTION 'ID tamper missed target'; END IF; END $$;
SET ROLE lab_authenticated;
DO $$ BEGIN
 IF lab_api.read_current()->>'status' IS DISTINCT FROM 'recovery_hold' THEN RAISE EXCEPTION 'request ID alteration not held'; END IF;
END $$;
RESET ROLE;
UPDATE lab_private.journal SET request_id='20000000-0000-0000-0000-000000000001'
 WHERE owner_id='00000000-0000-0000-0000-000000000001' AND seq=1;
DO $$ BEGIN
 IF (SELECT pg_catalog.to_jsonb(x) FROM lab_private.stream x WHERE owner_id='00000000-0000-0000-0000-000000000001')
    IS DISTINCT FROM (SELECT pg_catalog.to_jsonb(x) FROM saved_a x) THEN
   RAISE EXCEPTION 'restored A row/digest differs from saved record'; END IF;
END $$;
SET ROLE lab_authenticated;
DO $$ DECLARE s jsonb; BEGIN
 s:=lab_api.read_current();
 IF s->>'status' IS DISTINCT FROM 'snapshot' OR (s->>'revision')::bigint IS DISTINCT FROM 1 OR
    s->'values' IS DISTINCT FROM '{"synthetic-debt":10}'::jsonb THEN
  RAISE EXCEPTION 'restored A snapshot not healthy'; END IF;
END $$;
RESET ROLE;
-- Coherent stream/checkpoint value modification still conflicts with journal.
CREATE TEMP TABLE saved_checkpoint AS SELECT * FROM lab_private.checkpoint
 WHERE owner_id='00000000-0000-0000-0000-000000000001';
UPDATE lab_private.stream SET day_values='{"synthetic-debt":22}'::jsonb,
 digest=lab_private.state_digest(owner_id,generation,revision,'{"synthetic-debt":22}'::jsonb,deleted_ids)
 WHERE owner_id='00000000-0000-0000-0000-000000000001';
UPDATE lab_private.checkpoint c SET digest=s.digest FROM lab_private.stream s WHERE c.owner_id=s.owner_id
 AND c.owner_id='00000000-0000-0000-0000-000000000001';
DO $$ BEGIN IF (SELECT count(*) FROM lab_private.stream s JOIN lab_private.checkpoint c USING(owner_id)
 WHERE s.owner_id='00000000-0000-0000-0000-000000000001' AND s.day_values='{"synthetic-debt":22}'::jsonb
 AND c.digest=s.digest) IS DISTINCT FROM 1 THEN RAISE EXCEPTION 'joint tamper missed target'; END IF; END $$;
SET ROLE lab_authenticated;
DO $$ BEGIN
 IF lab_api.read_current()->>'status' IS DISTINCT FROM 'recovery_hold' THEN RAISE EXCEPTION 'stream/checkpoint rewrite not held'; END IF;
END $$;
RESET ROLE;
UPDATE lab_private.stream s SET generation=t.generation,revision=t.revision,day_values=t.day_values,
 deleted_ids=t.deleted_ids,digest=t.digest FROM saved_a t WHERE s.owner_id=t.owner_id;
UPDATE lab_private.checkpoint c SET digest=t.digest FROM saved_checkpoint t WHERE c.owner_id=t.owner_id;
DO $$ BEGIN
 IF (SELECT pg_catalog.to_jsonb(x) FROM lab_private.stream x WHERE owner_id='00000000-0000-0000-0000-000000000001')
    IS DISTINCT FROM (SELECT pg_catalog.to_jsonb(x) FROM saved_a x) THEN
   RAISE EXCEPTION 'restored A row/digest differs from saved record'; END IF;
END $$;
SET ROLE lab_authenticated;
DO $$ DECLARE s jsonb; BEGIN
 s:=lab_api.read_current();
 IF s->>'status' IS DISTINCT FROM 'snapshot' OR (s->>'revision')::bigint IS DISTINCT FROM 1 OR
    s->'values' IS DISTINCT FROM '{"synthetic-debt":10}'::jsonb THEN
  RAISE EXCEPTION 'restored A snapshot not healthy'; END IF;
END $$;
RESET ROLE;
DELETE FROM lab_private.journal WHERE owner_id='00000000-0000-0000-0000-000000000001' AND seq=1;
DO $$ BEGIN IF (SELECT count(*) FROM lab_private.journal WHERE owner_id='00000000-0000-0000-0000-000000000001'
 AND seq=1) IS DISTINCT FROM 0 THEN RAISE EXCEPTION 'journal deletion missed target'; END IF; END $$;
SET ROLE lab_authenticated;
DO $$ BEGIN
 IF lab_api.read_current()->>'status' IS DISTINCT FROM 'recovery_hold' THEN RAISE EXCEPTION 'missing journal entry not held'; END IF;
END $$;
RESET ROLE;
-- Even jointly changed synthetic genesis/state/checkpoint must disagree with
-- the explicitly provisioned empty genesis. This is not real migration proof.
SET ROLE lab_authenticated;
SELECT pg_catalog.set_config('lab.owner','00000000-0000-0000-0000-000000000003',false);
DO $$ DECLARE s jsonb; BEGIN
 s:=lab_api.read_current();
 IF s->>'status' IS DISTINCT FROM 'snapshot' OR (s->>'revision')::bigint IS DISTINCT FROM 0 OR
    s->'values' IS DISTINCT FROM '{}'::jsonb THEN RAISE EXCEPTION 'genesis fixture not healthy'; END IF;
END $$;
RESET ROLE;
UPDATE lab_private.stream SET day_values='{"x":1}'::jsonb,
 digest=lab_private.state_digest(owner_id,generation,revision,'{"x":1}'::jsonb,deleted_ids)
 WHERE owner_id='00000000-0000-0000-0000-000000000003';
UPDATE lab_private.checkpoint c SET digest=s.digest,genesis_digest=s.digest FROM lab_private.stream s
 WHERE c.owner_id=s.owner_id AND c.owner_id='00000000-0000-0000-0000-000000000003';
DO $$ BEGIN IF (SELECT count(*) FROM lab_private.stream s JOIN lab_private.checkpoint c USING(owner_id)
 WHERE s.owner_id='00000000-0000-0000-0000-000000000003' AND s.day_values='{"x":1}'::jsonb AND
 s.digest=c.digest AND c.genesis_digest=s.digest) IS DISTINCT FROM 1 THEN
 RAISE EXCEPTION 'genesis tamper missed target'; END IF; END $$;
SET ROLE lab_authenticated;
SELECT pg_catalog.set_config('lab.owner','00000000-0000-0000-0000-000000000003',false);
DO $$ BEGIN
 IF lab_api.read_current()->>'status' IS DISTINCT FROM 'recovery_hold' THEN RAISE EXCEPTION 'synthetic genesis rewrite not held'; END IF;
END $$;
RESET ROLE;
\echo 'PASS: fake-auth owner routing, private grants, immutable retry, conflict, tamper holds'
