-- Versioned safety disclosure and private acknowledgement for the existing
-- self-touch tracker. The acknowledgement is deliberately kept out of the
-- public user_profiles table because public profile rows are anonymously
-- readable when is_public=true.

CREATE TABLE IF NOT EXISTS public.self_touch_disclosures (
  version text PRIMARY KEY,
  title text NOT NULL CHECK (char_length(title) BETWEEN 1 AND 120),
  body text NOT NULL CHECK (char_length(body) BETWEEN 1 AND 2000),
  support_label text NOT NULL CHECK (char_length(support_label) BETWEEN 1 AND 160),
  support_url text NOT NULL CHECK (support_url ~ '^https://'),
  is_active boolean NOT NULL DEFAULT false,
  effective_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS self_touch_disclosures_one_active_idx
  ON public.self_touch_disclosures ((is_active))
  WHERE is_active;

ALTER TABLE public.self_touch_disclosures ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS self_touch_disclosures_read_active
  ON public.self_touch_disclosures;
CREATE POLICY self_touch_disclosures_read_active
  ON public.self_touch_disclosures
  FOR SELECT
  TO anon, authenticated
  USING (is_active);

CREATE TABLE IF NOT EXISTS public.self_touch_tracking_consents (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  consent_version text NOT NULL
    REFERENCES public.self_touch_disclosures(version),
  consent_granted boolean NOT NULL DEFAULT true CHECK (consent_granted),
  consented_at timestamptz NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.self_touch_tracking_consents ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS self_touch_tracking_consents_select_own
  ON public.self_touch_tracking_consents;
CREATE POLICY self_touch_tracking_consents_select_own
  ON public.self_touch_tracking_consents
  FOR SELECT
  TO authenticated
  USING ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS self_touch_tracking_consents_insert_own
  ON public.self_touch_tracking_consents;
CREATE POLICY self_touch_tracking_consents_insert_own
  ON public.self_touch_tracking_consents
  FOR INSERT
  TO authenticated
  WITH CHECK ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS self_touch_tracking_consents_update_own
  ON public.self_touch_tracking_consents;
CREATE POLICY self_touch_tracking_consents_update_own
  ON public.self_touch_tracking_consents
  FOR UPDATE
  TO authenticated
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS self_touch_tracking_consents_delete_own
  ON public.self_touch_tracking_consents;
CREATE POLICY self_touch_tracking_consents_delete_own
  ON public.self_touch_tracking_consents
  FOR DELETE
  TO authenticated
  USING ((SELECT auth.uid()) = user_id);

INSERT INTO public.self_touch_disclosures (
  version,
  title,
  body,
  support_label,
  support_url,
  is_active,
  effective_at
)
VALUES (
  '2026-09-03-v1',
  '記録を始める前に',
  'この機能は自己観察を助けるもので、医療上の診断や治療ではありません。記録回数だけで疾患や重症度を判断しません。心身の不調が続く場合や、自分を傷つける心配がある場合は、医療機関や公的な相談窓口に相談してください。',
  '厚生労働省「まもろうよ こころ」相談窓口',
  'https://www.mhlw.go.jp/mamorouyokokoro/soudan/',
  true,
  '2026-09-03T00:00:00Z'
)
ON CONFLICT (version) DO UPDATE SET
  title = EXCLUDED.title,
  body = EXCLUDED.body,
  support_label = EXCLUDED.support_label,
  support_url = EXCLUDED.support_url,
  is_active = EXCLUDED.is_active,
  effective_at = EXCLUDED.effective_at;

COMMENT ON TABLE public.self_touch_disclosures IS
  'Versioned non-diagnostic disclosure and official support link for the self-touch tracker.';
COMMENT ON TABLE public.self_touch_tracking_consents IS
  'Private record that the authenticated user acknowledged a specific self-touch tracker disclosure version.';
