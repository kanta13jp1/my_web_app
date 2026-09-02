-- Enforce MUSUBI research consent at the database boundary and make
-- withdrawal remove every research artifact owned by the participant.

ALTER TABLE public.musubi_research_feedback
  ADD COLUMN IF NOT EXISTS consent_version text NOT NULL
    DEFAULT '2026-08-13-v1'
    CHECK (char_length(consent_version) BETWEEN 1 AND 40);

ALTER TABLE public.musubi_research_events
  ADD COLUMN IF NOT EXISTS cohort text NOT NULL
    DEFAULT 'first-user-2026-08'
    CHECK (char_length(cohort) BETWEEN 1 AND 40),
  ADD COLUMN IF NOT EXISTS consent_version text NOT NULL
    DEFAULT '2026-08-13-v1'
    CHECK (char_length(consent_version) BETWEEN 1 AND 40);

DROP POLICY IF EXISTS musubi_events_insert_own
  ON public.musubi_research_events;
CREATE POLICY musubi_events_insert_with_active_consent
  ON public.musubi_research_events
  FOR INSERT TO authenticated
  WITH CHECK (
    user_id = auth.uid()
    AND EXISTS (
      SELECT 1
      FROM public.musubi_research_feedback feedback
      WHERE feedback.user_id = auth.uid()
        AND feedback.consent_to_research
        AND feedback.cohort = musubi_research_events.cohort
        AND feedback.consent_version = musubi_research_events.consent_version
    )
  );

DROP POLICY IF EXISTS musubi_events_delete_own
  ON public.musubi_research_events;
CREATE POLICY musubi_events_delete_own
  ON public.musubi_research_events
  FOR DELETE TO authenticated
  USING (user_id = auth.uid());

COMMENT ON COLUMN public.musubi_research_feedback.consent_version IS
  'Version of the disclosure accepted before research data is stored.';
COMMENT ON COLUMN public.musubi_research_events.consent_version IS
  'Consent disclosure version active when the event was recorded.';
