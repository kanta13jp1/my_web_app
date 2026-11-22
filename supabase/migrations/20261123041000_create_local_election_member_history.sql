-- Persistent daily official local-election legislator count history (#4112).
-- Written exclusively by local-election-intelligence patrol (service_role)
-- and publicly readable for /local-election-700 and /public/local-election-700
-- trend charts so first-time visitors see historical progression immediately.

CREATE TABLE IF NOT EXISTS public.local_election_member_history (
  snapshot_date date PRIMARY KEY,
  fetched_at timestamptz NOT NULL,
  official_current_local_members integer NOT NULL
    CHECK (official_current_local_members > 0),
  actual_net_increase_required integer NOT NULL
    CHECK (actual_net_increase_required >= 0),
  source text NOT NULL DEFAULT 'local-election-intelligence',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS local_election_member_history_fetched_at_idx
  ON public.local_election_member_history (fetched_at DESC);

ALTER TABLE public.local_election_member_history ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.local_election_member_history
  FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.local_election_member_history
  TO anon, authenticated;
GRANT ALL ON public.local_election_member_history
  TO service_role;

DROP POLICY IF EXISTS local_election_member_history_public_read
  ON public.local_election_member_history;
CREATE POLICY local_election_member_history_public_read
  ON public.local_election_member_history
  FOR SELECT
  TO anon, authenticated
  USING (true);

DROP POLICY IF EXISTS local_election_member_history_service_write
  ON public.local_election_member_history;
CREATE POLICY local_election_member_history_service_write
  ON public.local_election_member_history
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- Idempotently backfill historical daily points already stored in hub_data.
DO $$
BEGIN
  IF to_regclass('public.hub_data') IS NOT NULL THEN
    INSERT INTO public.local_election_member_history (
      snapshot_date,
      fetched_at,
      official_current_local_members,
      actual_net_increase_required,
      source
    )
    SELECT DISTINCT ON (candidate.snapshot_date)
      candidate.snapshot_date,
      candidate.fetched_at,
      candidate.official_current_local_members,
      candidate.actual_net_increase_required,
      'hub_data_backfill'
    FROM (
      SELECT
        (
          (
            CASE
              WHEN COALESCE(metadata->>'observed_at', '')
                ~ '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$'
                THEN (metadata->>'observed_at')::timestamptz
              ELSE COALESCE(created_at, now())
            END
          ) AT TIME ZONE 'Asia/Tokyo'
        )::date AS snapshot_date,
        CASE
          WHEN COALESCE(metadata->>'observed_at', '')
            ~ '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$'
            THEN (metadata->>'observed_at')::timestamptz
          ELSE COALESCE(created_at, now())
        END AS fetched_at,
        (
          COALESCE(
            NULLIF(
              metadata->'snapshot'->'metrics'->>'officialCurrentLocalMembers',
              ''
            ),
            NULLIF(metadata->'snapshot'->>'officialCurrentLocalMembers', '')
          )
        )::integer AS official_current_local_members,
        CASE
          WHEN COALESCE(
            NULLIF(
              metadata->'snapshot'->'metrics'->>'actualNetIncreaseRequired',
              ''
            ),
            NULLIF(metadata->'snapshot'->>'actualNetIncreaseRequired', ''),
            ''
          ) ~ '^[0-9]+$'
            THEN (
              COALESCE(
                NULLIF(
                  metadata->'snapshot'->'metrics'->>'actualNetIncreaseRequired',
                  ''
                ),
                NULLIF(metadata->'snapshot'->>'actualNetIncreaseRequired', '')
              )
            )::integer
          ELSE GREATEST(
            0,
            700 - (
              COALESCE(
                NULLIF(
                  metadata->'snapshot'->'metrics'->>'officialCurrentLocalMembers',
                  ''
                ),
                NULLIF(metadata->'snapshot'->>'officialCurrentLocalMembers', '')
              )
            )::integer
          )
        END AS actual_net_increase_required
      FROM public.hub_data
      WHERE source = 'local_election_dataset_snapshot'
        AND COALESCE(metadata->>'dataset', '') =
          'kokumin_local_election_intelligence'
        AND COALESCE(
          NULLIF(
            metadata->'snapshot'->'metrics'->>'officialCurrentLocalMembers',
            ''
          ),
          NULLIF(metadata->'snapshot'->>'officialCurrentLocalMembers', ''),
          ''
        ) ~ '^[0-9]+$'
    ) AS candidate
    WHERE candidate.official_current_local_members > 0
    ORDER BY candidate.snapshot_date, candidate.fetched_at DESC
    ON CONFLICT (snapshot_date) DO NOTHING;
  END IF;
END
$$;
