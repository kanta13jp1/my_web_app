# Cloud-first Development Workflow

This repository treats the Windows checkout as a lightweight control plane.
GitHub Actions owns expensive dependency resolution, analysis, tests, coverage,
browser smoke tests, and production builds.

## Route Before Work

Run the standard-library-only resource check before hydrating any toolchain:

```powershell
python scripts/cloud_first_route.py
```

Cloud execution is mandatory when any of these limits is reached:

- free disk below 30 GiB;
- free physical memory below 4 GiB;
- memory use at or above 85%.

`CLOUD_PREFERRED` still means that GitHub Actions is the default validation
authority. `CLOUD_REQUIRED` additionally prohibits local dependency installs,
full Flutter/Dart/Deno checks, builds, Docker, dev servers, and local child
workers.

## Lightweight Local Control Plane

When a separate checkout is necessary, use a sparse worktree and select only
the paths in the task's write set. This avoids copying application assets and
prevents accidental package-cache creation.

```powershell
git fetch origin main
git worktree add --no-checkout -b codex/<task> C:\tmp\mwa-<task> origin/main
Set-Location C:\tmp\mwa-<task>
git sparse-checkout init --no-cone
git sparse-checkout set '/lib/target/' '/test/target/' '/AGENTS.md'
git checkout
```

Keep local validation cheap and deterministic:

```powershell
git diff --check
python scripts/<targeted-policy-test>.py
```

Do not run package installation merely to make a local check available. The
missing toolchain is a routing signal to use CI.

## Cloud Validation

For normal implementation, push the branch and open a draft PR. Pull-request CI
classifies changed paths and runs only the required expensive scopes against
the merge ref.

For pre-PR or branch-only proof, dispatch the full cloud gate after pushing the
branch:

```powershell
git push -u origin HEAD
gh workflow run ci.yml --ref <branch>
gh run list --workflow ci.yml --branch <branch> --event workflow_dispatch --limit 1
gh run watch <run-id> --exit-status
```

The manual dispatch intentionally runs all scopes. It proves the pushed branch
head without creating Flutter, Deno, Node, coverage, or build outputs locally.
Record the run URL and head SHA in the PR. PR CI must still pass because it
tests the merge ref, not only the branch head.

## Cleanup Boundary

- Close only servers and browser tabs opened for the current task.
- Remove only ignored caches or build outputs created by the current task.
- Keep clean unmerged worktrees until the PR has review evidence; remove them
  after merge according to `docs/AGENT_DELEGATION_PROTOCOL.md`.
- Never delete dirty, locked, rescued, or unrelated worktrees to gain space.
- If CI is unavailable, report the infrastructure blocker. Do not silently fall
  back to a heavy local run while `CLOUD_REQUIRED` is active.
