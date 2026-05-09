# Issue Fix Plan #862

- Issue: [[ops] Codex worktree/PR merge backlog](https://github.com/kanta13jp1/my_web_app/issues/862)
- Labels: workflow-failure,powershell-instance
- Workflow: `.github/workflows/github-issue-fix.yml`
- CI repair pair: `.github/workflows/ci-auto-fix.yml`
- Run: https://github.com/kanta13jp1/my_web_app/actions/runs/25588046648

## Goal

[ops] Codex worktree/PR merge backlog

## Current Context

```text
Codex backlog detected by `codex-backlog-check.yml`.

## Stale unmerged codex branches
- `origin/codex/codex1-ios-university-release-playbook` (2 commits, 7d old)
- `origin/codex/codex1-msix-installer-url-fix` (1 commits, 7d old)
- `origin/codex/codex1-wbs-automation-drain` (5 commits, 8d old)
- `origin/codex/codex1-x-post-diagnostics` (1 commits, 11d old)
- `origin/codex/codex3-wbs-flow-automation` (1 commits, 7d old)
- `origin/codex/codex4-wbs-stale-subdivide` (2 commits, 7d old)

## Ready Codex PRs awaiting review or merge
- #1777 `codex/codex3-home-release-notes-1682` REVIEW_REQUIRED - feat(home): add release notes navigation
  https://github.com/kanta13jp1/my_web_app/pull/1777
- #1520 `codex/codex1-msix-installer-url-fix` REVIEW_REQUIRED - fix: point Windows MSIX installer links at release tag
  https://github.com/kanta13jp1/my_web_app/pull/1520

## Codex PRs blocked by merge conflicts
- #1671 `codex/codex5-nutrition-1269` CONFLICT - feat: add meal nutrition balance tracker
  https://github.com/kanta13jp1/my_web_app/pull/1671
- #1600 `codex/codex2-notebooklm-auth-check` CONFLICT - [codex] Detect NotebookLM auth during session check
  https://github.com/kanta13jp1/my_web_app/pull/1600
- #1519 `codex/codex1-wbs-automation-drain` CONFLICT - fix: harden WBS issue sync — limit 1000→5000, timeout 10→25min, fix VM test imports, dup keys
  https://github.com/kanta13jp1/my_web_app/pull/1519
- #863 `codex/codex1-x-post-diagnostics` CONFLICT - fix(x-share): surface X API enrollment errors
  https://github.com/kanta13jp1/my_web_app/pull/863

## Closed or already-applied Codex branch cleanup
- `origin/codex/codex2-lefthook-quality-gate` (1 commits, 6d old): closed PR branch still present; #1621 ci: add Lefthook quality gate - https://github.com/kanta13jp1/my_web_app/pull/1621
- `origin/codex/wbs-1568-delegation-protocol-20260507` (2 commits, 2d old): patch-equivalent to main; #2086 docs: define two-instance delegation protocol - https://github.com/kanta13jp1/my_web_app/pull/2086

## Operator action
- Review each ready PR and merge or request changes.
- Rebase or fresh-port conflicted PRs before review.
- Delete closed or already-applied branches only after owner confirmation.
- For stale branches without useful PRs, close, delete, or rebase them.

Run: https://github.com/kanta13jp1/my_web_app/actions/runs/25586789307


```

## Autonomous Repair Loop

1. Reproduce the smallest failing path for this issue.
2. Apply the minimum safe fix on this branch.
3. Let normal CI run on the draft PR.
4. If CI fails on mechanical issues, `ci-auto-fix.yml` attempts `dart fix --apply` and `deno fmt`.
5. Merge only after CI is green and the issue scope is satisfied.

## Checklist

- [ ] Reproduction is clear
- [ ] Smallest safe fix is implemented
- [ ] Analyze/tests/CI are checked
- [ ] PR notes explain the change and the remaining risk
