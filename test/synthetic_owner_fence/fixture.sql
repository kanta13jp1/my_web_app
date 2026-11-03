-- Disposable fixture, fake user GUC is spoofable and NOT Supabase Auth.
\set ON_ERROR_STOP on
DO $$ BEGIN IF current_database() <> 'owner_sync_lab' OR current_user <> 'postgres' THEN RAISE EXCEPTION 'wrong synthetic database'; END IF; END $$;
CREATE ROLE authenticated NOLOGIN;
CREATE ROLE anon NOLOGIN;
CREATE SCHEMA auth;
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE SQL STABLE AS $$SELECT nullif(current_setting('lab.owner', true),'')::uuid$$;
GRANT USAGE ON SCHEMA auth TO authenticated,anon;
CREATE TABLE public.asset_pref_mirror (user_id uuid NOT NULL, pref_key text NOT NULL, value jsonb NOT NULL, PRIMARY KEY(user_id,pref_key));
ALTER TABLE public.asset_pref_mirror ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.asset_pref_mirror TO authenticated;
CREATE POLICY own_all ON public.asset_pref_mirror FOR ALL TO authenticated USING (auth.uid()=user_id) WITH CHECK (auth.uid()=user_id);
INSERT INTO public.asset_pref_mirror VALUES
 ('00000000-0000-0000-0000-000000000001','debt_payment_day_overrides','{"x":10}'),
 ('00000000-0000-0000-0000-000000000001','debt_payment_day_override_deleted','{"ids":["y"]}'),
 ('00000000-0000-0000-0000-000000000001','other','{}'),
 ('00000000-0000-0000-0000-000000000002','debt_payment_day_overrides','{"x":20}');
