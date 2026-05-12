# Win Codex hand off: #772 RAG Knowledge Graph アシスタント (= part 156)

> **From**: Win Claude (= part 156)
> **To**: Win Codex
> **Priority**: high (= Issue 自体 high)
> **Issue**: [#772](https://github.com/kanta13jp1/my_web_app/issues/772)
> **Spec**: [`docs/RAG_KNOWLEDGE_GRAPH_SPEC.md`](../RAG_KNOWLEDGE_GRAPH_SPEC.md)
> **推定工数**: 10h
> **期限**: 2026-05-19 (= 14 day / Phase 1 only)

## Summary

Writer AI Studio 型 RAG (= NotebookLM `54b6f2f2`) を応用した自分株式会社 Knowledge Graph アシスタント Phase 1 実装. 5 source (= GitHub Issues / WBS / docs / memory / notebooklm-intake) を pgvector で index → 自然言語 query → LLM 要約 + 引用元付き回答.

## Hand off scope (= 6 件 / 10h)

1. **migration**: `YYYYMMDDHHMMSS_create_kg_embeddings.sql` (1h)
   - `kg_embeddings` table (= source_id / source_type / embedding vector(1536) / content_hash / last_synced_at / metadata jsonb)
   - pgvector ivfflat index
   - `kg_query_logs` table (= trace + user pattern 蓄積)
   - `kg_indexer_failures` table (= DLQ)
   - RLS

2. **EF action**: `memory-search-hub.rag.query` (3h)
   - 入力: `{ user_id, query, top_k=8, sources?: ['issues','wbs','docs','memory','notebooklm'] }`
   - 出力 schema: spec §4 #3 (answer / citations[] / trace_id / answer_status)
   - retrieval: pgvector cosine similarity > 0.5
   - LLM: ai-hub.provider.chat (= top-K=8 注入 + citation 必須 instruction)
   - rate limit: 1 user / 1 min / 5 query

3. **Indexer scripts**: 5 source 並列 (3h)
   - `scripts/kg_index_github_issues.py` (= title + body + comments)
   - `scripts/kg_index_wbs_tasks.py` (= title + description + remaining_work / PII redact)
   - `scripts/kg_index_docs.py` (= docs/*.md / docs/concepts/*)
   - `scripts/kg_index_memory_vault.py` (= memory/vault/*)
   - `scripts/kg_index_notebooklm_intake.py` (= docs/notebooklm-intake/* / notebook_id 紐付け必須)
   - **共通**: PII regex detector + skip + audit log

4. **GHA workflow**: `.github/workflows/kg-indexer-nightly.yml` (0.5h)
   - nightly cron (= 04:30 JST)
   - 5 indexer 並列 / 失敗時 DLQ + Issue auto-create

5. **Flutter UI**: 2 並走 (2h)
   - `lib/pages/knowledge_graph_page.dart` 新規 (= 専用 page)
   - `lib/pages/site_question_chatbot_page.dart` 拡張 (= toggle 追加)
   - citation chip + stale_index banner

6. **dart format + flutter analyze + smoke test**: 0.5h

## 受け入れ条件 (= Issue #772 / 4 件)

- [ ] ユーザーが自然言語でプロジェクト情報を質問できる
- [ ] 回答に少なくとも 1 件以上の引用元が表示される
- [ ] GitHub Issues / WBS / docs のうち 2 種類以上を横断検索 (= 本 spec で 5 種類)
- [ ] 既存チャットボットまたは専用ページから利用可 (= 本 spec で両方)

## PII boundary 注意 (= [PII_GUARDRAIL_SPEC] cross-link)

- **index 対象外** (= MUST): `users` / `chat_messages` / `health_metrics` / `asset_records` / `cs_inquiries`
- **index 対象** (= public artifact only): GitHub Issues body / WBS tasks / docs / memory/vault / notebooklm-intake
- **PII detector**: regex (= phone / email / マイナンバー風 / credit card) hit で skip + audit log
- **既存 [`docs/PII_GUARDRAIL_SPEC.md`](../PII_GUARDRAIL_SPEC.md) 第 5 spec の方針 100% 遵守必須**

## ルール遵守 check

- [x] [EF-FIRST] (= 既存 memory-search-hub action 拡張)
- [x] [EF-CAP-50] (= 新 EF 不要 / 50 維持)
- [x] [REAL-DATA] (= 本物 source の embedding)
- [x] [DART-FORMAT] (= 絶対パス + pipe なし)
- [ ] [DYNAMIC-CLAIM] cap 遵守 (= Codex 着手時 wbs.claim_task)
- [ ] [WORKDIR-ISOLATION] (= Codex 自前 worktree)
- [ ] PII boundary 100% 遵守 (= [PII_GUARDRAIL_SPEC] cross-link)

## 関連

- spec: `docs/RAG_KNOWLEDGE_GRAPH_SPEC.md` (= 10 section / 9 原則 / NOT to do 8 + MUST do 11)
- 既存 EF: `supabase/functions/memory-search-hub/` / `supabase/functions/ai-hub/`
- 既存 page: `lib/pages/site_question_chatbot_page.dart`
- 関連 spec: `docs/PII_GUARDRAIL_SPEC.md` (= cross-link 必須)
- NotebookLM: `54b6f2f2-6831-4376-b2dd-99a1a4bf90ec`

## 起票元 part

- part 156 / Win Claude / 2026-05-05
- 本 part 副 task 第 5 件 (= chain merge primary + WBS UI fix + #768 spec + axis A ping + memory-cleanup register + 本 spec)
