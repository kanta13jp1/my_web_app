-- Shared approval queue for all X post candidate generators.
-- candidate_key is stable per owner so scheduled retries and concurrent workers
-- converge on one reviewable record without colliding across future operators.
CREATE UNIQUE INDEX IF NOT EXISTS idx_hub_data_x_post_candidate_key
  ON public.hub_data (
    (metadata->>'user_id'),
    (metadata->>'candidate_key')
  )
  WHERE source = 'x_post_candidate'
    AND NULLIF(metadata->>'candidate_key', '') IS NOT NULL;
