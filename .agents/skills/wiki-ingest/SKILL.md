---
name: wiki-ingest
description: Convert a local file, URL, GitHub Issue, or GitHub PR into a reviewed Obsidian-compatible atomic-note draft using scripts/memory_ingest.py, then save it only after approval. Use when asked to ingest material, add knowledge to the wiki, create an atomic note, or process new content under raw/. Preserve provenance and avoid silent writes to the durable vault.
---

# Wiki Ingest

Create a draft first and separate source capture from durable knowledge.

## 1. Resolve the source

Identify one exact local file, URL, Issue, or PR. Check for an existing note by source URL, Issue/PR identity, and normalized slug; do not rely on substring matching alone.

For URLs, fetch only public material the user is authorized to process. Preserve the canonical URL and distinguish source statements from inference.

## 2. Generate a draft

Use one input form:

```powershell
python scripts/memory_ingest.py --input-file '<path>' --mode draft --tag ingest-auto --print
python scripts/memory_ingest.py --url '<url>' --mode draft --tag ingest-auto --print
python scripts/memory_ingest.py --gh-issue <number> --mode draft --tag ingest-auto --print
python scripts/memory_ingest.py --gh-pr <number> --mode draft --tag ingest-auto --print
```

Review the generated frontmatter, summary, provenance, tags, related links, and unsupported claims. A request to ingest authorizes draft creation, not automatic publication to the durable vault.

## 3. Save after approval

After the user approves the draft, rerun the same source command with `--mode save`. Use `--slug` only to resolve a documented collision. Do not overwrite an existing note without showing the diff.

## 4. Verify

- Confirm the saved path and source provenance.
- Run `wiki-lint` when the note adds or changes wikilinks.
- Suggest `wiki-compile` after several approved notes, but do not chain it automatically.
- Report draft-only and saved states separately.
