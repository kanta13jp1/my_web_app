# Managed MCP Access Control

Status: active / 2026-05-08 / Issue #1586

The active development model is Claude Code #1 plus Codex #1 only. Historical
Codex #2, Codex #3, PS, WEB, mobile, Gemini, and Copilot labels are routing
metadata, not live instances.

## Delegation Packet

- WBS / Issue: #1586 managed-mcp.json MCP server organization access control
- Due date: 2026-05-16
- Current owner: Codex #1 implementation; Claude Code #1 policy and review boundary
- Branch: codex/codex1-managed-mcp-policy-1586
- Worktree: C:\Users\kanta\GitHub\my_web_app_wbs_sync
- Allowed write set: config/managed-mcp.json, scripts/check_managed_mcp_policy.py, scripts/check_managed_mcp_policy_test.py, scripts/codex_session_check.py, docs/automation/managed-mcp-access-control.md, docs/AGENT_TOOL_POLICY.md, AGENTS.md, .github/workflows/managed-mcp-policy.yml
- Prohibited write set: secrets, local credentials, production data, unrelated Flutter UI, Supabase migrations/functions
- Required validation: managed MCP policy test, codex session JSON check, two-instance audit, minimal E2E gate test, no hook-bypass marker check, GitHub Actions green
- Expected output: scoped PR, CI evidence, merged branch cleanup, Issue completion comment
- Risk triggers that must return to Claude Code: new write-capable MCP server, production credential access, outbound Slack/Gmail/Drive writes, denied server exception, auth model change
- Memory/disk hygiene action for this session: check C: free space and process pressure before/after; prune worktrees and git gc after merge

## Managed Register

The authoritative register is `config/managed-mcp.json`.

- `allowedMcpServers` records purpose, permissions, data classification,
  approver, human-approval scopes, audit log, auth status, and allow reason.
- `deniedMcpServers` records denied aliases, reason, approver, and review date.
- `defaultDecision` is `deny`, so any server not recorded in either list is
  unmanaged and must trigger a session-start warning.

Required issue #1586 integrations are present in the register: GitHub, Notion,
Slack, Google Drive, NotebookLM, and Context7. Related Google Calendar, Gmail,
Playwright, Browser Use, Claude Memory, and local document runtimes are also
recorded because they appear in the active Codex/Claude tool surface.

Issue #1645 adds a companion isolation contract for external MCP execution:

- `config/mcp-container-isolation.json` records the execution form,
  permissions, audit log, and failure fallback for representative MCP lanes.
- `docs/MCP_CONTAINER_ISOLATION_RUNBOOK.md` is the human-readable runbook.
- `scripts/check_mcp_container_isolation.py` validates that high-risk scopes
  still reference `docs/AGENT_TOOL_POLICY.md` and that the low-risk Docker PoC
  has no network, ports, secrets, host volumes, or writable root filesystem.

The managed register remains authoritative for allow/deny classification. The
container contract describes how an approved or read-only lane should execute;
it does not grant permission to use an unmanaged or denied server.

## Session-Start Gate

`scripts/codex_session_check.py` now includes a Managed MCP Policy section. It
imports `scripts/check_managed_mcp_policy.py` and scans repo settings plus local
Claude/Codex settings when available.

Warnings are emitted for:

- active servers not listed in `allowedMcpServers` or `deniedMcpServers`
- active servers that are explicitly denied
- NotebookLM/connector auth cache entries that report re-authentication needed
- dangerous local permission settings such as bypass mode, elevated sandbox,
  destructive process/file commands, or credential-printing command patterns

The session check is intentionally warning-first. CI validates the managed JSON
deterministically, while local sessions surface risk without printing secrets.

## Human Approval And Audit

High-privilege SaaS operations remain human-approved:

- Slack/Gmail sends, external shares, deletes, and bulk exports require explicit
  user approval and must cite a permalink or thread reference.
- GitHub merges, branch deletes, and admin writes require PR/issue timeline
  evidence.
- Drive/Docs/Sheets/Slides writes require target-document readback and a
  recorded issue/PR link.
- Production database or service-role access is denied as a direct MCP path and
  must go through reviewed scripts, GitHub Actions, or an explicit runbook.

Adding or changing a server requires a PR that updates the JSON register, this
document when policy changes, and the managed MCP policy CI gate.
