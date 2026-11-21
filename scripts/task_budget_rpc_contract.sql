-- Run only against the disposable CI database, never against production.
CREATE ROLE anon NOLOGIN;
CREATE ROLE authenticated NOLOGIN;
CREATE ROLE service_role NOLOGIN;
CREATE SCHEMA auth;
CREATE FUNCTION auth.role() RETURNS text LANGUAGE sql STABLE AS $$
  SELECT COALESCE(NULLIF(current_setting('request.jwt.claim.role', true), ''),
    (NULLIF(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role'))::text
$$;
CREATE FUNCTION public.update_updated_at_column() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END;
$$;
\ir ../supabase/migrations/20260429110500_create_task_budget.sql
-- Model production's explicit grants, which are not removed by REVOKE PUBLIC.
GRANT EXECUTE ON FUNCTION public.record_task_budget_spend(text,text,numeric)
  TO anon, authenticated;
\ir ../supabase/migrations/20261102230402_harden_task_budget_rpc.sql

DO $$
BEGIN
  IF has_function_privilege('anon', 'public.record_task_budget_spend(text,text,numeric)', 'EXECUTE')
    OR has_function_privilege('authenticated', 'public.record_task_budget_spend(text,text,numeric)', 'EXECUTE')
    OR NOT has_function_privilege('service_role', 'public.record_task_budget_spend(text,text,numeric)', 'EXECUTE') THEN
    RAISE EXCEPTION 'unexpected function execute privileges';
  END IF;
END $$;

SET ROLE anon;
DO $$ BEGIN
  BEGIN
    PERFORM public.record_task_budget_spend('ef', 'test_anon', 1);
    RAISE EXCEPTION 'anonymous call unexpectedly succeeded';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;

SET ROLE authenticated;
DO $$ BEGIN
  BEGIN
    PERFORM public.record_task_budget_spend('ef', 'test_authenticated', 1);
    RAISE EXCEPTION 'authenticated call unexpectedly succeeded';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;

SET ROLE service_role;
SELECT set_config('request.jwt.claim.role', '', false);
DO $$ BEGIN
  BEGIN
    PERFORM public.record_task_budget_spend('ef', 'test_no_claim', 1);
    RAISE EXCEPTION 'missing claim unexpectedly succeeded';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
SELECT set_config('request.jwt.claim.role', 'authenticated', false);
DO $$ BEGIN
  BEGIN
    PERFORM public.record_task_budget_spend('ef', 'test_wrong_claim', 1);
    RAISE EXCEPTION 'wrong claim unexpectedly succeeded';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
SELECT set_config('request.jwt.claim.role', 'service_role', false);
SELECT public.record_task_budget_spend('ef', 'test_allowed', 1.25);
SELECT public.record_task_budget_spend('ef', 'test_allowed', 0.75);
-- PostgREST also supplies role inside the JSON claims setting.
SELECT set_config('request.jwt.claim.role', '', false);
SELECT set_config('request.jwt.claims', '{"role":"service_role"}', false);
SELECT public.record_task_budget_spend('ef', 'test_json_claim', 0.5);
RESET ROLE;
DO $$ BEGIN
  IF (SELECT spent_usd FROM public.task_budget WHERE scope='ef' AND scope_id='test_allowed') IS DISTINCT FROM 2.00 THEN
    RAISE EXCEPTION 'service role spending did not accumulate';
  END IF;
  IF (SELECT spent_usd FROM public.task_budget WHERE scope='ef' AND scope_id='test_json_claim') IS DISTINCT FROM 0.50 THEN
    RAISE EXCEPTION 'JSON service role claim did not record spending';
  END IF;
  IF EXISTS (SELECT 1 FROM public.task_budget WHERE scope_id IN ('test_anon','test_authenticated','test_no_claim','test_wrong_claim')) THEN
    RAISE EXCEPTION 'denied calls created records';
  END IF;
END $$;
\echo 'PASS: explicit ACL, missing/wrong claim denial, and service-role spend'
