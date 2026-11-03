-- Tests are synthetic and do not assert real auth, service-role or actual migration.
\set ON_ERROR_STOP on
DO $$ BEGIN IF current_database() <> 'owner_sync_lab' OR current_user <> 'postgres' THEN RAISE EXCEPTION 'wrong synthetic database'; END IF; END $$;
DO $$ BEGIN
 IF EXISTS (SELECT 1 FROM unnest(ARRAY['SELECT','INSERT','UPDATE','DELETE']) AS p(priv) WHERE NOT has_table_privilege('authenticated','public.asset_pref_mirror',p.priv)) THEN
  RAISE EXCEPTION 'fixture missing baseline DML grants'; END IF;
END $$;
SET ROLE authenticated;
SELECT set_config('lab.owner','00000000-0000-0000-0000-000000000001',false);
DO $$ DECLARE n integer; BEGIN
 BEGIN
  INSERT INTO public.asset_pref_mirror VALUES ('00000000-0000-0000-0000-000000000001','debt_payment_day_overrides','{}');
  RAISE EXCEPTION 'protected insert accepted';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN
  INSERT INTO public.asset_pref_mirror VALUES ('00000000-0000-0000-0000-000000000001','debt_payment_day_override_deleted','{}')
   ON CONFLICT (user_id,pref_key) DO UPDATE SET value=excluded.value;
  RAISE EXCEPTION 'protected upsert accepted';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 UPDATE public.asset_pref_mirror SET value='{}' WHERE pref_key='debt_payment_day_overrides';
 GET DIAGNOSTICS n=ROW_COUNT; IF n<>0 THEN RAISE EXCEPTION 'protected update changed % rows',n; END IF;
 DELETE FROM public.asset_pref_mirror WHERE pref_key='debt_payment_day_override_deleted';
 GET DIAGNOSTICS n=ROW_COUNT; IF n<>0 THEN RAISE EXCEPTION 'protected delete changed % rows',n; END IF;
 BEGIN
  UPDATE public.asset_pref_mirror SET pref_key='debt_payment_day_overrides' WHERE pref_key='other';
  RAISE EXCEPTION 'rename into protected key accepted';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 UPDATE public.asset_pref_mirror SET pref_key='other2' WHERE pref_key='debt_payment_day_overrides';
 GET DIAGNOSTICS n=ROW_COUNT; IF n<>0 THEN RAISE EXCEPTION 'rename out changed % rows',n; END IF;
 INSERT INTO public.asset_pref_mirror VALUES ('00000000-0000-0000-0000-000000000001','control','{}');
 INSERT INTO public.asset_pref_mirror VALUES ('00000000-0000-0000-0000-000000000001','control','{"updated":true}')
   ON CONFLICT (user_id,pref_key) DO UPDATE SET value=excluded.value;
 DELETE FROM public.asset_pref_mirror WHERE pref_key='control';
 GET DIAGNOSTICS n=ROW_COUNT; IF n<>1 THEN RAISE EXCEPTION 'unrelated delete affected'; END IF;
 UPDATE public.asset_pref_mirror SET value='{"ok":true}' WHERE pref_key='other';
 GET DIAGNOSTICS n=ROW_COUNT; IF n<>1 THEN RAISE EXCEPTION 'unrelated key affected'; END IF;
END $$;
SELECT set_config('lab.owner','00000000-0000-0000-0000-000000000003',false);
DO $$ DECLARE k text; n integer; BEGIN
 INSERT INTO public.asset_pref_mirror VALUES ('00000000-0000-0000-0000-000000000003','control','{}');
 SELECT count(*) INTO n FROM public.asset_pref_mirror WHERE user_id='00000000-0000-0000-0000-000000000003' AND pref_key='control';
 IF n<>1 THEN RAISE EXCEPTION 'owner 003 control read failed'; END IF;
 DELETE FROM public.asset_pref_mirror WHERE user_id='00000000-0000-0000-0000-000000000003' AND pref_key='control';
 GET DIAGNOSTICS n=ROW_COUNT; IF n<>1 THEN RAISE EXCEPTION 'owner 003 control delete failed'; END IF;
 FOREACH k IN ARRAY ARRAY['debt_payment_day_overrides','debt_payment_day_override_deleted'] LOOP
  BEGIN
   INSERT INTO public.asset_pref_mirror VALUES ('00000000-0000-0000-0000-000000000003',k,'{}');
   RAISE EXCEPTION 'new protected insert accepted';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 END LOOP;
END $$;
RESET ROLE;
DO $$ BEGIN
 IF NOT EXISTS (SELECT 1 FROM public.asset_pref_mirror WHERE user_id='00000000-0000-0000-0000-000000000001' AND pref_key='debt_payment_day_overrides' AND value='{"x":11}'::jsonb) OR
 NOT EXISTS (SELECT 1 FROM public.asset_pref_mirror WHERE user_id='00000000-0000-0000-0000-000000000001' AND pref_key='debt_payment_day_override_deleted' AND value='{"ids":["y"]}'::jsonb) THEN
  RAISE EXCEPTION 'protected state changed'; END IF;
END $$;
