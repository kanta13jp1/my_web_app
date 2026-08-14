-- Observation-transition history for service-role local election snapshots.
-- The queue itself uses the shared x_post_candidate candidate_key index.

DROP INDEX IF EXISTS public.hub_data_local_election_snapshot_hash_unique;

CREATE UNIQUE INDEX IF NOT EXISTS hub_data_local_election_snapshot_transition_unique
  ON public.hub_data (
    (metadata->>'dataset'),
    (COALESCE(metadata->>'previous_snapshot_id', '__baseline__')),
    (metadata->>'snapshot_hash')
  )
  WHERE source = 'local_election_dataset_snapshot'
    AND COALESCE(metadata->>'dataset', '') <> ''
    AND COALESCE(metadata->>'snapshot_hash', '') <> '';

CREATE INDEX IF NOT EXISTS hub_data_local_election_snapshot_dataset_created_idx
  ON public.hub_data (
    (metadata->>'dataset'),
    created_at DESC
  )
  WHERE source = 'local_election_dataset_snapshot';

COMMENT ON INDEX public.hub_data_local_election_snapshot_transition_unique IS
  'Deduplicates retries of one predecessor/current-hash transition while allowing non-consecutive state reversions.';
