---
name: wiki-broken-cleanup
description: Repair confirmed broken wikilinks with scripts/wiki_broken_cleanup.py after a fresh wiki-lint report. Use when asked to clean dead links, placeholder wikilinks, or repository-path links that were incorrectly written as wikilinks. Require a dry run, review category decisions, preserve backups through validation, and avoid converting ambiguous links automatically.
---

# Wiki Broken-Link Cleanup

## 1. Generate fresh evidence

```powershell
$env:PYTHONUTF8 = '1'
$date = Get-Date -Format 'yyyy-MM-dd'
python scripts/knowledge_vault_lint.py `
  --output "docs/knowledge-vault-lint/$date.md" `
  --json-out "docs/knowledge-vault-lint/$date.json"
```

Review each proposed link as a dead reference, placeholder example, repository path, or unresolved ambiguity. Backtick conversion preserves display text but removes graph semantics; do not apply it to ambiguous knowledge links.

## 2. Dry run

```powershell
python scripts/wiki_broken_cleanup.py `
  --lint-json "docs/knowledge-vault-lint/$date.json" --dry-run
```

Show affected files and counts before applying.

## 3. Apply and verify

```powershell
python scripts/wiki_broken_cleanup.py `
  --lint-json "docs/knowledge-vault-lint/$date.json"
python scripts/knowledge_vault_lint.py
git diff --check
```

Inspect the diff and keep task-created backup files until the cleanup is proven. Remove only exact backup files created by this run after the user accepts the result; never use a repository-wide delete command. Do not append routine metrics to the product roadmap.
