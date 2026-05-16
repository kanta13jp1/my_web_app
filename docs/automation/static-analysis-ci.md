# Static Analysis CI

Issue: #1372

## Required Gates

The CI workflow enforces the repository's static-analysis rules on pull requests,
pushes, and `workflow_call` deploy preflights:

- `flutter analyze`
- `deno lint --config supabase/functions/deno.json supabase/functions/`
- `dart format --output=none --set-exit-if-changed .`
- VM tests, web import smoke tests, security checks, and production web build
- `scripts/check_no_verify_bypass.py` through the Minimal E2E Gate workflow,
  which fails PRs that carry local hook-bypass markers

`analysis_options.yaml` defines Dart analyzer errors and lints. Formatting is now
a hard gate instead of a warning so CI blocks merges when generated or manual
Dart edits skip `dart format`.

## Local Lefthook Mirror

Local commits should install the same fast gate through Lefthook:

```powershell
npm ci
npm run hooks:install
npm run quality:fast
```

The local hook flow is documented in
[`docs/automation/local-quality-gates.md`](local-quality-gates.md). In short,
`pre-commit` runs the fast gate, `prepare-commit-msg` blocks
`git commit --no-verify` by requiring a fresh pre-commit stamp, and `pre-push`
runs the fuller local CI mirror. Browser smoke remains in GitHub Actions by
default and can be included locally with `CODEX_INCLUDE_BROWSER_SMOKE=1`.

## Auto-Fix Path

`ci-auto-fix.yml` listens to the `CI` workflow's failed PR runs. For PR branches,
it attempts these safe repairs and pushes a bot commit back to the branch:

- `dart fix --apply lib/`
- `dart format .`
- `deno fmt supabase/functions/`

This keeps the new formatting gate strict while preserving the multi-instance
development flow: routine formatting drift is fixed automatically, and remaining
analysis errors still fail visibly for manual correction.

## Agent Handoff

- Claude Code #1 owns high-risk architecture, auth, database, production deploy,
  hook-scope, and exception-policy review.
- Codex #1 owns deterministic CI, formatting, workflow automation, and scoped
  implementation changes under the current two-instance development flow.
- Codex in-app browser checks remain the default for UI-facing changes after a
  local dev server is available.
- Automatic approval reviews are suitable for low-risk workflow or docs changes
  once required CI gates are green.

## Latest Tooling Notes

- Claude Code 2.1.120 added the non-interactive `claude ultrareview [target]`
  subcommand, which is suitable for future CI review jobs.
- Codex CLI 0.125.0 improved app-server automation, plugin management,
  permission profile round-tripping, and JSON execution telemetry; these are
  candidates for the next development-flow automation pass.
