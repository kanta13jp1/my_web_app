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
- 新規 memory file 作成時、関連する 10-15 個の既存 file 名を **必ず** 本文中に ``file_name`` リンクとして記載
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
  - 孤児ノート検出 (= 他 file から ``<file>`` 参照ゼロ)
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

## Karpathy AI 外部脳 (2025) 取込 — 4 cycle + Memex 系譜

> **追補ソース**: Andrej Karpathy (元 OpenAI / 元 Tesla AI トップ) が提唱した **「LLM Knowledge Base / AI 外部脳」** を hooeem (@hooeem / X) が 3 段階ガイド化 (= 海外 2,100+ いいね).
> 元記事: [https://x.com/hooeem/status/2041196025906418094](https://x.com/hooeem/status/2041196025906418094)
> 取込日: 2026-05-05 / Win版#132 part 138

### Karpathy 4-cycle (= 本 7 原則との対応)

Karpathy は AI 外部脳の運用を **4 サイクル** で定義. 本 7 原則とは以下の対応:

| Karpathy 4 cycle | 本 7 原則 | 状態 |
| --- | --- | --- |
| **Ingest** (= 新ソース取込 + 概念ページ自動生成) | 原則 #2 (Autonomous Ingest & Linking) | △ 原則化済 / `[[link]]` 慣習未定着 (= part 138 audit / isolated 98.2%) |
| **Compile** (= Wiki ページ構築・更新 / Index 維持) | 原則 #3 (Master Index + Daily Log) + 原則 #1 (Layer 2 evolving) | ✅ **実装済** = `scripts/wiki_compile.py` (part 132 / #1976 close / commit `557e0320b`) → `docs/INDEX.md` (= 295 concepts master index) + `docs/concepts/<slug>.md` × 50 file / `wiki-compile-cron.yml` GHA 自動 run |
| **Query** (= Wiki 横断検索 + 引用付き回答 / 結果 Wiki 保存) | 原則 #5 (Query 永続化) + 原則 #7 (Hybrid Search) | △ 原則化済 / `memory/query_artifact_*` 一部実例 / memory-search-hub EF 未公開 |
| **Lint** (= 矛盾 / リンク漏れ / 古情報 自動検出 + 修正) | 原則 #4 (定期 Lint + 孤児統合) | ✅ **実装済** = PS#1 `consolidate-memory --lint` (= orphan/dup/contradiction 3 検出器) + part 135-137 `sync_inject_rules.py` (= drift 自動修復 Tier 1-3) + part 138 `audit_memory_crosslinks.py` |

= **4 cycle ↔ 7 原則 全対応 + Compile/Lint は実装稼働中**. Karpathy 系譜での再確認 = 本原則の正当性 evidence + ship 実態の可視化.

### 3-layer Architecture (= Karpathy 流) と本原則 #1 の整合

Karpathy 提唱の 3 層 = 本原則 #1 の階層型分離と完全一致:

| Karpathy Layer | 本原則 #1 Layer | 自分株式会社実装 |
| --- | --- | --- |
| `raw/` (= 元素材 / immutable) | Layer 1 (= 真実の源泉) | `session_summary` / NotebookLM source / claude-mem 圧縮 |
| `wiki/` (= AI が更新 / 編集) | Layer 2 (= AI evolving) | `memory/*.md` / `docs/*PRINCIPLES.md` / **`docs/INDEX.md`** (= Karpathy 流 master index / 295 concepts / auto-generated by `scripts/wiki_compile.py`) / **`docs/concepts/*.md`** (= concept entity pages × 50 / wiki-compile-cron 自動更新) |
| `CLAUDE.md` (= スキーマ / 80 行 KPI) | Layer 3 (= 動作スキーマ) | `CLAUDE.md` (= **part 133 で 61 行達成**) / `~/.claude/hooks/inject-rules.txt` (= **part 134 で 69 行達成**) |

Karpathy 強調の **「CLAUDE.md は 80 行以内」KPI** = 本プロジェクト part 133-134 で **CLAUDE.md 61 行 / inject-rules.txt 69 行** 双方達成済.

### Memex (Vannevar Bush 1945) 系譜とメンテナンス問題

Karpathy 元記事 conclusion:

> **「Vannevar Bush の Memex (1945) が描いて解決できなかったのは『誰がメンテナンスするか』だった. いま、その答えが出た.」**

Notion / Evernote / Roam Research が数ヶ月で挫折してきた最大原因 = **メンテナンス労力の累積**. AI (= Claude Code) がこれを完全肩代わりすることで **「使うほど賢くなるパーソナル知識資産」** が初めて実用化.

本プロジェクト原則 #4 (= 定期 Lint + 孤児統合) は **PS#1 S4-S5 で `consolidate-memory --lint` 実装完了** (= 928 file scan / orphan 881 / duplicate 62 groups 検出). さらに **part 135-137 で inject-rules.txt drift 自動修復 Tier 1-3** (= SessionStart hook + Windows Task + GHA cron) 完成 → **メンテナンス完全自動化を Layer 3 (schema) でも達成**.

### Level 1-3 自動化階段との対応

Karpathy 元記事 Level 1-3 と本プロジェクト ship 状況:

| Karpathy Level | 説明 | 本プロジェクト実装 |
| --- | --- | --- |
| Level 1 (= コピペ運用) | Obsidian + Claude Chat / Vault + raw/ + wiki/ | (= 該当なし / Level 2 から開始) |
| Level 2 (= 3 層 + 4 cycle 自動) | CLAUDE.md スキーマ駆動 | ✅ part 133-134 (CLAUDE.md 61 / inject 69 行) |
| Level 3-1 (= CLI 一発実行) | `python scripts/sync_inject_rules.py --apply` | ✅ part 135 |
| Level 3-2 (= スラッシュコマンド) | `.claude/commands/*.md` (= /wiki-init etc) | ⏳ #1977 (= Win Codex / 5 file `wiki-{init,ingest,compile,query,lint}.md` worktree 内 staging 済 / main 未 commit) |
| Level 3-3 (= スケジュール実行) | Windows Task / cron | ✅ part 137 (= JibunKK-InjectRulesAutoSync daily 03:30 JST) |
| Level 3-4 (= GitHub Actions) | repo push で workflow 起動 | ✅ part 136 (inject-rules-drift-cron.yml) |
| Level 3-5 (= Agent Skills) | `.claude/skills/*` 文脈自動検出 | ✅ session-start-check / consolidate-memory 等 既存 |

= **Level 2 + Level 3 の 5 段中 4 段を本プロジェクトで ship 済** (= Level 3-2 のみ Win Codex 待ち).

### Karpathy 取込で得た insights

1. **「AI = 記憶喪失の検索エンジン」アンチパターン**: 質問 → 回答 → タブ閉じる → 翌日ゼロから = トークンを燃やし続けるだけ. PKM 化で **「使うほど賢くなる資産」** に転換.
2. **「インデックスではなく統合」**: Google 検索 = 索引 / Karpathy 流 PKM = 統合 (= 概念 + 概念のつながり). 本原則 #2 の **「10-15 個の Atomic Notes 同時更新」** がまさにこれ.
3. **「コピペで始められる」進入障壁の低さ**: Level 1 は技術スキル不要. CEO / 非技術 stakeholder にも展開可能 = `docs/PHILOSOPHY.md` #1 (CEO 感) と整合.
4. **「Vault に入れるべきは『この 1 年で消費して消えたもの全部』」**: 読んだ記事 / Podcast / 議論 / 古いプロジェクトノート — 全て Layer 2 候補. 既存 `memory/transcripts/` と整合.

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
| #2 Autonomous Ingest & Linking | △ measurement 完了 (= 2026-05-05 audit / 56 file 中 isolated 98.2%) | ``file`` link 慣習未定着 / 実 fix 待ち (`docs/audit-reports/memory_crosslinks_20260505.md`) |
| #3 Master Index + Daily Log | 部分 ✅ (MEMORY.md = index あり / log なし) | `memory/log.md` 未作成 |
| #4 定期 Lint + 孤児統合 | ✅ Done | `consolidate-memory --lint` PS#1 実装済 — orphan/duplicate/contradiction 3 検出器 + `lint_report_YYYY_MM.md` 自動生成 |
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

### 既存 audit script

- **`scripts/audit_memory_crosslinks.py`** (= part 138 で新規 / dependency-free)
  - 全 memory/*.md (root) の `[[link]]` outbound + inbound count
  - healthy (≥10) / moderate (1-9) / orphan-outbound (=0) / **isolated (in=0 out=0)** に分類
  - report: `docs/audit-reports/memory_crosslinks_YYYYMMDD.md`
  - **2026-05-05 baseline**: 56 file / healthy 0 (0%) / isolated 55 (98.2%) = SECOND_BRAIN #2 慣習未定着 を定量確認
  - 再実行: `PYTHONUTF8=1 python scripts/audit_memory_crosslinks.py`

### 将来追加候補

`scripts/check_second_brain_health.py` (= 上の audit を拡張):
- file 命名 prefix の重複検出 (= 同主題 90 日以内の file を統合候補に)
- MEMORY.md index と memory/ ディレクトリ実体の整合 (= 漏れ + 余剰検出)
- 違反検出時は GitHub Issue 自動作成 (= COLLAB_AI Verifier-Generator + OPS-28 改善トリガー連携)

---

## 実装履歴

| 日付 | part | 実装 | 達成原則 | baseline |
| --- | --- | --- | --- | --- |
| 2026-04-29 | Win版#132 part 68 | 軸確立 (docs + Rule [BRAIN-32]) | — | 2.5/7 |
| 2026-04-29 | Win版#132 part 69 | `memory/log.md` 新規 (#3 Daily Log) + PS#1 へ `consolidate-memory --lint` cross-instance-pr (#4 委譲) | #3 部分 (Daily Log 実装 / Master Index は既存 MEMORY.md) | 2.5 → **3.0/7** |
| 2026-04-29 | Win版#132 part 70 | Codex#2 へ `memory-search-hub` EF cross-instance-pr (#7 委譲) | (#7 完成は Codex#2 受領後) | 3.0/7 (PR 受領で 4.0/7 想定) |
| 2026-04-29 | Win版#132 part 71 | `query_artifact_TEMPLATE.md` 新規 + 第 1 実例 `query_artifact_20260429_hybrid_search_tradeoff.md` (#5 dogfood) | #5 (テンプレ + 1 実例 + 双方向 link) | 3.0 → **3.5/7** |
| 2026-04-29 | Win版#132 part 72 | `docs/CORE_LEAF_BOUNDARY.md` 新規 (4 Tier 統合表現 + memory/ 内部 Tier マッピング) — VIBE_CODING #1 + SECOND_BRAIN #1 同時 dogfood (1 doc 2 軸押上 第 1 例) | #1 階層型分離 | 3.5 → **4.0/7** |
| 2026-04-29 | PS#1 S5 受領完成 | `consolidate-memory --lint` 実装完了 (= part 69 Win 起票 / 孤児ノート/重複候補/矛盾検出 + lint_report 生成 + GHA Issue 化) | #4 定期 Lint + 孤児統合 | 4.0 → **4.5/7** |
| 2026-04-29 | Win版#132 part 84 | PS#1 #4 受領 close 確認 + `cross-instance-prs/done/` 移動済 (= PS#1 S5 で実施) + baseline 反映 | (= reciprocal close) | 4.5/7 維持 |
| 2026-04-29 | PS#1 S4 | `~/.claude/skills/consolidate-memory/lint.py` + `SKILL.md` 実装 — orphan (MEMORY.md 未参照) / duplicate (同 prefix 3+件/90日) / contradiction (keyword 3-10件) 3 検出器 + `memory/lint_report_YYYY_MM.md` 自動生成。テスト実行: 928 files / orphan 881 / duplicate 62 groups | #4 定期 Lint + 孤児統合 | 4.0 → **4.5/7** |
| 2026-05-05 | Win版#132 part 133 | CLAUDE.md 圧縮 → **61 行** (Karpathy 80 行 KPI 達成 / pointer hub 化) | #1 階層型分離 (Layer 3 sharpen) | 4.5/7 維持 |
| 2026-05-05 | Win版#132 part 134 | inject-rules.txt 圧縮 → **69 行** (= 同 Karpathy KPI / RULES_INDEX.md 詳細展開) | #1 階層型分離 (Layer 3 sharpen) | 4.5/7 維持 |
| 2026-05-05 | Win版#132 part 135 | `scripts/sync_inject_rules.py` (= canonical / home sync mechanism / --verify mode) | #4 Lint (drift 検出 / Karpathy Level 3-1) | 4.5/7 維持 |
| 2026-05-05 | Win版#132 part 136 | drift 自動修復 Tier 1-3 = SessionStart hook (Tier 1) + Windows Task setup script (Tier 2) + GHA cron 拡張 (Tier 3) | #4 Lint 自動化 (= Karpathy Level 3-3 + 3-4) | 4.5/7 維持 |
| 2026-05-05 | Win版#132 part 137 | Tier 2 Windows Task INSTALLED + verified (= JibunKK-InjectRulesAutoSync daily 03:30 JST) + setup script bugfix (DOMAIN\USER + verify-after-write) | #4 Lint 自動化 (= Karpathy Level 3-3 dogfood) | 4.5/7 維持 |
| 2026-05-05 | Win版#132 part 138 | Karpathy AI 外部脳 (2025) 取込 = 4 cycle / 3 layer / Memex 系譜 / Level 1-3 階段 cross-walk + #1975 close | (= 既存 7 原則の正当性 evidence + ship 状況可視化) | 4.5 → **5.0/7** |
| 2026-05-05 | Win版#132 part 138 | `scripts/audit_memory_crosslinks.py` 新規 + 初回 audit (= 56 file / isolated 98.2% / healthy 0%) | #2 measurement layer (定量化 = baseline 把握 / 実 fix 待ち) | 5.0 → **5.25/7** |
| 2026-05-05 | Win版#132 part 138 (discovery) | 既存 Karpathy infra 認識更新 = part 132 で `scripts/wiki_compile.py` (#1976 close / commit `557e0320b`) + `wiki-compile-cron.yml` GHA + `docs/INDEX.md` (= 295 concepts) + `docs/concepts/*.md` (× 50) が **Compile cycle 実装稼働中** を発見. SECOND_BRAIN doc を実態 reflect | (= 既存実装の認識更新 / baseline 維持) | 5.25/7 維持 |

**次回ターゲット** (baseline 5.25/7):
- **#2 実 fix** (= isolated 55 file 全てに `[[link]]` 10+ 追加 / audit healthy 50%+ 達成) → 5.25 → **5.5/7** (= 中規模 Win Claude task)
- #3 `memory/log.md` 運用強化 (既存 part 47-67 backfill) → Win版 territory
- #5 `memory/query_artifact_*` カテゴリ + テンプレ → Win版 territory (一部 part 71 + part 137 で実例あり)
- #6 megaprompt artifact 保存 (= 各 instance 起動時) → 12 fleet 共通 routine
- #7 `memory-search-hub` EF skeleton → Codex#2 cross-instance-pr 候補
- **Karpathy Level 3-2 (= /wiki-init /wiki-ingest /wiki-query /wiki-lint slash commands)** → #1977 Win Codex territory

### baseline 上昇 path (= measurement → fix → automation 3 phase)
1. **measurement layer** (= +0.25): audit script で定量化 / 本 part 達成
2. **fix layer** (= +0.25): isolated file への `[[link]]` 追加 / 別 session
3. **automation layer** (= +0.25): audit を GHA cron 化 + threshold で Issue 自動作成 / 別 session

---

*Win版#132 part 68 / 2026-04-29 起票 / NotebookLM 9871b0b1 "Claude Code and Obsidian: Building Your AI Second Brain" 蒸留 / Rule [BRAIN-32] / 10 番目の設計軸 (= Layer 3 設計層 / 知識インフラ・PKM ドメイン応用)*

*Win版#132 part 138 / 2026-05-05 改訂 / Karpathy AI 外部脳 (hooeem 経由) 取込 / 4 cycle + 3 layer + Memex + Level 1-3 cross-walk / #1975 受け入れ条件達成*

---

## 階層的クリーンアップ運用 — 静的ルール × 動的コンテキスト (= Issue #2710 正本)

> Win版#132 part 260 (2026-06-10): 原則 1 (階層分離)・原則 4 (定期 Lint) の**運用面を一枚に集約**。
> 「普遍的な真実」と「一時的な文脈」の混在 = 記憶の技術的負債、への標準対処手順。

### 現行の 2 階層 (= 何が静的で何が動的か)

| 階層 | 実体 | ロード |
|------|------|--------|
| **静的 (不変ルール)** | `CLAUDE.md` (80 行 pointer hub) + `docs/` 原則 12 軸・運用 docs + `~/.claude/hooks/inject-rules.txt` (39 rule) | CLAUDE.md = セッション開始時 / inject-rules = **毎ターン** |
| **動的 (短期記憶)** | `memory/MEMORY.md` (index) + `memory/project_*.md` / `feedback_*.md` + SessionStart hook の auto-capture work log | MEMORY.md = セッション開始時 / 個別 memory = 関連時 recall |

静的と動的は**物理的に別ファイル・別ロード経路** — 混在させない (原則 1)。

### 昇格 (動的 → 静的) の path

1. セッション中の学び → `/wrap-up` で `memory/project_*.md` / `feedback_*.md` 化 + MEMORY.md へ 1 行 index ([MEMORY-DECAY] 書式)。
2. **同種の学びが 2-3 回再現**したら昇格候補: 行動規範なら inject-rules へ rule 化 (`/hook-rule-audit` 経由) / 設計知見なら該当 `docs/` 原則 doc へ追記 / 概念なら `scripts/wiki_compile.py` で `docs/concepts/` 化。
3. 昇格したら memory 側は「正本は doc」へ pointer 化 (二重管理しない)。

### 破棄・整理 (クリーンアップ) の cadence

| 周期 | 手順 | 実体 (実装済み) |
|------|------|----------------|
| 毎セッション末 | `/wrap-up` で学び抽出 + 次回候補 | wrap-up skill |
| 月 1 | `consolidate-memory` skill — 重複 merge / stale 修正 / index prune + `--lint` (orphan/duplicate/contradiction 3 検出器 → `memory/lint_report_YYYY_MM.md`) | 原則 4 / PS#1 実装済 → 現行は Win Claude 実行 |
| 随時 ([MEMORY-DECAY]) | 30+ 日参照 0 → consolidate / 200+ entries → `MEMORY_<period>.md` 分割 / `feedback_correction_*` は absolute keep | rule 運用中 (archive 実績: MEMORY_202604 / MEMORY_202605_archive) |
| 週次 | vault lint (`scripts/knowledge_vault_lint.py`) + 必要時 `/wiki-orphan-batch` `/wiki-broken-cleanup` | Karpathy Lint cycle (GHA cron + 手動 skill) |

**禁止事項**: 古い動的 memory を静的 doc へ昇格せず放置したまま参照し続けること (= 記憶負債) / 静的 doc に一時的文脈 (デバッグログ等) を書くこと。

*Win版#132 part 260 / 2026-06-10 追記 / Issue #2710 ([notebooklm:d89ae1f5:3] 階層的クリーンアップ運用) の受入基準 ①②③ を既存実装への正本 pointer として一枚化*
