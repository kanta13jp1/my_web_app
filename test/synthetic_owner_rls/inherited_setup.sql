\set ON_ERROR_STOP on
DO $$ BEGIN
  IF current_database() <> 'owner_sync_lab' OR current_user <> 'postgres' THEN
    RAISE EXCEPTION 'wrong synthetic database or role';
  END IF;
END $$;
CREATE ROLE lab_inherited NOLOGIN;
CREATE ROLE lab_service NOLOGIN;
GRANT lab_inherited TO lab_authenticated;
GRANT TRUNCATE ON lab_row.asset_pref_mirror TO lab_inherited;
GRANT TRUNCATE ON lab_row.asset_pref_mirror TO lab_service;
GRANT TRUNCATE ON lab_upsert.asset_pref_mirror TO PUBLIC;
REVOKE TRUNCATE ON lab_row.asset_pref_mirror FROM lab_authenticated;
REVOKE TRUNCATE ON lab_upsert.asset_pref_mirror FROM lab_authenticated;
