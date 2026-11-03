\set ON_ERROR_STOP on
\set VERBOSITY verbose
DO $$ BEGIN
  IF current_database() <> 'owner_sync_lab' OR current_user <> 'postgres' THEN
    RAISE EXCEPTION 'wrong synthetic database or role';
  END IF;
END $$;
DO $$
DECLARE inherited_allowed boolean; public_allowed boolean;
BEGIN
  inherited_allowed := has_table_privilege('lab_authenticated', 'lab_row.asset_pref_mirror', 'TRUNCATE');
  public_allowed := has_table_privilege('lab_anon', 'lab_upsert.asset_pref_mirror', 'TRUNCATE');
  IF inherited_allowed OR public_allowed THEN
    RAISE EXCEPTION 'EXPECTED RED: direct revoke insufficient; inherited=%, public=%',
      inherited_allowed, public_allowed USING ERRCODE='P0001';
  END IF;
END $$;
