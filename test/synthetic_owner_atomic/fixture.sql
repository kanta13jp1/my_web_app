-- Disposable protocol experiment only. NOT A MIGRATION. The fake owner GUC
-- is caller-controlled and is NOT real Supabase authentication.
\set ON_ERROR_STOP on
DO $$ BEGIN
  IF current_database() <> 'owner_sync_lab' OR current_user <> 'postgres' THEN
    RAISE EXCEPTION 'wrong synthetic database or role';
  END IF;
END $$;
CREATE ROLE lab_authenticated NOLOGIN;
CREATE ROLE lab_anon NOLOGIN;
CREATE ROLE lab_api_owner NOLOGIN;
CREATE SCHEMA lab_sync;
ALTER SCHEMA lab_sync OWNER TO lab_api_owner;
GRANT USAGE ON SCHEMA lab_sync TO lab_authenticated, lab_anon, lab_api_owner;
CREATE FUNCTION lab_sync.fake_uid() RETURNS uuid LANGUAGE sql STABLE AS
  $$ SELECT nullif(current_setting('lab.owner', true), '')::uuid $$;
CREATE TABLE lab_sync.payment_state (
  owner_id uuid PRIMARY KEY, revision bigint NOT NULL CHECK (revision >= 0),
  day_values jsonb NOT NULL, deleted_ids jsonb NOT NULL
);
CREATE TABLE lab_sync.request_journal (
  owner_id uuid NOT NULL REFERENCES lab_sync.payment_state(owner_id),
  request_id uuid NOT NULL, payload jsonb NOT NULL, outcome jsonb NOT NULL,
  PRIMARY KEY (owner_id, request_id)
);
ALTER TABLE lab_sync.payment_state ENABLE ROW LEVEL SECURITY;
ALTER TABLE lab_sync.request_journal ENABLE ROW LEVEL SECURITY;
ALTER TABLE lab_sync.payment_state OWNER TO lab_api_owner;
ALTER TABLE lab_sync.request_journal OWNER TO lab_api_owner;
INSERT INTO lab_sync.payment_state VALUES
 ('00000000-0000-0000-0000-000000000001', 0, '{}', '[]'),
 ('00000000-0000-0000-0000-000000000002', 0, '{}', '[]'),
 ('00000000-0000-0000-0000-000000000004', 0, '{}', '[]');
-- A deliberately test-only failure injection trigger. Never ship this.
CREATE FUNCTION lab_sync.fail_journal_for_test() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF current_setting('lab.fail_journal', true) = 'on' THEN
    RAISE EXCEPTION 'synthetic journal failure';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER fail_journal_for_test BEFORE INSERT ON lab_sync.request_journal
  FOR EACH ROW EXECUTE FUNCTION lab_sync.fail_journal_for_test();

CREATE FUNCTION lab_sync.apply_days(
  p_request_id uuid, p_expected bigint, p_values jsonb, p_deleted jsonb
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, lab_sync AS $$
DECLARE
  v_owner uuid := lab_sync.fake_uid();
  v_revision bigint;
  v_prior lab_sync.request_journal%ROWTYPE;
  v_payload jsonb;
  v_outcome jsonb;
  v_sorted jsonb;
BEGIN
  IF v_owner IS NULL OR p_request_id IS NULL OR p_expected IS NULL OR p_expected < 0 THEN
    RAISE EXCEPTION 'invalid synthetic identity or request' USING ERRCODE='22023';
  END IF;
  IF p_values IS NULL OR jsonb_typeof(p_values) <> 'object' OR
     p_deleted IS NULL OR jsonb_typeof(p_deleted) <> 'array' THEN
    RAISE EXCEPTION 'invalid synthetic payload types' USING ERRCODE='22023';
  END IF;
  IF EXISTS (SELECT 1 FROM jsonb_each(p_values) e
      WHERE e.key = '' OR jsonb_typeof(e.value) <> 'number'
        OR e.value::text !~ '^([1-9]|[12][0-9]|3[01])$') THEN
    RAISE EXCEPTION 'invalid synthetic day value' USING ERRCODE='22023';
  END IF;
  IF EXISTS (SELECT 1 FROM jsonb_array_elements(p_deleted) e
      WHERE jsonb_typeof(e) <> 'string' OR e #>> '{}' = '') THEN
    RAISE EXCEPTION 'invalid synthetic deletion' USING ERRCODE='22023';
  END IF;
  SELECT coalesce(jsonb_agg(to_jsonb(x.item) ORDER BY x.item), '[]'::jsonb)
  INTO v_sorted FROM (SELECT DISTINCT value AS item FROM jsonb_array_elements_text(p_deleted)) x;
  IF v_sorted <> p_deleted OR EXISTS (
      SELECT 1 FROM jsonb_array_elements_text(p_deleted) x WHERE p_values ? x.value
  ) THEN
    RAISE EXCEPTION 'noncanonical or overlapping synthetic deletion' USING ERRCODE='22023';
  END IF;
  v_payload := jsonb_build_object('expected', p_expected, 'values', p_values, 'deleted', p_deleted);
  SELECT revision INTO v_revision FROM lab_sync.payment_state
    WHERE owner_id = v_owner FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'synthetic owner not provisioned' USING ERRCODE='55000';
  END IF;
  SELECT * INTO v_prior FROM lab_sync.request_journal
    WHERE owner_id = v_owner AND request_id = p_request_id;
  IF FOUND THEN
    IF v_prior.payload <> v_payload THEN
      RAISE EXCEPTION 'request ID payload mismatch' USING ERRCODE='22023';
    END IF;
    RETURN v_prior.outcome;
  END IF;
  IF v_revision <> p_expected THEN
    v_outcome := jsonb_build_object('status','conflict','revision',v_revision);
  ELSE
    UPDATE lab_sync.payment_state SET revision = revision + 1,
      day_values = p_values, deleted_ids = p_deleted WHERE owner_id = v_owner;
    v_outcome := jsonb_build_object('status','applied','revision',v_revision + 1);
  END IF;
  INSERT INTO lab_sync.request_journal VALUES (v_owner,p_request_id,v_payload,v_outcome);
  RETURN v_outcome;
END $$;
ALTER FUNCTION lab_sync.apply_days(uuid,bigint,jsonb,jsonb) OWNER TO lab_api_owner;
REVOKE ALL ON FUNCTION lab_sync.apply_days(uuid,bigint,jsonb,jsonb) FROM PUBLIC, lab_anon;
GRANT EXECUTE ON FUNCTION lab_sync.apply_days(uuid,bigint,jsonb,jsonb) TO lab_authenticated;
