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

This follows the Harness Engineering direction from NotebookLM
`bc58b50b-5fc4-4840-9a62-b397d6d3b65a`: Claude Code, Codex, and external AI
agents should operate inside explicit scopes, approval gates, and audit logs.
