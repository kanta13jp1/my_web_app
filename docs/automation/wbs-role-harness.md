# WBS Role Harness

Issue: #1636

This harness turns a WBS/GitHub Issue into a fixed two-instance execution
packet. It does not add more local agents. Historical mentions of Codex #2,
Codex #3/#4, VSCode, Win, or PS lanes are treated as routing context only.

Active execution lanes:

- Claude Code #1 owns architecture, boundary decisions, exception policy, and
  high-risk review.
- Codex #1 owns fresh-worktree implementation, local verification, scoped PRs,
  CI follow-through, merge, and cleanup.
- GitHub Actions owns evidence artifacts, required checks, and deploy status.
- User/Automation owns manual decisions, blocked states, and schedule-only work.

## Classification

`scripts/wbs_role_harness.py` classifies each Issue into one of these plans:

- `automation_wbs`: Codex #1 opens a single scoped PR for scripts, workflows,
  WBS docs, and evidence wiring.
- `ui_validation`: Codex #1 owns the implementation PR and captures visual/E2E
  evidence.
- `scoped_implementation`: Codex #1 owns one narrow PR and normal tests.
- `data_or_security`: Claude Code #1 writes or approves the design packet before
  Codex touches migrations, RLS, service-role paths, or Edge Functions.
- `claude_first`: Claude Code #1 starts with docs/ADR/review because the safe
  implementation boundary is not yet clear.
- `blocked_or_manual`: User/Automation must resolve the blocker before a PR.

The script sorts generated plans by the first explicit due/deadline date it can
find in the Issue body or comments. When WBS due dates are only visible in the
WBS UI, pass the nearest Issue number explicitly.

## Handoff Packet

Every packet must include:

- Issue/WBS id
- branch
- worktree
- allowed write set
- prohibited write set
- validation command
- unresolved risk
- next owner

The packet returns to Claude Code #1 when the task touches security, auth,
payments, legal/tax decisions, migrations, RLS, `service_role`, Supabase Edge
Functions, unclear ownership, or High conflict risk.

## Conflict Rules

- Start from a fresh task worktree based on latest `origin/main`.
- Record planned paths before editing.
- Use `scripts/worktree_registry.py preflight` for planned or staged paths.
- Use `scripts/instance_conflict_predictor.py` when shared workflows,
  migrations, or cross-instance docs are involved.
- Stop and hand off to Claude Code #1 on High conflict risk.

## Evidence Targets

- PR body Minimal E2E Gate section
- GitHub Actions report artifact
- Issue closing comment or linked merged PR
- WBS status/progress note when the Issue is not auto-closed
- CI run URL, deploy run URL, and cleanup confirmation

## Resource Hygiene

Every session must record:

- C drive free space before and after work
- top memory processes before and after work
- leftover dev server, dart, node, and git process check
- branch/worktree state before and after work

After merge, remove the task worktree, prune worktrees, run `git gc --auto`,
and avoid leaving task-local dependency caches such as `node_modules`.

## Local Commands

```powershell
python scripts\wbs_role_harness_test.py

$outMd = Join-Path $env:TEMP 'wbs-role-harness.md'
$outJson = Join-Path $env:TEMP 'wbs-role-harness.json'
python scripts\wbs_role_harness.py `
  --repo kanta13jp1/my_web_app `
  --issue-number 1636 `
  --output-md $outMd `
  --output-json $outJson
```
