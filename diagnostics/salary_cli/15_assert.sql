-- Synthetic post-CLI assertions. Run only on the guarded fresh service.
\set ON_ERROR_STOP on
BEGIN READ ONLY;
SELECT pg_catalog.set_config('salary_test.case_profile', :'case_profile', true);
DO $check$
DECLARE mode text := current_setting('salary_test.case_profile');
        col_count integer;
BEGIN
  IF current_database() <> 'salary_identity_isolated'
     OR current_setting('salary_test.isolated', true) IS DISTINCT FROM 'disposable-pg17-only'
     OR current_setting('server_version_num')::integer NOT BETWEEN 170000 AND 179999
     OR current_setting('session_replication_role') <> 'origin'
     OR inet_server_addr() IS DISTINCT FROM '127.0.0.1'::inet
     OR inet_client_addr() IS DISTINCT FROM '127.0.0.1'::inet
     OR mode NOT IN ('test', 'analyze') THEN
    RAISE EXCEPTION 'unsafe post-CLI assertion environment';
  END IF;
  IF (SELECT count(*) FROM public.cfo_assets) <> 2
     OR NOT EXISTS (SELECT 1 FROM public.cfo_assets WHERE user_id='11111111-1111-4111-8111-111111111111'::uuid AND title='legacy-a' AND amount=100 AND created_at='2026-10-31T00:00:00Z'::timestamptz)
     OR NOT EXISTS (SELECT 1 FROM public.cfo_assets WHERE user_id='22222222-2222-4222-8222-222222222222'::uuid AND title='legacy-b' AND amount=200 AND created_at IS NULL) THEN
    RAISE EXCEPTION 'synthetic legacy rows changed';
  END IF;
  SELECT count(*) INTO col_count FROM pg_attribute
    WHERE attrelid='public.cfo_assets'::regclass AND attnum>0 AND NOT attisdropped
      AND attname IN ('balance_account_id','observed_at','observation_source');
  IF mode='test' THEN
    IF to_regclass('public.asset_balance_accounts') IS NOT NULL OR col_count <> 0
       OR EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid='public.cfo_assets'::regclass
           AND conname IN ('cfo_assets_owner_account_fk','cfo_assets_observation_source_check'))
       OR EXISTS (SELECT 1 FROM supabase_migrations.schema_migrations WHERE version='20261104000001') THEN
      RAISE EXCEPTION 'failed migration left candidate schema or history';
    END IF;
  ELSE
    IF to_regclass('public.asset_balance_accounts') IS NULL OR col_count <> 3
       OR NOT EXISTS (SELECT 1 FROM supabase_migrations.schema_migrations WHERE version='20261104000001') THEN
      RAISE EXCEPTION 'successful migration missing schema or history';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid='public.asset_balance_accounts'::regclass
        AND confrelid='auth.users'::regclass AND contype='f' AND confdeltype='c')
       OR NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid='public.cfo_assets'::regclass
        AND conname='cfo_assets_owner_account_fk' AND contype='f' AND confdeltype='a' AND NOT convalidated
        AND confrelid='public.asset_balance_accounts'::regclass)
       OR NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid='public.cfo_assets'::regclass
        AND conname='cfo_assets_observation_source_check' AND contype='c' AND NOT convalidated)
       OR NOT (SELECT relrowsecurity FROM pg_class WHERE oid='public.asset_balance_accounts'::regclass)
       OR (SELECT count(*) FROM pg_policies WHERE schemaname='public' AND tablename='asset_balance_accounts') <> 4
       OR NOT has_table_privilege('authenticated','public.asset_balance_accounts','SELECT')
       OR NOT has_table_privilege('authenticated','public.asset_balance_accounts','INSERT')
       OR NOT has_table_privilege('authenticated','public.asset_balance_accounts','UPDATE')
       OR NOT has_table_privilege('authenticated','public.asset_balance_accounts','DELETE') THEN
      RAISE EXCEPTION 'successful migration candidate structure mismatch';
    END IF;
    IF EXISTS (SELECT 1 FROM public.cfo_assets WHERE balance_account_id IS NOT NULL OR observed_at IS NOT NULL OR observation_source IS NOT NULL) THEN
      RAISE EXCEPTION 'legacy metadata unexpectedly populated';
    END IF;
  END IF;
END
$check$;
ROLLBACK;
\echo 'candidate14 guarded post-CLI assertions passed'
