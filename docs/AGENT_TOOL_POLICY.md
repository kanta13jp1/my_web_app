# Agent Tool Policy

This document tracks the first implementation slice for Issue #846: agent tool
execution scopes and CEO approval gates.

## Scope Model

- `read`: read data
- `suggest`: generate proposals or drafts
- `create`: create internal records
- `update`: update internal records
- `delete`: delete records
- `send`: send content externally
- `purchase`: purchase or pay
- `external_share`: publish to SNS, email, public URLs, or other external
  surfaces

`delete`, `send`, `purchase`, and `external_share` are high-risk scopes. They
fail closed unless explicit CEO approval metadata is attached.

## Role Defaults

- `ceo`: all scopes
- `cfo`: `read`, `suggest`, `create`, `update`
- `cmo`: `read`, `suggest`, `create`, `external_share`
- `cho`: `read`, `suggest`, `create`
- `chro`: `read`, `suggest`, `create`, `update`
- `legal`: `read`, `suggest`, `create`, `update`
- unknown role: `read`, `suggest`

## Integration Notes

`supabase/functions/_shared/agent_tool_policy.ts` is intentionally a pure
function layer with no database or external API dependency. The next integration
points are `agent_tool_execution_logs` and `mcp_auth_guard.ts`.

Before an Edge Function executes an external tool, it should call
`evaluateAgentToolPolicy()`. If `blockedReason` is present, the function should
skip execution and persist `auditPayload` to the audit log.

`ai-hub` now exposes the server-side gate as
`agent.tool_policy.evaluate`. Authenticated callers pass `actor_agent_id` or
`actor_role`, `tool_name`, `requested_scopes`, optional `allowed_scopes`,
optional `side_effects`, and optional `approval` metadata. The action writes a
row to `agent_tool_execution_logs` and returns HTTP 403 when a scope is missing
or a high-risk scope lacks CEO approval.

`agent.run` also uses the same gate when a request includes `tool_name` or
`requested_scopes`, so execution intents fail closed before they are queued.
Existing simple `agent.run` calls without tool metadata keep their old behavior.

`mcp_auth_guard.logMcpInvocation()` now writes MCP calls to `mcp_audit_log`
through the Supabase service role when runtime secrets are present, and falls
back to structured console logging in local/test environments. This gives the
approval gate work a durable server-side audit trail before high-risk tool
actions such as `send`, `purchase`, and `external_share` are wired to blocking
CEO approval screens.

This follows the Harness Engineering direction from NotebookLM
`bc58b50b-5fc4-4840-9a62-b397d6d3b65a`: Claude Code, Codex, and external AI
agents should operate inside explicit scopes, approval gates, and audit logs.

## Managed MCP Server Control

Issue #1586 adds a repo-managed MCP access register:

- authoritative config: `config/managed-mcp.json`
- policy notes: `docs/automation/managed-mcp-access-control.md`
- deterministic checker: `scripts/check_managed_mcp_policy.py`

The default decision is deny. Any MCP server or plugin connector that is not in
`allowedMcpServers` or `deniedMcpServers` must be treated as unmanaged at
session start. Allowed entries must record purpose, permissions, data
classification, approver, human-approval scopes, audit log, and reason. Denied
entries must record a denial reason and review date.

`scripts/codex_session_check.py` includes the managed MCP snapshot so local
sessions warn on unmanaged servers, denied servers, expired or auth-required
connectors, and dangerous permission settings. CI validates the JSON register
without reading local secrets.
