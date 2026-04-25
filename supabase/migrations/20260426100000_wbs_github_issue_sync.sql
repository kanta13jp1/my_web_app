-- GitHub Issues <-> WBS sync metadata.
-- Adds stable issue linkage columns so scheduled sync can be idempotent.

ALTER TABLE public.wbs_tasks
  ADD COLUMN IF NOT EXISTS github_issue_number int,
  ADD COLUMN IF NOT EXISTS github_issue_url text,
  ADD COLUMN IF NOT EXISTS github_issue_state text,
  ADD COLUMN IF NOT EXISTS github_issue_labels text[] DEFAULT ARRAY[]::text[],
  ADD COLUMN IF NOT EXISTS github_issue_synced_at timestamptz;

CREATE INDEX IF NOT EXISTS idx_wbs_tasks_github_issue_number
  ON public.wbs_tasks (github_issue_number)
  WHERE github_issue_number IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_wbs_tasks_github_issue_state
  ON public.wbs_tasks (github_issue_state)
  WHERE github_issue_state IS NOT NULL;

WITH parsed AS (
  SELECT
    id,
    regexp_match(
      coalesce(title, '') || ' ' || coalesce(description, ''),
      '(?:github\.com/kanta13jp1/my_web_app/issues/|\[Issue #)([0-9]+)'
    ) AS match
  FROM public.wbs_tasks
  WHERE github_issue_number IS NULL
)
UPDATE public.wbs_tasks t
SET
  github_issue_number = (p.match)[1]::int,
  github_issue_url = coalesce(
    t.github_issue_url,
    'https://github.com/kanta13jp1/my_web_app/issues/' || (p.match)[1]
  ),
  github_issue_synced_at = coalesce(t.github_issue_synced_at, now())
FROM parsed p
WHERE t.id = p.id
  AND p.match IS NOT NULL;

COMMENT ON COLUMN public.wbs_tasks.github_issue_number IS
  'GitHub Issue number mirrored into WBS for idempotent issue sync.';
COMMENT ON COLUMN public.wbs_tasks.github_issue_url IS
  'Canonical GitHub Issue URL.';
COMMENT ON COLUMN public.wbs_tasks.github_issue_state IS
  'Last synced GitHub Issue state: OPEN/CLOSED.';
COMMENT ON COLUMN public.wbs_tasks.github_issue_labels IS
  'Last synced GitHub Issue labels.';
COMMENT ON COLUMN public.wbs_tasks.github_issue_synced_at IS
  'Last GitHub Issue <-> WBS sync timestamp.';

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'GitHub Issues <-> WBS sync metadata',
  'Added github_issue_number/url/state/labels/synced_at to wbs_tasks so GitHub Issues and WBS can sync idempotently.',
  '2026-04-26'
)
ON CONFLICT DO NOTHING;
