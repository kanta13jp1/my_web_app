-- EXPERIMENT ONLY: guarded for disposable owner_sync_lab and postgres.
-- NOT a deployable migration. Blocks legacy RLS-subject writes to two keys;
-- no reader fix, RPC, initialization, migration or elevated-role protection.
\set ON_ERROR_STOP on
BEGIN;
DO $$ BEGIN
 IF current_database() <> 'owner_sync_lab' OR current_user <> 'postgres' THEN
   RAISE EXCEPTION 'refusing non-synthetic database';
 END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
  WHERE n.nspname='public' AND c.relname='asset_pref_mirror' AND c.relrowsecurity) THEN
   RAISE EXCEPTION 'expected RLS table missing';
 END IF;
 IF has_table_privilege('authenticated','public.asset_pref_mirror','TRUNCATE') OR
    has_table_privilege('anon','public.asset_pref_mirror','TRUNCATE') THEN
   RAISE EXCEPTION 'TRUNCATE remains reachable';
 END IF;
 IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname IN ('authenticated','anon') AND (rolsuper OR rolbypassrls)) OR
    EXISTS (SELECT 1 FROM pg_class c JOIN pg_roles r ON r.oid=c.relowner JOIN pg_namespace n ON n.oid=c.relnamespace
            WHERE n.nspname='public' AND c.relname='asset_pref_mirror' AND r.rolname IN ('authenticated','anon')) THEN
   RAISE EXCEPTION 'RLS bypass on ordinary role';
 END IF;
END $$;
-- Do not fence an inflight transaction silently. Retrying requires inspection.
LOCK TABLE public.asset_pref_mirror IN ACCESS EXCLUSIVE MODE NOWAIT;
CREATE POLICY debt_day_block_insert ON public.asset_pref_mirror AS RESTRICTIVE FOR INSERT TO PUBLIC
 WITH CHECK (pref_key NOT IN ('debt_payment_day_overrides','debt_payment_day_override_deleted'));
CREATE POLICY debt_day_block_update ON public.asset_pref_mirror AS RESTRICTIVE FOR UPDATE TO PUBLIC
 USING (pref_key NOT IN ('debt_payment_day_overrides','debt_payment_day_override_deleted'))
 WITH CHECK (pref_key NOT IN ('debt_payment_day_overrides','debt_payment_day_override_deleted'));
CREATE POLICY debt_day_block_delete ON public.asset_pref_mirror AS RESTRICTIVE FOR DELETE TO PUBLIC
 USING (pref_key NOT IN ('debt_payment_day_overrides','debt_payment_day_override_deleted'));
COMMIT;
