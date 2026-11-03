\set ON_ERROR_STOP on
-- This file is a SQL-semantics experiment against the disposable fixture only.
DO $$
DECLARE p text;
BEGIN
  IF current_database() <> 'owner_sync_lab' OR current_user <> 'postgres' THEN
    RAISE EXCEPTION 'wrong synthetic database or role';
  END IF;
  FOREACH p IN ARRAY ARRAY['SELECT','INSERT','UPDATE','DELETE'] LOOP
    IF NOT has_table_privilege('lab_authenticated', 'lab_policy.asset_pref_mirror', p)
       OR NOT has_table_privilege('lab_authenticated', 'lab_upsert.asset_pref_mirror', p)
       OR NOT has_table_privilege('lab_authenticated', 'lab_row.asset_pref_mirror', p) THEN
      RAISE EXCEPTION 'missing synthetic table privilege: %', p;
    END IF;
  END LOOP;
END $$;
SET ROLE lab_authenticated;
SELECT set_config('lab.owner', '00000000-0000-0000-0000-000000000001', false);
DO $$
DECLARE k text; n integer;
BEGIN
  SELECT count(*) INTO n FROM lab_policy.asset_pref_mirror;
  IF n <> 3 THEN RAISE EXCEPTION 'owner read isolation expected 3, got %', n; END IF;
  UPDATE lab_policy.asset_pref_mirror SET value = '{"cross":true}'
    WHERE user_id = '00000000-0000-0000-0000-000000000002' AND pref_key = 'other';
  GET DIAGNOSTICS n = ROW_COUNT;
  IF n <> 0 THEN RAISE EXCEPTION 'cross-owner UPDATE allowed'; END IF;
  FOREACH k IN ARRAY ARRAY['debt_payment_day_overrides','debt_payment_day_override_deleted'] LOOP
    UPDATE lab_policy.asset_pref_mirror SET value = '{"edit":true}'
      WHERE user_id = '00000000-0000-0000-0000-000000000001' AND pref_key = k;
    GET DIAGNOSTICS n = ROW_COUNT;
    IF n <> 0 THEN RAISE EXCEPTION 'protected UPDATE allowed: %', k; END IF;
    UPDATE lab_policy.asset_pref_mirror SET pref_key = 'rekeyed'
      WHERE user_id = '00000000-0000-0000-0000-000000000001' AND pref_key = k;
    GET DIAGNOSTICS n = ROW_COUNT;
    IF n <> 0 THEN RAISE EXCEPTION 'protected to non-target UPDATE allowed: %', k; END IF;
    DELETE FROM lab_policy.asset_pref_mirror
      WHERE user_id = '00000000-0000-0000-0000-000000000001' AND pref_key = k;
    GET DIAGNOSTICS n = ROW_COUNT;
    IF n <> 0 THEN RAISE EXCEPTION 'protected DELETE allowed: %', k; END IF;
    BEGIN
      INSERT INTO lab_policy.asset_pref_mirror VALUES
        ('00000000-0000-0000-0000-000000000001', k, '{"edit":true}')
      ON CONFLICT (user_id, pref_key) DO UPDATE SET value = EXCLUDED.value;
      RAISE EXCEPTION 'existing protected UPSERT allowed: %', k;
    EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  END LOOP;
  UPDATE lab_policy.asset_pref_mirror SET value = '{"ok":1}'
    WHERE user_id = '00000000-0000-0000-0000-000000000001' AND pref_key = 'other';
  GET DIAGNOSTICS n = ROW_COUNT;
  IF n <> 1 THEN RAISE EXCEPTION 'unrelated UPDATE blocked'; END IF;
  INSERT INTO lab_policy.asset_pref_mirror VALUES
    ('00000000-0000-0000-0000-000000000001', 'other', '{"ok":2}')
  ON CONFLICT (user_id, pref_key) DO UPDATE SET value = EXCLUDED.value;
  BEGIN
    UPDATE lab_policy.asset_pref_mirror
      SET user_id = '00000000-0000-0000-0000-000000000002'
      WHERE user_id = '00000000-0000-0000-0000-000000000001' AND pref_key = 'other';
    RAISE EXCEPTION 'owner reassignment allowed';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  DELETE FROM lab_policy.asset_pref_mirror
    WHERE user_id = '00000000-0000-0000-0000-000000000001' AND pref_key = 'other';
  GET DIAGNOSTICS n = ROW_COUNT;
  IF n <> 1 THEN RAISE EXCEPTION 'unrelated DELETE blocked'; END IF;
  INSERT INTO lab_policy.asset_pref_mirror VALUES
    ('00000000-0000-0000-0000-000000000001', 'other', '{}');
END $$;
-- A new synthetic owner has no protected rows, exercising INSERT/upsert insert paths
-- and UPDATE from a non-target key to each not-yet-existing protected key.
SELECT set_config('lab.owner', '00000000-0000-0000-0000-000000000003', false);
DO $$
DECLARE k text;
BEGIN
  FOREACH k IN ARRAY ARRAY['debt_payment_day_overrides','debt_payment_day_override_deleted'] LOOP
    BEGIN
      INSERT INTO lab_policy.asset_pref_mirror VALUES
        ('00000000-0000-0000-0000-000000000003', k, '{}');
      RAISE EXCEPTION 'protected INSERT allowed: %', k;
    EXCEPTION WHEN insufficient_privilege THEN NULL; END;
    BEGIN
      INSERT INTO lab_policy.asset_pref_mirror VALUES
        ('00000000-0000-0000-0000-000000000003', k, '{}')
      ON CONFLICT (user_id, pref_key) DO UPDATE SET value = EXCLUDED.value;
      RAISE EXCEPTION 'new protected UPSERT allowed: %', k;
    EXCEPTION WHEN insufficient_privilege THEN NULL; END;
    INSERT INTO lab_policy.asset_pref_mirror VALUES
      ('00000000-0000-0000-0000-000000000003', 'movable', '{}');
    BEGIN
      UPDATE lab_policy.asset_pref_mirror SET pref_key = k
        WHERE user_id = '00000000-0000-0000-0000-000000000003' AND pref_key = 'movable';
      RAISE EXCEPTION 'non-target to protected UPDATE allowed: %', k;
    EXCEPTION WHEN insufficient_privilege THEN NULL; END;
    DELETE FROM lab_policy.asset_pref_mirror
      WHERE user_id = '00000000-0000-0000-0000-000000000003' AND pref_key = 'movable';
  END LOOP;
END $$;
RESET ROLE;
-- Isolate conflict UPDATE branch: INSERT is allowed here, but protected UPDATE is denied.
SET ROLE lab_authenticated;
SELECT set_config('lab.owner', '00000000-0000-0000-0000-000000000001', false);
DO $$
DECLARE k text;
BEGIN
  FOREACH k IN ARRAY ARRAY['debt_payment_day_overrides','debt_payment_day_override_deleted'] LOOP
    BEGIN
      INSERT INTO lab_upsert.asset_pref_mirror VALUES
        ('00000000-0000-0000-0000-000000000001', k, '{"edit":true}')
      ON CONFLICT (user_id, pref_key) DO UPDATE SET value = EXCLUDED.value;
      RAISE EXCEPTION 'conflict UPDATE branch allowed: %', k;
    EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  END LOOP;
END $$;
RESET ROLE;
-- No table rights were granted to the fake anon role.
SET ROLE lab_anon;
DO $$ BEGIN
  BEGIN
    PERFORM count(*) FROM lab_policy.asset_pref_mirror;
    RAISE EXCEPTION 'anonymous SELECT unexpectedly allowed';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;
-- A protected DML update must hit the synthetic row trigger.
SET ROLE lab_authenticated;
SELECT set_config('lab.owner', '00000000-0000-0000-0000-000000000001', false);
DO $$ BEGIN
  BEGIN
    UPDATE lab_row.asset_pref_mirror SET value = '{"edit":true}'
      WHERE user_id = '00000000-0000-0000-0000-000000000001'
        AND pref_key = 'debt_payment_day_overrides';
    RAISE EXCEPTION 'protected row trigger failed to fire';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM <> 'synthetic protected row' THEN RAISE; END IF;
  END;
END $$;
RESET ROLE;
-- A row trigger is not a TRUNCATE trigger and RLS does not govern TRUNCATE.
DO $$ BEGIN
  IF NOT has_table_privilege('lab_authenticated', 'lab_row.asset_pref_mirror', 'TRUNCATE') THEN
    RAISE EXCEPTION 'fixture lacks synthetic TRUNCATE privilege';
  END IF;
END $$;
BEGIN;
SET LOCAL ROLE lab_authenticated;
TRUNCATE lab_row.asset_pref_mirror;
RESET ROLE;
DO $$ BEGIN
  IF (SELECT count(*) FROM lab_row.asset_pref_mirror) <> 0 THEN
    RAISE EXCEPTION 'expected synthetic TRUNCATE to remove all rows';
  END IF;
END $$;
ROLLBACK;
DO $$ BEGIN
  IF (SELECT count(*) FROM lab_row.asset_pref_mirror) <> 5 THEN
    RAISE EXCEPTION 'synthetic TRUNCATE rollback failed';
  END IF;
END $$;
REVOKE TRUNCATE ON lab_row.asset_pref_mirror FROM lab_authenticated;
DO $$ BEGIN
  IF has_table_privilege('lab_authenticated', 'lab_row.asset_pref_mirror', 'TRUNCATE') THEN
    RAISE EXCEPTION 'synthetic TRUNCATE still effective';
  END IF;
END $$;
SET ROLE lab_authenticated;
DO $$ BEGIN
  BEGIN
    TRUNCATE lab_row.asset_pref_mirror;
    RAISE EXCEPTION 'synthetic TRUNCATE allowed after revoke';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;
