# Local Quality Gates

Issue: #1596

This repository uses Lefthook to make local agent commits follow the same
deterministic checks that GitHub Actions enforces.

## Setup

```powershell
npm ci
npm run hooks:install
npm run hooks:validate
```

Lefthook installs scripts under `.git/hooks/`. Those generated files are local
workspace state and must not be committed. The `hooks:install` script uses
`lefthook install --force` so shared worktrees that already set
`core.hooksPath` still receive the current hook definitions.

## Hook Flow

| Hook | Gate | Purpose |
| --- | --- | --- |
| `pre-commit` | `python scripts/pre_commit_quality_gate.py` | Runs Python smoke tests, Edge Function import checks, `flutter analyze`, and Deno lint, then stamps the Git tree only after the fast gate succeeds. |
| `prepare-commit-msg` | `python scripts/no_verify_sentinel.py assert-pre-commit ...` | Blocks commits whose index did not pass `pre-commit`. This hook is not skipped by `git commit --no-verify`. |
| `commit-msg` | `python scripts/check_no_verify_bypass.py --message-file ...` | Rejects explicit quality-gate bypass markers in commit messages. |
| `pre-push` | `python scripts/quality_gate.py --full` | Adds formatting, VM tests, and Edge Function Deno tests before pushing. Browser smoke stays in GitHub Actions by default and can be opted in locally. |

All Lefthook jobs use `parallel: false` on purpose. The gates are short enough
that deterministic ordering is more useful than local parallelism: the
`pre-commit` stamp must be written only after the fast gate succeeds, and
`prepare-commit-msg` / `commit-msg` should fail with stable, readable output.

## Commands

```powershell
npm run quality:fast
npm run quality:full
npm run quality:browser
npm run quality:no-verify
```

`quality:fast` is the normal pre-commit path. `quality:full` is intentionally
heavier and mirrors the PR CI path closely enough to catch failures before a
branch leaves the machine. Local browser smoke is opt-in because Windows Chrome
and Edge can fail inside editor-hosted agent sessions while the GitHub Actions
browser runner remains stable:

```powershell
$env:CODEX_INCLUDE_BROWSER_SMOKE = '1'
npm run quality:full
```

## No-Verify Policy

Do not use `git commit --no-verify` or `LEFTHOOK=0` for project work. Do not add
`Quality-Gate-Bypass:` or `Quality-Gate-Exception:` commit trailers; the CI
range scanner treats both as forbidden bypass markers. The `prepare-commit-msg`
hook requires a fresh pre-commit success stamp for the current Git tree, so a
normal `--no-verify` commit is stopped locally. Git sequencer operations such as
rebase, merge, cherry-pick, and revert are allowed to continue because they
replay commits rather than create a new unchecked working-tree commit.

If a hook itself is broken, open or update a GitHub issue and fix the hook in a
small PR. Do not hide the failure in a product PR. For true emergency recovery,
create a temporary local-only branch, repair the hook or failing check, then
recommit normally before opening a PR.

Exception requests are handled outside commit metadata: leave the reason, risk,
and replacement validation evidence on the PR or issue, route the decision to
Claude Code #1, then land a normal checked commit after the approved mitigation
is in place.

## Ownership

- Claude Code #1 owns hook design, quality-gate scope, and exception policy.
- Codex #1 owns cross-cutting implementation, CI/GitHub Actions wiring, Edge
  Function checks, deterministic automation drift, and UI/browser verification.
- GitHub Actions owns final merge-blocking evidence once required checks are
  green.

## PR Enforcement

`.github/workflows/minimal-e2e-gate.yml` runs
`scripts/check_no_verify_bypass.py` across the PR commit range. If a bypass
marker reaches GitHub, the PR fails before review.
