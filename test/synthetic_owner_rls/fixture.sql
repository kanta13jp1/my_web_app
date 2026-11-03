-- Synthetic-only fixture for an ephemeral database named owner_sync_lab.
-- The session GUC is intentionally spoofable: this is NOT real authentication.
\set ON_ERROR_STOP on
DO $$ BEGIN
  IF current_database() <> 'owner_sync_lab' OR current_user <> 'postgres' THEN
    RAISE EXCEPTION 'wrong synthetic database or role';
  END IF;
END $$;
CREATE ROLE lab_authenticated NOLOGIN;
CREATE ROLE lab_anon NOLOGIN;
CREATE SCHEMA lab_red;
CREATE FUNCTION lab_red.owner_id() RETURNS uuid LANGUAGE sql STABLE AS
  $$ SELECT nullif(current_setting('lab.owner', true), '')::uuid $$;
CREATE TABLE lab_red.asset_pref_mirror (
  user_id uuid NOT NULL, pref_key text NOT NULL, value jsonb NOT NULL,
  PRIMARY KEY (user_id, pref_key)
);
ALTER TABLE lab_red.asset_pref_mirror ENABLE ROW LEVEL SECURITY;
GRANT USAGE ON SCHEMA lab_red TO lab_authenticated, lab_anon;
GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE ON lab_red.asset_pref_mirror TO lab_authenticated;
CREATE POLICY owner_all ON lab_red.asset_pref_mirror FOR ALL TO lab_authenticated
  USING (user_id = lab_red.owner_id()) WITH CHECK (user_id = lab_red.owner_id());
INSERT INTO lab_red.asset_pref_mirror VALUES
 ('00000000-0000-0000-0000-000000000001', 'debt_payment_day_overrides', '{"x":10}'),
 ('00000000-0000-0000-0000-000000000001', 'debt_payment_day_override_deleted', '{"ids":["y"]}'),
 ('00000000-0000-0000-0000-000000000001', 'other', '{}'),
 ('00000000-0000-0000-0000-000000000002', 'debt_payment_day_overrides', '{"x":20}'),
 ('00000000-0000-0000-0000-000000000002', 'other', '{}');
CREATE SCHEMA lab_policy;
CREATE FUNCTION lab_policy.owner_id() RETURNS uuid LANGUAGE sql STABLE AS
  $$ SELECT nullif(current_setting('lab.owner', true), '')::uuid $$;
CREATE TABLE lab_policy.asset_pref_mirror (
  user_id uuid NOT NULL, pref_key text NOT NULL, value jsonb NOT NULL,
  PRIMARY KEY (user_id, pref_key)
);
ALTER TABLE lab_policy.asset_pref_mirror ENABLE ROW LEVEL SECURITY;
GRANT USAGE ON SCHEMA lab_policy TO lab_authenticated, lab_anon;
GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE ON lab_policy.asset_pref_mirror TO lab_authenticated;
CREATE POLICY owner_all ON lab_policy.asset_pref_mirror FOR ALL TO lab_authenticated
  USING (user_id = lab_policy.owner_id()) WITH CHECK (user_id = lab_policy.owner_id());
INSERT INTO lab_policy.asset_pref_mirror VALUES
 ('00000000-0000-0000-0000-000000000001', 'debt_payment_day_overrides', '{"x":10}'),
 ('00000000-0000-0000-0000-000000000001', 'debt_payment_day_override_deleted', '{"ids":["y"]}'),
 ('00000000-0000-0000-0000-000000000001', 'other', '{}'),
 ('00000000-0000-0000-0000-000000000002', 'debt_payment_day_overrides', '{"x":20}'),
 ('00000000-0000-0000-0000-000000000002', 'other', '{}');
CREATE SCHEMA lab_upsert;
CREATE FUNCTION lab_upsert.owner_id() RETURNS uuid LANGUAGE sql STABLE AS
  $$ SELECT nullif(current_setting('lab.owner', true), '')::uuid $$;
CREATE TABLE lab_upsert.asset_pref_mirror (
  user_id uuid NOT NULL, pref_key text NOT NULL, value jsonb NOT NULL,
  PRIMARY KEY (user_id, pref_key)
);
ALTER TABLE lab_upsert.asset_pref_mirror ENABLE ROW LEVEL SECURITY;
GRANT USAGE ON SCHEMA lab_upsert TO lab_authenticated, lab_anon;
GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE ON lab_upsert.asset_pref_mirror TO lab_authenticated;
CREATE POLICY owner_all ON lab_upsert.asset_pref_mirror FOR ALL TO lab_authenticated
  USING (user_id = lab_upsert.owner_id()) WITH CHECK (user_id = lab_upsert.owner_id());
INSERT INTO lab_upsert.asset_pref_mirror VALUES
 ('00000000-0000-0000-0000-000000000001', 'debt_payment_day_overrides', '{"x":10}'),
 ('00000000-0000-0000-0000-000000000001', 'debt_payment_day_override_deleted', '{"ids":["y"]}'),
 ('00000000-0000-0000-0000-000000000001', 'other', '{}'),
 ('00000000-0000-0000-0000-000000000002', 'debt_payment_day_overrides', '{"x":20}'),
 ('00000000-0000-0000-0000-000000000002', 'other', '{}');
CREATE SCHEMA lab_row;
CREATE FUNCTION lab_row.owner_id() RETURNS uuid LANGUAGE sql STABLE AS
  $$ SELECT nullif(current_setting('lab.owner', true), '')::uuid $$;
CREATE TABLE lab_row.asset_pref_mirror (
  user_id uuid NOT NULL, pref_key text NOT NULL, value jsonb NOT NULL,
  PRIMARY KEY (user_id, pref_key)
);
ALTER TABLE lab_row.asset_pref_mirror ENABLE ROW LEVEL SECURITY;
GRANT USAGE ON SCHEMA lab_row TO lab_authenticated, lab_anon;
GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE ON lab_row.asset_pref_mirror TO lab_authenticated;
CREATE POLICY owner_all ON lab_row.asset_pref_mirror FOR ALL TO lab_authenticated
  USING (user_id = lab_row.owner_id()) WITH CHECK (user_id = lab_row.owner_id());
INSERT INTO lab_row.asset_pref_mirror VALUES
 ('00000000-0000-0000-0000-000000000001', 'debt_payment_day_overrides', '{"x":10}'),
 ('00000000-0000-0000-0000-000000000001', 'debt_payment_day_override_deleted', '{"ids":["y"]}'),
 ('00000000-0000-0000-0000-000000000001', 'other', '{}'),
 ('00000000-0000-0000-0000-000000000002', 'debt_payment_day_overrides', '{"x":20}'),
 ('00000000-0000-0000-0000-000000000002', 'other', '{}');
-- A second permissive policy does not override owner_all: policies OR together.
CREATE POLICY supposed_restriction ON lab_red.asset_pref_mirror AS PERMISSIVE FOR ALL TO lab_authenticated
  USING (pref_key NOT IN ('debt_payment_day_overrides','debt_payment_day_override_deleted'))
  WITH CHECK (pref_key NOT IN ('debt_payment_day_overrides','debt_payment_day_override_deleted'));
CREATE POLICY owner_insert_guard ON lab_policy.asset_pref_mirror AS RESTRICTIVE FOR INSERT TO lab_authenticated
  WITH CHECK (pref_key NOT IN ('debt_payment_day_overrides','debt_payment_day_override_deleted'));
CREATE POLICY owner_update_guard ON lab_policy.asset_pref_mirror AS RESTRICTIVE FOR UPDATE TO lab_authenticated
  USING (pref_key NOT IN ('debt_payment_day_overrides','debt_payment_day_override_deleted'))
  WITH CHECK (pref_key NOT IN ('debt_payment_day_overrides','debt_payment_day_override_deleted'));
CREATE POLICY owner_delete_guard ON lab_policy.asset_pref_mirror AS RESTRICTIVE FOR DELETE TO lab_authenticated
  USING (pref_key NOT IN ('debt_payment_day_overrides','debt_payment_day_override_deleted'));
-- Update-only fixture isolates ON CONFLICT DO UPDATE from insert restriction.
CREATE POLICY upsert_update_guard ON lab_upsert.asset_pref_mirror AS RESTRICTIVE FOR UPDATE TO lab_authenticated
  USING (pref_key NOT IN ('debt_payment_day_overrides','debt_payment_day_override_deleted'))
  WITH CHECK (pref_key NOT IN ('debt_payment_day_overrides','debt_payment_day_override_deleted'));
-- Demonstrates row-trigger scope, not a secure production guard.
CREATE FUNCTION lab_row.reject_protected_row() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF (TG_OP <> 'INSERT' AND OLD.pref_key IN ('debt_payment_day_overrides','debt_payment_day_override_deleted'))
     OR (TG_OP <> 'DELETE' AND NEW.pref_key IN ('debt_payment_day_overrides','debt_payment_day_override_deleted')) THEN
    RAISE EXCEPTION 'synthetic protected row';
  END IF;
  IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER row_only_guard BEFORE INSERT OR UPDATE OR DELETE ON lab_row.asset_pref_mirror
  FOR EACH ROW EXECUTE FUNCTION lab_row.reject_protected_row();
