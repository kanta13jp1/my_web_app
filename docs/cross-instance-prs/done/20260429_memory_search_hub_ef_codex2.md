# Done: memory-search-hub EF — Hybrid Search via MCP

**FROM**: Win版 part 70
**TO**: Codex#2
**完了**: 2026-04-29

## 実装

- `supabase/functions/memory-search-hub/`
  - `memory.search`
  - `memory.rank`
  - `memory.related`
  - `memory.stats`
- `supabase/migrations/20260429100000_create_memory_index.sql`
- `scripts/sync_memory_index.py`
- `.github/workflows/memory-search-sync.yml`
- `docs/memory-search-architecture.md`
- `docs/SECOND_BRAIN_PRINCIPLES.md`

## 判断

Supabase Edge Function から local claude-mem SQLite は直接読めないため、初期実装は `memory/**/*.md` を Supabase `memory_index` に同期する案Aを採用。ローカルMCP直結は同じ action schema の後続拡張にする。

## 検証

- `deno check supabase/functions/memory-search-hub/index.ts` pass
- `python scripts/sync_memory_index.py --memory-dir memory --dry-run` pass

## 追加ハードニング

- `scripts/sync_memory_index.py --with-embeddings` 追加: `GEMINI_API_KEY` がある場合のみ `gemini-embedding-001` の 768 次元 retrieval-document embedding を保存
- `memory-search-hub` の query embedding も 768 次元 retrieval-query に固定し、`memory_index.embedding vector(768)` と整合
- `match_memory_index` RPC は service_role のみ実行可能
