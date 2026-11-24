-- DISPOSABLE EXPERIMENT ONLY. Not a migration, not production Auth.
\set ON_ERROR_STOP on
DO $$ BEGIN
 IF current_database() <> 'owner_sync_lab' OR current_user <> 'postgres' THEN
  RAISE EXCEPTION 'refusing non-synthetic target';
 END IF;
END $$;
CREATE ROLE lab_authenticated NOLOGIN;
CREATE ROLE lab_anon NOLOGIN;
CREATE ROLE lab_rpc_owner NOLOGIN NOSUPERUSER NOBYPASSRLS;
CREATE SCHEMA lab_auth;
CREATE SCHEMA lab_private AUTHORIZATION lab_rpc_owner;
CREATE SCHEMA lab_api;
REVOKE ALL ON SCHEMA lab_private FROM PUBLIC;
GRANT USAGE ON SCHEMA lab_private, lab_api, lab_auth TO lab_authenticated;
GRANT USAGE ON SCHEMA lab_auth TO lab_rpc_owner;
CREATE FUNCTION lab_auth.fake_uid() RETURNS uuid LANGUAGE sql STABLE
SET search_path = '' AS $$
 SELECT nullif(pg_catalog.current_setting('lab.owner', true), '')::uuid
$$;
-- GUC can be caller-forged. This is NOT Supabase/JWT authentication.
REVOKE ALL ON FUNCTION lab_auth.fake_uid() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION lab_auth.fake_uid() TO lab_rpc_owner;
CREATE TABLE lab_private.stream (
 owner_id uuid PRIMARY KEY, generation uuid NOT NULL, revision bigint NOT NULL CHECK (revision >= 0),
 day_values jsonb NOT NULL, deleted_ids jsonb NOT NULL, digest text NOT NULL
);
CREATE TABLE lab_private.checkpoint (
 owner_id uuid PRIMARY KEY, generation uuid NOT NULL, revision bigint NOT NULL CHECK (revision >= 0),
 digest text NOT NULL, journal_count bigint NOT NULL CHECK (journal_count >= 0),
 journal_head text NOT NULL, genesis_digest text NOT NULL
);
CREATE TABLE lab_private.journal (
 owner_id uuid NOT NULL, request_id uuid NOT NULL, seq bigint NOT NULL CHECK (seq > 0),
 previous_hash text NOT NULL, entry_hash text NOT NULL, payload jsonb NOT NULL, outcome jsonb NOT NULL,
 PRIMARY KEY(owner_id, request_id), UNIQUE(owner_id, seq)
);
ALTER TABLE lab_private.stream OWNER TO lab_rpc_owner;
ALTER TABLE lab_private.checkpoint OWNER TO lab_rpc_owner;
ALTER TABLE lab_private.journal OWNER TO lab_rpc_owner;
REVOKE ALL ON ALL TABLES IN SCHEMA lab_private FROM PUBLIC, lab_authenticated, lab_anon;
ALTER TABLE lab_private.stream ENABLE ROW LEVEL SECURITY;
ALTER TABLE lab_private.stream FORCE ROW LEVEL SECURITY;
ALTER TABLE lab_private.checkpoint ENABLE ROW LEVEL SECURITY;
ALTER TABLE lab_private.checkpoint FORCE ROW LEVEL SECURITY;
ALTER TABLE lab_private.journal ENABLE ROW LEVEL SECURITY;
ALTER TABLE lab_private.journal FORCE ROW LEVEL SECURITY;
CREATE POLICY stream_rpc_owner ON lab_private.stream TO lab_rpc_owner USING (true) WITH CHECK (true);
CREATE POLICY checkpoint_rpc_owner ON lab_private.checkpoint TO lab_rpc_owner USING (true) WITH CHECK (true);
CREATE POLICY journal_rpc_owner ON lab_private.journal TO lab_rpc_owner USING (true) WITH CHECK (true);
CREATE FUNCTION lab_private.state_digest(p_owner uuid, p_generation uuid, p_revision bigint,
 p_values jsonb, p_deleted jsonb) RETURNS text LANGUAGE sql IMMUTABLE STRICT SET search_path = '' AS $$
 SELECT pg_catalog.encode(pg_catalog.sha256(pg_catalog.convert_to(
   pg_catalog.jsonb_build_object('schema',1,'owner',p_owner,'generation',p_generation,
      'revision',p_revision,'values',p_values,'deleted',p_deleted)::text, 'UTF8')), 'hex')
$$;
ALTER FUNCTION lab_private.state_digest(uuid,uuid,bigint,jsonb,jsonb) OWNER TO lab_rpc_owner;
REVOKE ALL ON FUNCTION lab_private.state_digest(uuid,uuid,bigint,jsonb,jsonb) FROM PUBLIC;
-- Five explicitly provisioned synthetic owners; no automatic enrollment or migration.
INSERT INTO lab_private.stream
 SELECT o, g, 0, '{}'::jsonb, '[]'::jsonb,
  lab_private.state_digest(o,g,0,'{}'::jsonb,'[]'::jsonb)
 FROM (VALUES ('00000000-0000-0000-0000-000000000001'::uuid,'10000000-0000-0000-0000-000000000001'::uuid),
              ('00000000-0000-0000-0000-000000000002'::uuid,'10000000-0000-0000-0000-000000000002'::uuid),
              ('00000000-0000-0000-0000-000000000003'::uuid,'10000000-0000-0000-0000-000000000003'::uuid),
              ('00000000-0000-0000-0000-000000000004'::uuid,'10000000-0000-0000-0000-000000000004'::uuid),
              ('00000000-0000-0000-0000-000000000005'::uuid,'10000000-0000-0000-0000-000000000005'::uuid)) AS f(o,g);
INSERT INTO lab_private.checkpoint SELECT owner_id,generation,revision,digest,0,pg_catalog.repeat('0',64),digest FROM lab_private.stream;

CREATE FUNCTION lab_private.entry_digest(p_owner uuid, p_seq bigint, p_request uuid, p_previous text,
 p_payload jsonb, p_outcome jsonb) RETURNS text LANGUAGE sql IMMUTABLE STRICT SET search_path = '' AS $$
 SELECT pg_catalog.encode(pg_catalog.sha256(pg_catalog.convert_to(
   pg_catalog.jsonb_build_object('schema',1,'owner',p_owner,'seq',p_seq,'requestId',p_request,'previous',p_previous,
      'payload',p_payload,'outcome',p_outcome)::text,'UTF8')), 'hex')
$$;
ALTER FUNCTION lab_private.entry_digest(uuid,bigint,uuid,text,jsonb,jsonb) OWNER TO lab_rpc_owner;
REVOKE ALL ON FUNCTION lab_private.entry_digest(uuid,bigint,uuid,text,jsonb,jsonb) FROM PUBLIC;
CREATE FUNCTION lab_private.valid_journal(p_owner uuid,p_generation uuid,p_revision bigint,p_digest text,
 p_count bigint,p_head text,p_genesis text) RETURNS boolean LANGUAGE plpgsql STABLE SET search_path = '' AS $$
DECLARE v_seq bigint := 0; v_head text := pg_catalog.repeat('0',64); v_entry record;
 v_revision bigint := 0; v_digest text := p_genesis; v_expected text; v_next text;
BEGIN
 -- The synthetic fixture explicitly provisions an empty version-0 genesis.
 -- Production migration/provision requires independently verified evidence.
 IF p_count < 0 OR p_head IS NULL OR p_genesis !~ '^[0-9a-f]{64}$' OR
    p_genesis IS DISTINCT FROM lab_private.state_digest(p_owner,p_generation,0,'{}'::jsonb,'[]'::jsonb) THEN
   RETURN false;
 END IF;
 FOR v_entry IN SELECT * FROM lab_private.journal WHERE owner_id=p_owner ORDER BY seq LOOP
   v_seq := v_seq + 1;
   IF v_entry.seq<>v_seq OR v_entry.previous_hash<>v_head OR
      v_entry.entry_hash<>lab_private.entry_digest(p_owner,v_seq,v_entry.request_id,v_head,v_entry.payload,v_entry.outcome) THEN
     RETURN false;
   END IF;
   v_expected := v_entry.payload->>'expected';
   IF pg_catalog.jsonb_typeof(v_entry.payload)<>'object' OR
      pg_catalog.jsonb_typeof(v_entry.outcome)<>'object' OR
      v_expected IS NULL OR v_expected !~ '^(0|[1-9][0-9]*)$' OR
      pg_catalog.length(v_expected)>19 OR v_entry.payload->>'generation' IS NULL OR
      v_entry.payload->>'digest' IS NULL OR v_entry.payload->'values' IS NULL OR
      v_entry.payload->'deleted' IS NULL OR v_entry.outcome->>'status' IS NULL OR
      v_entry.outcome->>'generation' IS NULL OR v_entry.outcome->>'revision' IS NULL OR
      v_entry.outcome->>'digest' IS NULL THEN RETURN false; END IF;
   IF v_entry.outcome->>'status' = 'applied' THEN
     IF v_entry.payload->>'generation'<>p_generation::text OR v_expected<>v_revision::text OR
        v_entry.payload->>'digest'<>v_digest OR v_revision=9223372036854775807 THEN RETURN false; END IF;
     v_next := lab_private.state_digest(p_owner,p_generation,v_revision+1,
       v_entry.payload->'values',v_entry.payload->'deleted');
     IF v_next IS NULL OR v_entry.outcome->>'generation'<>p_generation::text OR
        v_entry.outcome->>'revision'<>(v_revision+1)::text OR v_entry.outcome->>'digest'<>v_next THEN RETURN false; END IF;
     v_revision:=v_revision+1; v_digest:=v_next;
   ELSIF v_entry.outcome->>'status' = 'conflict' THEN
     IF v_entry.outcome->>'generation'<>p_generation::text OR
        v_entry.outcome->>'revision'<>v_revision::text OR v_entry.outcome->>'digest'<>v_digest OR
        (v_entry.payload->>'generation'=p_generation::text AND v_expected=v_revision::text AND
         v_entry.payload->>'digest'=v_digest) THEN RETURN false; END IF;
   ELSE RETURN false;
   END IF;
   v_head := v_entry.entry_hash;
 END LOOP;
 RETURN v_seq=p_count AND v_head=p_head AND v_revision=p_revision AND v_digest=p_digest;
END $$;
ALTER FUNCTION lab_private.valid_journal(uuid,uuid,bigint,text,bigint,text,text) OWNER TO lab_rpc_owner;
REVOKE ALL ON FUNCTION lab_private.valid_journal(uuid,uuid,bigint,text,bigint,text,text) FROM PUBLIC;

CREATE FUNCTION lab_private.read_current() RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_owner uuid := lab_auth.fake_uid(); v_row record;
BEGIN
 IF v_owner IS NULL THEN RAISE EXCEPTION 'unauthenticated' USING ERRCODE='42501'; END IF;
 SELECT s.owner_id,s.generation,s.revision,s.day_values,s.deleted_ids,s.digest,
        c.generation AS checkpoint_generation,c.revision AS checkpoint_revision,c.digest AS checkpoint_digest,
        c.journal_count,c.journal_head,c.genesis_digest
 INTO v_row FROM lab_private.stream s JOIN lab_private.checkpoint c ON c.owner_id=s.owner_id
 WHERE s.owner_id=v_owner;
 IF NOT FOUND OR v_row.generation <> v_row.checkpoint_generation OR
    v_row.revision <> v_row.checkpoint_revision OR v_row.digest <> v_row.checkpoint_digest OR
    v_row.digest <> lab_private.state_digest(v_owner,v_row.generation,v_row.revision,v_row.day_values,v_row.deleted_ids) OR
    NOT lab_private.valid_journal(v_owner,v_row.generation,v_row.revision,v_row.digest,
      v_row.journal_count,v_row.journal_head,v_row.genesis_digest) THEN
   RETURN pg_catalog.jsonb_build_object('status','recovery_hold');
 END IF;
 RETURN pg_catalog.jsonb_build_object('status','snapshot','owner',v_owner,'generation',v_row.generation,
  'revision',v_row.revision,'digest',v_row.digest,'journalCount',v_row.journal_count,
  'journalHead',v_row.journal_head,'values',v_row.day_values,'deleted',v_row.deleted_ids);
END $$;
ALTER FUNCTION lab_private.read_current() OWNER TO lab_rpc_owner;
REVOKE ALL ON FUNCTION lab_private.read_current() FROM PUBLIC, lab_anon;
GRANT EXECUTE ON FUNCTION lab_private.read_current() TO lab_authenticated;
CREATE FUNCTION lab_api.read_current() RETURNS jsonb LANGUAGE sql STABLE SECURITY INVOKER SET search_path = ''
 AS $$ SELECT lab_private.read_current() $$;
REVOKE ALL ON FUNCTION lab_api.read_current() FROM PUBLIC, lab_anon;
GRANT EXECUTE ON FUNCTION lab_api.read_current() TO lab_authenticated;

CREATE FUNCTION lab_private.apply_request(p_request uuid,p_generation uuid,p_expected bigint,p_digest text,
 p_values jsonb,p_deleted jsonb) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_owner uuid := lab_auth.fake_uid(); v_s lab_private.stream%ROWTYPE;
 v_c lab_private.checkpoint%ROWTYPE; v_prior lab_private.journal%ROWTYPE;
 v_payload jsonb; v_outcome jsonb; v_sorted jsonb; v_next_digest text; v_entry_hash text;
BEGIN
 IF v_owner IS NULL THEN RAISE EXCEPTION 'unauthenticated' USING ERRCODE='42501'; END IF;
 IF p_request IS NULL OR p_generation IS NULL OR p_expected IS NULL OR p_expected < 0 OR
    p_digest IS NULL OR p_digest !~ '^[0-9a-f]{64}$' OR
    p_values IS NULL OR pg_catalog.jsonb_typeof(p_values) <> 'object' OR
    p_deleted IS NULL OR pg_catalog.jsonb_typeof(p_deleted) <> 'array' OR
    pg_catalog.octet_length(p_values::text) > 65536 OR pg_catalog.octet_length(p_deleted::text) > 65536 THEN
   RAISE EXCEPTION 'invalid request' USING ERRCODE='22023';
 END IF;
 IF EXISTS (SELECT 1 FROM pg_catalog.jsonb_each(p_values) e WHERE e.key='' OR
   pg_catalog.jsonb_typeof(e.value)<>'number' OR e.value::text !~ '^([1-9]|[12][0-9]|3[01])$') OR
    EXISTS (SELECT 1 FROM pg_catalog.jsonb_array_elements(p_deleted) e WHERE
      pg_catalog.jsonb_typeof(e)<>'string' OR e #>> '{}'='') THEN
   RAISE EXCEPTION 'invalid payload' USING ERRCODE='22023';
 END IF;
 SELECT coalesce(pg_catalog.jsonb_agg(pg_catalog.to_jsonb(x.item) ORDER BY x.item), '[]'::jsonb)
 INTO v_sorted FROM (SELECT DISTINCT value AS item FROM pg_catalog.jsonb_array_elements_text(p_deleted)) x;
 IF v_sorted <> p_deleted OR EXISTS (SELECT 1 FROM pg_catalog.jsonb_array_elements_text(p_deleted) x WHERE p_values ? x.value) THEN
   RAISE EXCEPTION 'noncanonical deletion' USING ERRCODE='22023';
 END IF;
 SELECT * INTO v_s FROM lab_private.stream WHERE owner_id=v_owner FOR UPDATE;
 IF NOT FOUND THEN RETURN pg_catalog.jsonb_build_object('status','recovery_hold'); END IF;
 SELECT * INTO v_c FROM lab_private.checkpoint WHERE owner_id=v_owner FOR UPDATE;
 IF NOT FOUND OR v_s.generation<>v_c.generation OR v_s.revision<>v_c.revision OR v_s.digest<>v_c.digest OR
    v_s.digest<>lab_private.state_digest(v_owner,v_s.generation,v_s.revision,v_s.day_values,v_s.deleted_ids) OR
    NOT lab_private.valid_journal(v_owner,v_s.generation,v_s.revision,v_s.digest,
      v_c.journal_count,v_c.journal_head,v_c.genesis_digest) THEN
   RETURN pg_catalog.jsonb_build_object('status','recovery_hold');
 END IF;
 v_payload := pg_catalog.jsonb_build_object('generation',p_generation,'expected',p_expected,'digest',p_digest,
   'values',p_values,'deleted',p_deleted);
 SELECT * INTO v_prior FROM lab_private.journal WHERE owner_id=v_owner AND request_id=p_request;
 IF FOUND THEN
   IF v_prior.payload<>v_payload THEN RAISE EXCEPTION 'request reuse mismatch' USING ERRCODE='22023'; END IF;
   RETURN pg_catalog.jsonb_build_object('status','historical_receipt','outcome',v_prior.outcome);
 END IF;
 IF p_generation<>v_s.generation OR p_expected<>v_s.revision OR p_digest<>v_s.digest THEN
   v_outcome := pg_catalog.jsonb_build_object('status','conflict','generation',v_s.generation,
      'revision',v_s.revision,'digest',v_s.digest);
 ELSE
   IF v_s.revision=9223372036854775807 THEN RETURN pg_catalog.jsonb_build_object('status','recovery_hold'); END IF;
   v_next_digest := lab_private.state_digest(v_owner,v_s.generation,v_s.revision+1,p_values,p_deleted);
   UPDATE lab_private.stream SET revision=v_s.revision+1,day_values=p_values,deleted_ids=p_deleted,digest=v_next_digest
     WHERE owner_id=v_owner;
   UPDATE lab_private.checkpoint SET revision=v_s.revision+1,digest=v_next_digest WHERE owner_id=v_owner;
   v_outcome := pg_catalog.jsonb_build_object('status','applied','generation',v_s.generation,
      'revision',v_s.revision+1,'digest',v_next_digest);
 END IF;
 IF v_c.journal_count=9223372036854775807 THEN
   RAISE EXCEPTION 'journal capacity exceeded' USING ERRCODE='54000';
 END IF;
 v_entry_hash := lab_private.entry_digest(v_owner,v_c.journal_count+1,p_request,v_c.journal_head,v_payload,v_outcome);
 INSERT INTO lab_private.journal(owner_id,request_id,seq,previous_hash,entry_hash,payload,outcome)
  VALUES(v_owner,p_request,v_c.journal_count+1,v_c.journal_head,v_entry_hash,v_payload,v_outcome);
 UPDATE lab_private.checkpoint SET journal_count=v_c.journal_count+1,journal_head=v_entry_hash WHERE owner_id=v_owner;
 RETURN v_outcome;
END $$;
ALTER FUNCTION lab_private.apply_request(uuid,uuid,bigint,text,jsonb,jsonb) OWNER TO lab_rpc_owner;
REVOKE ALL ON FUNCTION lab_private.apply_request(uuid,uuid,bigint,text,jsonb,jsonb) FROM PUBLIC, lab_anon;
GRANT EXECUTE ON FUNCTION lab_private.apply_request(uuid,uuid,bigint,text,jsonb,jsonb) TO lab_authenticated;
CREATE FUNCTION lab_api.apply_request(p_request uuid,p_generation uuid,p_expected bigint,p_digest text,
 p_values jsonb,p_deleted jsonb) RETURNS jsonb LANGUAGE sql SECURITY INVOKER SET search_path = '' AS $$
 SELECT lab_private.apply_request(p_request,p_generation,p_expected,p_digest,p_values,p_deleted)
$$;
REVOKE ALL ON FUNCTION lab_api.apply_request(uuid,uuid,bigint,text,jsonb,jsonb) FROM PUBLIC, lab_anon;
GRANT EXECUTE ON FUNCTION lab_api.apply_request(uuid,uuid,bigint,text,jsonb,jsonb) TO lab_authenticated;

-- Read-only synthetic comparison with an independently *assumed* prior anchor.
-- The caller-provided tuple has NO authenticity or monotonicity guarantee here.
-- All reads use the calling statement snapshot (STABLE). Not a migration.
CREATE FUNCTION lab_private.read_checked_v1(p_owner uuid,p_generation uuid,p_revision bigint,p_digest text,
 p_count bigint,p_head text) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_owner uuid := lab_auth.fake_uid(); v_current jsonb; v_head text; v_genesis text;
 v_anchor_revision bigint; v_anchor_digest text; v_last record; v_test record;
BEGIN
 IF v_owner IS NULL THEN RAISE EXCEPTION 'unauthenticated' USING ERRCODE='42501'; END IF;
 IF p_owner IS NULL OR p_owner<>v_owner OR p_generation IS NULL OR p_revision IS NULL OR p_revision<0 OR
    p_digest IS NULL OR p_digest !~ '^[0-9a-f]{64}$' OR p_count IS NULL OR p_count<0 OR
    p_head IS NULL OR p_head !~ '^[0-9a-f]{64}$' THEN
  RETURN pg_catalog.jsonb_build_object('status','recovery_hold');
 END IF;
 v_current:=lab_private.read_current();
 -- TEST ONLY: deterministic barrier for concurrent-commit snapshot testing.
 -- Never include this GUC/sleep in a production function.
 IF pg_catalog.current_setting('lab.synthetic_read_sleep',true)='on' THEN
  PERFORM pg_catalog.pg_sleep(10);
  SELECT s.generation,s.revision,s.digest,c.journal_count,c.journal_head INTO v_test
   FROM lab_private.stream s JOIN lab_private.checkpoint c ON c.owner_id=s.owner_id WHERE s.owner_id=v_owner;
  IF NOT FOUND OR v_test.generation::text IS DISTINCT FROM v_current->>'generation' OR
     v_test.revision::text IS DISTINCT FROM v_current->>'revision' OR
     v_test.digest IS DISTINCT FROM v_current->>'digest' OR
     v_test.journal_count::text IS DISTINCT FROM v_current->>'journalCount' OR
     v_test.journal_head IS DISTINCT FROM v_current->>'journalHead' THEN
   RAISE EXCEPTION 'synthetic post-barrier read used inconsistent snapshot';
  END IF;
 END IF;
 IF v_current->>'status' IS DISTINCT FROM 'snapshot' OR
    v_current->>'owner' IS DISTINCT FROM v_owner::text OR
    v_current->>'generation' IS DISTINCT FROM p_generation::text OR
    (v_current->>'revision')::bigint < p_revision OR (v_current->>'journalCount')::bigint < p_count THEN
  RETURN pg_catalog.jsonb_build_object('status','recovery_hold');
 END IF;
 SELECT genesis_digest INTO v_genesis FROM lab_private.checkpoint WHERE owner_id=v_owner;
 IF NOT FOUND THEN RETURN pg_catalog.jsonb_build_object('status','recovery_hold'); END IF;
 IF p_count=0 THEN
  v_head:=pg_catalog.repeat('0',64);
 ELSE
  SELECT entry_hash INTO v_head FROM lab_private.journal WHERE owner_id=v_owner AND seq=p_count;
  IF NOT FOUND THEN RETURN pg_catalog.jsonb_build_object('status','recovery_hold'); END IF;
 END IF;
 IF v_head IS DISTINCT FROM p_head THEN RETURN pg_catalog.jsonb_build_object('status','recovery_hold'); END IF;
 SELECT outcome INTO v_last FROM lab_private.journal WHERE owner_id=v_owner AND seq<=p_count
   AND outcome->>'status'='applied' ORDER BY seq DESC LIMIT 1;
 IF FOUND THEN
  v_anchor_revision:=(v_last.outcome->>'revision')::bigint;
  v_anchor_digest:=v_last.outcome->>'digest';
 ELSE
  v_anchor_revision:=0; v_anchor_digest:=v_genesis;
 END IF;
 IF v_anchor_revision IS DISTINCT FROM p_revision OR v_anchor_digest IS DISTINCT FROM p_digest THEN
  RETURN pg_catalog.jsonb_build_object('status','recovery_hold');
 END IF;
 RETURN v_current || pg_catalog.jsonb_build_object('anchorProtocol',1,'anchorComparison','matched');
END $$;
ALTER FUNCTION lab_private.read_checked_v1(uuid,uuid,bigint,text,bigint,text) OWNER TO lab_rpc_owner;
REVOKE ALL ON FUNCTION lab_private.read_checked_v1(uuid,uuid,bigint,text,bigint,text) FROM PUBLIC, lab_anon;
GRANT EXECUTE ON FUNCTION lab_private.read_checked_v1(uuid,uuid,bigint,text,bigint,text) TO lab_authenticated;
CREATE FUNCTION lab_api.read_checked_v1(p_owner uuid,p_generation uuid,p_revision bigint,p_digest text,
 p_count bigint,p_head text) RETURNS jsonb LANGUAGE sql STABLE SECURITY INVOKER SET search_path = '' AS $$
 SELECT lab_private.read_checked_v1(p_owner,p_generation,p_revision,p_digest,p_count,p_head)
$$;
REVOKE ALL ON FUNCTION lab_api.read_checked_v1(uuid,uuid,bigint,text,bigint,text) FROM PUBLIC, lab_anon;
GRANT EXECUTE ON FUNCTION lab_api.read_checked_v1(uuid,uuid,bigint,text,bigint,text) TO lab_authenticated;
