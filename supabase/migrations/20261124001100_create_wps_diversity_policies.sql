-- WPS & diversity knowledge policy storage, deterministic tagging metadata,
-- admin review/override workflow, and strict owner + admin RLS (#2585).

CREATE TABLE IF NOT EXISTS public.wps_diversity_policies (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  intake_source text NOT NULL DEFAULT 'manual'
    CHECK (intake_source IN ('notebooklm', 'ai_monitor', 'manual')),
  title text NOT NULL CHECK (char_length(btrim(title)) > 0),
  summary text NOT NULL DEFAULT '',
  primary_topic text NOT NULL DEFAULT 'general'
    CHECK (primary_topic IN ('wps', 'diversity', 'gender', 'human_rights', 'general')),
  policy_tags text[] NOT NULL DEFAULT '{}'::text[],
  framework_references text[] NOT NULL DEFAULT '{}'::text[],
  reference_url text NOT NULL DEFAULT ''
    CHECK (reference_url = '' OR reference_url ~ '^https?://'),
  confidence_score integer NOT NULL DEFAULT 0
    CHECK (confidence_score >= 0 AND confidence_score <= 100),
  review_status text NOT NULL DEFAULT 'pending_review'
    CHECK (review_status IN ('pending_review', 'approved', 'needs_revision')),
  review_note text,
  reviewed_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  reviewed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_wps_diversity_policies_user_status_updated
  ON public.wps_diversity_policies (user_id, review_status, updated_at DESC);

CREATE INDEX IF NOT EXISTS idx_wps_diversity_policies_tags_gin
  ON public.wps_diversity_policies USING gin (policy_tags);

ALTER TABLE public.wps_diversity_policies ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.wps_diversity_policies FROM PUBLIC, anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.wps_diversity_policies TO authenticated;
GRANT ALL ON TABLE public.wps_diversity_policies TO service_role;

DROP POLICY IF EXISTS "wps_diversity_policies_owner_select"
  ON public.wps_diversity_policies;
CREATE POLICY "wps_diversity_policies_owner_select"
  ON public.wps_diversity_policies
  FOR SELECT
  TO authenticated
  USING ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "wps_diversity_policies_owner_insert"
  ON public.wps_diversity_policies;
CREATE POLICY "wps_diversity_policies_owner_insert"
  ON public.wps_diversity_policies
  FOR INSERT
  TO authenticated
  WITH CHECK (
    (SELECT auth.uid()) = user_id
    AND review_status = 'pending_review'
    AND reviewed_by IS NULL
    AND reviewed_at IS NULL
    AND review_note IS NULL
  );

DROP POLICY IF EXISTS "wps_diversity_policies_owner_update"
  ON public.wps_diversity_policies;
CREATE POLICY "wps_diversity_policies_owner_update"
  ON public.wps_diversity_policies
  FOR UPDATE
  TO authenticated
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "wps_diversity_policies_owner_delete"
  ON public.wps_diversity_policies;
CREATE POLICY "wps_diversity_policies_owner_delete"
  ON public.wps_diversity_policies
  FOR DELETE
  TO authenticated
  USING ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "wps_diversity_policies_admin_select"
  ON public.wps_diversity_policies;
CREATE POLICY "wps_diversity_policies_admin_select"
  ON public.wps_diversity_policies
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.user_profiles up
      WHERE up.user_id = (SELECT auth.uid())
        AND up.is_admin = true
    )
  );

DROP POLICY IF EXISTS "wps_diversity_policies_admin_update"
  ON public.wps_diversity_policies;
CREATE POLICY "wps_diversity_policies_admin_update"
  ON public.wps_diversity_policies
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.user_profiles up
      WHERE up.user_id = (SELECT auth.uid())
        AND up.is_admin = true
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.user_profiles up
      WHERE up.user_id = (SELECT auth.uid())
        AND up.is_admin = true
    )
  );

DROP POLICY IF EXISTS "wps_diversity_policies_service_role_all"
  ON public.wps_diversity_policies;
CREATE POLICY "wps_diversity_policies_service_role_all"
  ON public.wps_diversity_policies
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

CREATE OR REPLACE FUNCTION public.guard_wps_diversity_policy_review_fields()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $guard$
DECLARE
  v_uid uuid := auth.uid();
  v_is_admin boolean := false;
BEGIN
  IF auth.role() = 'service_role'
     OR current_user IN ('postgres', 'supabase_admin', 'supabase_auth_admin') THEN
    RETURN NEW;
  END IF;

  IF v_uid IS NOT NULL THEN
    SELECT EXISTS (
      SELECT 1
      FROM public.user_profiles up
      WHERE up.user_id = v_uid
        AND up.is_admin = true
    )
    INTO v_is_admin;
  END IF;

  IF COALESCE(v_is_admin, false) THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'INSERT' THEN
    IF NEW.review_status IS DISTINCT FROM 'pending_review'
       OR NEW.reviewed_by IS NOT NULL
       OR NEW.reviewed_at IS NOT NULL
       OR NEW.review_note IS NOT NULL THEN
      RAISE EXCEPTION
        'Only administrators or service_role may set review fields on insert'
        USING ERRCODE = '42501';
    END IF;
    RETURN NEW;
  END IF;

  IF NEW.review_status IS DISTINCT FROM OLD.review_status
     OR NEW.reviewed_by IS DISTINCT FROM OLD.reviewed_by
     OR NEW.reviewed_at IS DISTINCT FROM OLD.reviewed_at
     OR NEW.review_note IS DISTINCT FROM OLD.review_note THEN
    RAISE EXCEPTION
      'Only administrators or service_role may modify review fields'
      USING ERRCODE = '42501';
  END IF;

  RETURN NEW;
END;
$guard$;

DROP TRIGGER IF EXISTS trg_guard_wps_diversity_policy_review_fields
  ON public.wps_diversity_policies;
CREATE TRIGGER trg_guard_wps_diversity_policy_review_fields
  BEFORE INSERT OR UPDATE ON public.wps_diversity_policies
  FOR EACH ROW
  EXECUTE FUNCTION public.guard_wps_diversity_policy_review_fields();

COMMENT ON FUNCTION public.guard_wps_diversity_policy_review_fields() IS
  'Blocks non-admin/non-service_role clients from setting or altering review_status, reviewed_by, reviewed_at, or review_note (#2585).';

COMMENT ON TABLE public.wps_diversity_policies IS
  'WPS & organizational diversity policy documents, auto-extracted tags, access links, and admin review status (#2585).';
