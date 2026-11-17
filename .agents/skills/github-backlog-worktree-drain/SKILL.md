---
name: github-backlog-worktree-drain
description: Orchestrate a resumable, one-lane-at-a-time GitHub backlog transaction for my_web_app from Issue or PR selection through dirty Worktree preservation, validation, commit, push, CI repair, main merge, WBS synchronization, and safe cleanup. Use when asked to continue many Issues or PRs, organize dirty or unmerged Worktrees, merge proven PRs, recover an interrupted hook or push, resolve a large backlog, or pause heavy Flutter/Dart/Git work without losing progress.
---

# GitHub Backlog Worktree Drain

Finish one owned GitHub lane at a time and leave enough evidence to resume it
after a timeout, process interruption, or PC-load pause.

## Delegate instead of duplicating

- Use `$github-backlog-batch` to build the oldest-first queue and select an
  actionable Issue or existing PR.
- Use `$github`, `$gh-fix-ci`, and `$yeet` for GitHub metadata, CI logs, and
  publication when those skills are available.
- Use `$reduce-windows-pc-lag` when CPU, memory, paging, or orphaned Flutter and
  Dart jobs become the active problem.
- Follow repository `AGENTS.md`, hooks, branch protection, and WBS policy over
  this skill when they are more specific.

## Non-negotiable invariants

- Run only one mutating Git lane at a time. Read-only triage may be batched.
- Preserve unrelated dirty files. Never stash, reset, restore, or clean another
  lane's changes.
- Never use `--no-verify`, force push, broad process kills, or forced Worktree
  removal.
- Treat local HEAD, remote SHA, PR state, required checks, and merge result as
  separate facts. Verify each fact directly.
- Do not remove a Worktree until the bundled cleanup checker returns safe and
  the exact PR merge is proven.
- The latest explicit pause or load-relief request wins immediately.

## Transaction

### 1. Apply the pause gate

Before starting a test, analysis, build, browser run, monitor, push, or Worktree
operation, check the latest user instruction. On pause:

1. Stop only task-owned command sessions or freshly revalidated process IDs.
2. Do not delete files, branches, Worktrees, PRs, or checkpoints.
3. Save a checkpoint with status `paused`, completed evidence, unconfirmed
   remote actions, and one exact next action.
4. Resume only after new user input permits work. Re-audit local and remote
   state before continuing.

Read [`references/transaction-contract.md`](references/transaction-contract.md)
for interruption and cleanup evidence rules.

### 2. Load state and run preflight

Resolve bundled paths from this skill directory. Show existing checkpoints,
then inspect the target Worktree without mutating it:

```powershell
python scripts/worktree_state.py checkpoint list --repo <repo>
python scripts/worktree_state.py audit --repo <repo> --target <worktree>
```

Run the repository session check and AI tooling watch. If the root is dirty,
reuse an already-owned dedicated Worktree or create a fresh one from
`origin/main`. Never transplant root changes into the lane without inspecting
and attributing every path.

### 3. Establish ownership and scope

Confirm the Issue, PR, branch, Worktree, current HEAD, upstream, dirty paths,
and competing branches or PRs. Prefer the existing PR lane over a duplicate.
Write a checkpoint before the first mutation:

```powershell
python scripts/worktree_state.py checkpoint set --repo <worktree> `
  --phase scope --status in_progress --issue <number> --pr <number> `
  --summary "Scope and ownership confirmed" `
  --next-action "Run targeted validation"
```

### 4. Validate from narrow to broad

Derive acceptance criteria from the live Issue, PR, docs, and code. Run format
or syntax checks, targeted tests, targeted analysis, and finally one required
full gate when the PC has capacity. Record exact commands and results as
checkpoint evidence.

If a hook times out, inspect its process tree. Do not remove `index.lock` while
an owning Git process is alive. After the process ends, verify whether a commit
or push actually happened before retrying.

### 5. Commit and synchronize

Stage only attributed paths. Confirm the staged diff, commit normally, fetch
`origin/main`, integrate it under repository policy, and rerun checks affected
by conflicts. Save the new commit SHA in a checkpoint.

### 6. Publish and repair CI

Update the PR body before push when body-driven gates exist. Push the explicit
branch and verify the remote ref with `git ls-remote`; a local command exit or
timeout does not prove the remote result. Inspect required checks and review
threads, repair failures, and repeat until the exact head SHA is green.

Use [`references/my-web-app-operations.md`](references/my-web-app-operations.md)
for repository commands, PR gate checks, and WBS updates.

### 7. Merge and prove completion

Merge only when authority, required checks, review state, and branch protection
allow it. Use an expected head SHA. Then confirm `mergedAt`, merge commit or
squash result, `origin/main`, Issue state, and WBS state. Mark WBS
`completed / 100` only after this proof.

### 8. Check cleanup, then remove explicitly

Fetch `origin/main` and run the checker before any removal:

```powershell
python scripts/worktree_state.py cleanup-check --repo <repo> `
  --worktree <worktree> --base origin/main `
  --github-repo OWNER/REPO --pr <number> --expected-head <sha>
```

The checker is read-only. When it returns `safe: true`, remove that exact
Worktree, delete only the merged local branch, verify the remote branch state,
and re-run `git worktree list`. Keep the checkpoint until cleanup is confirmed;
then clear it with `--confirm-cleaned`.

### 9. Continue the backlog

Refresh live Issue and PR counts, record skipped older items with concrete
reasons, and return to `$github-backlog-batch` for the next oldest safe lane.
Never mark the whole backlog complete from one merged PR.

## Bundled resources

- `scripts/worktree_state.py`: audit Worktrees, store secret-free checkpoints,
  and prove cleanup safety without deleting anything.
- `scripts/test_worktree_state.py`: deterministic temporary-repository tests.
- `references/transaction-contract.md`: state, interruption, and cleanup proof.
- `references/my-web-app-operations.md`: repository-specific command recipes.
