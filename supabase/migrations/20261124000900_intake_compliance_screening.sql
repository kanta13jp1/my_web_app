-- Automated legal/regulatory compliance screening records for intake data (#2595).

CREATE TABLE IF NOT EXISTS public.intake_compliance_screenings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  intake_source text NOT NULL
    CHECK (intake_source IN ('notebooklm', 'github_issue', 'manual')),
  title text NOT NULL CHECK (char_length(btrim(title)) > 0),
  content_excerpt text NOT NULL DEFAULT '',
  risk_category text NOT NULL DEFAULT 'none'
    CHECK (
      risk_category IN (
        'none',
        'antitrust',
        'competition_law',
        'financial_claim',
        'regulatory',
        'legal_compliance'
      )
    ),
  risk_score integer NOT NULL DEFAULT 0
    CHECK (risk_score >= 0 AND risk_score <= 100),
  matched_keywords text[] NOT NULL DEFAULT '{}'::text[],
  requires_verification boolean NOT NULL DEFAULT false,
  review_status text NOT NULL DEFAULT 'pending'
    CHECK (review_status IN ('pending', 'verified_safe', 'flagged_hold')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_intake_compliance_screenings_user_verif
  ON public.intake_compliance_screenings (
    user_id,
    requires_verification,
    review_status,
    created_at DESC
  );

ALTER TABLE public.intake_compliance_screenings ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.intake_compliance_screenings FROM PUBLIC, anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.intake_compliance_screenings
  TO authenticated;
GRANT ALL ON TABLE public.intake_compliance_screenings TO service_role;

DROP POLICY IF EXISTS "intake_compliance_owner_select"
  ON public.intake_compliance_screenings;
CREATE POLICY "intake_compliance_owner_select"
  ON public.intake_compliance_screenings
  FOR SELECT
  TO authenticated
  USING ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "intake_compliance_owner_insert"
  ON public.intake_compliance_screenings;
CREATE POLICY "intake_compliance_owner_insert"
  ON public.intake_compliance_screenings
  FOR INSERT
  TO authenticated
  WITH CHECK ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "intake_compliance_owner_update"
  ON public.intake_compliance_screenings;
CREATE POLICY "intake_compliance_owner_update"
  ON public.intake_compliance_screenings
  FOR UPDATE
  TO authenticated
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "intake_compliance_owner_delete"
  ON public.intake_compliance_screenings;
CREATE POLICY "intake_compliance_owner_delete"
  ON public.intake_compliance_screenings
  FOR DELETE
  TO authenticated
  USING ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "intake_compliance_service_role_all"
  ON public.intake_compliance_screenings;
CREATE POLICY "intake_compliance_service_role_all"
  ON public.intake_compliance_screenings
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

COMMENT ON TABLE public.intake_compliance_screenings IS
  'Stores automated legal/regulatory/financial compliance screening results for intake items (#2595).';
