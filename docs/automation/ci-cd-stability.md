# CI/CD Stability Automation

Issue: #1307

Related readiness gate: #1556

## What Is Automated

- `scripts/check_migration_timestamps.py` blocks duplicate Supabase migration timestamp prefixes before deploy.
- `scripts/ci_failure_digest.py` records the latest local migration files before production `supabase db push`.
- The same script classifies migration push failures, extracts 14-digit migration versions, applies the safe Supabase repair status, and retries once.
- CI captures Deno lint output into `.ci-logs/deno-lint.log` and appends a short digest to the GitHub Step Summary.
- Production deploy uploads `.deploy-logs/` as an artifact when migration logs exist.
- `release-readiness.yml` runs the alpha release gate manually, daily, and after successful `deploy-prod`: migration collision guard, Edge Function import guard, full Edge Function Deno lint, Deno check for the readiness smoke hub entrypoints, Flutter analyze/build, production route smoke, `tools-hub` / `schedule-hub` service-role smoke, Notion WBS preflight, Slack webhook readiness, and optional WBS completion for the synced #1556 task.

## Repair Rules

The deploy job still keeps the legacy preflight repair list as a conservative safety belt. The dynamic repair path owns new failures:

- `schema_migrations_pkey` or duplicate key errors repair extracted versions as `applied`.
- `Remote migration versions not found` style errors repair extracted versions as `reverted`.
- Unknown failures are not repaired automatically; the job fails and the digest/artifact points to the relevant log lines.
- Release readiness failures are not self-repaired in the gate. `workflow-failure-handler.yml` monitors `Release Readiness Gate` and opens a `workflow-failure` issue with the failing run so the normal repair lane can take over.

## Agent Handoff

- Codex #2 owns deterministic CI/deploy automation and log extraction.
- Claude Code should run `/ultrareview` for high-risk DB migration or auth changes before merge.
- Codex in-app browser checks are reserved for UI-facing deploy or smoke-test changes.
- Automatic approval reviews are appropriate for low-risk workflow/docs changes after CI is green.
- Under the current two-instance operating model, Codex #1 absorbs the former Codex #2 CI automation lane for #1556/#1557 scoped PRs.
