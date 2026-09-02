# Codex Operating Guide

This file is the Codex-facing companion to `CLAUDE.md`. Keep it short and
actionable; detailed product memory stays in docs, issues, and NotebookLM.

## Session Start

1. Check the working tree before editing.
2. If a local checkout is required, prefer a sparse worktree from `origin/main`
   when the root tree is dirty. Include only the paths needed by the task.
3. Route from a cheap disk/RAM snapshot before starting toolchains:

```powershell
python scripts/cloud_first_route.py
```

4. Record the Codex session/worktree safety snapshot:

```powershell
python scripts/codex_session_check.py
```

The report should show the current branch, upstream drift, dirty paths, nearby
worktrees, and any exposed sandbox/approval environment variables. Treat
warnings as routing signals before editing.

5. Run the official AI tooling watch:

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

6. For NotebookLM-driven sessions, run the intake diff gate after confirming
   NotebookLM authentication:

```powershell
notebooklm list --json
python scripts/notebooklm_intake_gate.py --refresh --metadata routed --gh-dedup
```

Route `docs/notebooklm-intake/issue-drafts.md` into existing GitHub Issues/WBS
before creating a new Issue. Keep skip reasons in
`docs/notebooklm-intake/state.json` so repeated sessions do not re-triage the
same notebook.

## Cloud-first Resource Policy

- GitHub Actions is the default authority for Flutter/Dart analysis, tests,
  Deno checks, production builds, coverage, and generated artifacts.
- Cloud execution is mandatory when free disk is below 30 GiB, free physical
  memory is below 4 GiB, or memory use is at least 85%. In that state, do not
  run `flutter pub get`, `flutter analyze`, `flutter test`, `flutter build`,
  broad `dart analyze`, `deno test`, Docker builds, package installs, local
  dev servers, or local child workers.
- Under pressure, keep local work to sparse editing, `git diff --check`, and
  lightweight Python/YAML policy tests. Push the exact branch and either open a
  draft PR or dispatch `.github/workflows/ci.yml`; record the checked head SHA.
- A manual cloud gate can be started after the committed branch exists on
  GitHub. The helper rejects dirty, protected, missing, or unpushed branch
  state, passes the exact 40-character HEAD to Actions, and finds only the new
  run for that SHA:

```powershell
git push -u origin HEAD
python scripts/cloud_ci_handoff.py --execute --watch
```

- Manual dispatch validates the branch head. PR CI remains required because it
  validates the GitHub merge ref. See `docs/CLOUD_FIRST_DEVELOPMENT.md`.
- Do not remove unrelated worktrees or caches to manufacture headroom. Clean
  only outputs created by the current task and preserve every dirty worktree.

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
- Prefer deterministic checks over agent claims. Under the cloud-first policy,
  use GitHub Actions status and artifacts for `flutter analyze`, `flutter test`,
  `deno lint`, migrations, and builds instead of repeating them locally.
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
## Cloud-first Execution

- Prefer remote-only GitHub API edits for small changes and the default GitHub Codespaces control-plane configuration for interactive multi-file editing.
- The default `.devcontainer/devcontainer.json` must stay lightweight: do not add Flutter installation, `flutter pub get`, builds, browser automation, or media processing to its startup path.
- Default heavy work to `.github/workflows/cloud-development.yml`; see `docs/CLOUD_FIRST_DEVELOPMENT_WORKFLOW.md`.
- Keep local work to scoped inspection, emergency-safe edits, branch/PR operations, workflow dispatch, log inspection, and short HTTP/revision smoke checks.
- Run Flutter dependency resolution, analysis, tests, release web builds, and deployment gates on GitHub-hosted runners whenever the workflow can cover the task.
- Do not create a local worktree or start local Flutter/Dart builds, analysis, tests, browser automation, or media processing when RAM usage is at least 85% or free physical memory is below 2 GB. Preserve edits remotely and dispatch the cloud workflow instead.
- The `.devcontainer/flutter-local/devcontainer.json` configuration is an explicit resource-heavy fallback only; never select it automatically.
- Use `workspace` for configuration-only validation, `analyze`, `test`, or `web-build` while iterating, and `full` before merge. Do not download cloud build artifacts merely to redeploy them locally.