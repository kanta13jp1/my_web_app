-- WBS update / Codex #3: AI Tool Watch route-to-issue automation.
--
-- This advances Issue #1559 by adding a deterministic bridge from the daily
-- official-source watch report to GitHub Issues, WBS sync, and cross-instance
-- handoff drafts.

UPDATE public.wbs_tasks
SET status = 'in_progress',
    progress = GREATEST(progress, 30),
    recovery_plan = COALESCE(
      NULLIF(trim(recovery_plan), ''),
      'Codex #3 added scripts/ai_tool_watch_route.py and wired ai-tool-watch.yml to create deduplicated GitHub issues plus cross-instance handoff drafts. Remaining work: run the scheduled workflow once and extend routing to PR draft creation if needed.'
    ),
    recovery_planned_at = COALESCE(recovery_planned_at, NOW()),
    description = COALESCE(description, '') ||
      E'\n\n[Codex #3 / 2026-05-02] Issue #1559 advanced: daily AI Tool Watch can now route changed high-priority official Claude Code/Codex signals into one deduplicated GitHub Issue and a docs/cross-instance-prs handoff draft. The existing issue-to-WBS workflow remains the WBS write path.'
WHERE github_issue_number = 1559;

INSERT INTO public.development_achievements (title, description, completed_at)
SELECT
  'Codex #3: AI Tool Watch route-to-issue bridge (#1559)',
  'Added scripts/ai_tool_watch_route.py and wired .github/workflows/ai-tool-watch.yml so high-priority official Claude Code/Codex changes become a GitHub Issue plus cross-instance handoff draft, allowing issue-to-WBS sync to keep the backlog current without service-role credentials in the watcher.',
  '2026-05-02'
WHERE NOT EXISTS (
  SELECT 1 FROM public.development_achievements
  WHERE title = 'Codex #3: AI Tool Watch route-to-issue bridge (#1559)'
);
