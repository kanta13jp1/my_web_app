# Agent Delegation Protocol

Status: canonical operating protocol / 2026-05-07 / Issue #1568

This project runs development with exactly two top-level human-operated
instances:

- Claude Code #1 (Windows app): planning, architecture, research, product judgment, UX triage, WBS design, review boundaries, and wrap-up.
- Codex #1 (Windows app): scoped implementation, CI, GitHub PRs, Edge Functions, workflows, branch cleanup, and deterministic verification.

Historical lanes such as PS#1-6, WEB, mobile, Gemini, Copilot, Codex #2, and
ad-hoc sub-fleet labels are dormant mappings only. They must not be started as
additional top-level live instances unless the user explicitly reactivates them.

Guarded subagents are permitted as child workers under Claude Code #1 or Codex
#1. They are not independent project owners. Use them only for bounded,
task-scoped work such as isolated research, rubric critique, large-output
inspection, or disjoint implementation. The full policy is
`docs/SUBAGENT_ORCHESTRATION_POLICY.md`.

## Routing Rule

Work WBS items from the nearest due date first.

Before choosing a local worker or toolchain, run
`python scripts/cloud_first_route.py`. When it reports `CLOUD_REQUIRED`, both
top-level instances must keep the local session lightweight: no dependency
hydration, full analyzer/test/build, dev server, Docker job, or local child
worker. Use a sparse checkout for edits and
`python scripts/cloud_ci_handoff.py --execute --watch` for exact-SHA GitHub
Actions proof after pushing the branch. The full procedure is
`docs/CLOUD_FIRST_DEVELOPMENT.md`.

Local tool check on 2026-05-07:

- `claude --version`: `2.1.126 (Claude Code)`
- `claude mcp serve --help`: available; do not leave a long-running MCP server open unless a task explicitly needs it.
- `codex --version`: `codex-cli 0.128.0`

Use this decision gate before changing files:

| Question | If yes | If no |
| --- | --- | --- |
| Does the task need product judgment, architecture, or a trade-off decision? | Claude Code owns the decision note. | Continue. |
| Does it change shared rules, memory, WBS policy, or cross-instance process? | Claude Code owns the spec and review boundary. | Continue. |
| Is it implementation, CI, GitHub Actions, Edge Function, SQL, or deterministic UI repair? | Codex owns the PR. | Continue. |
| Does it touch payments, security, permissions, production data, or user-visible irreversible behavior? | Claude Code approves before Codex ships. | Continue. |
| Is the task obsolete under the two-instance flow? | Close or supersede the Issue with a comment. | Implement normally. |
| Would a subagent reduce context noise, run an independent critique, or own a disjoint side task? | Launch a guarded child worker and record the evidence. | Keep the work in the lead session. |

## Delegation Packet

Every delegated task must include this packet. If any field is unknown, write `TBD` and assign the owner of that decision.

```markdown
## Delegation Packet

- WBS / Issue:
- Due date:
- Current owner: Claude Code #1 / Codex #1 / User / Automation
- Objective:
- Branch:
- Worktree:
- Allowed write set:
- Prohibited write set:
- Required validation:
- Expected output:
- Risk triggers that must return to Claude Code:
- Memory/disk hygiene action for this session:
- Subagent plan: none / roles, scope, budget, return contract

## Result Contract

- Changed files:
- Validation result:
- PR / Issue links:
- Remaining risk:
- Next owner:
- Subagent evidence:
```

## Write Boundary

Use narrow ownership. One task may be split across both instances only when their write sets are disjoint.

| Area | Owner | Notes |
| --- | --- | --- |
| Architecture, decision records, WBS policy | Claude Code #1 | Codex may edit only from an explicit packet. |
| Flutter UI implementation and tests | Codex #1 | Claude Code provides UX intent or acceptance criteria when needed. |
| Supabase Edge Functions and SQL | Codex #1 | Escalate schema-risk or production-data decisions. |
| GitHub Actions, CI, deploy repair | Codex #1 | Claude Code reviews policy changes. |
| Memory, NotebookLM, wrap-up records | Claude Code #1 | Codex may add handoff notes and issue comments. |
| Branch/worktree cleanup | Codex #1 | Never delete an unmerged or dirty worktree without evidence. |

## Intake, Review, And Discard

When Codex returns a PR or branch:

1. Confirm the Issue/WBS id and due date match the packet.
2. Confirm changed files are inside the allowed write set.
3. Confirm the validation commands actually ran, or that CI passed equivalent checks.
4. Confirm unresolved risks are explicit.
5. Merge only after checks are green or after the user explicitly accepts the residual risk.
6. Delete merged branches and prune stale worktree metadata.

Discard instead of merge when:

- The branch edits prohibited files.
- The branch includes unrelated cleanup or formatting churn.
- The implementation duplicates a feature already merged.
- The Issue has become obsolete under the current two-instance flow.
- The validation result is missing and CI does not cover the changed surface.

## Session Hygiene Gate

Every session must perform a cheap resource check before wrap-up:

```powershell
Get-PSDrive C
Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 12 ProcessName,Id,@{Name='MB';Expression={[math]::Round($_.WorkingSet64/1MB,1)}}
git worktree prune
git gc --auto
```

The check at session start is a routing decision, not a cleanup request. Free
disk below 30 GiB, free physical memory below 4 GiB, or memory use at/above 85%
makes cloud validation mandatory. Never delete another task's worktree or stop
an unverified process merely to cross the threshold.

Safe cleanup candidates:

- Stop orphaned `dart`, `flutter`, `node`, `git`, or `deno` processes that are not serving the active task.
- Delete local branches only after the matching PR is merged or the Issue is explicitly closed as obsolete.
- Remove missing-worktree metadata with `git worktree prune`.
- Prefer CI-only verification for all heavy toolchains; local Flutter/Deno
  execution is an exception reserved for healthy resources or unavailable CI.

Never clean:

- Active user documents.
- Dirty worktrees without a recorded handoff.
- OneDrive folders that may still be syncing user data.
- Browser/Obsidian sessions the user is actively inspecting.

## Acceptance Mapping For Issue #1568

- Conflict-free decomposition: enforced by the `Allowed write set` and `Prohibited write set` fields.
- Result completeness: enforced by the `Result Contract`.
- High-risk routing: enforced by the routing gate and risk triggers.
- Two-instance constraint: canonical roles reduce live human agents to Claude Code #1 and Codex #1.
- Guarded orchestration: subagents may be child workers under those two leads,
  with bounded scope, evidence, and cleanup requirements.
