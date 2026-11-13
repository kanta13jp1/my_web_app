-- Fake authenticated owner plus externally assumed synthetic anchors only.
\set ON_ERROR_STOP on
DO $$ BEGIN
 IF current_database() IS DISTINCT FROM 'owner_sync_lab' OR current_user IS DISTINCT FROM 'postgres' THEN
  RAISE EXCEPTION 'wrong synthetic target'; END IF;
END $$;
CREATE TEMP TABLE old_stream AS SELECT * FROM lab_private.stream WHERE owner_id='00000000-0000-0000-0000-000000000005';
CREATE TEMP TABLE old_checkpoint AS SELECT * FROM lab_private.checkpoint WHERE owner_id='00000000-0000-0000-0000-000000000005';
CREATE TEMP TABLE synthetic_anchors(name text PRIMARY KEY, snapshot jsonb NOT NULL);
GRANT SELECT,INSERT ON synthetic_anchors TO lab_authenticated;
SET ROLE lab_authenticated;
SELECT pg_catalog.set_config('lab.owner','00000000-0000-0000-0000-000000000005',false);
INSERT INTO synthetic_anchors SELECT 'zero',lab_api.read_current();
DO $$ DECLARE s jsonb; response jsonb; BEGIN
 SELECT snapshot INTO STRICT s FROM synthetic_anchors WHERE name='zero';
 IF s->>'status' IS DISTINCT FROM 'snapshot' OR (s->>'revision')::bigint IS DISTINCT FROM 0 THEN
  RAISE EXCEPTION 'synthetic initial snapshot invalid'; END IF;
 response:=lab_api.read_checked_v1(NULL,NULL,NULL,NULL,NULL,NULL);
 IF response->>'status' IS DISTINCT FROM 'recovery_hold' THEN RAISE EXCEPTION 'missing anchor not held'; END IF;
END $$;
SELECT lab_api.apply_request('50000000-0000-0000-0000-000000000001',
 (snapshot->>'generation')::uuid,0,snapshot->>'digest','{"synthetic":10}'::jsonb,'[]'::jsonb)
 FROM synthetic_anchors WHERE name='zero';
INSERT INTO synthetic_anchors SELECT 'one',lab_api.read_current();
DO $$ DECLARE s jsonb; BEGIN
 SELECT snapshot INTO STRICT s FROM synthetic_anchors WHERE name='one';
 IF (s->>'revision')::bigint IS DISTINCT FROM 1 OR (s->>'journalCount')::bigint IS DISTINCT FROM 1 THEN
  RAISE EXCEPTION 'first apply not recorded'; END IF;
END $$;
-- Conflict adds a receipt without advancing state revision.
SELECT lab_api.apply_request('50000000-0000-0000-0000-000000000002',
 (snapshot->>'generation')::uuid,0,snapshot->>'digest','{"synthetic":11}'::jsonb,'[]'::jsonb)
 FROM synthetic_anchors WHERE name='zero';
INSERT INTO synthetic_anchors SELECT 'after-conflict',lab_api.read_current();
DO $$ DECLARE a jsonb; c jsonb; r jsonb; BEGIN
 SELECT snapshot INTO STRICT a FROM synthetic_anchors WHERE name='one';
 SELECT snapshot INTO STRICT c FROM synthetic_anchors WHERE name='after-conflict';
 IF (c->>'revision')::bigint IS DISTINCT FROM 1 OR (c->>'journalCount')::bigint IS DISTINCT FROM 2 THEN
  RAISE EXCEPTION 'conflict did not preserve state and advance journal'; END IF;
 r:=lab_api.read_checked_v1((a->>'owner')::uuid,(a->>'generation')::uuid,(a->>'revision')::bigint,
    a->>'digest',(a->>'journalCount')::bigint,a->>'journalHead');
 IF r->>'status' IS DISTINCT FROM 'snapshot' OR (r->>'journalCount')::bigint IS DISTINCT FROM 2 THEN
  RAISE EXCEPTION 'valid same-revision prefix rejected'; END IF;
 r:=lab_api.read_checked_v1((a->>'owner')::uuid,(a->>'generation')::uuid,(a->>'revision')::bigint,
    a->>'digest',2,a->>'journalHead');
 IF r->>'status' IS DISTINCT FROM 'recovery_hold' THEN RAISE EXCEPTION 'mixed count/head accepted'; END IF;
END $$;
SELECT lab_api.apply_request('50000000-0000-0000-0000-000000000003',
 (snapshot->>'generation')::uuid,(snapshot->>'revision')::bigint,snapshot->>'digest',
 '{"synthetic":12}'::jsonb,'[]'::jsonb) FROM synthetic_anchors WHERE name='after-conflict';
INSERT INTO synthetic_anchors SELECT 'two',lab_api.read_current();
DO $$ DECLARE a jsonb; c jsonb; z jsonb; r jsonb; BEGIN
 SELECT snapshot INTO STRICT a FROM synthetic_anchors WHERE name='one';
 SELECT snapshot INTO STRICT c FROM synthetic_anchors WHERE name='two';
 SELECT snapshot INTO STRICT z FROM synthetic_anchors WHERE name='zero';
 IF (c->>'revision')::bigint IS DISTINCT FROM 2 OR (c->>'journalCount')::bigint IS DISTINCT FROM 3 THEN
  RAISE EXCEPTION 'second apply not recorded'; END IF;
 r:=lab_api.read_checked_v1((a->>'owner')::uuid,(a->>'generation')::uuid,1,a->>'digest',1,a->>'journalHead');
 IF r->>'status' IS DISTINCT FROM 'snapshot' OR (r->>'revision')::bigint IS DISTINCT FROM 2 THEN
  RAISE EXCEPTION 'valid older applied prefix rejected'; END IF;
 r:=lab_api.read_checked_v1('00000000-0000-0000-0000-000000000001',(a->>'generation')::uuid,1,a->>'digest',1,a->>'journalHead');
 IF r->>'status' IS DISTINCT FROM 'recovery_hold' THEN RAISE EXCEPTION 'foreign owner anchor accepted'; END IF;
 r:=lab_api.read_checked_v1((a->>'owner')::uuid,'ffffffff-ffff-ffff-ffff-ffffffffffff',1,a->>'digest',1,a->>'journalHead');
 IF r->>'status' IS DISTINCT FROM 'recovery_hold' THEN RAISE EXCEPTION 'foreign generation anchor accepted'; END IF;
 r:=lab_api.read_checked_v1((a->>'owner')::uuid,(a->>'generation')::uuid,1,pg_catalog.repeat('0',64),1,a->>'journalHead');
 IF r->>'status' IS DISTINCT FROM 'recovery_hold' THEN RAISE EXCEPTION 'wrong state digest accepted'; END IF;
 r:=lab_api.read_checked_v1((a->>'owner')::uuid,(a->>'generation')::uuid,0,z->>'digest',1,a->>'journalHead');
 IF r->>'status' IS DISTINCT FROM 'recovery_hold' THEN RAISE EXCEPTION 'wrong revision at prefix accepted'; END IF;
END $$;
RESET ROLE;
-- Restore all server rows coherently while preserving the separate test anchor.
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
  RAISE EXCEPTION 'coherent rollback fixture mismatch'; END IF;
END $$;
COMMIT;
SET ROLE lab_authenticated;
DO $$ DECLARE a jsonb; z jsonb; current jsonb; r jsonb; BEGIN
 SELECT snapshot INTO STRICT a FROM synthetic_anchors WHERE name='one';
 SELECT snapshot INTO STRICT z FROM synthetic_anchors WHERE name='zero';
 current:=lab_api.read_current();
 IF current->>'status' IS DISTINCT FROM 'snapshot' THEN RAISE EXCEPTION 'rollback setup unexpectedly held'; END IF;
 r:=lab_api.read_checked_v1((a->>'owner')::uuid,(a->>'generation')::uuid,1,a->>'digest',1,a->>'journalHead');
 IF r->>'status' IS DISTINCT FROM 'recovery_hold' THEN RAISE EXCEPTION 'known newer anchor failed to detect rollback'; END IF;
 -- Negative control: an equally rolled-back/untrusted client anchor cannot prove latestness.
 r:=lab_api.read_checked_v1((z->>'owner')::uuid,(z->>'generation')::uuid,0,z->>'digest',0,z->>'journalHead');
 IF r->>'status' IS DISTINCT FROM 'snapshot' THEN RAISE EXCEPTION 'negative-control baseline unexpected'; END IF;
END $$;
RESET ROLE;
\echo 'PASS: prior synthetic anchor detects server rollback; stale anchor cannot establish latestness'
