# Issue Fix Plan #974

- Issue: [[追加要望] AI第二の脳IngestパイプラインとObsidian/Markdown Vault同期](https://github.com/kanta13jp1/my_web_app/issues/974)
- Priority: high
- Source notebook: `Claude Code and Obsidian: Building Your AI Second Brain`

## Goal

Ship the first useful slice of the second-brain ingest pipeline without waiting
for a full UI: deterministic Markdown proposal generation, related-note
suggestions, user approval modes, Obsidian export, and audit logging.

## Scope

- Replace the mojibake-heavy `scripts/memory_ingest.py` with a clean,
  dependency-free implementation.
- Support URL, stdin/text file, GitHub Issue, and GitHub PR input.
- Generate Obsidian-compatible Markdown with YAML frontmatter, tags, wiki links,
  summary, concepts, related notes, and raw source content.
- Add `draft`, `save`, and `discard` modes.
- Write `memory/ingest_log.jsonl` for every attempt.
- Document operations in `docs/OBSIDIAN_INGEST_PIPELINE.md`.

## Remaining Follow-Up

The script covers the memory layer. A later UI/Edge Function can wrap it for
one-click browser ingestion and Vault zip download.
