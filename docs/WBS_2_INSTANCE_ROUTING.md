# WBS 2-Instance Routing

Last updated: 2026-05-05

The WBS screen keeps historical `instance` and `owner_instance` values intact, but the active operating view is now projected into two human-operated development lanes:

- Claude Code: architecture, research, docs, UX triage, old Win/VSCode/PS#1/PS#3/PS#4/WEB/mobile lanes.
- Codex: implementation, CI, GitHub PR work, old Codex/PS#2/PS#5/PS#6 lanes.

`User` and `Automation` remain visible as non-development lanes so manual decisions and scheduled/GitHub Actions work do not disappear into either agent lane.

WBS execution policy:

1. Work from the nearest due date first.
2. If a task is obsolete because of the 2-instance Windows app flow, close or supersede the GitHub issue instead of implementing the old lane literally.
3. For Codex-owned implementation tasks, ship a narrow PR and record cross-instance handoff notes.
4. For Claude Code-owned design tasks, create the spec or decision note first, then hand implementation to Codex only when code changes are clear.

