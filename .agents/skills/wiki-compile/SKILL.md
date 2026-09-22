---
name: wiki-compile
description: Preview and apply the repository's deterministic wiki compile cycle with scripts/wiki_compile.py, generating managed concept pages and the master index from current knowledge sources. Use when asked to rebuild docs/concepts, refresh docs/INDEX.md, compile the wiki, or integrate several approved atomic notes. Always preview before --apply and inspect generated diffs.
---

# Wiki Compile

Compile managed wiki outputs without overwriting human-authored pages.

## 1. Preview

```powershell
$env:PYTHONUTF8 = '1'
python scripts/wiki_compile.py --json
```

Adjust `--days`, `--min-sources`, or `--limit` only from the requested scope. Confirm that output paths use the script's managed `_compile_` convention and identify any unexpected source roots.

## 2. Apply

When the preview is acceptable and the user requested compilation:

```powershell
python scripts/wiki_compile.py --apply
```

The command without `--apply` is a dry run and must not be reported as regeneration.

## 3. Verify

```powershell
git status --short -- docs/concepts docs/INDEX.md
git diff --check -- docs/concepts docs/INDEX.md
```

Inspect new pages, changed index entries, duplicate concepts, source attribution, and unrelated churn. Run `wiki-lint` after compilation. Do not commit generated output automatically or claim success until the diff exists and lint completes.
