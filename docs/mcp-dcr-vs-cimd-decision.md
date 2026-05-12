# MCP DCR vs CIMD Decision

> Issue: [#1577](https://github.com/kanta13jp1/my_web_app/issues/1577)
> Parent spec: [MCP_AUTH_HARDENING_SPEC.md](MCP_AUTH_HARDENING_SPEC.md)
> Status: Phase 1 uses DCR with Terraform-managed client records. CIMD is a Phase 2 migration target for 2027 Q1.

## Decision

`my_web_app` will keep Dynamic Client Registration (DCR, RFC 7591) as the Phase 1 client onboarding path and prepare Client ID Metadata Document (CIMD) compatibility as a Phase 2 migration.

The decision is intentionally conservative:

- DCR is already represented by `mcp_oauth_clients` and the Phase A schema extensions.
- Terraform plan-only skeletons now give DCR records a reviewable IaC path instead of manual SQL.
- `metadata_document_url` is already present so CIMD can be enabled without another table redesign.
- Existing MCP clients still need a DCR-compatible path while CIMD support stabilizes.

## Why Not CIMD First

CIMD is the preferred long-term protocol shape because the client id points to metadata rather than depending on unauthenticated registration at runtime. It is not the Phase 1 default because the current app already has a DCR-shaped registry and needs a smaller blast radius for the first public MCP example.

The Phase 1 replacement for CIMD's risk reduction is:

- no manual client inserts outside Terraform-reviewed HCL,
- `managed_by`, `reputation_score`, `rotation_due_at`, and `suspended` fields on `mcp_oauth_clients`,
- WorkOS JWT validation through `mcp_auth_guard.ts`,
- resource indicator checks in `requireScope`,
- anomaly detection through `mcp-audit-anomaly-cron`.

## Guardrails While DCR Remains Active

DCR records are production-eligible only when all of the following hold:

| Gate | Required state |
|---|---|
| Registry owner | `managed_by = 'terraform'` |
| Reputation | `reputation_score >= 50` unless an incident review approves an exception |
| Secret age | `rotation_due_at` is absent or in the future |
| Runtime status | `suspended = false` |
| Resource scope | token `aud` contains the target `urn:jibun:tool:*` value, not a broad app-wide audience |
| Auditability | each invocation reaches `mcp_audit_log` through `logMcpInvocation` |

Manual SQL is reserved for incident response only. New OAuth clients must be proposed as Terraform changes.

## Phase 2 CIMD Triggers

Start CIMD implementation when any of these is true:

- a supported MCP client requires CIMD and no longer accepts DCR,
- at least five production MCP clients are active,
- one cross-server propagation incident is confirmed,
- DCR operational load exceeds one client registry change per week for four consecutive weeks,
- security review decides unauthenticated registration is no longer acceptable for the next public MCP surface.

Phase 2 work should add metadata retrieval to the auth guard path, populate `metadata_document_url`, and keep DCR as a bounded fallback until all active clients are migrated.

## Failure Mode

If a client stops connecting because it requires CIMD only:

1. Confirm the failing client and exact auth error in `mcp_audit_log` and the client logs.
2. Keep the affected client suspended if repeated retries look automated or abusive.
3. Add a temporary DCR compatibility note to the incident thread only if the client is trusted.
4. Open a CIMD migration issue referencing this document and the incident runbook.

Do not bypass `requireScope`, disable issuer validation, or accept bearer tokens from query parameters to make a CIMD-only client work.

## References

- `supabase/migrations/20260509093000_extend_mcp_oauth_clients.sql`
- `terraform/mcp_oauth_clients/`
- `supabase/functions/_shared/mcp_auth_guard.ts`
- `docs/mcp-auth-incident-runbook.md`
