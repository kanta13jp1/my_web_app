-- SYNTHETIC TEST ONLY. Never run against a live or shared database.
-- Included inside 03's outer transaction after synthetic A/B rows exist.
-- Fake auth.uid() reads an in-session GUC: it does not verify a real JWT.
-- This test does not claim the actual Supabase role graph or effective grants.
\set ON_ERROR_STOP on
DO $rls_guard$
BEGIN
  IF pg_catalog.current_database() <> 'salary_identity_isolated'
     OR pg_catalog.current_setting('salary_test.isolated', true) IS DISTINCT FROM 'disposable-pg17-only'
     OR pg_catalog.current_setting('server_version_num')::integer < 170000
     OR pg_catalog.current_setting('server_version_num')::integer >= 180000
     OR (pg_catalog.inet_server_addr() IS NOT NULL AND
         pg_catalog.inet_server_addr() NOT IN ('127.0.0.1'::inet, '::1'::inet))
     OR pg_catalog.to_regclass('public.asset_balance_accounts') IS NULL
     OR pg_catalog.to_regprocedure('auth.uid()') IS NULL
     OR NOT EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname='authenticated')
     OR NOT EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname='anon')
     OR NOT EXISTS (SELECT 1 FROM pg_catalog.pg_class
                    WHERE oid='public.asset_balance_accounts'::regclass AND relrowsecurity) THEN
    RAISE EXCEPTION 'unsafe or unexpected synthetic RLS setup';
  END IF;
END
$rls_guard$;

-- Record the role and exact ACLs outside the savepoint to verify restoration.
-- This synthetic temporary table is removed after the comparison.
CREATE TEMP TABLE fixture_rls_before ON COMMIT DROP AS
SELECT current_user::text AS current_role_name,
       session_user::text AS session_role_name,
       pg_catalog.current_setting('role') AS role_setting,
       coalesce(pg_catalog.current_setting('request.jwt.claim.sub', true), '') AS claim_setting,
       (SELECT nspacl::text FROM pg_catalog.pg_namespace WHERE nspname='auth') AS auth_schema_acl,
       (SELECT proacl::text FROM pg_catalog.pg_proc WHERE oid='auth.uid()'::regprocedure) AS auth_uid_acl;

SAVEPOINT synthetic_rls;
-- Test-only assumptions that expose the mock auth.uid to the fake roles.
GRANT USAGE ON SCHEMA auth TO authenticated, anon;
GRANT EXECUTE ON FUNCTION auth.uid() TO authenticated, anon;

SET LOCAL ROLE authenticated;
SELECT pg_catalog.set_config('request.jwt.claim.sub','',true);
DO $empty_claim$
DECLARE affected integer; denied boolean := false;
BEGIN
  IF (SELECT count(*) FROM public.asset_balance_accounts) <> 0 THEN
    RAISE EXCEPTION 'empty authenticated claim exposed account rows';
  END IF;
  BEGIN
    INSERT INTO public.asset_balance_accounts (id,user_id,display_name)
    VALUES ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3','11111111-1111-4111-8111-111111111111','empty claim');
  EXCEPTION WHEN insufficient_privilege THEN denied := true;
  END;
  IF NOT denied THEN RAISE EXCEPTION 'empty claim INSERT unexpectedly succeeded'; END IF;
  UPDATE public.asset_balance_accounts SET display_name='empty claim';
  GET DIAGNOSTICS affected = ROW_COUNT;
  IF affected <> 0 THEN RAISE EXCEPTION 'empty claim UPDATE affected rows'; END IF;
  DELETE FROM public.asset_balance_accounts;
  GET DIAGNOSTICS affected = ROW_COUNT;
  IF affected <> 0 THEN RAISE EXCEPTION 'empty claim DELETE affected rows'; END IF;
END
$empty_claim$;

SELECT pg_catalog.set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
DO $user_a$
DECLARE affected integer; denied boolean := false;
BEGIN
  IF (SELECT count(*) FROM public.asset_balance_accounts) <> 1
     OR NOT EXISTS (SELECT 1 FROM public.asset_balance_accounts
                    WHERE id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1')
     OR EXISTS (SELECT 1 FROM public.asset_balance_accounts
                WHERE id='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1') THEN
    RAISE EXCEPTION 'A SELECT isolation failed';
  END IF;
  BEGIN
    INSERT INTO public.asset_balance_accounts (id,user_id,display_name)
    VALUES ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2','22222222-2222-4222-8222-222222222222','forged owner');
  EXCEPTION WHEN insufficient_privilege THEN denied := true;
  END;
  IF NOT denied THEN RAISE EXCEPTION 'A forged B INSERT was accepted'; END IF;
  denied := false;
  BEGIN
    UPDATE public.asset_balance_accounts
       SET user_id='22222222-2222-4222-8222-222222222222'
     WHERE id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1';
  EXCEPTION WHEN insufficient_privilege THEN denied := true;
  END;
  IF NOT denied OR NOT EXISTS (SELECT 1 FROM public.asset_balance_accounts
                               WHERE id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1'
                                 AND user_id='11111111-1111-4111-8111-111111111111') THEN
    RAISE EXCEPTION 'A account owner rewrite was not rejected';
  END IF;
  UPDATE public.asset_balance_accounts SET display_name='forged'
   WHERE id='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1';
  GET DIAGNOSTICS affected = ROW_COUNT;
  IF affected <> 0 THEN RAISE EXCEPTION 'A updated B account'; END IF;
  DELETE FROM public.asset_balance_accounts
   WHERE id='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1';
  GET DIAGNOSTICS affected = ROW_COUNT;
  IF affected <> 0 THEN RAISE EXCEPTION 'A deleted B account'; END IF;
  UPDATE public.asset_balance_accounts SET display_name='A updated'
   WHERE id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1';
  GET DIAGNOSTICS affected = ROW_COUNT;
  IF affected <> 1 OR NOT EXISTS (SELECT 1 FROM public.asset_balance_accounts
                                 WHERE id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1'
                                   AND display_name='A updated') THEN
    RAISE EXCEPTION 'A own account UPDATE control failed';
  END IF;
  INSERT INTO public.asset_balance_accounts (id,user_id,display_name)
  VALUES ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2','11111111-1111-4111-8111-111111111111','A control');
  DELETE FROM public.asset_balance_accounts WHERE id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2';
  GET DIAGNOSTICS affected = ROW_COUNT;
  IF affected <> 1 THEN RAISE EXCEPTION 'A own unreferenced account control failed'; END IF;
END
$user_a$;

SELECT pg_catalog.set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',true);
DO $user_b$
DECLARE affected integer;
BEGIN
  IF (SELECT count(*) FROM public.asset_balance_accounts) <> 1
     OR NOT EXISTS (SELECT 1 FROM public.asset_balance_accounts
                    WHERE id='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1')
     OR EXISTS (SELECT 1 FROM public.asset_balance_accounts
                WHERE id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1') THEN
    RAISE EXCEPTION 'B SELECT isolation failed';
  END IF;
  UPDATE public.asset_balance_accounts SET display_name='forged'
   WHERE id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1';
  GET DIAGNOSTICS affected = ROW_COUNT;
  IF affected <> 0 THEN RAISE EXCEPTION 'B updated A account'; END IF;
  DELETE FROM public.asset_balance_accounts
   WHERE id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1';
  GET DIAGNOSTICS affected = ROW_COUNT;
  IF affected <> 0 THEN RAISE EXCEPTION 'B deleted A account'; END IF;
  UPDATE public.asset_balance_accounts SET display_name='B updated'
   WHERE id='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1';
  GET DIAGNOSTICS affected = ROW_COUNT;
  IF affected <> 1 OR NOT EXISTS (SELECT 1 FROM public.asset_balance_accounts
                                 WHERE id='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1'
                                   AND display_name='B updated') THEN
    RAISE EXCEPTION 'B own account UPDATE control failed';
  END IF;
END
$user_b$;

RESET ROLE;
SET LOCAL ROLE anon;
SELECT pg_catalog.set_config('request.jwt.claim.sub','',true);
DO $anonymous$
DECLARE denied boolean;
BEGIN
  denied := false;
  BEGIN
    PERFORM 1 FROM public.asset_balance_accounts;
  EXCEPTION WHEN insufficient_privilege THEN denied := true;
  END;
  IF NOT denied THEN RAISE EXCEPTION 'anonymous SELECT unexpectedly succeeded'; END IF;
  denied := false;
  BEGIN
    INSERT INTO public.asset_balance_accounts (id,user_id,display_name)
    VALUES ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa4','11111111-1111-4111-8111-111111111111','anonymous');
  EXCEPTION WHEN insufficient_privilege THEN denied := true;
  END;
  IF NOT denied THEN RAISE EXCEPTION 'anonymous INSERT unexpectedly succeeded'; END IF;
  denied := false;
  BEGIN
    UPDATE public.asset_balance_accounts SET display_name='anonymous';
  EXCEPTION WHEN insufficient_privilege THEN denied := true;
  END;
  IF NOT denied THEN RAISE EXCEPTION 'anonymous UPDATE unexpectedly succeeded'; END IF;
  denied := false;
  BEGIN
    DELETE FROM public.asset_balance_accounts;
  EXCEPTION WHEN insufficient_privilege THEN denied := true;
  END;
  IF NOT denied THEN RAISE EXCEPTION 'anonymous DELETE unexpectedly succeeded'; END IF;
END
$anonymous$;
RESET ROLE;

-- Restore test-only grants and data; outer transaction remains open.
ROLLBACK TO SAVEPOINT synthetic_rls;
RELEASE SAVEPOINT synthetic_rls;
DO $restored$
DECLARE before_state record;
BEGIN
  SELECT * INTO STRICT before_state FROM pg_temp.fixture_rls_before;
  IF current_user::text IS DISTINCT FROM before_state.current_role_name
     OR session_user::text IS DISTINCT FROM before_state.session_role_name
     OR pg_catalog.current_setting('role') IS DISTINCT FROM before_state.role_setting
     OR coalesce(pg_catalog.current_setting('request.jwt.claim.sub', true), '') IS DISTINCT FROM before_state.claim_setting
     OR (SELECT nspacl::text FROM pg_catalog.pg_namespace WHERE nspname='auth')
          IS DISTINCT FROM before_state.auth_schema_acl
     OR (SELECT proacl::text FROM pg_catalog.pg_proc WHERE oid='auth.uid()'::regprocedure)
          IS DISTINCT FROM before_state.auth_uid_acl THEN
    RAISE EXCEPTION 'synthetic role or auth grant state was not restored';
  END IF;
END
$restored$;
DROP TABLE pg_temp.fixture_rls_before;
-- No claim about a real JWT, owner/BYPASSRLS, role inheritance or deployed ACL.
