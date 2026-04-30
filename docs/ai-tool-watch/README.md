# AI Tool Watch

This directory is the session-start and scheduled watch surface for official
Claude Code and Codex changes.

## What It Watches

- Claude Code changelog, hooks reference, and GitHub Actions docs.
- Codex changelog, Codex use cases, and Codex overview.
- Workflow keywords that affect this repo: hooks, schedules, GitHub Actions,
  Automations, in-app browser, models, worktrees, MCP, cost controls, CI, and
  review gates.

## How To Run

```powershell
python scripts/ai_tool_watch.py `
  --state docs/ai-tool-watch/state.json `
  --report docs/ai-tool-watch/latest-report.md `
  --json docs/ai-tool-watch/latest-report.json
```

Use `--no-save-state` during a manual session-start read if you want a dry
inspection without changing the baseline.

## Automation

`.github/workflows/ai-tool-watch.yml` runs daily at 06:15 JST and can also be
started manually. It updates the report/state files and comments on issue
`#1422` when high-priority official changes are detected.

## Routing

- Claude Code hooks, SessionStart, PostToolUse, Stop, or ultrareview changes
  route to Claude Code quality-gate work.
- Codex model, browser, computer-use, worktree, or subagent changes route to
  Codex execution and UI verification work.
- Schedule, GitHub Actions, and automation changes route to WBS/CI/deploy
  automation.
- MCP, connector, Slack, and integration changes route to connector reliability
  and NotebookLM knowledge capture.
