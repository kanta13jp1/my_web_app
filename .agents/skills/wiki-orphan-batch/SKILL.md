---
name: wiki-orphan-batch
description: Add a bounded, reviewed set of orphan or missing-index notes to managed MEMORY indexes using scripts/wiki_orphan_batch.py. Use after wiki-lint when many valid notes lack index references. Require a dry run, use a small batch, preserve semantic grouping, and never treat mass index insertion as proof that the notes are useful.
---

# Wiki Orphan Batch

## 1. Generate a current lint artifact

```powershell
$env:PYTHONUTF8 = '1'
$date = Get-Date -Format 'yyyy-MM-dd'
python scripts/knowledge_vault_lint.py `
  --output "docs/knowledge-vault-lint/$date.md" `
  --json-out "docs/knowledge-vault-lint/$date.json"
```

## 2. Preview a bounded batch

Start with at most 50 entries and one source category:

```powershell
python scripts/wiki_orphan_batch.py `
  --lint-json "docs/knowledge-vault-lint/$date.json" `
  --source orphans --top 50 --dry-run
```

Review whether each note belongs in an index, should link from a concept page, needs consolidation, or is obsolete. Do not index a note only to improve a score.

## 3. Apply the reviewed batch

Use explicit `--prefixes` and a unique `--marker`:

```powershell
$marker = "<!-- wiki-batch $([guid]::NewGuid()) -->"
python scripts/wiki_orphan_batch.py `
  --lint-json "docs/knowledge-vault-lint/$date.json" `
  --source orphans --top 50 `
  --prefixes 'project_,feedback_success_' --marker "$marker"
```

Then run lint again and inspect only the affected MEMORY index files.

Do not process hundreds of entries in one opaque mutation, append routine metrics to the roadmap, or claim repository isolation when the configured memory directory is tracked by Git.
