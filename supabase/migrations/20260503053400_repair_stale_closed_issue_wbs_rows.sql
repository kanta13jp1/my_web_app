-- Codex #1 / 2026-05-03:
-- Backfill known stale GitHub-closed WBS mirrors reported in #1648/#1687.
--
-- The durable fix lives in tools-hub:wbs.sync_github_issues. This migration is
-- intentionally narrow so the already-observed stale rows stop blocking the
-- top WBS priority list on the next production deploy.

UPDATE public.wbs_tasks
SET status = 'completed',
    progress = 100,
    github_issue_state = 'CLOSED',
    github_issue_synced_at = NOW(),
    ai_review_status = COALESCE(ai_review_status, 'pending'),
    remaining_work = 'GitHub Issue is closed; Codex #1 backfill mirrored this WBS row as completed.',
    recovery_plan = COALESCE(
      NULLIF(recovery_plan, ''),
      'Backfilled by migration 20260503053400 after GitHub closed-state drift was detected.'
    ),
    recovery_planned_at = COALESCE(recovery_planned_at, NOW())
WHERE status <> 'completed'
  AND (
    github_issue_number IN (1270, 1272, 1274)
    OR title ~* '^\[Issue #(1270|1272|1274)\]'
  );

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'Codex #1: repaired stale closed GitHub Issue WBS mirrors',
  'Backfilled known stale WBS rows for closed GitHub Issues #1270, #1272, and #1274 while hardening tools-hub sync to repair future title/metadata drift.',
  '2026-05-03'
)
ON CONFLICT DO NOTHING;
