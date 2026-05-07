# 自分株式会社 Knowledge Graph / RAG アシスタント 設計 spec (= #772 / part 156)

> **Issue**: [#772 [追加要望] Writer AI Studio型ナレッジグラフ/RAG検索アシスタント](https://github.com/kanta13jp1/my_web_app/issues/772)
> **NotebookLM**: `54b6f2f2-6831-4376-b2dd-99a1a4bf90ec` (= Writer AI Studio Comprehensive Development and Management Guide)
> **Spec 種別**: 通常 (= 非 sensitive / ただし PII boundary cross-link 必須)
> **担当**: Win Codex hand off (= migration + EF + UI / 推定 10h)
> **EF**: `memory-search-hub` 既存 hub action 拡張 [EF-CAP-50] 遵守

---

## §1. 思想

Writer AI Studio の核 = **「Knowledge Graph + RAG で根拠付き回答」**.
本 spec は自分株式会社の散在知識源 (= CLAUDE.md / WBS / Issues / docs/concepts/ / memory/vault/ / NotebookLM intake / schedule_task_runs / supabase tables) を横断検索 + LLM 要約 + 引用元表示する RAG アシスタントとして定義.

### 「Knowledge Graph」の段階的実装方針

- **Phase 1 (= 本 spec)**: pgvector embedding + full-text search + LLM 要約
- **Phase 2 (= 別 spec)**: Knowledge Graph 化 (= entity extraction + relation graph)
- 本 spec は Phase 1 のみ ship / Phase 2 は将来 Issue 起票

---

## §2. 受け入れ条件 mapping (= Issue #772)

| # | 受入条件 | 実装方針 |
|---|---|---|
| 1 | ユーザーが自然言語でプロジェクト情報を質問できる | `memory-search-hub.rag.query` action (= LLM call + retrieval) |
| 2 | 回答に少なくとも 1 件以上の引用元が表示される | output schema に `citations[]` 必須 (= `source_type / source_url / excerpt / confidence / last_synced_at`) |
| 3 | GitHub Issues / WBS / docs のうち 2 種類以上を横断検索 | indexer が 5 source 対応 (= issues / wbs / docs / memory / notebooklm-intake) |
| 4 | 既存チャットボットまたは専用ページから利用可 | 既存 site_question_chatbot_page 拡張 + 新 page `knowledge_graph_page.dart` 両対応 |

---

## §3. NOT to do (= 失敗 pattern 8 件)

1. ❌ **ユーザー個人 data を index する** (= chat 履歴 / health metrics / asset 詳細 等). Phase 1 は project artifact only.
2. ❌ **citation なし で回答返す** (= hallucination の温床). citations[] empty なら「該当情報なし」と返却.
3. ❌ **Phase 1 で Knowledge Graph と称する** (= Phase 2 と混同). 本 spec は「RAG with citations」と表記統一.
4. ❌ **embedding を sync していない古い batch で query** (= last_synced_at が >24h なら警告 banner).
5. ❌ **NotebookLM 由来 docs を notebook_id 紐付けなく index** (= 出典追跡不能).
6. ❌ **LLM prompt 内に index 結果全文 dump** (= context 爆発 + cost 高騰). top-K=8 retrieval.
7. ❌ **既存 site_question_chatbot を破壊的に置き換え** (= [NO-SCOPE-CREEP]). 拡張 mode で並走.
8. ❌ **PII / sensitive boundary review なし で ship** (= [PII_GUARDRAIL_SPEC] cross-link 必須 / §7 参照).

---

## §4. MUST do (= 必須要件 11 項)

1. ✅ EF action 名: `memory-search-hub.rag.query` (= 既存 memory-search-hub への拡張 / 新 EF 不要)
2. ✅ EF 入力: `{ user_id, query: string, top_k: 8, sources?: ['issues','wbs','docs','memory','notebooklm']}`
3. ✅ EF 出力 schema:
   ```json
   {
     "answer": "string (= LLM summary)",
     "citations": [
       {
         "source_type": "issue|wbs|doc|memory|notebooklm",
         "source_url": "string",
         "excerpt": "string (= ≤ 280 char)",
         "confidence": "number (= 0.0-1.0)",
         "last_synced_at": "ISO 8601"
       }
     ],
     "trace_id": "string",
     "answer_status": "ok|no_results|stale_index|llm_failure"
   }
   ```
4. ✅ pgvector embedding storage: `kg_embeddings` table (= source_id / source_type / embedding vector(1536) / content_hash / last_synced_at)
5. ✅ indexer: nightly cron job + on-demand trigger
   - `index_github_issues.py` (= title + body + comments / source_type='issue')
   - `index_wbs_tasks.py` (= title + description + remaining_work)
   - `index_docs.py` (= docs/*.md / docs/concepts/*)
   - `index_memory_vault.py` (= memory/vault/*)
   - `index_notebooklm_intake.py` (= docs/notebooklm-intake/*)
6. ✅ LLM prompt: top-K=8 retrieval results を context 注入 + 「必ず citations を返す」 instruction
7. ✅ `confidence` 計算: cosine similarity を 0.0-1.0 にスケール (= 0.5 未満は除外)
8. ✅ `last_synced_at` >24h なら EF response に `answer_status='stale_index'` セット
9. ✅ Flutter UI: `knowledge_graph_page.dart` 新規 + 既存 `site_question_chatbot_page.dart` への button 追加
10. ✅ rate limit: 1 user / 1 min cap = 5 query (= ai-hub 経由で circuit breaker)
11. ✅ PII boundary check: index 対象から `users` / `chat_messages` / `health_metrics` / `asset_records` を **明示除外** (= [PII_GUARDRAIL_SPEC] cross-link)

---

## §5. EF 既存基盤確認 (= [EF-FIRST] / [EF-CAP-50])

### 既存活用

- `memory-search-hub` EF (= 既存 / RAG hub 化最適)
- `ai-hub.provider.chat` (= LLM call backbone)
- `pgvector` extension (= Supabase 標準)
- `wbs_tasks` / GitHub API / docs/ / memory/vault/ (= index 対象 source)

### 新規追加

- **EF action**: `memory-search-hub.rag.query` (= 1 action / hub 内追加 / 新 EF 不要 ✅)
- **table**: `kg_embeddings` (= source_id / source_type / embedding / content_hash / last_synced_at / metadata jsonb)
- **migration**: `YYYYMMDDHHMMSS_create_kg_embeddings.sql` + pgvector index
- **GHA workflow**: `.github/workflows/kg-indexer-nightly.yml` (= nightly cron / 5 source indexer 並列)

### EF 数

| 項目 | 数 | 状態 |
|---|---|---|
| 現在 EF | 50 | [EF-CAP-50] 上限 |
| 本 spec 追加 | 0 | hub action のみ |
| 残枠 | 0 | 維持 |

---

## §6. UI 設計

### 配置先 (= 2 並走)

#### 案 A: 既存 `site_question_chatbot_page.dart` 拡張
- 既存 chatbot に「📚 Knowledge Graph mode」 toggle 追加
- toggle ON で `memory-search-hub.rag.query` 経由
- citation chip 表示 (= 引用元 click → source_url へ)

#### 案 B: 新 `knowledge_graph_page.dart`
- 専用 page / 検索特化 UI
- 大型 query input + 結果 list + filter (= source_type)

両方 ship 推奨 (= 受入条件 #4 「既存または専用 ページ」両対応).

### Citation 表示 UI

```
回答 text...
[1][2][3]

📚 引用元
[1] 📋 [追加要望] Gemini... | github.com/.../issues/768 | 信頼度 0.87 | 同期: 2 hour 前
[2] 📐 docs/PII_GUARDRAIL_SPEC.md | github.com/.../docs/PII... | 信頼度 0.82 | 同期: 1 day 前
[3] 🧠 memory/vault/atomic_note_xxx | local | 信頼度 0.79 | 同期: 5 hour 前
```

`stale_index` warning banner: 「⚠️ 一部 source の index が 24h+ 経過しています. 最新情報が反映されていない可能性があります.」

---

## §7. PII / Sensitive boundary cross-link (= 必須)

本 spec は通常 (= 非 sensitive) だが、index 対象に PII 含めると一気に sensitive 化する境界 spec.
[`docs/PII_GUARDRAIL_SPEC.md`](PII_GUARDRAIL_SPEC.md) の方針を遵守:

| 項目 | 本 spec での扱い |
|---|---|
| chat_messages / users / health_metrics | **index 対象外** (= §4 #11) |
| asset_records / cs_inquiries | **index 対象外** |
| GitHub Issues body | index 可 (= public artifact) ただし issue body 内に PII 混入有無を indexer が検知 + skip |
| WBS tasks | index 可 (= owner_instance 別 RLS) ただし remaining_work field 内 PII 検知 + redact |
| docs/ | index 可 (= public docs) |
| memory/vault/ | index 可 (= curated PKM / PII 混入なし前提 / lint cron で監視) |

**PII detector**: indexer 内に regex (= phone / email / マイナンバー風 / credit card) 検出. hit 時 skip + audit log.

---

## §8. 9 原則 alignment

### PHILOSOPHY-22 (= 9 原則 / 7+/9 ✅必要)

| # | 原則 | 適用 |
|---|---|---|
| 1 | CEO 感 | ✅ 「どこに何があるか」を即答 = CEO の意思決定速度向上 |
| 2 | ミッション | ✅ 知能 (= 6 軸 #5) を最大化 |
| 3 | mentor | ✅ AI が引用付きで導く |
| 4 | 6 部署 | ✅ 全部署 (= 開発/経営/学習/etc) 横断 |
| 5 | 商品=価値 | ✅ chatbot 品質向上 = SaaS 価値向上 |
| 6 | 資本=時間 | ✅ 検索時間短縮 = 時間資本 protect |
| 7 | 資産負債 | ✅ 既存 memory-search-hub / pgvector を活用 (= 資産再活用) |
| 8 | KPI | ✅ query 数 / citation hit 率 / response time tracked |
| 9 | IPO | ✅ 知識資産可視化 = 外部 due diligence 容易化 |

**9/9 ✅** (= 全達成)

### AI-DEV-23 (= 7 原則 / 6+/7 ✅必要)

| # | 原則 | 適用 |
|---|---|---|
| 1 | Auth | ✅ user 認証必須 / RLS source_type 別 |
| 2 | deny-by-default | ✅ index 対象 source は §7 で explicit allow list |
| 3 | trace_id | ✅ EF 内 trace_id / kg_query_logs table |
| 4 | circuit-breaker | ✅ 1 user / 1 min cap 5 query |
| 5 | memory | ✅ NotebookLM `54b6f2f2` 引用 + kg_embeddings 履歴 |
| 6 | DLQ | ✅ LLM call fail / index sync fail → kg_indexer_failures table |
| 7 | quality-gate | ✅ citation 0 件なら answer_status='no_results' で返却 |

**7/7 ✅**

### IMBUE-25 (= 7 パターン / 6+/7 ✅推奨)

| # | パターン | 適用 |
|---|---|---|
| 1 | 過程透明性 | ✅ citations[] で根拠提示 / confidence score 公開 |
| 2 | 細粒度コントロール | ✅ sources filter (= 5 種類) |
| 3 | やり直し容易性 | ✅ 同 query 再実行 / source filter 変更 |
| 4 | 失敗時の人間 fallback | ✅ no_results 時 「直接 docs 検索」 button |
| 5 | 学習統合 | ✅ kg_query_logs で query パターン蓄積 → 将来 Phase 2 で活用 |
| 6 | 操作性の安心感 | ✅ stale_index warning で信頼性可視化 |
| 7 | 段階的開示 | ✅ 回答 + 引用元 折りたたみ |

**7/7 ✅**

### COLLAB-26 (= 7 パターン / 6+/7 ✅推奨)

| # | パターン | 適用 |
|---|---|---|
| 1 | Tinker | ✅ source filter で AI と協調探索 |
| 2 | Co-Reasoning | ✅ user が citation 採否判断 |
| 3 | Red-Team | ⏸ 「この回答は信頼できる?」 button (= Phase 2 候補) |
| 4 | Trail | ✅ kg_query_logs で履歴比較 |
| 5 | Reciprocal teaching | ⏸ 未実装 |
| 6 | Negotiation | ✅ sources filter で範囲交渉 |
| 7 | Trust calibration | ✅ confidence score + last_synced_at 表示 |

**5/7 ✅**

### MCP-AUTH-27 (= 10 原則 / 関連時 10/10 必須)

本 spec の RAG 結果を MCP server 経由で外部公開する場合のみ MCP-AUTH-27 10/10 評価必須. Phase 1 では内部 only → 適用外.

---

## §9. Win Codex hand off

### scope (= 推定 10h)

| 項目 | 工数 |
|---|---|
| migration `create_kg_embeddings.sql` (= table + pgvector index + RLS) | 1h |
| `memory-search-hub.rag.query` action (= retrieval + LLM + schema validation) | 3h |
| `index_*.py` 5 indexer scripts (= GitHub Issues / WBS / docs / memory / notebooklm) | 3h |
| GHA workflow `kg-indexer-nightly.yml` | 0.5h |
| Flutter UI: `knowledge_graph_page.dart` 新規 + chatbot 拡張 | 2h |
| dart format + flutter analyze + smoke test | 0.5h |

### Codex 振分 5 質問 (= [INSTANCE-ROLES])

| Q | 内容 | 答 |
|---|---|---|
| Q1 | UI 設計 / docs 更新? | YES |
| Q2 | architect / triage? | YES (= 設計判断複数) |
| Q3 | AI 機能 設計? | YES (= RAG + LLM) |
| Q4 | mobile UAT / 動画? | NO |
| Q5 | 部署横断 / 9 原則 cross-check? | YES (= 全部署 + PII boundary) |

4 YES → **Win Claude territory ✅** (= spec ship 本 part / 実装 = Win Codex hand off)

---

## §10. 関連

- [Issue #772](https://github.com/kanta13jp1/my_web_app/issues/772)
- 既存統合: `lib/pages/site_question_chatbot_page.dart` / `supabase/functions/memory-search-hub/`
- 関連 spec: [`docs/PII_GUARDRAIL_SPEC.md`](PII_GUARDRAIL_SPEC.md) (= sensitive 第 5 / cross-link 必須) / `docs/DESIGN_SPEC_PATTERNS.md` (= 抽象化 layer)
- 将来 Phase 2: Knowledge Graph 化 (= entity extraction + relation graph) → 別 Issue 起票予定
- NotebookLM: `54b6f2f2-6831-4376-b2dd-99a1a4bf90ec`
