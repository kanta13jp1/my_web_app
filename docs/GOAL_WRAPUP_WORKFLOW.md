# Goal And Wrap-Up Workflow

Last updated: 2026-08-26

## Goal

Keep long-running WBS work resumable across Codex sessions without relying on
memory alone. Prefer a persisted goal when the active Codex app or CLI runtime
exposes it. The UI, model tools, or app-server API may expose that capability
even when a non-interactive shell does not expose a literal `/goal` command.
Always mirror the durable state through the GitHub Issue, WBS task, branch, PR
body, and this wrap-up template.

## Runtime Contract

- A goal stores the objective and continuation status. It does not replace the
  Issue acceptance criteria, branch/PR checkpoint, or deterministic validation.
- Pause or clear a goal only after recording the next action and any recovery
  state in GitHub or the wrap-up template.
- Runtime continuation does not broaden the user's permissions. Production
  writes, deploys, merges, messages, and other external changes retain their
  normal approval and safety gates.
- Use Thread Automations only when an explicit schedule is required. Do not
  convert a goal into an unattended dependency-update-to-merge loop.
- Select only a model and effort level that the current runtime exposes. Apply
  the configured adaptive router instead of permanently assigning work to the
  historical GPT-5.5 or Codex #2 labels.
- Any subagent fan-out remains bounded by
  `docs/SUBAGENT_ORCHESTRATION_POLICY.md`, including its resource-pressure gate.

## Session Start

1. Run the repository session checks:

   ```powershell
   git status --short --branch
   python scripts/codex_session_check.py
   python scripts/ai_tool_watch.py --print-only
   ```

2. Check resource pressure:

   ```powershell
   Get-CimInstance Win32_OperatingSystem |
     Select-Object FreePhysicalMemory,TotalVisibleMemorySize
   Get-PSDrive -PSProvider FileSystem |
     Select-Object Name,Free,Used,Root
   ```

3. Prefer a fresh worktree from `origin/main` if the root tree is dirty.

4. Set or mirror the active goal:

   ```text
   Goal:
   - WBS task / Issue:
   - Branch / worktree:
   - Next command:
   - Validation gate:
   - Cleanup target:
   ```

## During Work

- Follow WBS planned order, nearest due task first.
- Keep one bounded PR per WBS task unless the task is explicitly docs-only.
- Do not let AI calculate money values. Use deterministic Dart/SQL services.
- Add Issue comments instead of duplicate Issues when a task already exists.
- If memory or disk pressure rises, pause new builds and remove completed
  worktrees before running broad tests.

## Wrap-Up Checklist

1. Record implementation state:
   - Issue / WBS task
   - PR URL
   - branch / commit
   - CI or local validation
   - remaining blockers

2. Clean safe local state:
   - remove merged task worktrees,
   - delete merged local branches,
   - run `git worktree prune`,
   - avoid deleting user-owned dirty paths.

3. Capture resources after cleanup:

   ```powershell
   Get-CimInstance Win32_OperatingSystem |
     Select-Object FreePhysicalMemory,TotalVisibleMemorySize
   Get-PSDrive -PSProvider FileSystem |
     Select-Object Name,Free,Used,Root
   ```

4. Update WBS:
   - use `completed / 100` only for merged or otherwise proven work,
   - use `in_progress / 95` for implemented but unmerged PRs,
   - include Issue/PR and validation summary.

5. Produce the next-session prompt.

## Next-Session Prompt Template

```text
Continue from the previous Codex session with this state.

Goal:
- <goal statement>

Completed:
- <merged PR / closed issue / WBS update>

Current WBS next task:
- Issue: #<number>
- WBS task id: <uuid or issue-number if unknown>
- Planned: <start> to <end>
- Scope: <one bounded task>

Workspace:
- Worktree: <path>
- Branch: <branch>
- Root worktree dirty paths: <known unrelated paths>
- Memory/disk note: <free RAM, disk, cleanup already done>

Next actions:
1. git status / codex_session_check / ai_tool_watch
2. Confirm Issue/WBS state
3. Implement the scoped task
4. Run format/analyze/test/diff check
5. Create PR, check CI, mark ready, squash merge
6. Update WBS, clean worktree, wrap up
```

## Linked Issue

This workflow satisfies #2523 and the persisted-goal adoption portion of #1860.
The current Codex runtime has proven persisted objective/status recovery; no
repository-specific UI or CLI wrapper is required.
