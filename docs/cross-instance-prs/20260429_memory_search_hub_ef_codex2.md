# Cross-Instance PR: memory-search-hub EF — Hybrid Search via MCP

**作成**: Win版#132 part 70 / 2026-04-29
**FROM**: Win版 (SECOND_BRAIN 軸起案者 / docs territory)
**TO**: Codex#2 (EF / Deno / GHA 補助 territory)
**優先度**: HIGH (MEMORY.md 32.4KB 警告解消の本命 = 数千 file 規模対応の唯一解)
**期限**: 2026-05-13 (2 週間)
**親軸**: docs/SECOND_BRAIN_PRINCIPLES.md 原則 #7 (Hybrid Search via MCP)
**依存**: docs/MCP_AUTH_SECURITY_PRINCIPLES.md 10 原則 / mcp_auth_guard.ts skeleton (Win版#132 part 49 既存)

---

## 背景

Win版#132 part 68 で `docs/SECOND_BRAIN_PRINCIPLES.md` (10 番目軸 / PKM 設計) を確立.
Part 69 で原則 #3 (Daily Log) + #4 (PS#1 Lint 委譲) を実装し baseline 2.5 → 3.0/7.

残り急務 = 原則 #7 (Hybrid Search via MCP). **MEMORY.md 32.4KB 警告** + **memory/ 100+ files** + **claude-mem 累積 50+ obs 642k tokens** = full-text scan が遅すぎる.

= **オンデバイス hybrid search engine (BM25 + ベクトル + LLM 再ランク)** を MCP server として実装することで、12 fleet 全体から **数百ミリ秒で関連 N 件取得** 可能になる. **本軸 #7 完成は MEMORY.md 警告の本命解決策**.

## Win版 routing 判断 (5 質問 + WORKDIR-ISOLATION)

| Q | 答え | 補足 |
| --- | --- | --- |
| Q1 設計判断 / trade-off? | YES | BM25 vs ベクトル vs LLM 再ランクの組合せ / claude-mem SQLite 統合方法 / MCP server か EF action か |
| Q2 cross-instance 調整? | △ | claude-mem との統合は ~/.claude/projects/ 構造に依存 (= per-Windows-user) → MCP_AUTH 共有設計と対立しないか確認要 |
| Q3 軸 docs 更新? | YES | 完了時 docs/SECOND_BRAIN_PRINCIPLES.md 実装履歴 + docs/MCP_AUTH_SECURITY_PRINCIPLES.md ベースライン両方更新 |
| Q4 docs に残す判断? | YES | hybrid search アルゴリズム選定根拠 / claude-mem 統合判断 / per-instance vs 共有検索の trade-off |
| Q5 NotebookLM 連携? | △ | 検索結果の品質検証用に NotebookLM Master Brain を ground truth として活用検討 |

→ Q1+Q3+Q4 YES + WORKDIR-ISOLATION (`supabase/functions/` = Codex#2 territory) = **Codex#2 territory 確定**.
※ Q1 の判断重みが大きいため、Codex 単独でなく **Win版 + Codex#2 の co-implementation** が望ましい (= Win版が設計判断、Codex#2 が実装).

## 期待する実装

### 1. 新 EF: `supabase/functions/memory-search-hub/`

既存 hub 化方針 (= EF-CAP-50 rule) に整合. 単独 EF でなく hub として 4 アクション提供.

#### Actions

| Action | 入力 | 出力 | 説明 |
| --- | --- | --- | --- |
| `memory.search` | `{query: string, top_k?: 5}` | `{results: [{file, score, snippet}]}` | BM25 + ベクトル ハイブリッド検索 |
| `memory.rank` | `{query: string, candidates: file_paths[]}` | `{ranked: [{file, llm_score}]}` | LLM 再ランク (Haiku 4.5 で fast / 候補 N=20 cap) |
| `memory.related` | `{file: string, top_k?: 10}` | `{related: [{file, similarity}]}` | 指定 file ID から関連 N 件取得 (= [[link]] 推薦) |
| `memory.stats` | `{}` | `{total_files, avg_size, orphan_count, ...}` | PKM 健全性メトリクス (= consolidate-memory --lint との連携) |

### 2. Hybrid Search アルゴリズム選定

#### Trade-off 分析

| 手法 | 速度 | 精度 | 実装コスト | 自分株式会社適合度 |
| --- | --- | --- | --- | --- |
| **BM25 (キーワード)** | 速 (~10ms) | 中 (= 同義語弱) | 低 | ✅ 必須 baseline |
| **ベクトル (= claude-mem 既存)** | 中 (~50ms) | 高 (= 意味類似) | 既に存在 | ✅ 既存資産 reuse |
| **LLM 再ランク (Haiku 4.5)** | 遅 (~500ms / N=20) | 最高 | 中 | ✅ top_k 候補絞った後にのみ |
| **RAG infra (= chunking + DB)** | 中 | 高 | 高 | ❌ MEMORY.md 規模では過剰 |

→ **採用**: BM25 (粗 retrieve) → ベクトル (= claude-mem SQLite reuse / 中粒度) → LLM 再ランク (= Haiku 4.5 / 精緻化). **3 段ハイブリッド**.

#### 実装フロー

```
query
  ↓
[Stage 1] BM25 retrieve (= top 50 / ~10ms)
  ↓ 候補絞る
[Stage 2] ベクトル類似度 (= claude-mem SQLite / top 20 / ~50ms)
  ↓ 候補絞る
[Stage 3] Haiku 4.5 LLM 再ランク (= top_k=5 / ~500ms / 並列処理可)
  ↓
results (top 5 with snippet)
```

= 3 段で **合計 ~600ms** 程度. RAG インフラなしでこの精度は実用的.

### 3. claude-mem SQLite 統合

claude-mem は既に SQLite に **observations + Gemini 圧縮ベクトル** を持つ (= PROJECT.md 記載 / セッション間 L2 メモリ).

```
~/.claude/projects/<project>/memory/
  ├── MEMORY.md (index)
  ├── log.md (Daily Log / part 69 新規)
  ├── project_*.md (Atomic Notes)
  └── claude-mem/  (= Worker が管理 / SQLite + ベクトル)
       └── memory.db (= SQLite)
```

→ memory-search-hub EF は **claude-mem SQLite を read-only** で参照. Stage 2 (ベクトル類似度) で reuse.

#### 制約

- claude-mem は **per-Windows-user local** (= ~/.claude/projects/ 配下)
- EF は cloud Supabase 上で動作 → ローカル SQLite に直接 access 不可
- → **2 案** あり:

  **案 A**: claude-mem SQLite を **定期的に Supabase memory_index table に sync**
  - メリット: EF が常にアクセス可
  - デメリット: sync ラグ + データ重複
  - 同期方法: `scripts/sync_claude_mem_to_supabase.py` (cron / GHA 1h ごと)

  **案 B**: memory-search-hub を **ローカル MCP server として実装** (= EF でなく)
  - メリット: claude-mem 直接 access / 同期不要
  - デメリット: cloud 連携不可 / 12 fleet が同 Windows user に縛られる

  **案 C** (推奨): **両方実装** = ローカル MCP server (per-instance 高速) + cloud EF (cross-instance / 同期 1h)
  - ローカル: `scripts/mcp_servers/memory_search.py` (Win版 territory)
  - cloud: `supabase/functions/memory-search-hub/` (Codex#2 territory)
  - 両方が同じ schema を提供 → AI が透明に呼出可能

→ **Codex#2 が判断**.

### 4. MCP_AUTH 10 原則準拠

memory-search-hub は **MCP server として外部公開** (= Claude Code / Cursor が DCR 経由で利用) を想定.

| MCP_AUTH 原則 | 適用 |
| --- | --- |
| #1 DCR (RFC 7591) | mcp_oauth_clients table 既存 / 利用 |
| #2 Bearer Deny-by-Default | mcp_auth_guard.ts validateBearer 利用 (Win版 part 49 既存) |
| #3 Prompt Injection 防御 | search query を `<<<USER_DATA>>>...<<<END>>>` で delimit |
| #4 Streamable HTTP | 実装. SSE/WS 禁止 |
| #5 Resource Indicators (RFC 8707) | `aud=memory-search-hub` 強制 (production strict) |
| #6 WorkOS managed | MAU 1M まで無料 / 利用 |
| #7 Audit Log | mcp_audit_log table に search query を記録 (= privacy 注意) |
| #8 OAuth 2.1 + PKCE | 必須 |
| #9 .well-known/oauth-protected-resource | mcp-well-known EF と統合 |
| #10 最小権限 | search 専用 scope (= 書込み禁止) |

→ **10/10 必須** (= 公開 server なので).

### 5. ファイル設計

```
supabase/functions/memory-search-hub/
  ├── index.ts                # action router (memory.search / .rank / .related / .stats)
  ├── search/
  │   ├── bm25.ts             # Stage 1: BM25 retrieve
  │   ├── vector.ts           # Stage 2: ベクトル類似度 (= memory_index table)
  │   └── rerank.ts           # Stage 3: Haiku 4.5 LLM 再ランク
  └── deno.jsonc              # imports / lint settings

supabase/migrations/
  └── 20260429100000_create_memory_index.sql
       # memory_index (file_path, content_hash, embedding vector(768), updated_at)
       # = claude-mem sync 先

scripts/
  └── sync_claude_mem_to_supabase.py  # 案 A: 1h 同期 / GHA cron
       # OR
  └── mcp_servers/memory_search.py     # 案 B: ローカル MCP server

.github/workflows/
  └── memory-search-sync.yml           # GHA cron (1h ごと)

docs/
  └── memory-search-architecture.md   # 設計判断記録 (案 A/B/C / Stage 1-3 / MCP_AUTH 適合)
```

### 6. 受け入れ基準

- [ ] 新 EF `memory-search-hub` 作成 (4 アクション)
- [ ] 3 段 hybrid search 実装 (BM25 + ベクトル + LLM 再ランク)
- [ ] claude-mem SQLite 統合 (案 A/B/C いずれか採用 + 根拠 docs)
- [ ] migration `20260429100000_create_memory_index.sql` 作成
- [ ] MCP_AUTH 10/10 準拠 (= mcp_auth_guard.ts 利用)
- [ ] `docs/memory-search-architecture.md` 設計判断記録
- [ ] `_smoke_test.py` または equivalent で 4 アクション動作確認
- [ ] flutter analyze / deno lint / dart format 0 エラー
- [ ] git commit + push origin HEAD:main
- [ ] `docs/SECOND_BRAIN_PRINCIPLES.md` 実装履歴更新 (#7 完成 → 3.0/7 → 4.0/7)
- [ ] `docs/MCP_AUTH_SECURITY_PRINCIPLES.md` ベースライン更新 (= 0.5/10 → 5/10 想定)
- [ ] 本 cross-instance-pr を `done/` 移動

## 連携先

### consolidate-memory --lint (= part 69 PS#1 cross-instance-pr) との連携

`memory.stats` action の `orphan_count` 等は consolidate-memory --lint の検出結果と同期. **両者が同じ memory_index** を参照することで **lint と search の整合** を保つ.

### #2 Atomic Notes Linking との連携

`memory.related` action は `[[link]]` 推薦 UI として将来活用可. AI が新 file 作成時に「関連既存 file 10+ 件を update」する際の候補抽出に使用.

### #6 Mega-Prompt との連携

`memory.search` で context-relevant file を集めた後、`memory.rank` で精緻化 → Mega-Prompt 生成入力として活用.

→ **#7 完成は #2 + #6 の精度を一気に底上げ** = ベースライン 3.0 → 5.0/7 (3 原則同時押上) も視野.

## OPS-28 charter §6 受領 lane 履歴 (2026-04-29 2 件目 / Win → Codex#2 lane)

| part | from | to | 内容 | 性質 |
| --- | --- | --- | --- | --- |
| 54 | Win → Codex#2 | Codex#2 | memo.react test fixture | 5 質問判定 ベース |
| 54 | Win → Codex#1 or #2 | Codex either | mcp_auth_guard WorkOS JWKS | 5 質問判定 ベース |
| **70 (本)** | **Win → Codex#2** | **Codex#2** | **memory-search-hub EF (hybrid search via MCP)** | **SECOND_BRAIN dogfood + co-implementation 第 3 例** |

= co-implementation pattern 第 3 例:
- 第 1 例 = AI_VIDEO #5 (Win + VSCode)
- 第 2 例 = SECOND_BRAIN #3+#4 (Win + PS#1)
- **第 3 例 (本)** = SECOND_BRAIN #7 (Win 設計 + Codex#2 実装)

= 1 軸の中で **3 territory に分散委譲** (= 設計者 + UI/data + EF) する pattern が初出. SECOND_BRAIN は **fleet 全体の協調** が必要な軸.

---

*Win版#132 part 70 / 2026-04-29 起票 / SECOND_BRAIN 原則 #7 (Hybrid Search via MCP) Codex#2 territory 委譲 / MEMORY.md 32.4KB 警告解消の本命 / co-implementation pattern 第 3 例 / 1 軸内 3 territory 分散委譲 第 1 例*
