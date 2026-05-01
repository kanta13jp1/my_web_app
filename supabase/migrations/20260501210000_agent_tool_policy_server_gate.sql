-- WBS update / Issue #846: server-side AI officer tool policy gate.
--
-- This extends the existing fail-close audit table so Edge Functions can record
-- the same scope and CEO approval decision that the client-side AgentOrg guard
-- already logs in payload JSON.

ALTER TABLE public.agent_tool_execution_logs
  ADD COLUMN IF NOT EXISTS actor_role text,
  ADD COLUMN IF NOT EXISTS requested_scopes text[] NOT NULL DEFAULT '{}'::text[],
  ADD COLUMN IF NOT EXISTS allowed_scopes text[],
  ADD COLUMN IF NOT EXISTS high_risk_scopes text[] NOT NULL DEFAULT '{}'::text[],
  ADD COLUMN IF NOT EXISTS requires_approval boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS approval_decision text,
  ADD COLUMN IF NOT EXISTS approved_by text,
  ADD COLUMN IF NOT EXISTS approved_at timestamptz,
  ADD COLUMN IF NOT EXISTS side_effects text,
  ADD COLUMN IF NOT EXISTS evaluated_at timestamptz NOT NULL DEFAULT now();

CREATE INDEX IF NOT EXISTS idx_agent_tool_execution_logs_policy_blocked
  ON public.agent_tool_execution_logs(user_id, requires_approval, allowed, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_agent_tool_execution_logs_high_risk
  ON public.agent_tool_execution_logs(user_id, created_at DESC)
  WHERE requires_approval = true;

COMMENT ON COLUMN public.agent_tool_execution_logs.actor_role IS
  'Normalized AI officer role used by the server-side tool policy gate.';
COMMENT ON COLUMN public.agent_tool_execution_logs.requested_scopes IS
  'Normalized requested tool scopes such as read, suggest, create, update, delete, send, purchase, external_share.';
COMMENT ON COLUMN public.agent_tool_execution_logs.high_risk_scopes IS
  'Requested scopes that require explicit CEO approval before execution.';
COMMENT ON COLUMN public.agent_tool_execution_logs.approval_decision IS
  'CEO approval state attached to the execution request: approved, pending, or rejected.';

UPDATE public.wbs_tasks
SET status = 'in_progress',
    progress = GREATEST(progress, 35),
    recovery_plan = COALESCE(
      NULLIF(trim(recovery_plan), ''),
      'Server-side AI officer tool policy gate implemented in ai-hub; remaining work is approval UI and broader external tool wiring.'
    ),
    recovery_planned_at = COALESCE(recovery_planned_at, NOW()),
    description = COALESCE(description, '') ||
      E'\n\n[Codex #4 2026-05-01] Issue #846 advanced: ai-hub now exposes agent.tool_policy.evaluate and agent.run fail-closes before queueing when requested scopes are missing or high-risk scopes lack CEO approval. agent_tool_execution_logs gained explicit scope / approval audit columns.'
WHERE github_issue_number = 846;

INSERT INTO public.development_achievements (title, description, completed_at)
SELECT
  'Codex #4: AI officer tool policy server gate (#846)',
  'Added server-side scope and CEO approval evaluation to ai-hub. agent.tool_policy.evaluate logs every policy decision, and agent.run rejects tool execution intents before queueing when scopes are missing or high-risk actions lack approval. agent_tool_execution_logs now has explicit requested_scopes, high_risk_scopes, approval, and side_effect columns.',
  '2026-05-01'
WHERE NOT EXISTS (
  SELECT 1 FROM public.development_achievements
  WHERE title = 'Codex #4: AI officer tool policy server gate (#846)'
);
