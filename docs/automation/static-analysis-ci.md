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

## Bounded local analyzer runner

Issue #4266 adds deterministic resource bounds to `scripts/quality_gate.py`.
Every delegated command has an explicit timeout. Flutter analyzer commands also
take one advisory lock stored under the repository's shared Git directory, so
all local worktrees serialize analyzer startup instead of competing for Dart
analysis-server processes.

Automation that validates an explicit set of Dart files must use the shared
entry point rather than invoking `flutter analyze` directly:

```powershell
py -3 scripts/quality_gate.py --analyze-files lib/pages/example_page.dart test/pages/example_page_test.dart
```

Repository-wide analysis uses the same wrapper locally and in GitHub Actions:

```powershell
py -3 scripts/quality_gate.py --analyze-only
```

Issue #1780 extends that entry point with a Windows-safe fallback. When
`flutter analyze` times out, cannot start, exits abnormally, reports analysis
server failure, or reports OOM, the wrapper runs plain `dart analyze`. Normal
analyzer diagnostics and advisory-lock contention are code/coordination
failures and do not trigger the fallback. A successful fallback is reported as
`degraded_pass`; it preserves the CI gate while making the infrastructure
failure visible instead of hiding it.

The runner emits one structured `quality_gate_command` JSON record with the
command, elapsed time, timeout, exit code, lock result, child-process cleanup
result, and recovery command. Exit code `124` means the owned command tree was
terminated after its timeout. Exit code `75` means the shared analyzer lock was
not acquired within its bounded wait; the analyzer was not started.

Each analyzer run writes `.ci-logs/analyzer/result.json`, command logs,
Flutter/Dart versions, matching Flutter crash-log paths, a Markdown summary,
and (for non-clean runs) `comment.md`. GitHub Actions uploads that directory as
the `analyzer-evidence` artifact and appends the summary to the workflow and PR
results. The recorded recovery command can be rerun locally without guessing
which analyzer path was used.

Local defaults can be tuned without changing CI policy:

- `QUALITY_GATE_ANALYZE_TIMEOUT_SECONDS` — analyzer runtime limit (default 180s)
- `QUALITY_GATE_DART_ANALYZE_TIMEOUT_SECONDS` — fallback runtime limit (default 180s)
- `QUALITY_GATE_ANALYZER_LOCK_TIMEOUT_SECONDS` — cross-worktree lock wait (default 30s)

Timeout cleanup targets only the process tree created by that command. It must
never terminate unrelated Dart, Flutter, IDE, or user processes.

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
