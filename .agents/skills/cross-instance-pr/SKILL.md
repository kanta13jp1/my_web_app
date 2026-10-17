---
name: cross-instance-pr
description: Create or update a structured handoff between Claude Code #1 and Codex #1 in docs/cross-instance-prs. Use when work requires product or architecture judgment from Claude Code, deterministic implementation or CI work from Codex, or an explicit user-requested cross-instance handoff. Do not use for child subagents or dormant PS, WEB, mobile, Gemini, Copilot, or extra-Codex lanes.
---

# Cross-Instance Handoff

Create a durable handoff that follows `docs/AGENT_DELEGATION_PROTOCOL.md`.

## 1. Confirm that a handoff is needed

Use only these top-level owners:

- `claude`: Claude Code #1 for product judgment, architecture, policy, WBS design, and review boundaries.
- `codex`: Codex #1 for scoped implementation, CI, SQL, migrations, Edge Functions, workflows, and deterministic verification.

Do not represent a child subagent as a top-level instance. Record subagent work in the parent task or PR instead.

## 2. Check for an existing handoff

Search `docs/cross-instance-prs/`, `docs/cross-instance-prs/done/`, open Issues, and active PRs for the same objective. Update the existing record instead of creating a duplicate.

## 3. Create the handoff

Use `docs/cross-instance-prs/YYYYMMDD_<issue-or-wbs>_<slug>.md`. Include:

```markdown
---
date: YYYY-MM-DD
from: Claude Code #1 | Codex #1
to: Claude Code #1 | Codex #1
status: pending
priority: high | medium | low
issue: <number or null>
wbs: <UUID or null>
---

# <Title>

## Delegation Packet

- WBS / Issue:
- Due date:
- Current owner:
- Objective:
- Branch:
- Worktree:
- Allowed write set:
- Prohibited write set:
- Required validation:
- Expected output:
- Risk triggers that must return to Claude Code:
- Memory/disk hygiene action for this session:
- Subagent plan: none

## Result Contract

- Changed files:
- Validation result:
- PR / Issue links:
- Remaining risk:
- Next owner:
- Subagent evidence:
```

Use `TBD` for unknown fields and assign who must decide them. Never infer a WBS UUID from an Issue number.

## 4. Publish safely

Create the file on the current scoped branch. Review the diff and include it in the task's normal PR or handoff commit. Do not push directly to `main`, bypass branch protection, or invent a co-author identity.

When completed, update `status: completed` and move the exact file to `docs/cross-instance-prs/done/` in a reviewed change. Do not delete a pending handoff merely because it is old.

## Report

Return the handoff path, source owner, destination owner, Issue/WBS reference, allowed write set, required validation, and next owner.
