# tools-hub MCP Smoke Runbook

This runbook covers the deterministic smoke path for the `tools-hub` MCP
facade added under the MCP/AuthKit WBS track. It is meant to support Issue
#1608 and the NotebookLM harness rule for `bc58b50b-5fc4-4840-9a62-b397d6d3b65a`:
Claude Code designs the environment, Codex executes scoped changes, and GitHub
Actions proves the result.

## Local command

Metadata and unauthenticated auth-gate checks only:

```powershell
.\scripts\tools_hub_mcp_smoke.ps1 `
  -BaseUrl "https://<project>.supabase.co/functions/v1/tools-hub" `
  -SkipRegistration
```

Authenticated read check. The token must be valid for the tools-hub MCP
resource and include `read` or `wbs.tasks.list` access.

```powershell
$env:MCP_BEARER_TOKEN = "<WorkOS/AuthKit access token>"
.\scripts\tools_hub_mcp_smoke.ps1 `
  -BaseUrl "https://<project>.supabase.co/functions/v1/tools-hub" `
  -SkipRegistration
```

Audit-log proof is automatic when the script can see both `SUPABASE_URL` and
`SUPABASE_SERVICE_ROLE_KEY`. It verifies that the current smoke run produced
the expected `mcp_audit_log` row for each executed tool-call status. Without
those values, the HTTP smoke still runs and prints an explicit audit skip.

Authenticated write confirmation gate check. The token must include `create` or
`feature_request.create` access. This intentionally omits `confirm=true`; it
must return HTTP 409 and must not create a WBS row.

```powershell
$env:MCP_BEARER_TOKEN = "<WorkOS/AuthKit access token>"
.\scripts\tools_hub_mcp_smoke.ps1 `
  -BaseUrl "https://<project>.supabase.co/functions/v1/tools-hub" `
  -SkipRegistration `
  -EnableWriteConfirmationProbe
```

Dynamic Client Registration check. This creates a test row in
`mcp_oauth_clients`, so use it only against the intended environment.

```powershell
.\scripts\tools_hub_mcp_smoke.ps1 `
  -BaseUrl "https://<project>.supabase.co/functions/v1/tools-hub" `
  -RegistrationRedirectUri "http://localhost:39123/callback"
```

## GitHub Actions

The same smoke path is wired to
`.github/workflows/tools-hub-mcp-smoke.yml`.

Scheduled runs execute every 6 hours against the production `tools-hub` URL and
record `schedule_task_runs` when `SUPABASE_SERVICE_ROLE_KEY` is configured.

Manual dispatch supports:

- `base_url`: override the `tools-hub` URL.
- `registration_redirect_uri`: create a DCR test client row only when supplied.
- `enable_write_confirmation_probe`: verify that `feature_request.create`
  without the confirmation phrase returns `confirmation_required`.

Secrets:

- `SUPABASE_SERVICE_ROLE_KEY`: records the schedule run summary.
- `SUPABASE_URL_PROD`: optional; defaults to the current production Supabase URL.
- `TOOLS_HUB_MCP_BEARER_TOKEN`: optional WorkOS/AuthKit-issued token for
  authenticated read/write-gate checks.

When `SUPABASE_SERVICE_ROLE_KEY` is configured, the workflow also checks
`mcp_audit_log` through PostgREST for the statuses that were actually probed:
anonymous 401 by default, plus authenticated 200 and write-gate 409 when the
token/write probe inputs are available.

## Expected matrix

| Check | Expected |
| --- | --- |
| `GET /.well-known/oauth-protected-resource` | HTTP 200, `resource`, `read`, `create`, and tool scopes |
| JSON-RPC `tools/list` | HTTP 200 with `wbs.tasks.list`, `feature_request.create`, `user_tasks.list` |
| Unauthenticated JSON-RPC `tools/call` | HTTP 401 with `WWW-Authenticate: Bearer ...` |
| Audit row for unauthenticated call | `mcp_audit_log` row for `wbs.tasks.list` / 401 when service role is configured |
| Authenticated `wbs.tasks.list` | HTTP 200 with `structuredContent` |
| Audit row for authenticated read | `mcp_audit_log` row for `wbs.tasks.list` / 200 when token + service role are configured |
| `feature_request.create` without confirmation | HTTP 409 `confirmation_required` |
| Audit row for confirmation gate | `mcp_audit_log` row for `feature_request.create` / 409 when token + service role are configured |
| `POST /register` with loopback redirect URI | HTTP 201 with redacted client secret in logs |

## Automation path

1. Keep this PowerShell script as the Windows/manual probe for Codex sessions.
2. Use `tools-hub-mcp-smoke.yml` as the scheduled and manual GitHub Actions
   wrapper.
3. Store the Action result as a deployment artifact or Issue #1608 comment.
4. If Deno on Windows still panics during `deno test`, track that separately in
   Issue #1609 and keep this HTTP smoke as the deploy proof.

Related work: #845, #1194, #1577, #1608, #1609.
