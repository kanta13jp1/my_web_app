# Cloud-First Execution Policy

Status: canonical / 2026-08-30 / owner-approved local resource protection

## Objective

Protect the user's Windows PC from disk exhaustion, paging, and long-lived build
processes. Heavy validation and artifact production run on GitHub-hosted runners
whenever the repository already has an equivalent workflow. The local machine
remains the control plane for lightweight inspection, scoped edits, approvals,
and reading cloud results.

This policy changes the execution venue, not the quality bar. A cloud check must
still cover the same files and commands that a local check would have covered.

## Routing Matrix

| Task | Cloud route | Local default |
| --- | --- | --- |
| Static analysis and unit/widget tests | `CI` (`.github/workflows/ci.yml`) | Do not run Flutter/Dart analysis or tests |
| Public browser and visual smoke | `E2E Smoke` (`.github/workflows/e2e-smoke.yml`) | Do not install or launch Playwright browsers |
| Minimal release/browser gate | `Minimal E2E Gate` (`.github/workflows/minimal-e2e-gate.yml`) | Read the run and artifact only |
| Android/iOS artifacts | `Build Mobile Release Artifacts` (`.github/workflows/mobile-release-build.yml`) | Do not build mobile artifacts |
| Dart/Deno formatting recovery | `CI Auto-Fix (manual)` (`.github/workflows/ci-auto-fix.yml`) | Use only lightweight manual edits |
| Deployment | Existing development/staging/production deploy workflows | Do not build or deploy from the PC |
| WBS and operations updates | Existing manual wrapper workflow when available | Use `gh` API calls only when no wrapper exists |

## Standard Flow

1. Inspect repository and GitHub state with read-only commands.
2. If the root tree is dirty or disk/RAM is constrained, leave it untouched.
3. Create a scoped remote branch and commit through GitHub APIs or an approved
   cloud environment. Avoid an additional local clone/worktree.
4. Open a PR so path-aware cloud checks run automatically.
5. When a full pre-PR check is needed, dispatch `CI` against the remote branch:

   ```powershell
   gh workflow run ci.yml --ref <branch>
   gh run list --workflow ci.yml --branch <branch> --limit 1
   gh run view <run-id>
   ```

6. Dispatch browser or build workflows only when their evidence is required.
7. Keep evidence as GitHub check/run URLs and retained artifacts. Do not download
   artifacts unless the user needs them locally.
8. Merge only after required cloud checks succeed and review requirements are
   satisfied.

## Local Exception Gate

A heavyweight local command is permitted only when all conditions are true:

- the user explicitly requests local execution, or no equivalent cloud route
  exists;
- the active user task/worktree is identified and will not be disturbed;
- free disk and top memory consumers have been checked;
- expected disk growth, duration, and cleanup are understood;
- the PR or handoff records why cloud execution was unavailable.

Stop and reroute to the cloud if the PC is paging, C: is low, another Flutter or
browser run is active, or ownership of dirty files/processes is unclear.

## Cost and Safety

- Disabled paid OpenAI/Anthropic review workflows stay disabled until their
  tracked re-enable gate is satisfied.
- Prefer path-aware jobs, concurrency cancellation, timeouts, caches, and short
  artifact retention to control GitHub Actions usage.
- Cloud execution does not authorize production changes, purchases, secret
  changes, or destructive cleanup.
- Do not create a second check suite when the PR-triggered workflow already
  provides equivalent evidence.

## Evidence Contract

Every handoff or PR should state:

- execution venue;
- cloud workflow and run URL;
- checks that succeeded, failed, or were intentionally skipped;
- local heavyweight commands run (normally `none`);
- artifacts downloaded locally (normally `none`);
- remaining resource or verification risk.
