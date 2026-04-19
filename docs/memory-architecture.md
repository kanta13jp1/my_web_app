# Memory Architecture — 自分株式会社 (Win版#130)

NotebookLM `d89ae1f5` ("Persistent Memory for Claude Code: claude-mem vs DIY Hooks") の知見を本プロジェクトの永続メモリ運用に統合した 3 層アーキテクチャ。

## なぜ 3 層必要か

Claude Code は**セッション圧縮で記憶が消える**弱点を持つ。10 インスタンス並行運用 + 100+ セッション/週 では、メモリ陳腐化 (Memory Decay) と肥大化 (Context Rot) が技術的負債化する。

役割を分離した 3 層で「リアルタイム検索」「監査可能ログ」「長期知識」を独立に進化させる。

## 3 層構造

| 層 | 名前 | ストレージ | 用途 | 既存実装 |
|---|---|---|---|---|
| **L1** | Real-time Memory | claude-mem (SQLite + Gemini 圧縮) | セッション内のツール使用履歴 / ベクトル検索 | `npx claude-mem start` (Bun 必須) |
| **L2** | Markdown Memory | `memory/*.md` + git tracked | セッション間の意思決定ログ / 監査・共有可能 | `~/.claude/hooks/auto-capture.ps1` + `memory/MEMORY.md` |
| **L3** | Long-term Knowledge | NotebookLM Master Brain (jibun-master-brain) | プロジェクト横断の深い設計判断 / 長期保管 | `notebooklm use ea6cff25` |

## L1: claude-mem (リアルタイム)

### 役割
- ツール呼び出し全件を SQLite に保存
- Gemini 1.5 Flash で要約 → token cost 圧縮
- ベクトル検索で「過去に同じ問題を解いたか」即取得

### 実装
- `npx claude-mem start` でワーカー起動 (セッション開始前)
- worker 未起動なら hook が silent skip (エラーにならない)
- SQLite path: `~/.claude/claude-mem/`

### 検索
```bash
# キーワード検索 (mem-search skill)
claude-mem 経由で semantic_search / get_observations
```

### 制約
- Bun 必須 (Node.js 不可)
- Worker process 必要 (常駐)
- DB 肥大化したら `consolidate-memory` skill で整理

## L2: Markdown Memory (中期・監査可能)

### 役割
- 意思決定の根拠を git tracked Markdown で保存
- 10 インスタンス間で共有 + git diff で変更追跡可能
- データベースのブラックボックス化を防ぐ

### ファイル種別
| 種別 | パターン | 用途 |
|---|---|---|
| 成功パターン | `feedback_success_YYYYMMDD_<topic>.md` | うまくいったアプローチ |
| 訂正・失敗 | `feedback_correction_YYYYMMDD_<topic>.md` | 二度と繰り返さない罠 |
| 新規発見 | `project_YYYYMMDD_<topic>.md` | プロジェクト固有の仕様発見 |
| インデックス | `MEMORY.md` | 全ファイル 1 行サマリ |

### Hook 構成
- **PostToolUse hook**: `~/.claude/hooks/auto-capture.ps1` — Write/Edit 後にログ
- **SessionStart hook**: `~/.claude/hooks/session-resume.ps1` — 直近ログを context 注入
- **UserPromptSubmit hook**: `~/.claude/hooks/inject-rules.ps1` — RULES (毎ターン)

### Namespace 化 (10 インスタンス並行対策)
ファイル名に **インスタンス ID** を含めてレースコンディション回避:
- `project_20260419_win129.md` (Win版)
- `project_20260419_ps3_s1.md` (PS版#3)
- `project_20260419_vscode118_119.md` (VSCode版)

### Memory Decay 対策 (Win版#130 NEW)

**[MEMORY-DECAY] ルール** (inject-rules.txt 注入):
- 全ファイル名に **タイムスタンプ** (YYYYMMDD) 必須 ✅ 既存
- 同主題の新ファイルは古いファイルを **shadow** (上書きせず新ファイル併存)
- 30 日経過 + reference 0 のメモリは `consolidate-memory` skill で merge or 削除候補
- 「失敗パターン」は時間経過後も保持 (将来の繰返し防止)

### Context Rot 対策
- MEMORY.md は 1 ファイル 1 行サマリ (現状 ~150 entries)
- 200+ entries 超えたら `MEMORY_2026Q2.md` 等で分割
- AI には最初 MEMORY.md インデックスだけ読ませる → 必要時のみ詳細 file open

## L3: NotebookLM Master Brain (長期)

### 役割
- セッション横断の深い意思決定を Gemini が自動抽出
- 「過去に試して失敗したアプローチ」を 100+ セッション分から検索
- 動画・スライド・FAQ 等 multi-format で参照可能

### 実装
```bash
notebooklm use jibun-master-brain  # ea6cff25
notebooklm source add memory/<latest>.md  # wrap-up で自動蓄積
notebooklm ask "過去の意思決定: <質問>"
```

### 蓄積フロー
1. `/wrap-up` で memory/ にファイル保存
2. cookie 有効なら `notebooklm source add` で Master Brain に蓄積
3. cookie 期限切れなら `notebooklm login` で 30 秒再認証

### 制約
- cookie 期限切れ要再認証 (~6 ヶ月だが頻度確認)
- WEB 版インスタンスは notebooklm CLI 不可 (代替: WebSearch)

## 4. 複数インスタンス Namespace 化

10 インスタンス並行時の競合回避:

| 問題 | 対策 |
|---|---|
| 同名ファイル書き込みレース | ファイル名に instance ID + session# (例: `project_20260420_win129.md`) |
| 同一行 git conflict | rebase 時 Python regex で両側残し |
| memory/MEMORY.md 同時編集 | 末尾追記方式・先勝ち rebase |
| EF action wbs.bulk_update 競合 | per-instance update + last-write-wins (status='completed' は不可逆) |

## 5. クリーンアップ手順 (Win版#130 ルール化)

### 月 1 回 (PS版#1 担当推奨)

1. `consolidate-memory` skill 実行 → 重複ファイル merge
2. MEMORY.md の dead link 確認 (記載 file 不在チェック)
3. 30+ 日経過 + reference 0 のメモリを review → アーカイブ or 削除
4. 「失敗パターン」は absolute keep (将来の繰返し防止)

### consolidate-memory skill が行うこと
- 同一トピックの複数 file → 1 file merge
- フォーマット統一 (frontmatter / Why / How to apply)
- インデックス再生成

## 既存資産マッピング

本プロジェクトでは既に以下が稼働中:

| 機能 | 場所 | 状態 |
|---|---|---|
| L1 claude-mem | `npx claude-mem start` (PS) | ✅ 動作中 |
| L2 auto-capture hook | `~/.claude/hooks/auto-capture.ps1` | ✅ 動作中 |
| L2 session-resume hook | `~/.claude/hooks/session-resume.ps1` | ✅ 動作中 |
| L2 inject-rules hook | `~/.claude/hooks/inject-rules.ps1` | ✅ 動作中 ([MEMORY-DECAY] 追加済 / Win#130) |
| L2 memory/ markdown | `C:/Users/kanta/.claude/projects/.../memory/` | ✅ 150+ entries |
| L2 MEMORY.md インデックス | 同上 | ✅ 全件 1 行サマリ |
| L3 NotebookLM Master Brain | jibun-master-brain (ea6cff25) | ✅ wrap-up で蓄積 |
| 10 インスタンス Namespace | ファイル名に instance ID | ✅ Win#103-129 で確立 |
| consolidate-memory skill | `anthropic-skills:consolidate-memory` | ✅ 利用可能 |

## 将来的 Enhancement

- **pgvector セマンティック検索**: Supabase テーブル `memory_embeddings` 新設 → メモリ全件 embedding → 「過去の似た問題」高速検索
- **知識グラフ (Neo4j)**: ノード (セッション/事実/洞察/連絡先) + 関係性 (blocks / supersedes / implements)
- **L1.5 caching layer**: Edge Function で WebFetch / WebSearch 結果を 24h キャッシュ

## 関連 rule (inject-rules.txt)

- `[MEMORY-DECAY]` (Win版#130 追加): タイムスタンプ + shadow + cleanup
- `[WBS-SYNC]` (Win版#128): WBS と同期で進捗可視化

## 関連 skill

- `wrap-up`: セッション終了時に memory/ 保存 + Master Brain 蓄積
- `consolidate-memory`: 月 1 回のメモリ整理
- `claude-mem:mem-search` / `smart-explore`: L1 検索

## 参考

- NotebookLM `d89ae1f5` (Persistent Memory for Claude Code: claude-mem vs DIY Hooks)
