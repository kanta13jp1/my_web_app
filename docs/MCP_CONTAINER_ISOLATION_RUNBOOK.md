# MCP Container Isolation Runbook

Status: active / 2026-05-11 / Issue #1645

This runbook defines the Codex #1 implementation slice for Docker MCP Toolkit /
Dynamic MCP isolation. It keeps the active execution model at Claude Code #1
plus Codex #1 only, and treats historical extra Codex lanes as routing metadata.

Docker documents MCP Catalog and Toolkit as the Docker Desktop path for browsing
and running MCP servers, and Dynamic MCP as the catalog/gateway feature that can
discover tools during a session:

- https://docs.docker.com/ai/mcp-catalog-and-toolkit/
- https://docs.docker.com/ai/mcp-catalog-and-toolkit/dynamic-mcp/

## Execution Matrix

| MCP server or lane | Execution form | Permissions | Audit log | Failure fallback |
| --- | --- | --- | --- | --- |
| `context7-docs` | Docker MCP catalog read-only container preferred; hosted read-only connector fallback. | `read`, `suggest` | Issue/PR note with package, docs source, and lookup summary. | Use checked-in docs or skip lookup; no unregistered host shell fallback. |
| `tools-hub-read-facade` | Supabase Edge Function MCP facade with container-smoke contract for local read-only MCP fixtures. | `read`, `suggest`, `create` | tools-hub MCP smoke workflow, `schedule_task_runs`, and PR/issue validation note. | Use tools-hub MCP smoke in GitHub Actions or keep `feature_request.create` disabled. |
| `playwright-browser` | Containerized browser session or in-app browser without credential entry unless approved. | `read`, `suggest`, `browser_interact` | Browser URL, screenshot or console evidence, and PR validation summary. | Skip browser evidence and state the validation gap when no isolated browser is available. |
| `slack-gmail-outbound` | Read/draft connector by default; outbound send blocked until approval metadata exists. | `read`, `suggest`, `send`, `external_share` | Permalink/thread reference, explicit user approval, and issue/PR note. | Keep draft local and do not send. |
| `direct-production-db` | Denied as direct MCP. Use reviewed Supabase scripts, GitHub Actions, or explicit runbook instead. | `credential_access`, `production_write` | Denied request recorded in issue/PR notes; no production credential exposed to MCP. | Fail closed. |

The authoritative machine-readable contract is
`config/mcp-container-isolation.json`.

## Dynamic MCP Flow

1. Discover the requested external tool from the issue, PR, or session prompt.
2. Classify the requested scopes against `docs/AGENT_TOOL_POLICY.md` and
   `config/managed-mcp.json`.
3. Require CEO approval metadata for high-risk scopes before launch.
4. Prefer isolated container execution with least privilege, no host secrets,
   and no ambient writable mounts.
5. Record workflow run, issue comment, PR summary, or durable MCP audit row.
6. Fall back to read-only documented paths or fail closed.

## Low-Risk PoC

The PoC is `tools/mcp-container-isolation/mcp_stdio_ping.py`, a tiny read-only
JSON-RPC stdio MCP fixture. It exposes one tool, `echo.ping`, and does not need
network, secrets, ports, or writable host mounts.

Local validation:

```powershell
python scripts/check_mcp_container_isolation.py
python scripts/check_mcp_container_isolation_test.py
```

Docker launch when Docker is available:

```powershell
python scripts/check_mcp_container_isolation.py --run-docker --require-docker
```

The Docker Compose service enforces:

- `network_mode: none`
- `read_only: true`
- `cap_drop: ALL`
- `no-new-privileges:true`
- no `ports`, no `volumes`, no compose `secrets`
- non-root `USER mcp`

## Approval Gate Compatibility

The high-risk scopes `delete`, `send`, `purchase`, and `external_share` retain
the existing fail-closed CEO approval gate from `docs/AGENT_TOOL_POLICY.md`.
This runbook also treats `credential_access`, `shell_execute`,
`filesystem_write`, and `production_write` as high-risk MCP launch scopes.

`scripts/check_mcp_container_isolation.py` fails when a high-risk permission is
listed without a matching `approvalRequiredFor` entry or when an entry bypasses
the Agent Tool Policy gate.
