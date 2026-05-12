# Claude Code Masterclass Agentic Workflow

Status: applied decision note for Issue #1784.

Date: 2026-05-07.

NotebookLM source:

- Notebook id: `1aced136-1352-4933-b727-478d3c35b360`.
- Title: `Claude Code Masterclass: From Foundations to Agentic Workflows`.
- Saved provenance:
  `docs/notebooklm-intake/latest-snapshot.json` and
  `docs/notebooklm-intake/latest-report.md`.
- Direct CLI access in this Codex #1 session was blocked by expired NotebookLM
  auth. The command `notebooklm use 1aced136` required `notebooklm login`.

## Operating Decision

Apply the Masterclass material as an operating pattern, not as a new parallel
fleet. The active development flow remains:

- Claude Code #1 owns planning, architecture, review, and quality-gate design.
- Codex #1 owns scoped implementation, deterministic validation, CI follow-up,
  merge, and cleanup.
- Additional historical instance labels remain routing metadata unless the user
  explicitly reactivates them.

## Applied Patterns

1. Foundations become session preflight.

   Codex work starts with worktree, branch, disk, memory, and process checks.
   The repo already captures this in `AGENTS.md`,
   `docs/AGENT_DELEGATION_PROTOCOL.md`, and `scripts/codex_session_check.py`.

2. MCP becomes a design and review surface.

   `claude mcp serve` is useful for protocol-aware review and future local
   orchestration, but this issue does not add a long-running MCP server. Remote
   MCP exposure must keep authentication and least-privilege boundaries intact.

3. Sub-agents become bounded handoff packets.

   This Codex app session may not spawn background agents unless the user
   explicitly asks for delegation. The safe repo equivalent is a scoped GitHub
   issue, a WBS owner, an implementation packet, and a single PR with CI proof.

4. Harness engineering becomes repeatable gates.

   New workflow ideas should first map to deterministic checks: GitHub Actions,
   NotebookLM intake gates, release notes, Edge Function audits, Playwright
   evidence, and issue-linked runbooks.

5. Memory becomes compact, inspectable artifacts.

   PreCompact, SessionStart, and StatusLine concepts are already represented by
   the precompact memory backup spec and session check tooling. This issue keeps
   those as references instead of duplicating them in new hooks.

## Candidate Backlog

These are candidates, not changes made by this PR:

- Add a NotebookLM auth-status warning to the session start check.
- Add a small `agentic-workflow-intake` guide only after fresh NotebookLM output
  identifies new, repo-specific deltas.
- Extend hook design only where it reduces manual recovery work and can be
  validated by CI.
- Add a short pointer in Claude-facing rules if Claude Code #1 confirms it is
  useful during planning sessions.

## Refresh Procedure

When NotebookLM auth is restored:

```powershell
notebooklm login
notebooklm use 1aced136
notebooklm ask "Extract repo-applicable Claude Code agentic workflow patterns for CLAUDE.md, AGENTS.md, hooks, skills, MCP, CI, and two-instance WBS routing. Return only actionable deltas not already covered by docs/CLAUDE_CODE_MASTERCLASS_AGENTIC_WORKFLOW.md."
python scripts/notebooklm_intake_gate.py --refresh --metadata routed --gh-dedup
```

If the refreshed output adds concrete deltas, open a follow-up scoped PR. If it
only repeats the current operating pattern, leave Issue #1784 closed.

## Minimal E2E Declaration

The E2E test is implementation-detail independent.

The plan is minimal, about three I/O cases.

E2E mechanism: docs-only verification.

E2E-Exception: this PR changes documentation only; the three verification cases
are link/readback of this decision note, NotebookLM auth-block evidence, and
issue/CI status.
