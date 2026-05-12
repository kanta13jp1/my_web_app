# インスタンス別制約・モデル・モード 管理台帳

> **更新ルール**: 新しい制約・仕様変更を発見したセッションが **即このファイルに追記** し、
> `COMPRESSED_PROMPT_V3.md` の該当インスタンス行も同時に更新する。
> 追記フォーマット: `| YYYY-MM-DD | インスタンス | 制約/変更内容 | 代替手段 | 発見セッション |`

---

## 制約発見ログ

| 日付 | インスタンス | 制約・制限 | 代替手段 | 発見 |
| --- | --- | --- | --- | --- |
| 2026-04-16 | WEB版 | `notebooklm` CLI 実行不可 (ローカルPython環境なし) | WebSearch で代替 | Win版#64 |
| 2026-04-16 | WEB版 | `flutter analyze` 実行不可 (Flutter SDK なし) | VSCode版に cross-instance-pr | Win版#64 |
| 2026-04-16 | WEB版 | `deno lint` 実行不可 (Deno なし) | EF変更はVSCode版に委譲 | Win版#64 |
| 2026-04-16 | WEB版 | `gh` CLI / ローカル `git` push 不可 | `mcp__plugin_github_github__push_files` / `create_or_update_file` | Win版#64 |
| 2026-04-13 | WEB版 | `git stash` / `git rebase` 操作不可 | GitHub MCP でファイル単位更新 | PS版#52 |
| 2026-04-11 | Windowsアプリ版 | Python実行時 CP932エラー | `PYTHONUTF8=1` プレフィックス必須 | Win版 |
| 2026-04-11 | Windowsアプリ版 | xlsx ファイルが Windows でロックされ `git stash` 失敗 | `git stash --exclude=*.xlsx` → 特定ファイルのみ stash | Win版 |
| 2026-04-11 | 全インスタンス | Edit ツールは Read 前に使用不可 (File not read yet) | 必ず Read → Edit の順。圧縮後は再 Read | 全 |
| 2026-04-12 | VSCode版 | Write ツールは相対パスのみ有効 (絶対パス silent fail) | `lib/pages/foo.dart` 形式で指定 | VSCode#35 |
| 2026-04-12 | 全インスタンス | Edit 後に linter が変更を巻き戻す場合あり | Edit → 即 `git add` (Python+即gitaddパターン) | VSCode#59 |
| 2026-04-12 | PowerShell版 | GHA `${{ steps.X.outputs.Y }}` を bash 文字列に直接展開禁止 | `env:` ブロック経由で安全に渡す | PS#54 |
| 2026-04-20 | PS版#1 | `~/.claude/hooks/inject-rules.txt` の `[AI-DEV-23]` "blog-publish (2/7)" 記述が陳腐化 | 5/7 に更新 (CB+QG+TRACE_ID+DLQ 追加済 commit 02bdea2d) — 残: retry policy + team memory score | PS#1 S12 |
| 2026-04-20 | PS版#2 | Qiita 429 = **rolling 24h window ではなく >72h の長期 cooldown**。`qiita-retry` skill の旧 Gate 前提 (JST 00:00 固定リセット / 6h 429 → 12h wait) は誤り。4 本連続投稿 (2026-04-17) 後 72h 経過でも 429 継続 | (a) Gate 1: 直近 **72h 429=0** 確認 (b) 429 検出時は **72h wait** (c) burst **1 本/1h+** (d) 日次 **1-2 本/日** に縮小 — skill 3 段階 Gate 化済 (commit 71bc6810) | PS#2 S3 |
| 2026-04-20 | PS版#2 | dev.to 422 "Title already used in last 5min" = 並行 instance collision (53 秒差 dispatch で発生) | `blog-publish.yml` 直前に **5 分以内 run の draft_path 一致 check** (skill Step 2.3)。collision 時は先発 run の URL 採用 + orphan 両方削除 | PS#2 S1 (別 session) |
| 2026-04-20 | PS版#2 | dev.to 4-tag cap silent truncation (`schedule-hub/index.ts:303` `rawTags.slice(0,4)` / 警告 log ゼロ) = frontmatter に 5 tags 書くと 5 番目が silent drop | frontmatter は価値順 sort で 先頭 4 個に価値タグ寄せる (最具体 > カテゴリ > 業界 > 運動 > 汎用)。3 Notion EN drafts で `Notion,AI,SaaS,buildinpublic,webdev` 並び替え済 (commit 976eaf92) | PS#2 S14 |
| 2026-04-20 | 全インスタンス (PS版#3 発見) | git-bash + cygwin Windows 環境で `cd <dir> && dart format <file> 2>&1 \| tail -N` を background task で起動すると stdout buffering lock → 180s timeout 3 連発で永久 hang | **絶対パス + pipe なし** テンプレ: `dart format C:/absolute/path/file.dart 2>&1` (同期 Bash)。exit code 判定のみなら `--set-exit-if-changed` 付加で pipe 完全禁止 | PS#3 S26 |
| 2026-04-20 | 全インスタンス (PS版#3 発見) | ScheduleWakeup 連鎖で 8h+ セッション化 (1 session で user input 3 件・last-prompt 31 件・idle gap 2 回 × 3.5h = 7h 待機) | 深夜 JST 02-06 は ScheduleWakeup 呼出禁止。idle gap 3h+ 検知で wrap-up 実行し session 終了。`delaySeconds` 1800 超過禁止。wake 2 連続自動起動=停止サイン | PS#3 S26 |
| 2026-04-20 | 全インスタンス (PS版#3 発見) | compaction 後 summary 継続セッションに新規大規模タスク投入 → context 再圧迫 → 再 compaction ループ | summary 継続時は wrap-up 済ませて 90 min 以内に session 終了。次タスクは新セッションで起動 | PS#3 S26 |
| 2026-05-05 | Windowsアプリ版 (Win Claude 発見) | `New-ScheduledTaskPrincipal -UserId $env:USERNAME` 単独 (= `"kanta"`) は `Register-ScheduledTask` で「The parameter is incorrect. (20,8):UserId:」失敗 (PowerShell 5.1 / Windows 11) | **DOMAIN\USER 形式必須**: `$userId = "$env:USERDOMAIN\$env:USERNAME"` (= `"KANTA\kanta"`) → `New-ScheduledTaskPrincipal -UserId $userId` | Win版#132 part 137 |
| 2026-05-05 | Windowsアプリ版 (Win Claude 発見) | `Register-ScheduledTask` 失敗後も後続 `Write-Host "INSTALLED"` が走り false-positive 表示 | (a) `try/catch` + `-ErrorAction Stop` で exception 確実捕捉 (b) registration 後 `Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue` で **verify-after-write** (= 不在なら exit) | Win版#132 part 137 |

---

## インスタンス別 現行仕様 (2026-04-16 時点)

### VSCode版 (Claude Code Desktop — Windows)

| 項目 | 値 |
| --- | --- |
| **推奨モデル** | `claude-sonnet-4-6` |
| **推奨モード** | 通常。複雑UI設計時は **Extended Thinking** (`--thinking` フラグ or API `thinking` param) |
| **Claude最新機能** | Extended Thinking / Interleaved Thinking (ツール使用中思考) / CAVEMAN プラグイン |
| **担当範囲** | `lib/` (Flutter) + `supabase/functions/` (EF) + `docs/DESIGN.md` |
| **必須コマンド** | `flutter analyze` (0エラー必須) / `deno lint` (0エラー必須) |
| **制約** | なし |
| **Copilot連携** | Inline Chat (`Ctrl+I`) / Copilot Edits (複数ファイル同時編集) / `@workspace` |

### Windowsアプリ版 (Claude Code Desktop — Windows)

| 項目 | 値 |
| --- | --- |
| **推奨モデル** | `claude-sonnet-4-6` |
| **推奨モード** | 通常 + CAVEMAN (token節約) |
| **Claude最新機能** | Extended Thinking (DB schema設計時) / notebooklm skill / deep-research skill |
| **担当範囲** | `docs/` (DESIGN.md除く) + `supabase/migrations/` + `notebooklm` CLI主担当 |
| **必須コマンド** | `PYTHONUTF8=1 notebooklm ...` / Python スクリプト |
| **制約** | Python実行時 `PYTHONUTF8=1` 必須 / xlsx ロック注意 |
| **Copilot連携** | なし (Windowsアプリ版はIDE非依存) |

### PowerShell版 (Claude Code Terminal — Windows)

| 項目 | 値 |
| --- | --- |
| **推奨モデル** | ルーティン: `claude-haiku-4-5` / CI設計・新機能: `claude-sonnet-4-6` |
| **推奨モード** | `/fast` (定型YAML編集) / 通常 (ワークフロー設計) |
| **Claude最新機能** | CAVEMAN (PR/commit message圧縮) / schedule skill (Claude Code Schedule管理) |
| **担当範囲** | `.github/workflows/` + `.mcp.json` + `docs/MULTI_INSTANCE_COORDINATION.md` |
| **必須コマンド** | `gh workflow run` / `gh pr list` / `deno lint` (EF確認用) |
| **制約** | GHA `${{ steps.X.outputs.Y }}` は env: ブロック経由で渡す |
| **Copilot連携** | Terminal での `gh copilot suggest` / `gh copilot explain` |

### WEB版 (claude.ai/code — ブラウザ)

| 項目 | 値 |
| --- | --- |
| **推奨モデル** | `claude-sonnet-4-6` (claude.ai設定で変更。変更不可の場合あり) |
| **推奨モード** | 通常 + **Projects機能** (プロジェクト専用コンテキスト永続化) + **Memory機能** (設定・パターン記憶) |
| **Claude最新機能** | Projects / Memory / Extended Thinking (opus選択時) / **Learning Mode** (Projectsでコードベース学習) |
| **担当範囲** | `docs/blog-drafts/` + `docs/competitor-reports/` + GitHub PR/Issues主担当 |
| **利用可能MCP** | WebSearch / WebFetch / GitHub MCP / Code Review MCP / Figma MCP / AIDesigner MCP / Magic MCP / Playwright MCP |
| **制約 (不可)** | `notebooklm` CLI / `flutter analyze` / `deno lint` / ローカルCLI全般 / `git` 直接操作 |
| **代替パターン** | notebooklm → WebSearch / analyze/lint → cross-instance-pr / git → GitHub MCP |

### Codex#1 (OpenAI Codex CLI)

> **canonical**: `docs/MULTI_INSTANCE_FLEET.md` 参照

| 項目 | 値 |
| --- | --- |
| **モデル** | GPT-5.2-Codex |
| **worktree** | `.claude/worktrees/instance-codex1` / branch: `codex/codex1-wip` |
| **担当範囲** | SQL + algorithm 最適化 / migration tuning / 数値計算 (馬学習ループ / WBS 同期) |
| **制約 (不可)** | session 持たない (1タスク = 1コマンド) / CLAUDE.md 全文 context 不可 / memory/ 書き込み禁止 (Claude 代行) |
| **Claude Code 役割** | タスク指示文に要点を埋め込んで Codex に渡す / 結果を memory/ に記録 |

### Codex#2 (OpenAI Codex CLI)

> **canonical**: `docs/MULTI_INSTANCE_FLEET.md` 参照

| 項目 | 値 |
| --- | --- |
| **モデル** | GPT-5.2-Codex |
| **worktree** | `.claude/worktrees/instance-codex2` / branch: `codex/codex2-wip` |
| **担当範囲** | 大規模 refactor (500+ 行) / CI cascade fix / UI badge 系 (trailing comma / header version / lint) |
| **制約 (不可)** | session 持たない / CLAUDE.md 全文 context 不可 / memory/ 書き込み禁止 |
| **Claude Code 役割** | タスク指示文に要点を埋め込んで Codex に渡す / 結果を memory/ に記録 |

---

## 外部AI 仕様・モード一覧 (2026-04-16 時点)

### GitHub Copilot

| 機能 | モデル選択肢 | 用途 |
| --- | --- | --- |
| **Inline補完** | GPT-4o (デフォルト) | 行補完・Next-line予測 |
| **Copilot Chat** | GPT-4o / Claude Sonnet / Gemini Pro 選択可 | コード説明・リファクタ提案 |
| **Copilot Edits** | GPT-4o | 複数ファイル同時編集 (VSCode版専用) |
| **Copilot Workspace** | GPT-4o | Issue→実装計画→PR全自動生成 |
| **@workspace** | GPT-4o | リポジトリ全体を文脈として使用 |
| **gh copilot suggest** | GPT-4o | ターミナルCLIコマンド提案 (PS版で活用) |

**このプロジェクトでの使い方**:
- VSCode版: Inline補完 (`Ctrl+Enter`) + Copilot Edits で Flutter 多ファイル修正
- PowerShell版: `gh copilot suggest "gh workflow run ..."` でCLI提案
- WEB版: Copilot Workspace で GitHub Issue → 実装PR 自動化

### Gemini Code Assist

| モデル | 特徴 | 用途 |
| --- | --- | --- |
| **Gemini 2.5 Pro** | 2Mトークンコンテキスト / 最強推論 | 大規模リファクタ / 全EF横断分析 |
| **Gemini 2.5 Flash** | 高速・低コスト | 定型コード生成・補完 |

**このプロジェクトでの使い方**:
- Flutter/Dart 大規模リファクタ (Google製フレームワーク = 相性最良)
- `supabase/functions/` 全体横断分析 (2Mコンテキスト活用)
- Agent mode: 自律的なコード変更 (VSCode Code Assist拡張)
- 制約: `GEMINI_API_KEY` → quota-monitor.yml で監視

### OpenAI CODEX (o3 / o4-mini)

| モデル | 特徴 | 用途 |
| --- | --- | --- |
| **o3** | コーディングベンチ最高スコア / 深い推論 | 複雑アルゴリズム・SQL最適化 |
| **o4-mini** | 高速・低コスト・コーディング特化 | 定型コード生成・変換 |
| **Codex CLI** | ターミナルで直接実行・ファイル読み書き対応 | PowerShell版でローカル実行 |

**このプロジェクトでの使い方**:
- Supabase クエリ最適化 (PostgreSQL + RLS)
- Edge Function の複雑なビジネスロジック
- Codex CLI: PowerShell版で `codex "このSQL最適化して"` で使用
- 制約: `OPENAI_API_KEY` → quota-monitor.yml で監視 (月次 $20 閾値)

---

## 制約発見時の更新ワークフロー

```text
【新制約発見時 — どのインスタンスでも必須】

Step 1: このファイル (docs/instance-constraints.md) の「制約発見ログ」に追記
        フォーマット: | YYYY-MM-DD | インスタンス名 | 制約内容 | 代替手段 | セッション名 |

Step 2: COMPRESSED_PROMPT_V3.md の該当インスタンス行の「制約」列を更新
        (Python replace スクリプト使用。WEB版は GitHub MCP 経由)

Step 3: memory/feedback_correction_YYYYMMDD.md に記録
        (auto-capture hook が自動記録する場合あり)

Step 4: cross-instance-pr で他インスタンスへ周知
        ファイル: docs/cross-instance-prs/YYYYMMDD_constraint_discovery.md

Step 5: GROWTH_STRATEGY_ROADMAP.md のセッション記録に追記
```

---

## 推奨次回セッション開始プロンプト

### VSCode版

```
このインスタンスはVSCode版です。

【セッション開始時必須】まずバージョンチェックを実行してください:
  PYTHONUTF8=1 python3 scripts/check_versions.py
バージョン更新があれば docs/tool-versions.md の制約解消チェックリストを確認し、
解消済みなら docs/instance-constraints.md から該当行を削除して役割分担を見直すこと。

.github/COMPRESSED_PROMPT_V3.md と docs/instance-constraints.md を確認してください。
その後、以下の順で実行してください:
1. docs/cross-instance-prs/ の pending タスクをすべて処理
2. Rule 16: 本番 https://my-web-app-b67f4.web.app/ をPlaywright MCP でスクリーンショット取得・表示チェック
3. Rule 19: UI改善ツールチェーン (design-skills → Figma MCP → AIDesigner MCP → 実装)
4. 新制約発見時は docs/instance-constraints.md に追記
```

### Windowsアプリ版

```
このインスタンスはWindowsアプリ版です。

【セッション開始時必須】まずバージョンチェックを実行してください:
  PYTHONUTF8=1 python3 scripts/check_versions.py
バージョン更新があれば docs/tool-versions.md の制約解消チェックリストを確認し、
解消済みなら docs/instance-constraints.md から該当行を削除して役割分担を見直すこと。

.github/COMPRESSED_PROMPT_V3.md と docs/instance-constraints.md を確認してください。
その後、標準フローで実行してください:
1. Rule 10: docs/ 全件分析 (矛盾・鮮度切れ修正)
2. AI大学: WebSearch で新規プロバイダー候補を調査 → migration 追加
3. notebooklm Master Brain 更新 (PYTHONUTF8=1 必須)
4. 新制約発見時は docs/instance-constraints.md に追記
```

### PowerShell版

```
このインスタンスはPowerShell版です (推奨モデル: ルーティンはclaude-haiku-4-5)。

【セッション開始時必須】まずバージョンチェックを実行してください:
  PYTHONUTF8=1 python3 scripts/check_versions.py
バージョン更新があれば docs/tool-versions.md の制約解消チェックリストを確認し、
解消済みなら docs/instance-constraints.md から該当行を削除して役割分担を見直すこと。

.github/COMPRESSED_PROMPT_V3.md と docs/instance-constraints.md を確認してください。
その後、以下の順で実行してください:
1. Rule 17: .github/workflows/ 最適化チェック (エラーステップ削除・timeout確認)
2. quota-monitor.yml の実行結果確認 (ai_quota_usage テーブル)
3. T-1 ブログ投稿タスクのスケジュール確認
4. 新制約発見時は docs/instance-constraints.md に追記
```

### WEB版

```
このインスタンスはWEB版(claude.ai/code)です。
【制約】notebooklm CLI・flutter analyze・deno lint・ローカルCLI は実行不可。
代替: notebooklm→WebSearch / git→GitHub MCP / analyze→cross-instance-pr依頼。

【セッション開始時必須】WEB版はCLIが使えないためWebFetchでリリース確認してください:
  Claude Code  : https://github.com/anthropics/claude-code/releases
  Gemini       : https://marketplace.visualstudio.com/items?itemName=google.geminicodeassist
  Copilot      : https://marketplace.visualstudio.com/items?itemName=github.copilot
  OpenAI models: https://platform.openai.com/docs/models
バージョン変更があれば docs/tool-versions.md を GitHub MCP 経由で更新し、
制約解消チェックリストを確認すること。

.github/COMPRESSED_PROMPT_V3.md と docs/instance-constraints.md を確認してください。
その後、WEB版許可タスクを実行してください:
1. WebSearch で競合21社の最新情報をリサーチ → docs/competitor-reports/ に保存 (GitHub MCP)
2. Rule 11: AI大学コンテンツ更新 (WebFetch → Supabase API 経由でupsert)
3. GitHub MCP で open PR をレビュー (Code Review MCP 使用)
4. 新制約発見時は docs/instance-constraints.md に追記 (GitHub MCP 経由でファイル更新)
```
