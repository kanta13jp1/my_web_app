# Codex Operating Guide

This file is the Codex-facing companion to `CLAUDE.md`. Keep it short and
actionable; detailed product memory stays in docs, issues, and NotebookLM.

## Cloud-First Resource Policy

- Treat GitHub-hosted runners and remote repository APIs as the default execution
  venue. Keep the Windows PC focused on lightweight inspection, small edits, and
  user interaction.
- Do not start local `flutter analyze`, `flutter test`, Flutter builds, Playwright
  browsers, emulators, dev servers, dependency installs, or artifact generation
  when an equivalent GitHub Actions workflow exists.
- Use `CI` (`ci.yml`) for analysis and tests, `E2E Smoke` (`e2e-smoke.yml`) for
  browser evidence, and `Build Mobile Release Artifacts`
  (`mobile-release-build.yml`) for Android/iOS builds. Treat their run URLs and
  artifacts as the verification record.
- When the root tree is dirty or disk/RAM pressure is reported, preserve it and
  create the branch, commit, and PR through GitHub APIs or another approved cloud
  environment. Do not create another local worktree merely to isolate the task.
- A local heavy command is an exception. Run it only when the user explicitly
  requests local execution, no cloud equivalent exists, and a fresh disk/RAM
  check shows that the machine can safely absorb it. Record the reason in the PR
  or handoff.
- Do not download cloud artifacts unless the user needs to inspect or publish
  them locally. Prefer GitHub summaries, logs, checks, and retained artifacts.

See `docs/CLOUD_FIRST_EXECUTION_POLICY.md` for the routing matrix and commands.

## Session Start

1. Check the working tree before editing.
2. Prefer a scoped remote branch from `origin/main`. Create a local worktree only when cloud editing is unavailable and the resource gate is safe.
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
- Top-level live instances remain Claude Code #1 and Codex #1. Historical extra
  Codex lanes and older PS/WEB/mobile/Gemini/Copilot lanes are dormant labels
  only unless the user explicitly reactivates them as top-level instances.
- Guarded subagents are now allowed as child workers owned by Claude Code #1 or
  Codex #1 when they provide isolated context, bounded parallel research,
  rubric-based critique, or disjoint scoped implementation. Follow
  `docs/SUBAGENT_ORCHESTRATION_POLICY.md` before launching or accepting their
  output.
- Use `docs/AGENT_DELEGATION_PROTOCOL.md` as the current handoff and review
  contract for WBS tasks.

## Codex Defaults

- Work from a scoped branch and keep unrelated user changes intact.
- Prefer deterministic cloud checks over agent claims. Use GitHub Actions for
  Flutter analysis/tests/builds, Deno checks, browser automation, and artifacts;
  reserve local execution for documented exceptions.
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
- When using subagents, record their role, scope, result summary, validation
  impact, and cleanup impact in the PR, Issue comment, or wrap-up. Subagents do
  not replace deterministic checks or WBS due-date order.
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

## AI-generated code responsibility

- AI-generated changes are proposals; the repository owner retains the final
  product and release decision.
- Authentication, database schema or RLS, billing, external publishing,
  permissions, secrets, and batch execution are core areas. They require an
  explicit human review acknowledgement in addition to deterministic checks.
- PostToolUse anti-pattern warnings are review prompts, not proof of safety.
  Resolve each warning or record a narrow exception, then run the applicable
  formatter, analyzer, tests, security checks, and PR quality gates.
