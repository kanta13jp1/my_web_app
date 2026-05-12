-- Codex #1 / 2026-05-11:
-- The first WBS duplicate cleanup handled rows mirrored from the same GitHub
-- Issue. Production still had non-Issue WBS rows duplicated across owner lanes
-- with the same title, so "unfinished only" kept showing repeated actionable
-- tasks. Keep one canonical active row per normalized non-Issue title and mark
-- the rest completed as duplicate bookkeeping rows.

WITH candidate_rows AS (
  SELECT
    task.id,
    task.title,
    task.status,
    task.progress,
    task.remaining_work,
    task.recovery_plan,
    task.created_at,
    task.updated_at,
    lower(
      btrim(
        regexp_replace(
          regexp_replace(
            task.title,
            '^[[:space:]]*\[Issue #[0-9]+\][[:space:]]*',
            '',
            'i'
          ),
          '[[:space:]]+',
          ' ',
          'g'
        )
      )
    ) AS title_key
  FROM public.wbs_tasks AS task
  WHERE
    task.title IS NOT NULL
    AND NULLIF(task.github_issue_number, 0) IS NULL
    AND task.title !~* '^[[:space:]]*\[Issue #[0-9]+\]'
    AND COALESCE(task.github_issue_url, '') !~* 'issues/[0-9]+'
),
ranked AS (
  SELECT
    candidate_rows.*,
    COUNT(*) FILTER (
      WHERE candidate_rows.status IS DISTINCT FROM 'completed'
    ) OVER (PARTITION BY candidate_rows.title_key) AS unfinished_count,
    ROW_NUMBER() OVER (
      PARTITION BY candidate_rows.title_key
      ORDER BY
        CASE WHEN candidate_rows.status = 'completed' THEN 1 ELSE 0 END,
        CASE
          WHEN lower(
            COALESCE(candidate_rows.remaining_work, '') || ' ' ||
            COALESCE(candidate_rows.recovery_plan, '')
          ) LIKE '%duplicate%' THEN 1
          ELSE 0
        END,
        candidate_rows.progress DESC NULLS LAST,
        candidate_rows.updated_at DESC NULLS LAST,
        candidate_rows.created_at ASC NULLS LAST,
        candidate_rows.id ASC
    ) AS rn
  FROM candidate_rows
  WHERE candidate_rows.title_key <> ''
),
duplicates AS (
  SELECT
    duplicate.id,
    duplicate.title,
    keeper.id AS keeper_id
  FROM ranked AS duplicate
  JOIN ranked AS keeper
    ON keeper.title_key = duplicate.title_key
   AND keeper.rn = 1
  WHERE
    duplicate.rn > 1
    AND duplicate.unfinished_count > 1
    AND duplicate.status IS DISTINCT FROM 'completed'
)
UPDATE public.wbs_tasks AS task
SET
  status = 'completed',
  progress = 100,
  ai_review_status = 'pending',
  remaining_work = CASE
    WHEN lower(COALESCE(task.remaining_work, '')) LIKE '%duplicate%' THEN task.remaining_work
    ELSE 'Duplicate WBS title; kept WBS task ' || duplicates.keeper_id ||
      ' as canonical for "' || left(duplicates.title, 120) || '".'
  END,
  recovery_plan = COALESCE(
    NULLIF(task.recovery_plan, ''),
    'Completed as a duplicate WBS title by migration 20260511033000.'
  ),
  recovery_planned_at = COALESCE(task.recovery_planned_at, NOW())
FROM duplicates
WHERE task.id = duplicates.id;

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'Codex #1: completed duplicate non-Issue WBS title rows',
  'Marked non-canonical active WBS rows with the same normalized title as completed duplicate rows so the unfinished WBS timeline keeps one actionable row per task title.',
  '2026-05-11'
)
ON CONFLICT DO NOTHING;
