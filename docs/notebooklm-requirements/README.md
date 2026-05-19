# NotebookLM Requirements Intake

This folder stores the daily NotebookLM additional-request extraction report.

The workflow `.github/workflows/notebooklm-requirements-to-issues.yml` runs
`notebooklm list --json`, asks each notebook for exactly three additional
requests, and creates GitHub Issues with `notebooklm`, `automation`, `wbs`,
`追加要望`, and priority labels. The GitHub Issues WBS Sync workflow then
pulls those Issues into the WBS.

Safety rules:

- Issue creation requires GitHub Issue dedup evidence first; if `gh issue list`
  fails, the script aborts instead of opening duplicate Issues.
- Created Issues contain stable `notebooklm-requirement:<notebook-id>:<slot>`
  markers so reruns skip already-created notebook/slot pairs.
- Scheduled runs cap new Issues at 9 by default. Manual dispatch can set
  `max_created_issues` to a different value, including `0` for an uncapped run.
- The default extraction count is 3 requests per notebook, matching the
  NotebookLM intake policy.
- Every generated Issue includes a two-instance routing checkbox so Claude Code
  #1 and Codex #1 remain the only persistent top-level owners.

Reports are generated, not hand-authored:

- `latest-requirements.json`
- `latest-report.md`
- `state.json`
