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

.github/COMPRESSED_PROMPT_V3.md と docs/instance-constraints.md を確認してください。
その後、WEB版許可タスクを実行してください:
1. WebSearch で競合21社の最新情報をリサーチ → docs/competitor-reports/ に保存 (GitHub MCP)
2. Rule 11: AI大学コンテンツ更新 (WebFetch → Supabase API 経由でupsert)
3. GitHub MCP で open PR をレビュー (Code Review MCP 使用)
4. 新制約発見時は docs/instance-constraints.md に追記 (GitHub MCP 経由でファイル更新)
```
