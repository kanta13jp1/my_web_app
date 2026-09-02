---
name: asset-management-wbs-release
description: Deliver this repository's asset-management work in realistic WBS due-date order, from issue and schedule review through a fresh worktree, scoped Flutter/Supabase/AI implementation, low-load validation, pull request, merge, WBS synchronization, cleanup, and wrap-up. Use for 資産管理, 負債マスタ, Supabase sync or egress, external AI, MoneyForward or brokerage integration, WBS replanning, or requests to continue the next due task under the two-instance workflow.
---

# Asset Management WBS Release

Deliver one bounded asset-management task without losing user work, overloading the PC, or letting Issue and WBS state drift. Reuse existing project and global skills instead of duplicating their implementation details.

## Compose The Workflow

Use these companion skills when available and relevant:

- `session-start-check` for repository and tooling intake.
- `flutter-feature-release-pipeline` for layered Flutter implementation, tests, responsive QA, and release stages.
- `reduce-windows-pc-lag` when resource pressure is reported or observed.
- `github:gh-fix-ci` only after a GitHub check actually fails.
- `source-command-wrap-up` at the end of the session.

Repository instructions and the user's latest explicit request take precedence.

## 1. Start Safely

Run the repository-required intake before editing:

```powershell
git status
python scripts/codex_session_check.py
python scripts/ai_tool_watch.py --print-only
Get-CimInstance Win32_OperatingSystem |
  Select-Object @{n='FreeMemoryGB';e={[math]::Round($_.FreePhysicalMemory / 1MB, 2)}}
Get-PSDrive -PSProvider FileSystem |
  Select-Object Name, @{n='FreeGB';e={[math]::Round($_.Free / 1GB, 2)}}
```

Also inspect `AGENTS.md`, the current branch, upstream drift, nearby worktrees, and attributable Flutter/Dart/browser automation processes.

If the root worktree is dirty, create a fresh worktree from the latest `origin/main` on a scoped `codex/` branch. Never modify, move, clean, archive, or delete unrelated dirty files.

Record the worktree path, branch, base commit, Issue, WBS task UUID, intended files, and validation plan.

## 2. Select And Schedule The Work

1. Read the WBS and open Issues before choosing work.
2. Select the earliest due unblocked task assigned to Codex #1. Respect explicit user priority when it conflicts with due-date order.
3. Resolve the WBS task UUID separately from the GitHub Issue number. Never pass an Issue number where `wbs.update_progress` expects a WBS UUID.
4. Estimate focused effort before assigning dates. Put tasks on the same day only when their combined estimate fits one realistic workday and their validations do not contend for the same machine resources.
5. When adding Issues, split the plan into independently testable, reviewable, and reversible tasks. Add acceptance criteria, dependencies, estimate, owner, start date, due date, and parent/child links.
6. After Issue synchronization, rerun or inspect WBS scheduling so feature requests are not collapsed onto one date.

Apply the two-instance model:

- Claude Code #1 owns product judgment, architecture, plan arbitration, and quality-gate design.
- Codex #1 owns scoped implementation, migrations, Supabase and Edge operations, deterministic checks, CI repair, synchronization, and cleanup.
- Use guarded child workers only for bounded, disjoint research or critique. Record their scope and validation impact.

If the next task needs unresolved product judgment, leave a short Claude Code handoff instead of guessing.

## 3. Define A Small Vertical Slice

Turn the Issue into explicit acceptance criteria and a focused test matrix. Trace the current path through UI, state/controller, service, repository, local persistence, Supabase, and Edge Functions before editing.

Keep these boundaries:

- Calculations and financial rules remain deterministic in Dart or trusted server code; an LLM may explain results but must not invent amounts.
- UI never calls Supabase or external AI providers directly.
- Local persistence remains recoverable during staged synchronization changes.
- Feature flags default to the safest existing behavior unless the Issue explicitly authorizes rollout.
- Evidence uploads are private, user-scoped, size-limited, MIME-validated, and reviewed without exposing service credentials.
- External-site integration uses documented APIs or user-authorized exports. Do not automate credential entry or bypass access controls.

For any Supabase query or Storage change, read [Supabase Egress Checklist](references/supabase-egress-checklist.md) before implementation.

## 4. Implement With Resource Checkpoints

Implement the smallest vertical slice in repository style. Keep unrelated refactors and generated files out of the diff.

Before each expensive phase, check memory, disk, and active attributable processes. Use this order:

1. Read and search only the relevant files.
2. Format changed files.
3. Run focused analysis.
4. Run focused unit or widget tests.
5. Run repository-wide analysis and tests only when required by gates or blast radius.
6. Build or launch a browser only after focused checks pass.

Do not run full analysis, full tests, a build, and browser automation concurrently. Do not repeat an expensive passing check unless relevant inputs changed.

If the user requests a stop or the PC is under pressure:

1. Start no new commands.
2. Stop only processes confidently attributable to this task.
3. Preserve edits, staged state, task files, and worktrees.
4. Record completed checks, the interrupted command, and the exact next safe command.
5. Wait for user input. Never report an interrupted check as passing.

## 5. Validate The User Outcome

Validate cheap to expensive and keep exact evidence:

- `dart format` on changed Dart files.
- Focused `dart analyze` or `flutter analyze`.
- Focused service, repository, migration, and widget tests.
- Full required tests and `git diff --check`.
- Desktop and mobile browser QA for responsive UI changes.
- Reload restoration for persistence changes.
- Network inspection for Supabase/AI changes: request count, selected columns, rows, transferred bytes, duplicate fetches, cache behavior, and error fallback.
- Migration/RLS checks and staging smoke tests for database changes.

Test fallback paths explicitly: feature flag off, unauthenticated or unconfigured Supabase, provider billing failure, timeout, conflict, offline/local-only state, and missing evidence.

## 6. Publish And Merge

Proceed only through the release stage the user has authorized.

1. Review the final diff and stage explicit intended paths.
2. Commit with a focused message and push the scoped branch.
3. Open a Draft PR containing scope, acceptance criteria, persistence/security notes, egress impact, exact validation results, Minimal E2E Declaration, High-risk Ultrareview notes when required, and recovery limitations.
4. Inspect Files changed for unrelated root files, lockfiles, generated platform files, secrets, migrations outside scope, and parent-task omissions.
5. Wait for required CI and gates. Diagnose failures from logs and rerun only affected gates.
6. Mark Ready only after Draft CI and the diff review pass.
7. Recheck CI and mergeability. Squash merge only when authorized and all required gates permit it.
8. Confirm the GitHub PR is actually `MERGED`, capture merge and head commits, and delete the remote branch.
9. Treat a nonzero local `gh pr merge` exit as inconclusive; GitHub PR state is the source of truth.

Do not claim deployment success from a merge alone. Verify the deployment workflow and production route separately when deployment is in scope.

## 7. Synchronize WBS And Close The Loop

After merge or other proof of completion:

1. Update the correct WBS UUID with the Issue/PR reference and validation summary.
2. Use `completed` / `100` only for merged or otherwise proven work. Use `in_progress` / `95` for implemented but unmerged work.
3. If local Supabase credentials are unavailable, dispatch `WBS Progress Update (manual)` once as described in `AGENTS.md`.
4. Close the Issue only after acceptance criteria are met. Audit the parent Issue and WBS roll-up before closing a parent.
5. Recheck the WBS schedule after Issue synchronization.
6. Stop attributable servers and automation. Remove only clean, finished worktrees and task-owned temporary build output. Never delete user files.
7. Run `source-command-wrap-up`, persist the durable session summary, and output a ready-to-paste next-session prompt with the next due WBS task and exact resume command.

## Definition Of Done

Report the task complete only when every authorized stage is proven:

- Acceptance criteria pass and existing behavior remains intact.
- Financial calculations are deterministic and persistence/fallback behavior is tested.
- Supabase and Storage changes satisfy the egress, security, and cost checklist.
- Required local checks, responsive QA, CI, and review gates pass.
- PR state, merge commit, remote branch cleanup, Issue state, and WBS UUID state agree.
- Attributable heavy processes are stopped and cleanup did not touch unrelated work.
- Wrap-up and the next-session prompt are produced.
