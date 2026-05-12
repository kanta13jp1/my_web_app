# AI Tool Watch

This directory is the session-start and scheduled watch surface for official
Claude Code, Codex, Gemini Code Assist, and GitHub Copilot changes.

2026-05-07 #1706 gate: new AI-tool capability claims must be verified against
official sources before they are adopted by the active two-instance flow:
Claude Code #1 (Windows app) for policy/review and Codex #1 (Windows app) for
scoped implementation PRs, CI, merge, and cleanup.

## What It Watches

- Claude Code changelog, hooks reference, and GitHub Actions docs.
- Codex changelog, Codex use cases, and Codex overview.
- Workflow keywords that affect this repo: hooks, schedules, GitHub Actions,
  Automations, in-app browser, models, worktrees, MCP, cost controls, CI, and
  review gates.
- NotebookLM harness notebook
  `bc58b50b-5fc4-4840-9a62-b397d6d3b65a`, used as the Master Brain routing
  reference after it is normalized to the current Claude Code #1 plus Codex #1
  two-instance operating model.

## How To Run

```powershell
python scripts/ai_tool_watch.py `
  --state docs/ai-tool-watch/state.json `
  --report docs/ai-tool-watch/latest-report.md `
  --json docs/ai-tool-watch/latest-report.json
```

Use `--no-save-state` during a manual session-start read if you want a dry
inspection without changing the baseline.

NotebookLM intake uses a separate gate because it needs local NotebookLM auth
and Issue/WBS deduplication:

```powershell
notebooklm list --json
python scripts/notebooklm_intake_gate.py --refresh --metadata routed --gh-dedup
```

Review `docs/notebooklm-intake/issue-drafts.md` before creating new Issues;
existing Issues and skip reasons should be preferred.

## Automation

`.github/workflows/ai-tool-watch.yml` runs daily at 06:15 JST and can also be
started manually. It updates the report/state files and comments on issue
`#1422` when high-priority official changes are detected.

## Routing

- Claude Code hooks, SessionStart, PostToolUse, Stop, or ultrareview changes
  route to Claude Code quality-gate work.
- Codex model, browser, computer-use, worktree, or subagent changes route to
  Codex #1 execution and UI verification work.
- Schedule, GitHub Actions, and automation changes route to WBS/CI/deploy
  automation, normally owned by Codex #1 as scoped PR work.
- MCP, connector, Slack, and integration changes route to connector reliability
  and NotebookLM knowledge capture.
- Repeated manual WBS work becomes a candidate for a scheduled task, hook, or
  GitHub Actions gate.
