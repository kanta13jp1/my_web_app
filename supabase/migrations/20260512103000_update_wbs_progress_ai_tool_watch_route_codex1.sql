-- Codex #1: Issue #1559 AI Tool Watch route-to-issue bridge.
--
-- This records the scoped hand-off implementation that connects daily official
-- source changes to GitHub Issues, WBS Sync, and two-instance PR skeletons.

UPDATE public.wbs_tasks
SET status = 'in_progress',
    progress = GREATEST(progress, 55),
    recovery_plan = COALESCE(
      NULLIF(trim(recovery_plan), ''),
      'Codex #1 added daily AI Tool Watch route-to-issue automation. Remaining work: review generated adoption issues, implement accepted low-risk PR skeletons, and close #1559 when the broader routing loop is accepted.'
    ),
    recovery_planned_at = COALESCE(recovery_planned_at, NOW()),
    description = COALESCE(description, '') ||
      E'\n\n[Codex #1 / 2026-05-12] Issue #1559 advanced: daily AI Tool Watch can now create/update a deduplicated GitHub Issue, write a two-instance handoff draft, write a PR skeleton draft, and rely on GitHub Issues WBS Sync as the WBS write path.'
WHERE github_issue_number = 1559;

INSERT INTO public.development_achievements (title, description, completed_at)
SELECT
  'Codex #1: AI Tool Watch route-to-issue bridge (#1559)',
  'Added scripts/ai_tool_watch_route.py plus workflow wiring so high-priority official AI tool changes become a GitHub Issue, WBS-syncable route, two-instance handoff draft, and PR skeleton draft without starting dormant Codex #2/#3 lanes.',
  '2026-05-12'
WHERE NOT EXISTS (
  SELECT 1 FROM public.development_achievements
  WHERE title = 'Codex #1: AI Tool Watch route-to-issue bridge (#1559)'
);
