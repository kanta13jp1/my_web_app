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
- Execution venue: GitHub Actions / remote API / approved cloud environment / local exception
- Local resource budget and memory/disk hygiene action for this session:
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

## Cloud-First Execution Gate

Route work before creating a worktree or starting a heavyweight process:

| Work | Default venue | Evidence |
| --- | --- | --- |
| Branch/file changes while the root tree is dirty | GitHub API or approved cloud environment | Commit and PR URL |
| Flutter/Dart analysis and tests | `CI` (`ci.yml`) on a pushed branch or PR | Successful check and analyzer artifact |
| Browser/Playwright verification | `E2E Smoke` (`e2e-smoke.yml`) | Run URL and Playwright artifact |
| Android/iOS builds | `Build Mobile Release Artifacts` (`mobile-release-build.yml`) | Run URL and retained build artifact |
| Mechanical Dart/Deno formatting | `CI Auto-Fix (manual)` after human acknowledgement | Bot commit and PR comment |
| GitHub/WBS/Supabase operations with an existing wrapper | The matching manual GitHub Actions workflow | Dispatch/run URL |

Local execution is allowed only when no equivalent cloud path exists or the user
explicitly requests it. Before the exception, record free disk, top memory
processes, expected duration, and cleanup plan. Never start local Flutter,
browser, emulator, build, or dependency-install work merely because it is the
next traditional development step.

For manual CI, push the scoped branch and run:

```powershell
gh workflow run ci.yml --ref <branch>
gh run list --workflow ci.yml --branch <branch> --limit 1
```

Use `gh run view` for summaries and logs. Download artifacts only when local
inspection or publication is explicitly needed.

## Session Hygiene Gate

Every session must perform a cheap resource check before wrap-up:

```powershell
Get-PSDrive C
Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 12 ProcessName,Id,@{Name='MB';Expression={[math]::Round($_.WorkingSet64/1MB,1)}}
git status --short --branch
git worktree list
```

These checks are read-only. Do not run `git gc`, create a worktree, install
packages, or download artifacts as an automatic session ritual when disk/RAM is
under pressure. Cleanup must target a verified inactive process or stale
worktree and remain a separate, explicit action.

Safe cleanup candidates:

- Stop orphaned `dart`, `flutter`, `node`, `git`, or `deno` processes that are not serving the active task.
- Delete local branches only after the matching PR is merged or the Issue is explicitly closed as obsolete.
- Remove missing-worktree metadata with `git worktree prune`.
- Prefer docs-only or CI-only verification when local Flutter tooling is hanging and GitHub Actions already covers the surface.

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
