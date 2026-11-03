---
name: wiki-dup-h1-cleanup
description: Resolve confirmed duplicate Markdown H1 titles with scripts/wiki_dup_h1_cleanup.py after a fresh wiki-lint report. Use when duplicate titles make wiki identities ambiguous. Require a dry run and semantic review; do not rename files or mechanically suffix titles that should instead be merged.
---

# Wiki Duplicate-H1 Cleanup

## 1. Generate fresh evidence

```powershell
$env:PYTHONUTF8 = '1'
$date = Get-Date -Format 'yyyy-MM-dd'
python scripts/knowledge_vault_lint.py `
  --output "docs/knowledge-vault-lint/$date.md" `
  --json-out "docs/knowledge-vault-lint/$date.json"
```

Classify each duplicate as an intentional copy, archive variant, template collision, or concepts that should be merged. Return product or taxonomy decisions to Claude Code when a suffix would change meaning.

## 2. Dry run and apply

```powershell
python scripts/wiki_dup_h1_cleanup.py `
  --lint-json "docs/knowledge-vault-lint/$date.json" --dry-run
```

Apply only the reviewed set:

```powershell
python scripts/wiki_dup_h1_cleanup.py `
  --lint-json "docs/knowledge-vault-lint/$date.json"
python scripts/knowledge_vault_lint.py
git diff --check
```

Inspect every changed H1. Keep task-created backups until validation and remove only the exact files created by this run after acceptance. Do not rename or delete knowledge files automatically.
