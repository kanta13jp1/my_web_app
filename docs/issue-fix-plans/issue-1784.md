# Issue Fix Plan #1784

- Issue: [#1784](https://github.com/kanta13jp1/my_web_app/issues/1784)
- Title: Claude Code Masterclass agentic workflow pattern application
- Labels: enhancement, priority:high, automation, notebooklm
- Workflow: `.github/workflows/github-issue-fix.yml`
- CI repair pair: `.github/workflows/ci-auto-fix.yml`
- Run: https://github.com/kanta13jp1/my_web_app/actions/runs/25470322509

## Goal

Turn NotebookLM notebook `1aced136-1352-4933-b727-478d3c35b360`
("Claude Code Masterclass: From Foundations to Agentic Workflows") into a
repo-local, two-instance operating decision for Claude Code #1 and Codex #1.

## Reproduction

- `notebooklm use 1aced136` was attempted in this Codex #1 Windows session.
- The CLI returned an expired/invalid Google auth state and required
  `notebooklm login`.
- No browser login was performed from this repair lane.
- Saved local intake artifacts were used as provenance:
  `docs/notebooklm-intake/latest-snapshot.json` and
  `docs/notebooklm-intake/latest-report.md`.

## Implemented Fix

- Added `docs/CLAUDE_CODE_MASTERCLASS_AGENTIC_WORKFLOW.md` as the current
  applied decision note for #1784.
- Updated `AGENTS.md` so NotebookLM-driven sessions know where the applied
  Masterclass decision lives and when to refresh it.
- Kept this PR docs-only: no new hook, skill, MCP server, live instance lane, or
  workflow change is introduced until NotebookLM auth is restored and concrete
  new deltas are extracted.

## Minimal E2E Declaration

- The E2E test is implementation-detail independent.
- The plan is minimal, about three I/O cases.
- E2E mechanism: docs-only verification.
- E2E-Exception: this PR changes documentation only; the three verification
  cases are link/readback of the decision note, NotebookLM auth-block evidence,
  and issue/CI status.

## Checklist

- [x] Reproduction is clear.
- [x] Smallest safe fix is implemented.
- [x] Analyze/tests/CI are checked or queued for GitHub Actions.
- [x] PR notes explain the change and the remaining risk.
