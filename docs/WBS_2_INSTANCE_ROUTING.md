# WBS 2-Instance Routing

Last updated: 2026-05-07

Canonical delegation protocol: [`docs/AGENT_DELEGATION_PROTOCOL.md`](./AGENT_DELEGATION_PROTOCOL.md).
Role harness report: [`docs/automation/wbs-role-harness.md`](./automation/wbs-role-harness.md).

The WBS screen keeps historical `instance` and `owner_instance` values intact, but the active operating view is now projected into two human-operated development lanes:

- Claude Code: architecture, research, docs, UX triage, old Win/VSCode/PS#1/PS#3/PS#4/WEB/mobile lanes.
- Codex: implementation, CI, GitHub PR work, old Codex/PS#2/PS#5/PS#6 lanes.

`User` and `Automation` remain visible as non-development lanes so manual decisions and scheduled/GitHub Actions work do not disappear into either agent lane.

Implementation notes:

- The WBS UI shows only `All`, `Claude Code`, `Codex`, `User`, and `Automation` chips. Historical VS/Win/PS#1-6/Gemini/Copilot chips are hidden from active operation.
- `tools-hub:wbs.list_tasks`, `wbs.tasks.list`, `wbs.priority_for_instance`, and workload summaries project legacy DB values into the same four active lanes.
- `claude` writes to legacy `win` only when a task must be persisted, and `automation` writes to legacy `schedule`. Existing historical `instance` values are not rewritten in place.
- `gemini`, `co-pilot`, `schedule`, and `gha` are grouped as `Automation` because they are tools or scheduled jobs, not human development instances.

WBS execution policy:

1. Work from the nearest due date first.
2. If a task is obsolete because of the 2-instance Windows app flow, close or supersede the GitHub issue instead of implementing the old lane literally.
3. For Codex-owned implementation tasks, ship a narrow PR and record cross-instance handoff notes.
4. For Claude Code-owned design tasks, create the spec or decision note first, then hand implementation to Codex only when code changes are clear.
5. Every handoff must include Issue/WBS id, branch, worktree, allowed write set, prohibited write set, validation command, unresolved risk, and the next owner.
6. Every session must include a cheap memory/disk hygiene check before wrap-up.
7. Use `scripts/wbs_role_harness.py` to classify high-priority WBS Issues into
   `single_scoped_pr`, `multi_pr_or_claude_first`, or
   `blocked_until_owner_decision` before opening a scoped PR.

