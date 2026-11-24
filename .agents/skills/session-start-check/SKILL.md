---
name: session-start-check
description: Run the my_web_app session intake before repository work. Use at the start of a Codex or Claude Code implementation, CI, migration, release, cleanup, or broad repository review to inspect branch safety, dirty paths, worktrees, tool drift, rule drift, and current two-instance routing without mutating project state.
---

# Session Start Check

Run a read-only intake before editing or launching expensive commands.

## 1. Establish repository state

Run from the intended worktree:

```powershell
git status -sb
git branch --show-current
git rev-parse --show-toplevel
python scripts/codex_session_check.py
```

Treat the report as routing evidence:

- If the primary worktree is dirty, preserve it and use a clean scoped worktree from `origin/main` for new changes.
- Reuse an already-owned clean worktree when its Issue, branch, and write set match the task.
- Never repair unrelated changes with stash, reset, restore, clean, or a broad commit.

## 2. Verify injected rules

Use UTF-8 on Windows:

```powershell
$env:PYTHONUTF8 = '1'
python scripts/sync_inject_rules.py --verify
```

Report drift. Do not run `--apply` or `--reverse` unless the user explicitly authorizes synchronization after reviewing the direction.

## 3. Check tool changes

```powershell
$env:PYTHONUTF8 = '1'
python scripts/check_versions.py
python scripts/ai_tool_watch.py --print-only
```

Route meaningful tool changes to an existing Issue, WBS item, hook, workflow, or review gate. Do not create a new Issue solely because a changelog changed before checking for an existing route.

## 4. Confirm the operating model

Read `AGENTS.md` and `docs/AGENT_DELEGATION_PROTOCOL.md` when ownership or handoff matters.

- Claude Code #1 owns product judgment, architecture, policy, and review boundaries.
- Codex #1 owns scoped implementation, CI, SQL, Edge Functions, GitHub Actions, and deterministic verification.
- Historical PS, WEB, mobile, Gemini, Copilot, and extra-Codex lanes remain dormant unless the user explicitly reactivates them.
- Use child subagents only under `docs/SUBAGENT_ORCHESTRATION_POLICY.md`.

## 5. Add task-specific gates

- For NotebookLM-driven work, run the authenticated intake gate required by `AGENTS.md`.
- For product behavior, read `docs/PHILOSOPHY.md` before making design decisions.
- For WBS work, select the nearest-due unblocked task and keep the Issue number distinct from the WBS UUID.
- Do not perform WBS writes, notifications, commits, pushes, or cleanup as part of this intake.

## Report

Return:

- repository, branch, HEAD, and upstream drift;
- dirty-path count and worktree decision;
- rule and tool drift;
- active two-instance owner;
- resource or authentication warnings relevant to the requested task;
- the next safe action.

Do not claim the session is safe when a required check failed or was skipped.
