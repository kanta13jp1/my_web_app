\set ON_ERROR_STOP on
DO $$ BEGIN
  IF current_database() <> 'owner_sync_lab' OR current_user <> 'postgres' THEN
    RAISE EXCEPTION 'wrong synthetic database or role';
  END IF;
END $$;
-- Only disposable synthetic tables/roles are affected, within this service.
BEGIN;
SET LOCAL ROLE lab_authenticated;
TRUNCATE lab_row.asset_pref_mirror;
RESET ROLE;
ROLLBACK;
BEGIN;
SET LOCAL ROLE lab_anon;
TRUNCATE lab_upsert.asset_pref_mirror;
RESET ROLE;
ROLLBACK;
DO $$ BEGIN
  IF (SELECT count(*) FROM lab_row.asset_pref_mirror) <> 5 OR
     (SELECT count(*) FROM lab_upsert.asset_pref_mirror) <> 5 THEN
    RAISE EXCEPTION 'synthetic rollback failed';
  END IF;
END $$;
REVOKE TRUNCATE ON lab_row.asset_pref_mirror FROM lab_inherited;
REVOKE TRUNCATE ON lab_upsert.asset_pref_mirror FROM PUBLIC;
DO $$ BEGIN
  IF has_table_privilege('lab_authenticated', 'lab_row.asset_pref_mirror', 'TRUNCATE') OR
     has_table_privilege('lab_anon', 'lab_upsert.asset_pref_mirror', 'TRUNCATE') THEN
    RAISE EXCEPTION 'synthetic effective privilege remains';
  END IF;
  IF NOT has_table_privilege('lab_service', 'lab_row.asset_pref_mirror', 'TRUNCATE') THEN
    RAISE EXCEPTION 'synthetic service-like grant changed';
  END IF;
END $$;
SET ROLE lab_authenticated;
DO $$ BEGIN
  BEGIN
    TRUNCATE lab_row.asset_pref_mirror;
    RAISE EXCEPTION 'truncate unexpectedly allowed after inherited revoke';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;
SET ROLE lab_anon;
DO $$ BEGIN
  BEGIN
    TRUNCATE lab_upsert.asset_pref_mirror;
    RAISE EXCEPTION 'truncate unexpectedly allowed after PUBLIC revoke';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;
