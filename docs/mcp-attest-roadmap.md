# MCP Attest Roadmap

> Issue: [#1577](https://github.com/kanta13jp1/my_web_app/issues/1577)
> Parent spec: [MCP_AUTH_HARDENING_SPEC.md](MCP_AUTH_HARDENING_SPEC.md)
> Status: AttestMCP is not a Phase 1 dependency. The app is now structured so attestation can be added without reopening the auth boundary.

## Current Stance

Phase 1 hardening relies on least-privilege OAuth clients, WorkOS-managed JWT validation, resource indicators, `.well-known/oauth-protected-resource`, and audit/anomaly detection.

AttestMCP-style verification becomes mandatory when the risk changes from "one public MCP example" to "multiple independent MCP servers with cross-server propagation risk".

## Adoption Triggers

Move from readiness to implementation when at least one trigger is met:

| Trigger | Reason |
|---|---|
| five or more MCP servers are production-active | capability drift becomes likely |
| one confirmed cross-server propagation incident | runtime audit alone is no longer enough |
| a third-party client requires an attestation manifest | integration compatibility |
| sampling is introduced | origin tagging and capability proof become mandatory |
| security review flags over-declared capabilities | least-privilege evidence is needed in CI |

Until then, keep the controls simple and inspectable.

## Readiness Already In Place

| Requirement | Current control |
|---|---|
| Explicit public metadata | `mcp-well-known` and per-function metadata requests |
| Stable tool identity | `urn:jibun:tool:<tool>` resource naming |
| Least-privilege scope checks | `requireScope(ctx, tool)` |
| Invocation audit | `logMcpInvocation` inserts into `mcp_audit_log` |
| Client lifecycle state | `mcp_oauth_clients.suspended` escape hatch |
| Sampling risk reduction | no sampling capability is declared |

## Roadmap

### Phase 0: Keep Manifests Human-Readable

For each MCP-facing Edge Function, keep the supported scopes and transport behavior visible in code. The function-local `.well-known` response is the source of truth until an attestation manifest exists.

### Phase 1: Generate Manifest Snapshots

Add a script that reads function metadata and emits a JSON manifest with:

- function name,
- resource URN,
- supported scopes,
- transport,
- sampling capability state,
- audit table target,
- owner issue/spec link.

Run it in CI as a no-write check first.

### Phase 2: Diff Manifests In PRs

Fail CI when a PR adds a public MCP function, scope, or capability without updating the manifest snapshot and the issue acceptance criteria.

The first failure mode to block is over-declared capability, especially sampling.

### Phase 3: External Attestation

Adopt an external AttestMCP-compatible verifier only after the trigger threshold is met. The verifier should read the manifest snapshot, the `.well-known` endpoint, and a dry-run invocation log, then produce a machine-readable pass/fail result.

## Non-Goals

- No sampling origin tagging until sampling is actually enabled.
- No custom crypto attestation before OAuth/WorkOS/audit controls are fully exercised.
- No CI requirement that depends on a network-only third-party verifier for ordinary docs or migration PRs.

## References

- `supabase/functions/mcp-well-known/index.ts`
- `supabase/functions/_shared/mcp_auth_guard.ts`
- `.github/workflows/mcp-audit-anomaly-cron.yml`
- `docs/mcp-dcr-vs-cimd-decision.md`
