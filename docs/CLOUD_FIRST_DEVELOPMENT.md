# Cloud-first Development Workflow

This repository treats the Windows checkout as a lightweight control plane.
GitHub/API operations and remote tasks should be used without a local checkout
when possible. GitHub Actions owns expensive dependency resolution, analysis,
tests, coverage, browser smoke tests, generated artifacts, and production
builds.

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

## Cloud Editing Control Plane

Use the GitHub web editor or Git Data API for the smallest source changes. For
interactive multi-file editing, use the default lightweight GitHub Codespaces
configuration after checking the payer and available quota. It intentionally
does not install Flutter or hydrate project dependencies. Codespaces must never
be created automatically; stop or delete one after its branch is preserved.

The resource-heavy local Flutter dev container is an explicit fallback only.
See `docs/CLOUD_FIRST_DEVELOPMENT_WORKFLOW.md` for the Codespaces lifecycle and
fallback boundary.

## Lightweight Local Control Plane

Read remote files, PRs, checks, and logs through GitHub before creating another
checkout. When a separate checkout is necessary, use a sparse worktree and
select only the paths in the task's read/write set. This avoids copying
application assets and prevents accidental package-cache creation.

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

For pre-PR or branch-only proof, choose the smallest cloud profile that proves
the current iteration:

| Profile | Hosted-runner work |
| --- | --- |
| `workspace` | Validate cloud/local workspace descriptors without Flutter |
| `analyze` | Dependency resolution and Flutter analysis |
| `test` | Dependency resolution and Flutter tests |
| `web-build` | Dependency resolution and a release web build |
| `full` | Analysis, tests, and a release web build |

Dispatch it only after pushing the branch:

```powershell
git push -u origin HEAD
python scripts/cloud_ci_handoff.py --profile analyze --execute --watch
python scripts/cloud_ci_handoff.py --profile full --execute --watch
```

Run the helper without `--execute` for a read-only preflight. It refuses a
dirty checkout, a protected branch, an origin branch that is missing or differs
from local `HEAD`, or a missing GitHub CLI. The dispatched workflow receives
`expected_head_sha`, fetches the immutable event SHA instead of the moving
branch ref, and fails if checkout does not equal the handoff SHA.

The helper defaults to `.github/workflows/cloud-development.yml`; its profile
controls cost while keeping Flutter dependencies and output off the developer
machine. Use `--workflow ci.yml` only when branch-only proof needs the complete
repository CI surface. Record the emitted run URL and exact head SHA in the PR.
PR CI must still pass because it tests the merge ref, not only the branch head.

The GitHub CLI commands remain available for incident diagnosis, but do not
dispatch either workflow by hand: the required SHA input and new-run fencing
belong to `cloud_ci_handoff.py`.

## Cleanup Boundary

- Close only servers and browser tabs opened for the current task.
- Remove only ignored caches or build outputs created by the current task.
- Keep clean unmerged worktrees until the PR has review evidence; remove them
  after merge according to `docs/AGENT_DELEGATION_PROTOCOL.md`.
- Never delete dirty, locked, rescued, or unrelated worktrees to gain space.
- If CI is unavailable, report the infrastructure blocker. Do not silently fall
  back to a heavy local run while `CLOUD_REQUIRED` is active.
