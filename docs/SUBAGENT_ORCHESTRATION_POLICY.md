# Guarded Subagent Orchestration Policy

Status: active / 2026-05-17 / Issue #2535

This project permits bounded subagent use, but it does not return to the old
uncontrolled multi-instance fleet. Claude Code #1 and Codex #1 remain the only
top-level human-operated instances. Subagents are child workers owned by one of
those two leads, and their work must be summarized back into the lead session,
GitHub Issue, WBS note, or PR evidence.

## Operating Model

- Claude Code #1 remains the lead for architecture, product judgment, high-risk
  review, and policy decisions.
- Codex #1 remains the lead for scoped implementation, local verification, CI,
  PRs, deploy follow-up, WBS sync, and cleanup.
- A lead may spawn subagents only when the task benefits from isolated context,
  parallel search, independent critique, or bounded verification.
- Historical lanes such as Codex #2/#3, PS lanes, Gemini, Copilot, WEB, or
  mobile remain dormant labels unless the user explicitly reactivates them as
  top-level instances. Subagents do not reactivate those lanes.

## Allowed Patterns

Use subagents when at least one condition is true:

- Breadth-first research: independent fact, competitor, source, or log searches
  can run in parallel and return compact findings.
- Outcomes loop: a reviewer or evaluator subagent scores output against a
  rubric and returns pass/fail plus concrete repair instructions.
- Architect/implementer split: the lead owns design while a worker implements a
  narrow, disjoint write set, or vice versa.
- Memory/dreaming review: a read-only worker reviews prior session notes,
  recurring mistakes, or cleanup logs and returns a reusable lesson.
- Large-output isolation: tests, logs, code search, or artifact inspection would
  flood the main context if done inline.

## Guardrails

Every subagent launch must have:

- Purpose: one sentence describing the role and expected output.
- Scope: read-only or an explicit allowed write set.
- Budget: a practical cap on runtime, files, or investigation breadth.
- Return contract: a short summary, changed files if any, validation result, and
  unresolved risks.
- Resource note: whether it may start a dev server, install dependencies, or
  run long-lived processes. Default is no.

Do not use subagents when:

- The task is a quick, single-file edit.
- The next step is blocked on the subagent result and the lead would sit idle.
- The work touches production data, secrets, RLS, payments, legal/tax/banking
  decisions, or irreversible user-visible behavior without Claude Code #1 or
  user approval.
- The worktree is dirty or overlaps another active task and ownership is
  unclear.
- C: free space, RAM pressure, or process hygiene is already in a danger state.

## Evidence

The lead must record subagent use in the PR body, Issue comment, or wrap-up when
it materially affects the result:

```markdown
Subagent evidence:
- Lead: Claude Code #1 / Codex #1
- Subagent role(s):
- Scope and write set:
- Summary received:
- Validation impact:
- Cleanup impact:
```

Subagents do not replace deterministic validation. CI, local tests, deploy
checks, WBS sync, and cleanup evidence remain required.

## Resource Hygiene

Subagent use increases token, memory, and disk pressure. A session that uses
subagents must still record:

- C drive free space before and after work.
- Top memory processes before and after work.
- Worktree/branch state before and after work.
- Leftover dev server, dart, node, git, gh, bash, and shell process check.
- Cleanup actions executed and actions intentionally skipped.

Prefer read-only explorer/reviewer subagents by default. Worker subagents that
edit files must own a disjoint write set and must not revert unrelated changes.
