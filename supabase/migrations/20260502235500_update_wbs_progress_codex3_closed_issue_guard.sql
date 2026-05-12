-- Codex #3 / 2026-05-02: complete Issue #1605 WBS closed GitHub Issue guard.
--
-- tools-hub:wbs.priority_for_instance, wbs.instance_workload, and
-- wbs.rebalance_suggest now ignore active-looking WBS rows whose mirrored
-- GitHub Issue state is CLOSED. This keeps stale closed Issue mirrors out of
-- session-start task routing while issue-to-wbs performs the durable sync.

UPDATE public.wbs_tasks
SET status = 'completed',
    progress = 100,
    ai_review_status = 'approved',
    remaining_work = 'Implemented in tools-hub: closed GitHub Issue mirrors are excluded from priority_for_instance and rebalance candidate outputs; GitHub Actions logs include exclusion counts.',
    recovery_plan = 'Closed GitHub Issue mirrors are filtered before WBS priority and rebalance scoring. The existing issue-to-wbs sync remains the durable source for completing mirrored WBS rows.',
    recovery_planned_at = COALESCE(recovery_planned_at, NOW()),
    description = COALESCE(description, '') ||
      E'\n\n[Codex #3 / 2026-05-02] Added closed GitHub Issue filtering to tools-hub WBS priority/rebalance actions so stale CLOSED mirrors no longer appear as next work.'
WHERE github_issue_number = 1605
   OR title ILIKE '%closed GitHub Issue%'
   OR title ILIKE '%priority_for_instance%closed%';

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'Codex #3: WBS closed Issue priority guard',
  'Filtered CLOSED GitHub Issue mirrors out of tools-hub WBS priority and rebalance routing, with response counts for scheduled-run audit evidence.',
  '2026-05-02'
)
ON CONFLICT DO NOTHING;
