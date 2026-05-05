# Hedra API Credit Monitoring

Status: WBS #1296 implementation slice
Owner lane: Codex (Windows app)
Runtime: GitHub Actions quota monitor + Supabase `ai_quota_usage` + `/quota-dashboard`

## What Runs

`AI Quota Monitor` now checks Hedra API credits every day with the official credits endpoint:

```text
GET https://api.hedra.com/web-app/public/billing/credits
Header: X-API-Key: <HEDRA_API_KEY>
```

The monitor stores the result as an `ai_quota_usage` row where `tool = hedra`.

Stored fields include:

- `remaining`
- `used`
- `expiring`
- `workspace_credits`
- `severity`
- `threshold`
- `warning_threshold`
- `critical_threshold`
- `stop_threshold`

## Alert Policy

Default thresholds:

- warning: `remaining <= 50`
- critical: `remaining <= 20`
- stop: `remaining <= 5`

These can be overridden with repository variables:

- `HEDRA_CREDIT_WARNING_THRESHOLD`
- `HEDRA_CREDIT_CRITICAL_THRESHOLD`
- `HEDRA_CREDIT_STOP_THRESHOLD`

When Hedra is below threshold, the workflow:

- sets `alert = true` in `ai_quota_usage`
- writes a GitHub Actions summary
- inserts a global in-app notification linking to `/quota-dashboard`
- posts to `QUOTA_ALERT_WEBHOOK_URL` if that secret is configured

## User-Facing Failure Mode

`ai-assistant` maps Hedra billing/credit failures to `status = credit_shortage`.

The text reply remains available, but video generation is paused with a clear message so a credit shortage is not mistaken for a generic system outage.

## Verification

Use `workflow_dispatch` with `dry_run=true` to validate endpoint connectivity without writing Supabase rows.
