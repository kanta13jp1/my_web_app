# Codex Operating Guide

This file is the Codex-facing companion to `CLAUDE.md`. Keep it short and
actionable; detailed product memory stays in docs, issues, and NotebookLM.

## Session Start

1. Check the working tree before editing.
2. Prefer a fresh worktree from `origin/main` when the root tree is dirty.
3. Record the Codex session/worktree safety snapshot:

```powershell
python scripts/codex_session_check.py
```

The report should show the current branch, upstream drift, dirty paths, nearby
worktrees, and any exposed sandbox/approval environment variables. Treat
warnings as routing signals before editing.

4. Run the official AI tooling watch:

```powershell
python scripts/ai_tool_watch.py --print-only
```

Use the report to route new Claude Code or Codex capabilities into WBS, issues,
GitHub Actions, hooks, or review automation.
For NotebookLM-driven sessions, treat notebook
`bc58b50b-5fc4-4840-9a62-b397d6d3b65a` as the current harness-engineering
reference: Claude Code designs the environment, Codex executes scoped changes,
and GitHub Actions proves the result.
For notebook `1aced136-1352-4933-b727-478d3c35b360`, use
`docs/CLAUDE_CODE_MASTERCLASS_AGENTIC_WORKFLOW.md` as the applied decision note;
refresh NotebookLM auth before adding new hooks, skills, MCP servers, or agent
lanes from that source.

5. For NotebookLM-driven sessions, run the intake diff gate after confirming
   NotebookLM authentication:

```powershell
notebooklm list --json
python scripts/notebooklm_intake_gate.py --refresh --metadata routed --gh-dedup
```

Route `docs/notebooklm-intake/issue-drafts.md` into existing GitHub Issues/WBS
before creating a new Issue. Keep skip reasons in
`docs/notebooklm-intake/state.json` so repeated sessions do not re-triage the
same notebook.

## Role Split

- Claude Code owns planning, architecture, review, and quality-gate design.
- Codex #1 owns scoped implementation, cross-cutting investigation,
  SQL/migration review, CI, synchronization, operations, Edge Functions,
  GitHub Actions, deterministic automation, branch cleanup, and fix PRs.
- Historical extra Codex lanes and older PS/WEB/mobile/Gemini/Copilot lanes are
  dormant labels only. Codex #1 absorbs their implementation and CI duties under
  the current two-instance flow unless the user explicitly reactivates them.
- Use `docs/AGENT_DELEGATION_PROTOCOL.md` as the current handoff and review
  contract for WBS tasks.

## Codex Defaults

- Work from a scoped branch and keep unrelated user changes intact.
- Prefer deterministic checks over agent claims: `flutter analyze`,
  `flutter test`, `deno lint`, migration checks, and GitHub Actions status.
- For WBS pressure, prioritize tasks that reduce repeated manual work:
  CI repair, deploy stability, merge backlog, issue sync, scheduled reports,
  and tool-change monitoring.
- When an official Claude Code or Codex changelog mentions hooks, schedules,
  models, in-app browser, worktrees, MCP, or cost controls, connect it to the
  nearest existing issue before creating a new one.
- Codex #1 should take broad but bounded work from the WBS top list:
  migrations, data import/export, UI verification, stale automation audits, and
  clean fix PRs from a fresh worktree.
- Codex #1 should also absorb historical extra-Codex work: red CI, deploy
  unblockers, workflow drift, Edge Function failures, and GitHub/Notion/Slack
  synchronization issues.
- If local `SUPABASE_SERVICE_ROLE_KEY` is unavailable, use GitHub Actions
  `WBS Progress Update (manual)` (`wbs-progress-update.yml`) to dispatch one
  `wbs.update_progress` call with task id, progress, status, Issue/PR reference,
  validation summary, and a recovery plan for non-completed work. Use
  `in_progress` / `95` for implemented-but-unmerged PRs; reserve
  `completed` / `100` for merged or otherwise proven work.
- Edge Function dependency resolution follows
  `docs/adr/2026-04-30-edge-function-dependency-resolution.md`.
- If a task needs product judgment, cross-instance arbitration, or NotebookLM
  synthesis before code can be safely changed, route it back to Claude Code and
  leave a short handoff note.
