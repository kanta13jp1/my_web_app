# Testcontainers Supabase Smoke

Issue #1595 adds the first deterministic integration boundary for DB and Edge
Function work without using production Supabase credentials.

## Scope

- Starts a disposable `postgres:16-alpine` container through
  `testcontainers-python`.
- Installs the exact Python environment declared in
  `scripts/requirements-testcontainers.txt`; production and pull-request smoke
  runs use the same pinned Python 3.12.14 toolchain.
- Applies the fixture migrations in `test/fixtures/testcontainers/sql/`.
- Seeds representative `profiles`, `wbs_tasks`, and `ai_circuit_breaker` rows.
- Applies the real Issue #2773 migration and verifies fail-closed RLS for the
  six production tables identified by Supabase Security Advisor.
- Impersonates `anon` and `authenticated` roles to prove that a missing tenant
  claim returns no rows, cross-tenant writes fail with SQLSTATE `42501`, and an
  authenticated user sees only their own rows.
- Applies the Issue #2668 note-comment authorization migration twice and checks
  the full note-owner, public-viewer, verified-workspace-member, unrelated-user,
  and service-role matrix. The fixture also proves that legacy forged public
  memo rows, unverified memberships, and forged team shares grant no access.
- Verifies least-privilege column grants, immutable comment owner/note fields,
  the authenticated and actor-rate-limited invite-code RPC, bounded comment
  content, and removal of all eight permissive legacy comment policies.
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

Pull requests that touch Supabase migrations or functions run the standalone
`DB + Edge smoke` workflow. The production deploy workflow runs the same smoke
again before applying a migration or deploying an Edge Function, so a direct or
operator-triggered deployment cannot pass the DB/Edge boundary without the
deterministic checks succeeding.

The note-comment hardening is intentionally forward-only. After the database
migration applies, do not roll the web client back to the legacy direct
`team_memberships` insert flow because that path is denied by the new RLS.
Keep the RPC-capable client deployed or ship a forward fix. Existing legitimate
members must receive the current invite code again (or be re-added by the team
owner) before workspace comments and shares become available.

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
