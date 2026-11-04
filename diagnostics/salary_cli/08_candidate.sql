-- REVIEW DRAFT ONLY. NOT APPLIED. NOT A DEPLOYABLE MIGRATION.
-- This draft only expands metadata. It does not establish bank ownership,
-- prove salary, solve uncertain writes, or authorize new financial writes.
-- Real use requires the independent review and isolated tests in REVIEW.md.
SET LOCAL lock_timeout = '3s';
SET LOCAL statement_timeout = '30s';

CREATE TABLE public.asset_balance_accounts (
  id uuid PRIMARY KEY DEFAULT pg_catalog.gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id),
  display_name text NOT NULL CHECK (pg_catalog.btrim(display_name) <> ''),
  created_at timestamptz NOT NULL DEFAULT pg_catalog.now(),
  UNIQUE (user_id, id)
);

ALTER TABLE public.asset_balance_accounts ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.asset_balance_accounts FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.asset_balance_accounts TO authenticated;

CREATE POLICY asset_balance_accounts_select_own
  ON public.asset_balance_accounts FOR SELECT TO authenticated
  USING ((SELECT auth.uid()) = user_id);
CREATE POLICY asset_balance_accounts_insert_own
  ON public.asset_balance_accounts FOR INSERT TO authenticated
  WITH CHECK ((SELECT auth.uid()) = user_id);
CREATE POLICY asset_balance_accounts_update_own
  ON public.asset_balance_accounts FOR UPDATE TO authenticated
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);
CREATE POLICY asset_balance_accounts_delete_own
  ON public.asset_balance_accounts FOR DELETE TO authenticated
  USING ((SELECT auth.uid()) = user_id);

-- NULL means unknown / legacy; no name- or amount-based backfill is performed.
-- Source is a client declaration and must never be treated as bank proof.
ALTER TABLE public.cfo_assets
  ADD COLUMN balance_account_id uuid,
  ADD COLUMN observed_at timestamptz,
  ADD COLUMN observation_source text;

ALTER TABLE public.cfo_assets
  ADD CONSTRAINT cfo_assets_owner_account_fk
  FOREIGN KEY (user_id, balance_account_id)
  REFERENCES public.asset_balance_accounts (user_id, id)
  NOT VALID;

ALTER TABLE public.cfo_assets
  ADD CONSTRAINT cfo_assets_observation_source_check
  CHECK (observation_source IS NULL OR observation_source IN (
    'manual_unverified',
    'same_as_previous_unverified',
    'obsidian_reclassified_unverified',
    'imported_unverified',
    'corrected_unverified',
    'other_unverified'
  )) NOT VALID;

-- Validation is a later separately reviewed stage; it may scan existing rows.
-- No defaults, triggers, backfill, revocation of legacy cfo_assets grants,
-- new RPC, operation ledger, or writer cutover are part of this draft.
