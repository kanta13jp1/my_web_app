-- Add AI source URL HTTP verification status and manual review flags to competitor_candidates (#2698)

ALTER TABLE public.competitor_candidates
  ADD COLUMN IF NOT EXISTS source_url_status_code integer,
  ADD COLUMN IF NOT EXISTS source_url_checked_at timestamptz,
  ADD COLUMN IF NOT EXISTS source_url_error text,
  ADD COLUMN IF NOT EXISTS needs_manual_review boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS review_decision text NOT NULL DEFAULT 'pending';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'competitor_candidates_review_decision_check'
  ) THEN
    ALTER TABLE public.competitor_candidates
      ADD CONSTRAINT competitor_candidates_review_decision_check
      CHECK (review_decision IN ('pending', 'approved', 'rejected'));
  END IF;
END;
$$;

CREATE INDEX IF NOT EXISTS idx_competitor_candidates_manual_review
  ON public.competitor_candidates (needs_manual_review, review_decision, staged_at DESC);
