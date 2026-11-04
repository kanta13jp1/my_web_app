-- SYNTHETIC TEST ONLY. Never run against a live or shared database.
-- No real JWT, external service, real user, or actual financial data.
\set ON_ERROR_STOP on
DO $guard$
BEGIN
  IF pg_catalog.current_database() <> 'salary_identity_isolated'
     OR pg_catalog.current_setting('salary_test.isolated', true) IS DISTINCT FROM 'disposable-pg17-only'
     OR pg_catalog.current_setting('server_version_num')::integer < 170000
     OR pg_catalog.current_setting('server_version_num')::integer >= 180000
     OR pg_catalog.current_setting('session_replication_role') <> 'origin'
     OR (pg_catalog.inet_server_addr() IS NOT NULL AND
         pg_catalog.inet_server_addr() NOT IN ('127.0.0.1'::inet, '::1'::inet))
     OR pg_catalog.to_regclass('public.asset_balance_accounts') IS NULL
     OR pg_catalog.to_regclass('public.cfo_assets') IS NULL
     OR auth.jwt() ->> 'role' IS DISTINCT FROM 'service_role' THEN
    RAISE EXCEPTION 'unsafe or unexpected synthetic deletion fixture';
  END IF;
END
$guard$;
DO $probe_freshness$
BEGIN
  IF (SELECT is_called FROM public.deletion_probe_audit_seq)
     OR NOT EXISTS (
       SELECT 1 FROM pg_catalog.pg_trigger
       WHERE tgrelid = 'public.deletion_rollback_probe'::regclass
         AND tgname = 'fixture_probe_after_delete' AND NOT tgisinternal
         AND tgenabled IN ('O', 'A') AND tgtype = 9
         AND tgfoid = 'public.fixture_probe_after_delete()'::regprocedure
     ) THEN
    RAISE EXCEPTION 'probe sequence not fresh or trigger not correctly bound';
  END IF;
END
$probe_freshness$;

BEGIN;
INSERT INTO auth.users (id) VALUES
 ('11111111-1111-4111-8111-111111111111'),
 ('22222222-2222-4222-8222-222222222222');
INSERT INTO public.asset_balance_accounts (id, user_id, display_name) VALUES
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1','11111111-1111-4111-8111-111111111111','synthetic A'),
 ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1','22222222-2222-4222-8222-222222222222','synthetic B');
INSERT INTO public.cfo_assets (user_id, title, amount, balance_account_id) VALUES
 ('11111111-1111-4111-8111-111111111111','synthetic A',1,'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1'),
 ('22222222-2222-4222-8222-222222222222','synthetic B',2,'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1');

-- A: with no adapter, a populated NO ACTION account is classified as blocking.
DO $no_adapter$
DECLARE v record;
BEGIN
  SELECT * INTO v FROM public.account_deletion_dependency_inventory('11111111-1111-4111-8111-111111111111')
    WHERE table_name = 'asset_balance_accounts' AND column_name = 'user_id';
  IF NOT FOUND OR v.deletion_strategy IS DISTINCT FROM 'no_action_blocked'
     OR v.matching_rows IS DISTINCT FROM 1::bigint OR v.is_blocking IS DISTINCT FROM true THEN
    RAISE EXCEPTION 'expected account NO ACTION blocker not classified';
  END IF;
END
$no_adapter$;

-- B: both owner columns are reviewed direct-delete adapters. The inventory
-- sorts account before cfo, so FK should block pass one and allow pass two.
SAVEPOINT direct_case;
INSERT INTO public.account_deletion_direct_delete_adapters (table_name)
VALUES ('asset_balance_accounts'), ('cfo_assets');
DO $direct_case$
DECLARE n bigint;
BEGIN
  n := public.delete_account_deletion_direct_rows('11111111-1111-4111-8111-111111111111');
  IF n IS DISTINCT FROM 2::bigint THEN RAISE EXCEPTION 'unexpected direct deleted count: %', n; END IF;
  IF EXISTS (SELECT 1 FROM public.asset_balance_accounts WHERE user_id = '11111111-1111-4111-8111-111111111111')
     OR EXISTS (SELECT 1 FROM public.cfo_assets WHERE user_id = '11111111-1111-4111-8111-111111111111')
     OR NOT EXISTS (SELECT 1 FROM public.asset_balance_accounts WHERE user_id = '22222222-2222-4222-8222-222222222222')
     OR NOT EXISTS (SELECT 1 FROM public.cfo_assets WHERE user_id = '22222222-2222-4222-8222-222222222222') THEN
    RAISE EXCEPTION 'direct deletion or other-owner isolation failed';
  END IF;
END
$direct_case$;
ROLLBACK TO SAVEPOINT direct_case;

-- C: auth cascade on cfo is not executed until later auth deletion. Parent
-- direct deletion should remain blocked; another deleted fixture row must be
-- rolled back when the SECURITY DEFINER function raises 23503.
SAVEPOINT cascade_case;
ALTER TABLE public.cfo_assets DROP CONSTRAINT synthetic_cfo_owner_fk;
ALTER TABLE public.cfo_assets ADD CONSTRAINT synthetic_cfo_owner_fk
  FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
INSERT INTO public.account_deletion_direct_delete_adapters (table_name)
VALUES ('asset_balance_accounts'), ('deletion_rollback_probe');
INSERT INTO public.deletion_rollback_probe (id, user_id) VALUES
 (1,'11111111-1111-4111-8111-111111111111'),
 (2,'22222222-2222-4222-8222-222222222222');
DO $cascade_case$
DECLARE a record; c record; got_expected boolean := false;
BEGIN
  SELECT * INTO a FROM public.account_deletion_dependency_inventory('11111111-1111-4111-8111-111111111111')
    WHERE table_name = 'asset_balance_accounts' AND column_name = 'user_id';
  SELECT * INTO c FROM public.account_deletion_dependency_inventory('11111111-1111-4111-8111-111111111111')
    WHERE table_name = 'cfo_assets' AND column_name = 'user_id';
  IF a.deletion_strategy IS DISTINCT FROM 'delete_direct' OR a.is_blocking IS DISTINCT FROM false
     OR c.deletion_strategy IS DISTINCT FROM 'cascade' OR c.is_blocking IS DISTINCT FROM false THEN
    RAISE EXCEPTION 'unexpected cascade/direct inventory classification';
  END IF;
  BEGIN
    PERFORM public.delete_account_deletion_direct_rows('11111111-1111-4111-8111-111111111111');
  EXCEPTION WHEN foreign_key_violation THEN
    IF SQLERRM <> 'account_deletion_direct_delete_blocked' THEN RAISE; END IF;
    got_expected := true;
  END;
  IF NOT got_expected THEN RAISE EXCEPTION 'cascade-dependent parent unexpectedly deleted'; END IF;
  IF NOT (SELECT is_called FROM public.deletion_probe_audit_seq) THEN
    RAISE EXCEPTION 'probe deletion was not observed before exception rollback';
  END IF;
  IF (SELECT count(*) FROM public.deletion_rollback_probe) <> 2
     OR (SELECT count(*) FROM public.asset_balance_accounts) <> 2
     OR (SELECT count(*) FROM public.cfo_assets) <> 2
     OR NOT EXISTS (SELECT 1 FROM public.deletion_rollback_probe WHERE id=1 AND user_id='11111111-1111-4111-8111-111111111111')
     OR NOT EXISTS (SELECT 1 FROM public.deletion_rollback_probe WHERE id=2 AND user_id='22222222-2222-4222-8222-222222222222') THEN
    RAISE EXCEPTION 'failed call leaked partial deletion or changed another owner';
  END IF;
END
$cascade_case$;
ROLLBACK TO SAVEPOINT cascade_case;

-- Full transaction rollback proves test rows/adapters do not persist in these
-- fixture tables. It does not remove schemas, functions or the test cluster.
ROLLBACK;
DO $post_rollback$
BEGIN
  IF EXISTS (SELECT 1 FROM auth.users)
     OR EXISTS (SELECT 1 FROM public.asset_balance_accounts)
     OR EXISTS (SELECT 1 FROM public.cfo_assets)
     OR EXISTS (SELECT 1 FROM public.deletion_rollback_probe)
     OR EXISTS (SELECT 1 FROM public.account_deletion_direct_delete_adapters) THEN
    RAISE EXCEPTION 'synthetic test rows survived outer rollback';
  END IF;
END
$post_rollback$;
\echo 'synthetic deletion contract assertions passed; disposable cluster remains'
