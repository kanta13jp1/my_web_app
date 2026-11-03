-- Disposable protocol semantics. Fake GUC is not real authentication.
\set ON_ERROR_STOP on
DO $$ BEGIN
  IF current_database() <> 'owner_sync_lab' OR current_user <> 'postgres' THEN
    RAISE EXCEPTION 'wrong synthetic database or role';
  END IF;
  IF has_function_privilege('lab_anon', 'lab_sync.apply_days(uuid,bigint,jsonb,jsonb)', 'EXECUTE') OR
     NOT has_function_privilege('lab_authenticated', 'lab_sync.apply_days(uuid,bigint,jsonb,jsonb)', 'EXECUTE') THEN
    RAISE EXCEPTION 'synthetic function grant mismatch';
  END IF;
  IF has_table_privilege('lab_authenticated', 'lab_sync.payment_state', 'SELECT') OR
     has_table_privilege('lab_authenticated', 'lab_sync.request_journal', 'INSERT') THEN
    RAISE EXCEPTION 'synthetic direct table grant unexpectedly present';
  END IF;
END $$;
SET ROLE lab_authenticated;
SELECT set_config('lab.owner', '00000000-0000-0000-0000-000000000001', false);
DO $$
DECLARE result jsonb; same_result jsonb;
BEGIN
  BEGIN
    PERFORM count(*) FROM lab_sync.payment_state;
    RAISE EXCEPTION 'synthetic direct table read allowed';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  result := lab_sync.apply_days('10000000-0000-0000-0000-000000000001', 0, '{"x":10}', '["y"]');
  IF result <> '{"status":"applied","revision":1}'::jsonb THEN
    RAISE EXCEPTION 'unexpected first outcome %', result;
  END IF;
  same_result := lab_sync.apply_days('10000000-0000-0000-0000-000000000001', 0, '{"x":10}', '["y"]');
  IF same_result <> result THEN RAISE EXCEPTION 'identical retry changed result'; END IF;
  BEGIN
    PERFORM lab_sync.apply_days('10000000-0000-0000-0000-000000000001', 0, '{"x":11}', '["y"]');
    RAISE EXCEPTION 'same request ID accepted different payload';
  EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
  result := lab_sync.apply_days('10000000-0000-0000-0000-000000000002', 0, '{"x":9}', '[]');
  IF result <> '{"status":"conflict","revision":1}'::jsonb THEN
    RAISE EXCEPTION 'stale request not conflicted: %', result;
  END IF;
  result := lab_sync.apply_days('10000000-0000-0000-0000-000000000003', 1, '{"x":11}', '[]');
  IF result <> '{"status":"applied","revision":2}'::jsonb THEN
    RAISE EXCEPTION 'subsequent request not applied: %', result;
  END IF;
  result := lab_sync.apply_days('10000000-0000-0000-0000-000000000002', 0, '{"x":9}', '[]');
  IF result <> '{"status":"conflict","revision":1}'::jsonb THEN
    RAISE EXCEPTION 'recorded conflict not stable: %', result;
  END IF;
  BEGIN
    PERFORM lab_sync.apply_days('10000000-0000-0000-0000-000000000004', 2, '{"x":10}', '["x"]');
    RAISE EXCEPTION 'overlapping values and deletes accepted';
  EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
END $$;
-- Failure during journal INSERT must roll back the preceding state UPDATE.
SELECT set_config('lab.fail_journal', 'on', false);
DO $$ BEGIN
  BEGIN
    PERFORM lab_sync.apply_days('10000000-0000-0000-0000-000000000005', 2, '{"x":12}', '[]');
    RAISE EXCEPTION 'synthetic failure trigger did not fire';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM <> 'synthetic journal failure' THEN RAISE; END IF;
  END;
END $$;
SELECT set_config('lab.fail_journal', 'off', false);
-- Same UUID under another owner is a different journal namespace in this model.
SELECT set_config('lab.owner', '00000000-0000-0000-0000-000000000002', false);
DO $$
DECLARE result jsonb;
BEGIN
  result := lab_sync.apply_days('10000000-0000-0000-0000-000000000001', 0, '{"z":20}', '[]');
  IF result <> '{"status":"applied","revision":1}'::jsonb THEN
    RAISE EXCEPTION 'synthetic owner B outcome %', result;
  END IF;
END $$;
SELECT set_config('lab.owner', '00000000-0000-0000-0000-000000000003', false);
DO $$ BEGIN
  BEGIN
    PERFORM lab_sync.apply_days('10000000-0000-0000-0000-000000000006', 0, '{}', '[]');
    RAISE EXCEPTION 'unprovisioned synthetic owner accepted';
  EXCEPTION WHEN object_not_in_prerequisite_state THEN NULL; END;
END $$;
RESET ROLE;
DO $$
DECLARE a lab_sync.payment_state%ROWTYPE; b lab_sync.payment_state%ROWTYPE; n integer;
BEGIN
  SELECT * INTO STRICT a FROM lab_sync.payment_state WHERE owner_id='00000000-0000-0000-0000-000000000001';
  SELECT * INTO STRICT b FROM lab_sync.payment_state WHERE owner_id='00000000-0000-0000-0000-000000000002';
  IF a.revision <> 2 OR a.day_values <> '{"x":11}'::jsonb OR a.deleted_ids <> '[]'::jsonb THEN
    RAISE EXCEPTION 'synthetic owner A state mismatch or rollback failed';
  END IF;
  IF b.revision <> 1 OR b.day_values <> '{"z":20}'::jsonb THEN
    RAISE EXCEPTION 'synthetic owner B state mismatch';
  END IF;
  SELECT count(*) INTO n FROM lab_sync.request_journal
    WHERE owner_id='00000000-0000-0000-0000-000000000001';
  IF n <> 3 THEN RAISE EXCEPTION 'unexpected journal count %', n; END IF;
  IF EXISTS (SELECT 1 FROM lab_sync.request_journal
      WHERE request_id='10000000-0000-0000-0000-000000000005') THEN
    RAISE EXCEPTION 'failed request left a receipt';
  END IF;
END $$;
SET ROLE lab_anon;
DO $$ BEGIN
  BEGIN
    PERFORM lab_sync.apply_days('10000000-0000-0000-0000-000000000007', 0, '{}', '[]');
    RAISE EXCEPTION 'synthetic anonymous RPC allowed';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;
