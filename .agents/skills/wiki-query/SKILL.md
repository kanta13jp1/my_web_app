---
name: wiki-query
description: Answer questions from the my_web_app knowledge base using the authenticated NotebookLM CLI when available and local repository search as a fallback. Use for prior-decision checks, knowledge-base questions, historical rationale, or cross-referencing docs/concepts and memory notes. Use notebooklm ask rather than the removed query command, cite sources, and do not persist answers automatically.
---

# Wiki Query

## 1. Check NotebookLM state

```powershell
notebooklm doctor
notebooklm status
notebooklm list --json
```

Resolve the intended notebook by current context or an explicit notebook ID. Do not assume a title is accepted where the CLI requires an ID.

## 2. Ask with citations

```powershell
notebooklm ask -n '<notebook-id>' '<question>' --json
```

Use only the `ask` subcommand for questions. Do not pass `--new` unless the user explicitly authorizes deleting the notebook's current conversation.

Check cited source IDs and distinguish quoted source facts, repository evidence, and inference.

## 3. Fall back locally

If NotebookLM is unavailable or unauthenticated, search `docs/concepts/`, `docs/INDEX.md`, `memory/`, and relevant project docs with `rg`. Report the narrower evidence surface instead of presenting it as a full NotebookLM synthesis.

## 4. Preserve only on request

Answer with source paths or NotebookLM citations. Offer `wiki-ingest` when the result contains durable new knowledge, but do not write to memory, the roadmap, or NotebookLM notes automatically.
