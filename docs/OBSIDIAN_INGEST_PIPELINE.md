# Obsidian Ingest Pipeline

Issue: [#974](https://github.com/kanta13jp1/my_web_app/issues/974)

This is the first practical slice of the AI Second Brain workflow from
NotebookLM "Claude Code and Obsidian: Building Your AI Second Brain".

The pipeline accepts a URL, text file, stdin, GitHub Issue, or GitHub PR and
creates an Obsidian-compatible Markdown note proposal with YAML frontmatter,
wiki links, tags, related-note suggestions, and an append-only audit log.

## Draft

```powershell
python scripts\memory_ingest.py `
  --gh-issue 974 `
  --mode draft `
  --tag second-brain
```

The draft is written to `memory/ingest_drafts/`. Review or edit it there.

## Save

```powershell
python scripts\memory_ingest.py `
  --input-file memory\ingest_drafts\ingest_YYYYMMDD_example.md `
  --mode save `
  --target-dir memory\vault
```

Saved notes live in `memory/vault/` and can be opened by Obsidian as plain
Markdown.

## Discard

```powershell
python scripts\memory_ingest.py `
  --url https://example.com `
  --mode discard
```

Discard mode does not write a note, but it does log the decision to
`memory/ingest_log.jsonl`.

## Export To Another Vault

```powershell
python scripts\memory_ingest.py `
  --gh-pr 994 `
  --mode save `
  --export-dir C:\Users\kanta\Documents\Obsidian\jibun-vault
```

## Acceptance Coverage

- URL/text/GitHub input produces a Markdown note proposal.
- Related notes are ranked from `memory/` and `docs/`; at least `MEMORY.md` is
  suggested when no stronger match exists.
- Draft/save/discard modes support user approval before persistence.
- Saved notes are Obsidian-compatible Markdown with YAML frontmatter and wiki
  links.
- Every ingest attempt writes a JSONL audit record.

## Next Slice

The next application-level slice should add a small UI around the same script or
an Edge Function wrapper:

- paste URL/text
- preview Markdown
- edit before save
- show related notes and duplicate warnings
- export selected notes as a Vault zip
