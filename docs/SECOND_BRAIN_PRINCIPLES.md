# Second Brain 7 原則 — 自分株式会社 PKM (Personal Knowledge Management) インフラ設計

> このドキュメントは、自分株式会社の **12 instance fleet 共有知識インフラ** が **数千ページ規模** でも健全に機能するための **PKM 設計原則** を定義する **必守原則** である.
>
> **ソース**: NotebookLM Notebook [Claude Code and Obsidian: Building Your AI Second Brain](https://notebooklm.google.com/notebook/9871b0b1-0748-4d7d-99bc-bd6aea2231f6)
> Claude Code + Obsidian で AI Second Brain を構築するワークフロー (Markdown ベース PKM / Atomic Notes / Daily Notes / Wiki Lint / Mega-Prompt 生成) を題材とした原則 (2026-04-29 取り込み)
>
> **位置づけ**: 既存 9 設計軸 (3 層階層化済) に加え、**Layer 3 設計層** に追加する **10 番目の軸** (= 知識インフラ・ドメイン特化応用層 / AI_VIDEO と並列)
> - PHILOSOPHY (why) / AI_DEV (how) / AI_CHARACTER (who) / IMBUE (how it feels)
> - COLLAB_AI (how it evolves) / MCP_AUTH (how it opens) / AI_VIDEO (how it appears as media)
> - VIBE_CODING (how it stays responsible) / PLATFORM_EVOLUTION (how it grows)
> - **SECOND_BRAIN (how knowledge stays healthy at scale)** ← 新規 10 番目

---

## なぜ必要か

自分株式会社は既に **3 層メモリシステム** (memory/ + NotebookLM Master Brain + claude-mem) を持ち、本日 (2026-04-29) 時点で **memory/ ディレクトリは 100+ ファイル** を抱える. 今後 12 fleet × 数百 part/月 のペースで増殖すると、以下の問題が顕在化する:

- **MEMORY.md が肥大化** (本日警告: 32.4KB / limit 24.4KB) → AI が index を全部読めない
- **孤児ノート** (= どこにも参照されない Markdown) が増える → 知識が眠る
- **重複ノート** (= 同主題で別 timestamp) が増える → 矛盾が生じる
- **検索エンジン不在** → 12 fleet 各自が同じ調査を繰り返す
- **メガプロンプト不在** → 新インスタンス起動時にゼロから context 説明が必要

Claude Code + Obsidian の PKM ベストプラクティス (Atomic Notes / Linking / Daily Notes / Lint / Spaced Repetition / Mega-Prompt) を **自分株式会社既存メモリインフラ** に当てはめれば、**数千ページ規模でも健全な Second Brain** が構築可能.

= 「AI fleet が共有する **企業脳**」を技術的に実装するための原則層.

---

## 7 原則

### 原則 1: 階層型ナレッジの厳格な分離 (Immutable Sources / Evolving Wiki / Schema)

**ルール本文**: 知識を **3 層** に厳格分離する. (a) Layer 1 = **生データ (immutable / 真実の源泉)**. (b) Layer 2 = **AI が更新する Wiki (Markdown 群)**. (c) Layer 3 = **AI 動作スキーマ (CLAUDE.md / inject-rules.txt)**. 層を跨いだ書き込みを禁止.

**なぜ重要か**: AI は「汎用チャットボット」ではなく **「規律を持った Wiki 管理者」** として動作させる必要がある. 層が混ざると AI は生データを書き換えてしまい、**真実の源泉が失われる**.

**どう適用するか**:
- **Layer 1 (immutable)**: `session_summary`, NotebookLM source, claude-mem 圧縮 → 編集禁止
- **Layer 2 (evolving)**: `memory/*.md` (Atomic Notes), `docs/*PRINCIPLES.md` → AI が継続更新
- **Layer 3 (schema)**: `CLAUDE.md`, `~/.claude/hooks/inject-rules.txt`, `docs/OPERATIONS_CHARTER.md` → CEO が更新 (= 取締役会議題)
- ❌ NG: AI が `session_summary` を勝手に書き換える
- ✅ OK: AI が `session_summary` を Layer 1 として読み、Layer 2 (memory/*.md) に統合する

### 原則 2: 自律 Ingest と Atomic Notes の相互リンク (Autonomous Ingest & Linking)

**ルール本文**: 新ソースを取り込む時、AI が **既存知識と統合** し、**10〜15 個の関連 Atomic Notes** を **同時に更新・リンク (Tagging/Linking)** する. 単一ノート追加でなく **ネットワーク更新** を強制.

**なぜ重要か**: 単純な append だけでは断片化する. 新情報を既存 Atomic Notes と双方向リンクで繋ぐことで、**12 fleet 全体で利用可能な PKM ネットワーク** が自動構築される.

**どう適用するか**:
- 新規 memory file 作成時、関連する 10-15 個の既存 file 名を **必ず** 本文中に `[[file_name]]` リンクとして記載
- AI への ingest 指示テンプレ: 「`memory/<new>.md` を追加. 関連する既存 atomic notes 10 件以上を update して bidirectional link を張れ.」
- 月次 lint script (= 原則 4) で双方向リンク完全性を検証
- ❌ NG: 新 memory file 単体追加 → 既存 file は更新せず
- ✅ OK: 新 file + 関連 10+ file を同 commit で更新 (= 1 ingest = 11+ file 編集)

### 原則 3: 中央インデックス + 時系列ログの二元管理 (Master Index & Daily Notes)

**ルール本文**: **2 つの特別 file** で AI と人間の認識を同期する. (a) `index.md` (= **内容中心の最高次インデックス** / 既存 `MEMORY.md`). (b) `log.md` (= **すべての action の時系列ログ** / 新規追加).

**なぜ重要か**: index だけでは「何が **最近** 動いたか」が分からない. log だけでは「**全体構造**」が分からない. 2 軸併用で AI が常に最新 + 全体を把握できる.

**どう適用するか**:
- 既存 `MEMORY.md` = `index.md` 役割を継続 (内容中心 / 1 行サマリ / 200+ entries で分割)
- 新規 `memory/log.md` 追加: `## [2026-04-29] ingest | NotebookLM 9871b0b1 蒸留 → SECOND_BRAIN axis 確立` 形式で時系列追記
- `log.md` は append-only / 編集禁止 / 月次に過去分を summary 化
- 12 fleet 全員がセッション開始時に **必ず** `index.md` (MEMORY.md) + `log.md` 末尾 50 行を読む
- ❌ NG: AI がセッション開始時に MEMORY.md だけ読んで「何があったか」分からず作業
- ✅ OK: index + log 両方読んで「過去の全体 + 直近の動き」両方把握

### 原則 4: 定期 Lint + 孤児統合 (Continuous Lint & Orphan Resolution)

**ルール本文**: 定期的に AI に Wiki の **健康チェック** (= 矛盾解消 / リンク漏れ修正 / 孤児ノート統合 / 重複統合) を実行させる. **Spaced Repetition の代用** として「眠っている知識の再活性化」を担保.

**なぜ重要か**: PKM は放置すると衰える. 月次以上の頻度で全 atomic notes を AI が見直し、孤児ノート (= どこからも参照されない) を発見 → 関連既存ノートに統合することで、**全知識が活用可能な状態** を維持.

**どう適用するか**:
- 既存 PS#1 専任 `consolidate-memory` skill を拡張: lint 機能追加
  - 孤児ノート検出 (= 他 file から `[[<file>]]` 参照ゼロ)
  - 重複候補検出 (= 同 prefix + 90 日以内)
  - 矛盾検出 (= 同概念で対立する記述)
- 月 1 回 PS#1 が `consolidate-memory --lint` 実行 → 結果を `memory/lint_report_YYYY_MM.md` に保存
- 孤児ノートは `PHILOSOPHY` / `IMBUE` 等の既存 9 軸 docs と関連付け提案 → CEO 承認で統合
- ❌ NG: memory/ に追加だけして放置 → 数百 file 後に孤児が大量発生
- ✅ OK: 月次 lint で常に「全 file が網羅的にリンクされている」状態を維持

### 原則 5: 探求の永続化 (Query to Persistence)

**ルール本文**: AI への **Query から生まれた優れた回答** (= 比較表 / スライド構成 / アーキテクチャ図 / プロンプト案) を **一時 chat で消費せず**、そのまま Wiki の **新ページとして永続化** する.

**なぜ重要か**: 12 fleet 各 instance が独立に同じ質問をして同じ回答を再生成するのは無駄. **「あの時のあの比較表」を次回別 instance のセッションに直接活かせる** よう、優れた AI 出力を Layer 2 に蓄積.

**どう適用するか**:
- 新メモリ category: `memory/query_artifact_YYYYMMDD_<topic>.md` (= AI 出力の永続化 file)
- 各 instance が「これは保存価値あり」と判断した AI 出力を即 file 化 (= ダウンタイム 1 分)
- 永続化テンプレ: `## Query` (元質問) + `## Context` (背景) + `## Artifact` (AI 出力) + `## Reuse` (再利用先候補)
- VIBE_CODING 原則 #2 (AI as PM) の Plan アーティファクトと同形式 → 統一管理
- ❌ NG: AI が出した複雑な比較表を chat で読んで満足 → 翌日には消失
- ✅ OK: 比較表を memory/ に永続化 → 別 instance 検索可能

### 原則 6: メガプロンプト生成基盤としての PKM (PKM to Mega-Prompt)

**ルール本文**: 自身の **文体 + 価値観 + 過去のパターン** が統合された Wiki を用いて、AI に **極めて精度の高い指示書 (メガプロンプト)** を逆生成させる. ゼロから背景説明する **構造的ストレス** を排除.

**なぜ重要か**: 12 fleet × 数十 part/日のセッション起動時、毎回 context 説明する time cost は累積で巨大. CEO の文体 + 9 設計軸 + OPS-28 + 12 fleet 役割が統合された PKM があれば、**「次のタスクのプロンプトを作って」だけで完成形** が出る.

**どう適用するか**:
- AI への新規 instance 立ち上げプロンプト: 「`MEMORY.md` + `docs/CLAUDE_MD_FACTS_DUPLICATED.md` + 9 設計軸 docs を読んだ前提で、次のタスク `<X>` の megaprompt を作って」
- 各 instance 開始時に **megaprompt artifact** を memory/ に保存 → 次回流用
- AI_CHARACTER 人格設定の augmentation: 「Wiki 由来の文体パターン」を AI 応答に強制反映
- 外部アウトプット (= ブログ / プレゼン / 営業資料) も megaprompt 経由で生成
- ❌ NG: 毎セッション「自分株式会社って何?」から AI に説明
- ✅ OK: PKM が AI のメモリそのものとして機能 → ゼロ説明で適切な応答

### 原則 7: スケーラブルなハイブリッド検索 (Scalable Hybrid Search via MCP)

**ルール本文**: ノートが **数百ページ規模** に拡大した時、CLI ツール / MCP server による **ローカル検索エンジン** (BM25 ベクトル + LLM 再ランク) を導入. **RAG インフラなしでも高速検索** を実現.

**なぜ重要か**: 既に MEMORY.md は警告 (32.4KB). 1000 file 規模では full-text scan は遅すぎる. ハイブリッド検索 (= キーワード + ベクトル + LLM 再ランク) を MCP server 化すれば、**12 fleet 全体からオンデバイスで高速横断検索** 可能.

**どう適用するか**:
- 新 MCP server: `supabase/functions/memory-search-hub` (将来 / MCP_AUTH 10 原則準拠)
- アクション: `memory.search` (BM25 + ベクトル) / `memory.rank` (LLM 再ランク) / `memory.related` (file ID から関連 N 件)
- claude-mem の SQLite ベクトルストアと統合 (= 既存資産活用)
- 検索 API は MCP `ui://` リソースとしても公開 (= PLATFORM_EVOLUTION 原則 #1)
- ❌ NG: AI が grep で全 memory/ を毎回 scan → 数十秒
- ✅ OK: AI が memory.search 呼出 → 数百ミリ秒で関連 5 件取得

---

## 7 原則の相互依存

```
[#1 階層型ナレッジ分離 (3 層)]    ← 基盤構造
        ↓ 上で
[#2 Atomic Notes 相互リンク]      ← ネットワーク化
        ↓ 上で
[#3 Master Index + Daily Log]    ← 認識同期
        ↓ 維持のため
[#4 定期 Lint + 孤児統合]        ← 健全性
        ↓ 価値最大化
[#5 Query 永続化]                ← 知識蓄積
        ↓ 出口
[#6 Mega-Prompt 生成]            ← AI 駆動最大化
        ↓ スケール対応
[#7 Hybrid Search via MCP]       ← 数千ページ対応
```

= **基盤 → ネットワーク → 同期 → 健全 → 蓄積 → 駆動 → スケール** の 7 段成熟.

---

## 既存 9 設計軸との関係

| 既存軸 | SECOND_BRAIN 7 原則の augmentation 関係 |
| --- | --- |
| PHILOSOPHY (why) | 原則 6 (Mega-Prompt) で「自社文体の AI 強制反映」を補強 |
| AI_DEV (how) | (直接関連なし — 知識インフラは構造論) |
| AI_CHARACTER (who) | 原則 6 (Mega-Prompt) で「Wiki 由来人格」を補強 |
| IMBUE (how it feels) | (直接関連なし) |
| COLLAB_AI (how it evolves) | 原則 2 (Autonomous Ingest) で「新情報の AI 統合」を強化 |
| MCP_AUTH (how it opens) | 原則 7 (Hybrid Search via MCP) で「検索 server 公開」を追加 |
| AI_VIDEO (how it appears) | 原則 5 (Query 永続化) で「動画プロンプト案蓄積」を補強 |
| VIBE_CODING (how it stays responsible) | 原則 5 (Query 永続化) で「Plan アーティファクトの永続化」を補強 |
| PLATFORM_EVOLUTION (how it grows) | 原則 1 (階層型分離) + 原則 7 (MCP 検索) で「PKM 基盤」を補強 |

= 9 軸中 7 軸に対して 1+ 原則ずつ augmentation. AI_DEV / IMBUE 非介入 (専門領域非侵犯).

---

## 自分株式会社 既存ベースライン評価

| 原則 | 現状 | gap |
| --- | --- | --- |
| #1 階層型分離 | 部分 ✅ (memory/Layer2 + CLAUDE.md/Layer3) | Layer1 (immutable source) 明示なし |
| #2 Autonomous Ingest & Linking | ❌ (新 file 単体追加 / 双方向リンクなし) | `[[file]]` link 慣習未定着 |
| #3 Master Index + Daily Log | 部分 ✅ (MEMORY.md = index あり / log なし) | `memory/log.md` 未作成 |
| #4 定期 Lint + 孤児統合 | △ (consolidate-memory skill ある / 自動 lint なし) | `--lint` flag 未実装 |
| #5 Query 永続化 | △ (cross-instance-pr / project memory ある / query artifact 未分類) | `memory/query_artifact_*` カテゴリなし |
| #6 Mega-Prompt 生成 | △ (CLAUDE.md + inject-rules で context あり) | megaprompt artifact 未保存 |
| #7 Hybrid Search via MCP | △ (claude-mem SQLite ベクトルあり / MCP 未公開) | memory-search-hub EF 未実装 |

= **2.5/7** ベースライン. 残 gap = 主に「明示化 + 自動化」.

---

## チェックリスト (memory file 追加 PR 時)

- [ ] **#1 Layer**: file は Layer 1/2/3 のどれに属するか明示?
- [ ] **#2 Linking**: 関連既存 atomic notes 10+ 件を同 commit で update?
- [ ] **#3 Daily Log**: `memory/log.md` に追記済?
- [ ] **#4 Lint**: 既存 lint 結果と矛盾なし?
- [ ] **#5 Persistence**: AI 出力で保存価値あるものを永続化?
- [ ] **#6 Megaprompt**: 次回 instance がこの file を読めば megaprompt 生成可能?
- [ ] **#7 Search**: file 命名は memory.search で findable か?

---

## 整合性監査 (定期セルフレビュー)

`scripts/check_second_brain_health.py` (将来追加):
- 全 memory/ file の `[[link]]` 参照数を集計 → 孤児 file 検出
- file 命名 prefix の重複検出 (= 同主題 90 日以内の file を統合候補に)
- MEMORY.md index と memory/ ディレクトリ実体の整合 (= 漏れ + 余剰検出)
- 違反検出時は GitHub Issue 自動作成 (= COLLAB_AI Verifier-Generator + OPS-28 改善トリガー連携)

---

## 実装履歴

| 日付 | part | 実装 | 達成原則 | baseline |
| --- | --- | --- | --- | --- |
| 2026-04-29 | Win版#132 part 68 | 軸確立 (docs + Rule [BRAIN-32]) | — | 2.5/7 |
| 2026-04-29 | Win版#132 part 69 | `memory/log.md` 新規 (#3 Daily Log) + PS#1 へ `consolidate-memory --lint` cross-instance-pr (#4 委譲) | #3 部分 (Daily Log 実装 / Master Index は既存 MEMORY.md) | 2.5 → **3.0/7** |

**次回ターゲット**:
- #2 `[[link]]` 慣習定着: 全 memory file の crosslink audit → Win版 territory
- #3 `memory/log.md` 新規作成 + 既存 part 47-67 を時系列で append → Win版 territory
- #4 `consolidate-memory --lint` 実装 → PS#1 cross-instance-pr 候補
- #5 `memory/query_artifact_*` カテゴリ + テンプレ → Win版 territory
- #6 megaprompt artifact 保存 (= 各 instance 起動時) → 12 fleet 共通 routine
- #7 `memory-search-hub` EF skeleton → Codex#2 cross-instance-pr 候補

---

*Win版#132 part 68 / 2026-04-29 起票 / NotebookLM 9871b0b1 "Claude Code and Obsidian: Building Your AI Second Brain" 蒸留 / Rule [BRAIN-32] / 10 番目の設計軸 (= Layer 3 設計層 / 知識インフラ・PKM ドメイン応用)*
