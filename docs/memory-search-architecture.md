# Memory Search Architecture

**Status**: Codex#2 implementation, 2026-04-29

## Decision

`memory-search-hub` uses **cloud EF + Supabase `memory_index` sync** as the first implementation.

The requested local claude-mem SQLite integration cannot be read directly from Supabase Edge Functions because the SQLite file lives under a Windows user profile. The adopted path is therefore:

1. `scripts/sync_memory_index.py` reads local `memory/**/*.md`.
2. It upserts file path, content hash, title, snippet, links, and content into `memory_index`.
   When `--with-embeddings` and `GEMINI_API_KEY` are present, it also stores
   normalized 768-dimensional `gemini-embedding-001` retrieval-document vectors.
3. `memory-search-hub` serves four Streamable HTTP JSON actions:
   - `memory.search`
   - `memory.rank`
   - `memory.related`
   - `memory.stats`

## Retrieval Flow

`memory.search` runs a three-stage hybrid flow:

1. BM25 over synced Markdown content.
2. Optional pgvector search through `match_memory_index` when embeddings exist and `GEMINI_API_KEY` is configured. Query embeddings are generated as normalized 768-dimensional retrieval-query vectors to match the `memory_index.embedding vector(768)` column.
3. Optional Haiku rerank for `memory.rank`, capped at 20 candidates.

If embedding or LLM credentials are unavailable, the EF degrades to deterministic BM25 rerank. This keeps the tool usable in local and CI environments.

## Auth And Safety

The EF calls `_shared/mcp_auth_guard.ts` and requires either:

- a service-role internal call, or
- a valid MCP Bearer context with `memory-search-hub` or `memory` scope.

Rerank prompts wrap query and candidate text in `<<<USER_DATA>>>...<<<END>>>` blocks to keep indexed content from being interpreted as instructions.

## Follow-Up

Local MCP direct SQLite search remains useful for sub-100ms per-user workflows, but it should share the same action schema so clients can switch between local MCP and cloud EF without prompt changes.
