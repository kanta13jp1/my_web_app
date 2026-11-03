\set ON_ERROR_STOP on
\set VERBOSITY verbose
DO $$ BEGIN
  IF current_database() <> 'owner_sync_lab' OR current_user <> 'postgres' THEN
    RAISE EXCEPTION 'wrong synthetic database or role';
  END IF;
END $$;
SET ROLE lab_authenticated;
SELECT set_config('lab.owner', '00000000-0000-0000-0000-000000000001', false);
DO $$
DECLARE update_count integer; cross_read integer; cross_update integer;
BEGIN
  UPDATE lab_red.asset_pref_mirror SET value = '{"x":11}'
    WHERE user_id = '00000000-0000-0000-0000-000000000001'
      AND pref_key = 'debt_payment_day_overrides';
  GET DIAGNOSTICS update_count = ROW_COUNT;
  SELECT count(*) INTO cross_read FROM lab_red.asset_pref_mirror
    WHERE user_id = '00000000-0000-0000-0000-000000000002' AND pref_key = 'other';
  UPDATE lab_red.asset_pref_mirror SET value = '{"cross":true}'
    WHERE user_id = '00000000-0000-0000-0000-000000000002' AND pref_key = 'other';
  GET DIAGNOSTICS cross_update = ROW_COUNT;
  IF update_count <> 0 OR cross_read <> 0 OR cross_update <> 0 THEN
    RAISE EXCEPTION 'EXPECTED RED: permissive policies OR; protected_update=%, cross_read=%, cross_update=%',
      update_count, cross_read, cross_update USING ERRCODE = 'P0001';
  END IF;
END $$;
