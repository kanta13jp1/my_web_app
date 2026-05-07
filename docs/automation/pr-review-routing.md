# PR Review Routing Automation

Issue #1685 tracks the loop that turns PR review comments into WBS repair work.
The first implementation is deterministic: fetch comments, classify them, and
post a compact routing report back to the PR.

## Categories

- `local_patch`: bounded file-level feedback. Codex can patch only the listed
  paths, or open a small follow-up PR.
- `design_decision`: reviewers are asking for rationale or trade-off notes.
  Answer or document the decision before changing code.
- `needs_claude_code`: architecture, schema, security model, or quality-gate
  feedback. Route to Claude Code for planning/review ownership.
- `needs_user_product_judgment`: product, business, legal, or owner-decision
  feedback. Hand off through an Issue comment or WBS user task.
- `stale_superseded`: resolved, outdated, or already-fixed comments. Do not
  patch unless the reviewer reopens the point.

## Workflow

Run `PR Review Routing` (`pr-review-routing.yml`) with a PR number. The workflow
uses `gh` and the repository token to read review comments, requested changes,
and the first 100 unresolved review threads. It writes:

- an Actions job summary,
- `pr-review-routing.md` and `pr-review-routing.json` artifacts,
- an optional PR comment with the routing report,
- an optional handoff Issue comment.

The report includes the actor-visible validation trail and Actions run URL, so a
later Codex or Claude Code session can continue from the same evidence.

## Boundaries

- #1557 clusters CI failures and duplicate workflow-failure Issues.
- #1637 evaluates issue digests and backlog shape.
- #1559 routes Claude Code/Codex changelog changes into automation.
- #1565 classifies low-risk PR/Issue candidates before any autonomous review
  comment is posted.
- #1685 only routes PR review comments and requested changes into repair or
  handoff queues.
