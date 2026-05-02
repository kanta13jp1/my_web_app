# NotebookLM Intake Gate

This directory stores the session-start NotebookLM list diff report for #1606.
It keeps NotebookLM-derived work visible without creating duplicate GitHub
Issues before source-policy review.

## Run Locally

```powershell
python scripts/notebooklm_intake_gate.py `
  --repo kanta13jp1/my_web_app `
  --report docs/notebooklm-intake/latest-report.md `
  --json docs/notebooklm-intake/latest-report.json `
  --state docs/notebooklm-intake/state.json
```

Use `--print-only` for a dry read. Use `--input path/to/notebooklm-list.json`
when another machine captured `notebooklm list --json`.

## Routing Policy

- The harness notebook `bc58b50b-5fc4-4840-9a62-b397d6d3b65a` is always the
  priority reference.
- Known notebook families route to existing Issues such as #1559, #1606,
  #1608, #1629, #1632, #1638, #1660, #1682, and #1683.
- Unknown relevant notebooks become `draft_candidate` rows. Create a new
  additional-request Issue only after duplicate and source-policy checks.
- Target-out notebooks must keep a skip reason in `state.json` so the same
  notebook is not re-triaged every session.

<!-- generated surface for scripts/notebooklm_intake_gate.py -->
