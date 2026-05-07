# Issue #1568: 2-Instance Delegation Protocol

## Triage

- WBS / Issue: #1568
- Due date shown in WBS: 2026-05-17
- Priority order: nearest active task after closing stale CI Issue #2079
- Current owner: Claude Code #1 for architecture, Codex #1 for docs PR and GitHub hygiene
- Decision: implement the delegation protocol as a docs-only PR because the task is about routing, packet shape, review, and discard rules.

## Delegation Packet

- Branch: `codex/wbs-1568-delegation-protocol-20260507`
- Worktree: `C:\Users\kanta\GitHub\my_web_app\.claude\worktrees\focused-darwin-bcd64f`
- Allowed write set:
  - `docs/AGENT_DELEGATION_PROTOCOL.md`
  - `docs/WBS_2_INSTANCE_ROUTING.md`
  - `AGENTS.md`
  - `docs/cross-instance-prs/20260507_issue1568_2_instance_delegation_protocol.md`
- Prohibited write set:
  - Application runtime code
  - Supabase migrations or Edge Functions
  - WBS database data
  - User local Obsidian vault files
- Required validation:
  - `git diff --check`
  - GitHub Actions on PR
- Expected output:
  - Canonical two-instance routing rule
  - Delegation packet template
  - Review/intake/discard checklist
  - Per-session memory/disk hygiene gate

## Result Contract

- Changed files: recorded in the PR.
- Validation result:
  - `claude --version` -> `2.1.126 (Claude Code)`
  - `claude mcp serve --help` -> command is available; no long-running server was started.
  - `codex --version` -> `codex-cli 0.128.0`
  - docs-only local `git diff --check`, plus CI.
- Session hygiene:
  - C: free space snapshot -> `85.56 GB`
  - Ran `git worktree prune`
  - Ran `git gc --auto`
  - Stopped stale `dart.exe` PID `44536`; a new `dart.exe` was respawned by active tooling, so no further forced cleanup was applied.
- Remaining risk: none for runtime behavior; local Flutter tooling is not required for docs-only changes.
- Next owner: Codex #1 to merge PR and close #1568 after green checks.
