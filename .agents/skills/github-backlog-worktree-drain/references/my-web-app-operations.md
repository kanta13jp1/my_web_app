# my_web_app Operations

## Preflight

```powershell
git status -sb
python scripts/codex_session_check.py
python scripts/ai_tool_watch.py --print-only
git worktree list --porcelain
```

Use the repository Python executable when the Windows Store shim cannot start.
Do not repair a dirty root by stashing or resetting it.

## Audit and checkpoint

Resolve `worktree_state.py` from this skill directory:

```powershell
python <skill-dir>\scripts\worktree_state.py audit `
  --repo C:\Users\kanta\GitHub\my_web_app `
  --target C:\tmp\my_web_app-issue-1234

python <skill-dir>\scripts\worktree_state.py checkpoint set `
  --repo C:\tmp\my_web_app-issue-1234 `
  --phase validation --status in_progress --issue 1234 --pr 4567 `
  --summary "Targeted checks passed" `
  --evidence "flutter test test/path_test.dart: passed" `
  --next-action "Run the required full gate once"
```

## Publication proof

```powershell
git fetch origin
git status -sb
git diff --cached --stat
git commit -m "fix: scoped description"
git push origin <branch>
git ls-remote origin refs/heads/<branch>
gh pr view <pr> --repo kanta13jp1/my_web_app `
  --json state,mergedAt,headRefName,headRefOid,baseRefName,mergeable,mergeStateStatus,url
gh pr checks <pr> --repo kanta13jp1/my_web_app
```

Run `scripts/check_minimal_e2e_gate.py` and
`scripts/check_high_risk_ultrareview_gate.py` against the current PR body when
those gates apply. Do not copy a stale passing body from another PR.

For Actions failures, use `$gh-fix-ci` and inspect logs for the exact head SHA.
Distinguish code failures, infrastructure failures, cancelled superseded runs,
and production-smoke failures before editing.

## Merge and cleanup

Use an expected head SHA for merge. After merge, fetch main and run:

```powershell
python <skill-dir>\scripts\worktree_state.py cleanup-check `
  --repo C:\Users\kanta\GitHub\my_web_app `
  --worktree C:\tmp\my_web_app-issue-1234 `
  --base origin/main --github-repo kanta13jp1/my_web_app `
  --pr 4567 --expected-head <head-sha>
```

Only after `safe: true`:

```powershell
git worktree remove C:\tmp\my_web_app-issue-1234
git branch -d <branch>
git worktree list --porcelain
```

Never use `--force` to turn an unsafe result into cleanup.

## WBS synchronization

Use `WBS Progress Update (manual)` when local service-role credentials are not
available. Set implemented but unmerged work to `in_progress / 95`; set
`completed / 100` only after merge or equivalent production proof. Include the
Issue/PR reference, validation summary, remaining work, and recovery plan.

## Load pause

When the user requests lower load, do not launch another test or monitor. Save a
`paused` checkpoint first when possible, then use `$reduce-windows-pc-lag` to
identify task-owned rerunnable jobs. Stop exact revalidated PIDs only. On resume,
verify remote refs and PR state before restarting hooks or pushes.
