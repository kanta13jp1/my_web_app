-- WBS update / Codex #6 PowerShell: MCP AuthKit metadata + tools-hub MCP facade.
--
-- Applies the NotebookLM fleet rule for "Codex executes scoped changes,
-- GitHub Actions proves the result" to the overdue MCP_AUTH lane:
-- Issue #845: AI officer MCP OAuth/DCR auth hub
-- Issue #1194: WorkOS AuthKit backed MCP server and OAuth auth introduction

UPDATE public.wbs_tasks
SET status = CASE WHEN status = 'completed' THEN status ELSE 'in_progress' END,
    progress = GREATEST(progress, 78),
    recovery_plan = COALESCE(
      NULLIF(trim(recovery_plan), ''),
      'tools-hub now exposes OAuth protected resource metadata, a guarded MCP tools facade, DCR-style client registration, a PowerShell smoke runbook, and a scheduled GitHub Actions smoke workflow. Remaining work: WorkOS token issuance / consent wiring and authenticated external MCP client smoke test.'
    ),
    recovery_planned_at = COALESCE(recovery_planned_at, NOW()),
    remaining_work = 'Set TOOLS_HUB_MCP_BEARER_TOKEN with a WorkOS/AuthKit-issued token, run tools-hub-mcp-smoke.yml with the authenticated read/write probes, verify mcp_audit_log rows, then close after deployed smoke evidence.',
    description = COALESCE(description, '') ||
      E'\n\n[Codex #6 2026-05-02 JST] tools-hub now advertises /.well-known/oauth-protected-resource, accepts DCR-style client registration at /register or action=mcp.auth.register, lists WBS/user/feature-request tools, accepts MCP-style JSON-RPC tools/list and tools/call, enforces bearer scope checks via mcp_auth_guard, requires explicit confirmation for write tools, and has scripts/tools_hub_mcp_smoke.ps1 plus tools-hub-mcp-smoke.yml for repeatable smoke proof. Public prod smoke passed for metadata, tools/list, and unauthenticated 401 challenge; authenticated AuthKit token smoke remains.'
WHERE github_issue_number = 845;

UPDATE public.wbs_tasks
SET status = CASE WHEN status = 'completed' THEN status ELSE 'in_progress' END,
    progress = GREATEST(progress, 63),
    recovery_plan = COALESCE(
      NULLIF(trim(recovery_plan), ''),
      'WorkOS/AuthKit discovery metadata, DCR-style client registration, MCP facade smoke runbook, and scheduled smoke workflow are now wired around tools-hub. Remaining work: end-to-end AuthKit token flow.'
    ),
    recovery_planned_at = COALESCE(recovery_planned_at, NOW()),
    remaining_work = 'Provision or refresh a WorkOS/AuthKit-issued token for TOOLS_HUB_MCP_BEARER_TOKEN, run authenticated tools-hub-mcp-smoke.yml, and verify mcp_audit_log.',
    description = COALESCE(description, '') ||
      E'\n\n[Codex #6 2026-05-02 JST] AuthKit-oriented MCP metadata, guarded JSON-RPC tool facade, DCR-style client registration, PowerShell smoke script, and scheduled GitHub Actions smoke workflow were added as the first deployable slice. Public prod smoke passed without a bearer token for discovery and deny-by-default behavior.'
WHERE github_issue_number = 1194;

INSERT INTO public.development_achievements (title, description, completed_at)
SELECT
  'Codex #6: tools-hub MCP facade and AuthKit metadata',
  'Advanced overdue MCP_AUTH WBS work by exposing tools-hub OAuth protected resource metadata, DCR-style client registration, guarded MCP-style tools/list and tools/call support for WBS task listing, user task listing, and confirmed feature request creation. Added PowerShell and GitHub Actions smoke automation; public prod smoke passed for metadata, tool discovery, and unauthenticated Bearer challenge. ai_tool_watch was also refreshed from official Claude Code and OpenAI Codex sources for the session.',
  '2026-05-02'
WHERE NOT EXISTS (
  SELECT 1 FROM public.development_achievements
  WHERE title = 'Codex #6: tools-hub MCP facade and AuthKit metadata'
);
