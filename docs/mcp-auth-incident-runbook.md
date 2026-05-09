# MCP Auth Incident Runbook

> Issue: [#1577](https://github.com/kanta13jp1/my_web_app/issues/1577)
> Parent spec: [MCP_AUTH_HARDENING_SPEC.md](MCP_AUTH_HARDENING_SPEC.md)
> Scope: OAuth client suspension, audit review, and recovery for public MCP surfaces.

## When To Use This

Use this runbook when any of these happen:

- repeated 401/403 or scope failures from the same `client_id`,
- invocation volume exceeds the anomaly cron threshold,
- a client appears to be replaying or mutating tool arguments,
- a cross-server propagation pattern is suspected,
- a trusted MCP client can no longer authenticate after an auth boundary change,
- a CIMD-only client failure needs a temporary DCR compatibility decision.

## Roles

| Role | Permission |
|---|---|
| Sentinel | may suspend or restore MCP clients |
| Reviewer | validates evidence and approves recovery |
| Operator | runs dry-run checks and posts GitHub issue updates |
| Slack target | repository `SLACK_WEBHOOK_URL` destination for time-sensitive alerts |

The Sentinel role is deliberately narrow: it changes `mcp_oauth_clients.suspended` and does not edit secrets, migrations, or code.

## Immediate Containment

For a broad compromise, suspend all clients:

```sql
UPDATE public.mcp_oauth_clients
SET suspended = true
WHERE suspended IS DISTINCT FROM true;
```

For a single client:

```sql
UPDATE public.mcp_oauth_clients
SET suspended = true
WHERE client_id = '<client_id>';
```

After either command, verify:

```sql
SELECT client_id, suspended, managed_by, reputation_score, rotation_due_at
FROM public.mcp_oauth_clients
ORDER BY client_id;
```

Do not delete rows during containment. Preserving registry rows keeps audit correlation intact.

## Evidence Collection

Collect the smallest evidence bundle that can explain the decision:

```sql
SELECT client_id, tool_name, response_status, anomaly_score, cross_server_trace,
       origin_tag, invoked_at
FROM public.mcp_audit_log
WHERE invoked_at > now() - interval '24 hours'
ORDER BY invoked_at DESC
LIMIT 200;
```

Also capture:

- related GitHub Actions run URL,
- affected function name and action,
- client IP range if available,
- whether the request used a valid bearer header,
- whether `requireScope` denied the request,
- whether a `.well-known` metadata lookup preceded the failure.

## Communication

Post a GitHub issue comment with:

- impact window,
- affected `client_id` values,
- whether clients were suspended globally or selectively,
- current user impact,
- next verification step,
- recovery owner.

Use Slack only for time-sensitive alerts through the repository `SLACK_WEBHOOK_URL` destination. Keep the durable record in the GitHub issue and never include tokens, secrets, or raw bearer headers in Slack.

## Recovery

Before restoring a client, all must be true:

- root cause is identified or the event is confidently benign,
- no repeated anomaly appears in the last 30 minutes,
- the client is Terraform-managed or has an approved incident exception,
- token rotation is complete when credential leakage is suspected,
- a reviewer approves the restore in the issue thread.

Restore one client at a time:

```sql
UPDATE public.mcp_oauth_clients
SET suspended = false
WHERE client_id = '<client_id>';
```

Then run a dry-run invocation and confirm a new `mcp_audit_log` row with the expected `response_status`.

## CIMD Compatibility Incidents

If a client requires CIMD and DCR fails:

1. Keep auth validation strict; do not bypass issuer, audience, or bearer-header rules.
2. Check whether `metadata_document_url` exists for the client.
3. If the client is trusted, open a Phase 2 CIMD implementation issue referencing `docs/mcp-dcr-vs-cimd-decision.md`.
4. If the client is not trusted, leave it suspended and record the compatibility failure.

## Post-Incident Cleanup

Within one business day:

- add a concise root-cause comment to the GitHub issue,
- link the relevant workflow run and audit query result,
- file a scoped follow-up for any missing detector or runbook step,
- confirm no temporary manual SQL path remains in normal onboarding.

## References

- `supabase/functions/_shared/mcp_auth_guard.ts`
- `.github/workflows/mcp-audit-anomaly-cron.yml`
- `scripts/mcp_audit_anomaly.ts`
- `docs/mcp-dcr-vs-cimd-decision.md`
