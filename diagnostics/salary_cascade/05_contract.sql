-- SYNTHETIC TEST ONLY. Never run against a live or shared database.
-- Assertions use fake service-role JWT and synthetic rows, not live Auth/RLS.
\set ON_ERROR_STOP on
DO $guard$
BEGIN
  IF pg_catalog.current_database() <> 'salary_identity_isolated'
     OR pg_catalog.current_setting('salary_test.isolated', true) IS DISTINCT FROM 'disposable-pg17-only'
     OR pg_catalog.current_setting('server_version_num')::integer < 170000
     OR pg_catalog.current_setting('server_version_num')::integer >= 180000
     OR (pg_catalog.inet_server_addr() IS NOT NULL AND
         pg_catalog.inet_server_addr() NOT IN ('127.0.0.1'::inet, '::1'::inet))
     OR pg_catalog.to_regclass('public.cfo_assets') IS NULL
     OR pg_catalog.to_regclass('public.asset_balance_accounts') IS NOT NULL
     OR auth.jwt() ->> 'role' IS DISTINCT FROM 'service_role' THEN
    RAISE EXCEPTION 'unsafe or unexpected synthetic cascade setup';
  END IF;
END
$guard$;

BEGIN;
INSERT INTO auth.users (id) VALUES
 ('11111111-1111-4111-8111-111111111111'),
 ('22222222-2222-4222-8222-222222222222');
-- A legacy row predates the exact migration and must remain unknown.
INSERT INTO public.cfo_assets (user_id, title, amount, created_at)
VALUES ('11111111-1111-4111-8111-111111111111','synthetic old A',1,NULL);

-- Apply the exact 14 bytes within this outer transaction. No CLI is invoked.
\ir 14_expand_identity_auth_cascade_DRAFT.sql

INSERT INTO public.asset_balance_accounts (id,user_id,display_name) VALUES
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1','11111111-1111-4111-8111-111111111111','synthetic A'),
 ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1','22222222-2222-4222-8222-222222222222','synthetic B');
INSERT INTO public.cfo_assets (user_id,title,amount,balance_account_id) VALUES
 ('11111111-1111-4111-8111-111111111111','synthetic linked A',2,'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1'),
 ('22222222-2222-4222-8222-222222222222','synthetic linked B',3,'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1');

-- Real candidate preserves legacy NULL metadata, rejects cross-owner linkage,
-- and protects a referenced parent from individual deletion via NO ACTION.
DO $baseline$
DECLARE got_fk boolean;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.cfo_assets WHERE title='synthetic old A'
                 AND balance_account_id IS NULL AND observed_at IS NULL
                 AND observation_source IS NULL AND created_at IS NULL) THEN
    RAISE EXCEPTION 'legacy unknown metadata changed';
  END IF;
  got_fk := false;
  BEGIN
    INSERT INTO public.cfo_assets (user_id,title,amount,balance_account_id)
    VALUES ('11111111-1111-4111-8111-111111111111','cross-owner',4,'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1');
  EXCEPTION WHEN foreign_key_violation THEN got_fk := true;
  END;
  IF NOT got_fk THEN RAISE EXCEPTION 'cross-owner FK unexpectedly accepted'; END IF;
  got_fk := false;
  BEGIN
    DELETE FROM public.asset_balance_accounts WHERE id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1';
  EXCEPTION WHEN foreign_key_violation THEN got_fk := true;
  END;
  IF NOT got_fk OR NOT EXISTS (SELECT 1 FROM public.asset_balance_accounts
                               WHERE id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1')
     OR NOT EXISTS (SELECT 1 FROM public.cfo_assets WHERE title='synthetic linked A') THEN
    RAISE EXCEPTION 'referenced account was not protected';
  END IF;
END
$baseline$;

-- Additional test-only fake-role RLS case; see 04 and its limitations.
\ir 04_rls.sql

-- Case A: both cfo -> auth and new account -> auth CASCADE. Actual behavior
-- of the separate cfo -> account NO ACTION constraint is what we test here.
SAVEPOINT both_cascade;
ALTER TABLE public.cfo_assets DROP CONSTRAINT synthetic_cfo_owner_fk;
ALTER TABLE public.cfo_assets ADD CONSTRAINT synthetic_cfo_owner_fk
  FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
DO $both_cascade$
DECLARE a record; c record;
BEGIN
  SELECT * INTO a FROM public.account_deletion_dependency_inventory('11111111-1111-4111-8111-111111111111')
   WHERE table_name='asset_balance_accounts' AND column_name='user_id';
  SELECT * INTO c FROM public.account_deletion_dependency_inventory('11111111-1111-4111-8111-111111111111')
   WHERE table_name='cfo_assets' AND column_name='user_id';
  IF a.deletion_strategy IS DISTINCT FROM 'cascade' OR a.is_blocking IS DISTINCT FROM false
     OR c.deletion_strategy IS DISTINCT FROM 'cascade' OR c.is_blocking IS DISTINCT FROM false THEN
    RAISE EXCEPTION 'unexpected both-cascade inventory';
  END IF;
  DELETE FROM auth.users WHERE id='11111111-1111-4111-8111-111111111111';
  IF EXISTS (SELECT 1 FROM public.asset_balance_accounts WHERE user_id='11111111-1111-4111-8111-111111111111')
     OR EXISTS (SELECT 1 FROM public.cfo_assets WHERE user_id='11111111-1111-4111-8111-111111111111')
     OR NOT EXISTS (SELECT 1 FROM auth.users WHERE id='22222222-2222-4222-8222-222222222222')
     OR NOT EXISTS (SELECT 1 FROM public.asset_balance_accounts WHERE user_id='22222222-2222-4222-8222-222222222222')
     OR NOT EXISTS (SELECT 1 FROM public.cfo_assets WHERE user_id='22222222-2222-4222-8222-222222222222') THEN
    RAISE EXCEPTION 'both-cascade deletion or B preservation failed';
  END IF;
END
$both_cascade$;
ROLLBACK TO SAVEPOINT both_cascade;

-- Case B: cfo -> auth NO ACTION, no adapter. Inventory must fail closed.
SAVEPOINT no_adapter;
DO $no_adapter$
DECLARE c record; got_fk boolean := false;
BEGIN
  SELECT * INTO c FROM public.account_deletion_dependency_inventory('11111111-1111-4111-8111-111111111111')
   WHERE table_name='cfo_assets' AND column_name='user_id';
  IF c.deletion_strategy IS DISTINCT FROM 'no_action_blocked'
     OR c.matching_rows IS DISTINCT FROM 2::bigint OR c.is_blocking IS DISTINCT FROM true THEN
    RAISE EXCEPTION 'missing cfo NO ACTION blocker';
  END IF;
  BEGIN
    DELETE FROM auth.users WHERE id='11111111-1111-4111-8111-111111111111';
  EXCEPTION WHEN foreign_key_violation THEN got_fk := true;
  END;
  IF NOT got_fk OR (SELECT count(*) FROM auth.users) <> 2
     OR (SELECT count(*) FROM public.asset_balance_accounts) <> 2
     OR (SELECT count(*) FROM public.cfo_assets) <> 3 THEN
    RAISE EXCEPTION 'failed auth delete was not atomic';
  END IF;
END
$no_adapter$;
ROLLBACK TO SAVEPOINT no_adapter;

-- Case C: cfo NO ACTION with a reviewed adapter. Delete cfo A before auth A;
-- cascade then removes the new account, preserving all B rows.
SAVEPOINT with_adapter;
INSERT INTO public.account_deletion_direct_delete_adapters(table_name) VALUES ('cfo_assets');
DO $with_adapter$
DECLARE c record; n bigint;
BEGIN
  SELECT * INTO c FROM public.account_deletion_dependency_inventory('11111111-1111-4111-8111-111111111111')
   WHERE table_name='cfo_assets' AND column_name='user_id';
  IF c.deletion_strategy IS DISTINCT FROM 'delete_direct' OR c.is_blocking IS DISTINCT FROM false THEN
    RAISE EXCEPTION 'cfo adapter classification failed';
  END IF;
  n := public.delete_account_deletion_direct_rows('11111111-1111-4111-8111-111111111111');
  IF n IS DISTINCT FROM 2::bigint THEN RAISE EXCEPTION 'unexpected direct cfo count: %', n; END IF;
  DELETE FROM auth.users WHERE id='11111111-1111-4111-8111-111111111111';
  IF EXISTS (SELECT 1 FROM public.asset_balance_accounts WHERE user_id='11111111-1111-4111-8111-111111111111')
     OR EXISTS (SELECT 1 FROM public.cfo_assets WHERE user_id='11111111-1111-4111-8111-111111111111')
     OR NOT EXISTS (SELECT 1 FROM public.asset_balance_accounts WHERE user_id='22222222-2222-4222-8222-222222222222')
     OR NOT EXISTS (SELECT 1 FROM public.cfo_assets WHERE user_id='22222222-2222-4222-8222-222222222222') THEN
    RAISE EXCEPTION 'adapter-before-cascade deletion or B preservation failed';
  END IF;
END
$with_adapter$;
ROLLBACK TO SAVEPOINT with_adapter;

-- Case D: an unrelated NO ACTION FK blocks auth deletion, which must roll back
-- earlier referential actions within that failed statement, retaining A and B.
SAVEPOINT synthetic_blocker;
ALTER TABLE public.cfo_assets DROP CONSTRAINT synthetic_cfo_owner_fk;
ALTER TABLE public.cfo_assets ADD CONSTRAINT synthetic_cfo_owner_fk
  FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
CREATE TABLE public.synthetic_auth_blocker (
  id integer PRIMARY KEY, user_id uuid NOT NULL REFERENCES auth.users(id)
);
INSERT INTO public.synthetic_auth_blocker VALUES (1,'11111111-1111-4111-8111-111111111111');
DO $blocker$
DECLARE r record; got_fk boolean := false;
BEGIN
  SELECT * INTO r FROM public.account_deletion_dependency_inventory('11111111-1111-4111-8111-111111111111')
   WHERE table_name='synthetic_auth_blocker' AND column_name='user_id';
  IF r.is_blocking IS DISTINCT FROM true THEN RAISE EXCEPTION 'new blocker not classified'; END IF;
  BEGIN
    DELETE FROM auth.users WHERE id='11111111-1111-4111-8111-111111111111';
  EXCEPTION WHEN foreign_key_violation THEN got_fk := true;
  END;
  IF NOT got_fk OR (SELECT count(*) FROM auth.users) <> 2
     OR (SELECT count(*) FROM public.asset_balance_accounts) <> 2
     OR (SELECT count(*) FROM public.cfo_assets) <> 3
     OR (SELECT count(*) FROM public.synthetic_auth_blocker) <> 1 THEN
    RAISE EXCEPTION 'failed auth delete leaked cascade effects';
  END IF;
END
$blocker$;
ROLLBACK TO SAVEPOINT synthetic_blocker;

ROLLBACK;
DO $post_rollback$
BEGIN
  IF pg_catalog.to_regclass('public.asset_balance_accounts') IS NOT NULL
     OR EXISTS (SELECT 1 FROM pg_catalog.pg_attribute
                WHERE attrelid='public.cfo_assets'::regclass
                  AND attname IN ('balance_account_id','observed_at','observation_source')
                  AND NOT attisdropped)
     OR EXISTS (SELECT 1 FROM auth.users) OR EXISTS (SELECT 1 FROM public.cfo_assets)
     OR EXISTS (SELECT 1 FROM public.account_deletion_direct_delete_adapters) THEN
    RAISE EXCEPTION 'test transaction left fixture rows or candidate schema';
  END IF;
END
$post_rollback$;
\echo 'synthetic cascade contract assertions passed; disposable cluster remains'
