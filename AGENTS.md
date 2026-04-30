# Codex Operating Guide

This file is the Codex-facing companion to `CLAUDE.md`. Keep it short and
actionable; detailed product memory stays in docs, issues, and NotebookLM.

## Session Start

1. Check the working tree before editing.
2. Prefer a fresh worktree from `origin/main` when the root tree is dirty.
3. Run the official AI tooling watch:

```powershell
python scripts/ai_tool_watch.py --print-only
```

Use the report to route new Claude Code or Codex capabilities into WBS, issues,
GitHub Actions, hooks, or review automation.

## Role Split

- Claude Code owns planning, architecture, review, and quality-gate design.
- Codex #1 owns cross-cutting investigation, SQL/migration review, and fix PRs.
- Codex #2 owns CI, synchronization, operations, Edge Functions, GitHub Actions,
  and deterministic automation.

## Codex #2 Defaults

- Work from a scoped branch and keep unrelated user changes intact.
- Prefer deterministic checks over agent claims: `flutter analyze`,
  `flutter test`, `deno lint`, migration checks, and GitHub Actions status.
- For WBS pressure, prioritize tasks that reduce repeated manual work:
  CI repair, deploy stability, merge backlog, issue sync, scheduled reports,
  and tool-change monitoring.
- When an official Claude Code or Codex changelog mentions hooks, schedules,
  models, in-app browser, worktrees, MCP, or cost controls, connect it to the
  nearest existing issue before creating a new one.
