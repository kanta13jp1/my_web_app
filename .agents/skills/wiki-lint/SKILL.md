---
name: wiki-lint
description: Audit the repository knowledge vault for orphan notes, broken wikilinks, duplicate titles, and missing index entries using scripts/knowledge_vault_lint.py. Use for wiki health checks, vault audits, orphan or broken-link detection, and validation after ingest or compile. Keep note content read-only and use a temporary report unless the user requests a durable artifact.
---

# Wiki Lint

Pass `--output` explicitly for report destinations; the CLI has no report-only switch.

## Temporary audit

```powershell
$env:PYTHONUTF8 = '1'
$report = Join-Path ([IO.Path]::GetTempPath()) `
  ("my-web-app-wiki-lint-{0}.md" -f [guid]::NewGuid())
python scripts/knowledge_vault_lint.py --output "$report"
$healthExit = $LASTEXITCODE
Get-Content -LiteralPath "$report"
Remove-Item -LiteralPath "$report"
```

Exit `0`, `1`, and `2` represent healthy, warning, and cleanup-recommended scores. Treat other exit codes as execution failures. The script writes a dated repository report when `--output` is omitted, so always pass the temporary output path for a report-only audit.

## Durable report

Create report files only when requested:

```powershell
$date = Get-Date -Format 'yyyy-MM-dd'
python scripts/knowledge_vault_lint.py `
  --output "docs/knowledge-vault-lint/$date.md" `
  --json-out "docs/knowledge-vault-lint/$date.json"
```

Report raw counts and representative paths for orphan, broken, duplicate, and missing-index findings. Treat any aggregate Health Score as a prioritization aid, not proof that the vault is correct.

Do not modify notes, delete files, append to the roadmap, or launch cleanup skills automatically. Recommend the narrowest cleanup and require its normal dry-run gate.
