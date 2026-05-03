-- Scheduled Daily S3 (2026-05-03 06:00 UTC):
-- Standalone tech blog drafts for the agent_tool_policy server gate
-- (deny-by-default scope gate + CEO approval), fulfilling the next-action
-- candidate logged in Scheduled Daily S2 (2026-05-02). Drafts pair with the
-- prior MCP AuthKit metadata posts as declaration / enforcement structure
-- and reinforce Rule 27 #5 (Scope) and #7 (Audit).

INSERT INTO public.development_achievements (title, description, completed_at)
SELECT
  'Scheduled Daily S3: agent_tool_policy server gate blog drafts (JA + EN)',
  'Drafted standalone JA / EN technical blog posts on the deny-by-default agent tool policy gate added to ai-hub. Covers the 9-scope enum + 5 high-risk subset, per-role default scopes, three-way blockedReason taxonomy (empty_requested_scope / missing_scope / approval_required), the agent.tool_policy.evaluate dry-run vs agent.run fail-close pair, and the partial index on requires_approval=true in agent_tool_execution_logs. Frames metadata + gate as a declaration / enforcement pair to reinforce Rule 27 #5 (Scope) and #7 (Audit).',
  '2026-05-03'
WHERE NOT EXISTS (
  SELECT 1 FROM public.development_achievements
  WHERE title = 'Scheduled Daily S3: agent_tool_policy server gate blog drafts (JA + EN)'
);
