# NotebookLM Intake Gate

This directory stores the normalized NotebookLM list snapshot used to route
new notebooks into GitHub Issues, WBS, docs, or skip records.

## Local Session Run

Run this after `scripts/ai_tool_watch.py --print-only` when NotebookLM work is
in scope:

```powershell
python scripts/notebooklm_intake_gate.py --refresh --metadata routed --gh-dedup
```

The gate writes:

- `latest-snapshot.json`: normalized notebook id, title, owner flag,
  `created_at`, optional `updated_at`, source count when metadata is available,
  route, disposition, and existing Issue match.
- `latest-report.md`: human-readable intake report.
- `issue-drafts.md`: additional-request Issue drafts for notebooks that are not
  already routed, applied, or skipped.
- `state.json`: persistent skip and first-seen history so repeated sessions do
  not reopen the same routing discussion.

NotebookLM is an external memory source. Claims from NotebookLM should route
work, but implementation still needs repository checks, official or primary
source verification, and GitHub Actions proof.

## Claude Code Session-Ops Routes

For #1638 Claude Code operations notebooks, use
`config/notebooklm-session-ops-routes.json` and
`docs/NOTEBOOKLM_SESSION_OPS_ROUTING.md`. The guard command is:

```powershell
python scripts/check_notebooklm_session_ops_routes.py
```
