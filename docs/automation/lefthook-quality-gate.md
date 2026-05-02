# Lefthook Quality Gate

Issue: #1596

This repository uses Lefthook to make the local developer path and the PR path
run the same fast quality gates. The hook jobs call Python wrappers under
`.lefthook/` so Windows PowerShell sessions do not depend on Git Bash being
healthy. Local hooks are useful feedback. GitHub Actions is the source of truth
because Git does not record whether `git commit --no-verify` was used.

## Local Setup

Run once per worktree:

```powershell
npm ci
npm run hooks:install
```

Some Codex/Claude worktrees inherit a repository-level `core.hooksPath`. If
Lefthook prints that warning, use manual replay for the current worktree and let
CI enforce the gate:

```powershell
npm run hooks:pre-commit
npm run hooks:pre-push
```

## Gate Map

| Gate | Local hook | CI replay | Owner |
| --- | --- | --- | --- |
| Migration timestamp collision check | `pre-commit` | `Lefthook Quality Gate` | Codex |
| Edge Function import smoke | `pre-commit` | `Lefthook Quality Gate` | Codex |
| Explicit hook-bypass marker scan | `commit-msg` / `pre-commit` | `Lefthook Quality Gate` | Claude Code review owner |
| `flutter analyze` | `pre-push` | `Lefthook Quality Gate` | Codex |
| Targeted Flutter tests | Existing `CI` workflow | Existing `CI` workflow | Codex |
| Edge Function lint | `pre-push` | `Lefthook Quality Gate` | Codex #2 |
| Time-relative migration risk check | `pre-push` | `Lefthook Quality Gate` | Codex #1 / Codex #2 |

The main `CI` workflow still runs the full build and broader test suite. The
Lefthook workflow exists to prove that bypassed local hooks would still fail in
PR before merge. Targeted Flutter tests stay in the existing CI path because the
Windows PowerShell runner can leave stale Dart processes when `flutter test`
hangs locally; keeping those tests in CI avoids turning local hooks into a
developer blocker.

## Exception Procedure

Avoid `--no-verify`. If a production incident or broken local toolchain requires
an exception, get Claude Code approval first, then add this line to the commit
message:

```text
Quality-Gate-Exception: <issue-or-pr-url>
```

The PR must still have a green `Lefthook Quality Gate` check before merge. If
the workflow fails, route the failure to Codex #2 for CI/operations or Codex #1
for migration/data review. Codex #4 may take bounded quality-gate follow-up
work when the root worktree is dirty and a fresh worktree is available.
