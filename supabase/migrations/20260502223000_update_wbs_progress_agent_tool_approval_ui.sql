-- WBS update / Issue #846: CEO approval screen for high-risk AI officer tools.

UPDATE public.wbs_tasks
SET status = 'in_progress',
    progress = GREATEST(progress, 60),
    recovery_plan = 'Approval UI is now implemented as /agent-tool-approvals. Remaining work is authenticated smoke with a real JWT, broader external tool execution wiring, and production deploy evidence.',
    recovery_planned_at = COALESCE(recovery_planned_at, NOW()),
    remaining_work = 'Run authenticated ai-hub:agent.tool_policy.evaluate smoke, wire more external tool paths into the policy gate, and verify approval/denial rows in agent_tool_execution_logs.',
    description = COALESCE(description, '') ||
      E'\n\n[Codex #1 2026-05-02] Issue #846 advanced: added /agent-tool-approvals so CEO can review high-risk AI officer tool requests, inspect actor/tool/scopes/side effects/payload, approve or reject, and copy approval metadata for the next server-side execution attempt.'
WHERE github_issue_number = 846;

INSERT INTO public.development_achievements (title, description, completed_at)
SELECT
  'Codex #1: AI officer tool approval UI (#846)',
  'Added /agent-tool-approvals, a CEO approval and audit screen for agent_tool_execution_logs. The page displays pending high-risk tool requests, requested scopes, side effects, payload previews, approve/reject decisions, and copyable approval metadata for server-side ai-hub policy evaluation.',
  '2026-05-02'
WHERE NOT EXISTS (
  SELECT 1
  FROM public.development_achievements
  WHERE title = 'Codex #1: AI officer tool approval UI (#846)'
);
