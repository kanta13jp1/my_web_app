# Testcontainers Supabase Smoke

Issue #1595 adds the first deterministic integration boundary for DB and Edge
Function work without using production Supabase credentials.

## Scope

- Starts a disposable `postgres:16-alpine` container through
  `testcontainers-python`.
- Applies the fixture migrations in `test/fixtures/testcontainers/sql/`.
- Seeds representative `profiles`, `wbs_tasks`, and `ai_circuit_breaker` rows.
- Runs `scripts/check_edge_function_imports.py` so real Edge Functions keep the
  ADR-required `npm:@supabase/supabase-js@2` import rule.
- Runs `deno check` for `supabase/functions/health-check/index.ts`.
- Runs `deno check` for the Deno DB fixture before starting it so CI caches and
  type-checks remote runtime dependencies before the HTTP readiness window.
- Starts `test/fixtures/testcontainers/edge-db-smoke.ts` as a Deno HTTP runtime
  and verifies it can query the container DB. The runtime grants network access
  and only the fixture/database env vars required by `deno-postgres`.

This is not a full local Supabase stack. It is the first CI gate that proves the
DB migration/seed boundary and an Edge-like Deno function boundary can run
without production secrets. Broader coverage can add more fixture migrations or
function probes while keeping the same artifact contract.

## Artifacts

The workflow uploads `.testcontainers-logs/` on every run:

- `plan.json`: topology and checked boundaries.
- `sql-fixtures.log`: applied migration/seed files.
- `edge-imports.log`: real Edge Function import-policy result.
- `deno-check-health-check.log`: actual Edge Function type/dependency check.
- `deno-check-edge-db-smoke.log`: Deno DB fixture type/dependency check.
- `edge-db-smoke.log`: Deno fixture server output.
- `summary.json`: redacted pass summary.
- `failure.json`: redacted failure reason when a boundary fails.

Connection passwords are redacted before summary output. No GitHub, Supabase,
Firebase, Slack, Notion, or AI provider secret is required.
