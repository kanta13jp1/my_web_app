# インスタンス設定・制約カタログ — 自分株式会社 マルチAI開発ガイド

**作成**: 2026-04-16 (VSCode版#79)
**更新責任者**: セッション開始時に制約を発見したインスタンスが随時更新。構造変更は PowerShell版 が担当。

> **このドキュメントの目的**: 各AIインスタンスの「できること・できないこと」を一元管理し、
> セッション冒頭の自動確認と役割分担の最適化に使用する。

---

## Rule 22: バージョン確認・制約解消チェック（毎セッション必須）

### Step 1: Claude Code バージョン確認

```bash
# 現在バージョン確認
claude --version

# npm 最新版確認
npm show @anthropic-ai/claude-code dist-tags.latest

# 現在より新しければ更新
npm update -g @anthropic-ai/claude-code
```

**現在の確認済みバージョン**: `2.1.110` (確認日: 2026-04-16)

### Step 2: バージョン更新時の制約解消確認

バージョンが上がったら以下を確認し、解消された制約を本ドキュメントから削除 + 役割分担を更新する:

| 確認項目 | 確認コマンド |
|---|---|
| WEB版の制約変化 | `code.claude.com/docs/en/claude-code-on-the-web` を WebFetch で確認 |
| 新機能追加 | Changelog `claudefa.st/blog/guide/changelog` を WebFetch で確認 |
| Routines 上限変化 | `code.claude.com/docs/en/routines` を WebFetch で確認 |

### Step 3: 他ツールのバージョン確認

```bash
# GitHub Copilot CLI
gh copilot --version 2>/dev/null || echo "not installed"

# Gemini Code Assist (VS Code 拡張)
# → VS Code の Extensions パネルで "Google Cloud Code" を確認

# Codex CLI
codex --version 2>/dev/null || echo "not installed"
```

---

## インスタンス制約カタログ（確認済み）

### Claude Code VSCode版

| 項目 | 状態 | 備考 |
|---|---|---|
| ローカルCLI実行 | ✅ 可 | `flutter analyze`, `deno lint`, `gh`, `git`, `notebooklm` 全て可 |
| Hooks | ✅ 可 | `.claude/hooks/` 設定済み |
| Skills | ✅ 可 | `~/.claude/skills/` + `.claude/skills/` |
| flutter analyze | ✅ 可 | 毎コミット前に必須 |
| deno lint | ✅ 可 | EF変更後に必須 |
| Playwright MCP | ✅ 可 | `.mcp.json` 設定済み |
| Figma MCP | ✅ 可 | Rule 19 で活用 |
| notebooklm CLI | ✅ 可 | Rule 21 対応済み |
| Routines | ❌ 不可 | **Desktop専用機能** |
| モデル | `claude-sonnet-4-6` | デフォルト |

### Claude Code Windowsアプリ版

| 項目 | 状態 | 備考 |
|---|---|---|
| ローカルCLI実行 | ✅ 可 | ただし Windows パス規則あり |
| PYTHONUTF8=1 | ✅ 必須 | 日本語ファイル編集時に常に付加 |
| flutter analyze | ✅ 可 | 実行時間が長いため timeout 注意 |
| notebooklm CLI | ✅ 可 | |
| Routines | ✅ **利用可能** | **Desktop版専用！ 積極活用推奨** |
| `.github/workflows/` 直接編集 | ❌ 禁止 | PowerShell版 の担当 |
| モデル | `claude-sonnet-4-6` | デフォルト |

### Claude Code PowerShell版 (Windows Terminal)

| 項目 | 状態 | 備考 |
|---|---|---|
| ローカルCLI実行 | ✅ 可 | PowerShell構文注意 (bash引数は `""` でクォート) |
| gh CLI | ✅ 可 | `.github/workflows/` 編集の主担当 |
| deno lint/test | ✅ 可 | |
| notebooklm CLI | ✅ 可 | |
| Routines | ❌ 不可 | PowerShell = ターミナル版。Desktop Routines は不可 |
| モデル | `claude-sonnet-4-6` | デフォルト |

### Claude Code WEB版 (claude.ai/code) ← **要注意**

**確認済み制約一覧** (2026-04-14 調査):

| 項目 | 状態 | 代替手段 |
|---|---|---|
| notebooklm CLI | ❌ **不可** | WebSearch + WebFetch で直接リサーチ |
| flutter analyze | ❌ **不可** | コード読んで静的チェックのみ |
| deno lint | ❌ **不可** | deno lint チェックは VSCode版に依頼 |
| gh CLI | ❌ **不可** | **GitHub MCP** を使用 |
| git CLI | ❌ **不可** | **GitHub MCP** (push_files, create_branch 等) |
| ローカルHooks | ❌ **不可** | — |
| Skills (一部) | ⚠️ 制限あり | 一部スラッシュコマンド未対応 |
| GitHub以外のリポジトリ | ❌ **不可** | GitHubに限定 |
| ローカルファイルシステム | ❌ **不可** | GitHubリポジトリ経由のみ |
| Routines | ❌ **不可** | Windowsアプリ版 が担当 |
| 実行可能なCLI | ❌ **全般不可** | — |
| WebSearch | ✅ **可** | Deep Research の代替として活用 |
| WebFetch | ✅ **可** | URL調査・競合分析に活用 |
| GitHub MCP | ✅ **可** | PR作成・Issue管理・コードレビュー |
| Playwright MCP | ✅ **可** | UI確認 (MCP設定が共有されている場合) |
| ディスク容量 | 30GB | メモリ集中ビルドは不可 |
| セッション転送 | 一方向 | `--teleport` でCLI→Web は不可 (逆は可) |

**→ WEB版の新役割 (改訂)**:
- ~~Rule 21 NotebookLM Deep Research 専任~~ → **WebSearch/WebFetch 直接リサーチ専任**
- GitHub MCP 経由の PR 作成・Issue 管理
- ブログ英語版生成・競合調査
- extended thinking でのアーキテクチャレビュー (コード実行不要)

---

## モード・モデル指定ガイド

### 利用可能モデル

| モデルID | 用途 | 特徴 |
|---|---|---|
| `claude-opus-4-6` | 複雑なアーキテクチャ・設計判断 | 128K出力, 1M context, 最高品質 |
| `claude-sonnet-4-6` | **日常の実装タスク (デフォルト推奨)** | 64K出力, 1M context, バランス型 |
| `claude-haiku-4-5-20251001` | 単純なルーティン・クイックタスク | 高速・低コスト |

### 拡張思考 (Extended Thinking) トリガー

Claude Code プロンプトに以下のキーワードを含めると思考モードが起動:

| キーワード | 思考レベル | 使いどき |
|---|---|---|
| `think` | Lv.1 (軽い) | 設計の確認・方針チェック |
| `think deeply` / `think more` | Lv.2 | 中程度の設計判断 |
| `think harder` / `think really hard` | Lv.3 | 複雑なバグ・パフォーマンス問題 |
| `think very hard` | Lv.4 | アーキテクチャ設計・大規模リファクタ |
| `ultrathink` | Lv.5 (最大) | 全体設計・競合戦略・クリティカルな判断 |

**Claude Codeの`/fast`モード**: `/fast` コマンドでOpus 4.6の出力速度を上げる。モデルは変わらない。

### インスタンス別モード推奨

| インスタンス | 通常モード | 推奨思考レベル | 使用シーン |
|---|---|---|---|
| **VSCode版** | Sonnet 4.6 + normal | `think deeply` | 新ページ実装・FSRS統合 |
| **VSCode版** | Sonnet 4.6 + `/fast` | — | 定型のUI token修正・lint fix |
| **Windowsアプリ版** | Sonnet 4.6 + normal | `think` | provider追加・docs修正 |
| **PowerShell版** | Sonnet 4.6 + normal | `think deeply` | CI/CDワークフロー設計 |
| **WEB版** | **Opus 4.6** + normal | `ultrathink` | アーキテクチャレビュー・競合調査 (CLI不使用なのでより深い思考で補完) |

---

## 新機能: Routines (2026-04-14 リリース)

> **Windowsアプリ版専任機能** — Desktop版のみ利用可能

### 概要

Routines は Claude Code Desktop の新機能。PC をオフにしても Anthropic クラウドで自動実行されるサーバーレス自動化。

```
Routine = プロンプト + リポジトリ + コネクター + トリガー
```

**トリガー**: スケジュール (毎時/毎日/毎週) / API呼び出し / GitHub イベント

**使用上限** (サブスクリプション別):
- Pro: 5回/日
- Max: 15回/日
- Team/Enterprise: 25回/日

### 現在の GitHub Actions との関係

| タスク | 現在の実装 | Routines への移行候補 |
|---|---|---|
| AI大学コンテンツ更新 | `ai-university-update.yml` (2時間毎) | ✅ Routine 化で GHA を削減可能 |
| PR 自動レビュー | `claude-agent-review.yml` | ✅ GitHub イベントトリガーに向く |
| インフラヘルスチェック | `infra-health-check.yml` | ⚠️ Routines の30GBメモリ制限に注意 |
| blog-draft 生成 | `blog-draft.yml` | ✅ 毎日スケジュールに向く |
| competitor-monitoring | `competitor-monitoring.yml` | ✅ WebSearch/WebFetch Routine に最適 |

**→ Windowsアプリ版が次セッションで Routines 設定を検討すること**

---

## フォールバックAI詳細設定 (制限到達時)

### GitHub Copilot (常時PR自動レビュー + フォールバック)

| 設定項目 | 推奨値 | 備考 |
|---|---|---|
| モデル選択 | **Auto** | GPT-4.1 / GPT-5 mini / Claude Haiku 4.5 から自動最適化 |
| Agent Mode | ✅ 有効化 | 複数ファイル横断タスクに対応 |
| PR Review モデル | Claude Sonnet 4.6 または GPT-4.1 | GitHub Copilot のモデル選択画面から設定 |
| VSCode 拡張 | GitHub Copilot Chat + GitHub Copilot | 両方インストール推奨 |
| Agent (github.com) | Claude / Codex どちらかを選択可 | Issue/PR 対応タスクに活用 |

**確認コマンド**:
```bash
gh copilot --version
# GitHub Copilot CLI のバージョン確認
```

### CODEX CLI (OpenAI) フォールバック設定

| 設定項目 | 推奨値 | 備考 |
|---|---|---|
| 主な用途 | `.py` / `.ts` ファイル | Python スクリプト・EF draft |
| モデル | GPT-5.2-Codex (デフォルト) | コード特化 |
| 発動条件 | Claude 429 エラー / $50超過 のみ | 通常は不使用 |

**確認コマンド**:
```bash
codex --version 2>/dev/null || npm show @openai/codex dist-tags.latest
```

### Gemini Code Assist フォールバック設定

| 設定項目 | 推奨値 | 備考 |
|---|---|---|
| 主な用途 | `.dart` ファイル IDE 補完 | Flutter/Dart に最適化 |
| モデル | Gemini 2.5 Pro (VS Code 拡張設定) | |
| 発動条件 | Claude 429 / $50超過 のみ | |
| インストール | VS Code 拡張 "Google Cloud Code" | |

---

## インスタンス別 役割分担 (改訂版 2026-04-16)

### VSCode版 (Claude Code CLI + VS Code)

| 担当 | 詳細 |
|---|---|
| **Write 権限** | `lib/` (Flutter UI) + `supabase/functions/` + `docs/DESIGN.md` |
| **専任ルール** | Rule 8, 16 (表示チェック) / Rule 19 (UI改善) |
| **必須チェック** | `flutter analyze 0エラー` + `deno lint 0エラー` |
| **モデル** | Sonnet 4.6 (通常) / Opus 4.6 + ultrathink (アーキテクチャ判断) |
| **禁止** | `docs/` (DESIGN.md除く), `.github/` の編集 |

### Windowsアプリ版 (Claude Code Desktop)

| 担当 | 詳細 |
|---|---|
| **Write 権限** | `docs/` (DESIGN.md除く) + `supabase/migrations/` |
| **専任ルール** | Rule 10 (docs全件分析) / AI大学プロバイダー追加 |
| **新専任** | **Routines 設定・管理** (Desktop版専用機能) |
| **モデル** | Sonnet 4.6 (通常) / Opus 4.6 + think deeply (設計判断) |
| **禁止** | `lib/`, `supabase/functions/`, `.github/` の編集 |

### PowerShell版 (Claude Code CLI + Windows Terminal)

| 担当 | 詳細 |
|---|---|
| **Write 権限** | `.github/workflows/` + `.mcp.json` + `docs/MULTI_INSTANCE_COORDINATION.md` |
| **専任ルール** | Rule 17 (CI/CD最適化) / Schedule タスク管理 |
| **モデル** | Sonnet 4.6 (通常) / Opus 4.6 + think deeply (ワークフロー設計) |
| **禁止** | `lib/`, `supabase/functions/`, `docs/` (MULTI_INSTANCE_COORDINATION.md は own) |

### WEB版 (claude.ai/code) ← **役割改訂**

| 担当 | 詳細 |
|---|---|
| **Write 権限** | `docs/blog-drafts/` + `docs/research/` (GitHub MCP 経由) |
| **専任ルール** | WebSearch/WebFetch **直接リサーチ** (NotebookLM の代替) |
| **新追加** | GitHub MCP 経由の PR 作成・Issue 管理・コードレビュー |
| **新追加** | Opus 4.6 + ultrathink でのアーキテクチャレビュー (実行不要の純粋推論) |
| **削除** | ~~Rule 21 NotebookLM Deep Research 専任~~ (CLI不可のため) |
| **モデル** | **Opus 4.6** (CLIが使えない分、思考力で補完) |
| **禁止 (制約)** | `notebooklm` CLI / `flutter analyze` / `deno lint` / `gh` / `git` CLI |
| **代替手段** | GitHub MCP (gh代替) / WebSearch (notebooklm代替) |

---

## 各インスタンス推奨プロンプト (次回セッション用)

### VSCode版 推奨プロンプト

```
このインスタンスはVSCode版です。

【バージョン確認】
claude --version && npm show @anthropic-ai/claude-code dist-tags.latest

【今日のタスク候補 (優先度順)】
1. Rule 8: Playwright で https://my-web-app-b67f4.web.app/ を確認 → コンソールエラー修正
2. Rule 19: design-skills サブエージェント起動 → 本日のUI改善1ページ実施
3. AI大学v2実装: docs/superpowers/plans/2026-04-16-ai-university-v2.md の続き
4. T-1: 未投稿ブログがあれば blog-publish ワークフローでディスパッチ

【推奨思考モード】
- UI設計判断が必要な場合: "think deeply について検討してから実装してください"
- 新機能アーキテクチャ: "ultrathink して最適な実装を提案してください"
- 定型修正: /fast モードで高速処理
```

### Windowsアプリ版 推奨プロンプト

```
このインスタンスはWindowsアプリ版です (Claude Code Desktop)。

【バージョン確認】
claude --version && npm show @anthropic-ai/claude-code dist-tags.latest

【今日のタスク候補 (優先度順)】
1. Routines確認: Claude Code Desktop の Routines 機能でAI大学更新/ブログ生成を設定できるか確認
   → code.claude.com/docs/en/routines を参照
2. /ai-university-add-provider で新規プロバイダー候補を評価・追加
3. Rule 10: docs/ 全件分析 (Explore エージェント委譲) → 鮮度切れ修正
4. AI大学v2: supabase/migrations/ テーブル作成マイグレーション実行

【Routines 設定検討】
Desktop版専用のRoutines機能を活用し、以下のGHAを代替できないか検討:
- ai-university-update (2時間毎) → Routine化
- blog-draft (毎日) → Routine化
使用上限: Max = 15回/日、Pro = 5回/日 を確認してから設定

【推奨思考モード】
- プロバイダー調査: "think about which provider to add next"
- docs修正: 通常モード
```

### PowerShell版 推奨プロンプト

```
このインスタンスはPowerShell版です。

【バージョン確認】
claude --version; npm show @anthropic-ai/claude-code dist-tags.latest

【今日のタスク候補 (優先度順)】
1. Rule 17: .github/workflows/ を確認 → エラーワークフロー修正
   gh run list --limit 20 --json name,status,conclusion
2. T-1: blog-publish ワークフローで未投稿下書きをディスパッチ
   gh workflow run blog-publish.yml -f draft_path="docs/blog-drafts/YYYY-MM-DD.md" -f platforms="qiita,devto"
3. docs/MULTI_INSTANCE_COORDINATION.md 更新 (役割分担改訂を反映)
4. Routines 使用量確認 (Windowsアプリ版が設定した場合)

【推奨思考モード】
- CI/CDワークフロー設計: "think deeply してから実装"
- 定型dispatch: 通常モード
```

### WEB版 推奨プロンプト

```
このインスタンスはWEB版Claude Code (claude.ai/code) です。
【制約確認】notebooklm CLI / flutter analyze / deno lint / gh CLI / git CLI は使用不可。
代替: WebSearch/WebFetch / GitHub MCP を使用してください。

【バージョン確認】
WebFetch で code.claude.com/docs/en/about を確認し、WEB版の新機能・制約変更をチェック

【今日のタスク候補 (優先度順)】
1. WebSearch で AI大学新規プロバイダー候補を3軸評価してレポート作成
   → docs/research/YYYY-MM-DD-provider-candidates.md として GitHub MCP で保存
2. GitHub MCP でオープンPRのコードレビュー実施
   → mcp__plugin_github_github__list_pull_requests → pull_request_read → review_write
3. 競合21社最新動向調査 → docs/research/ に保存
4. ブログ英語版の品質レビュー・改善提案

【モデル設定】
このセッションは Opus 4.6 を使用。複雑な分析には "ultrathink" を含めてください。

【GitHub MCP 使用例】
PR一覧取得: list_pull_requests({state: "open"})
PR内容確認: pull_request_read({pullRequestNumber: 123})
レビュー投稿: pull_request_review_write({...})
```

### CODEX CLI 使用時プロンプト (フォールバック)

```
Claude 429エラーのため CODEX CLI で続行します。
対象ファイル: [.py または .ts ファイルのみ]
タスク: [具体的な実装内容]

注意: CODEX はプロジェクトコンテキストが限定的です。
以下のファイルの内容を先に貼り付けてください:
- 編集対象ファイル
- 関連する型定義ファイル
```

### GitHub Copilot 使用時プロンプト (フォールバック or PR Review)

```
# PR自動レビュー (常時稼働)
claude-agent-review.yml が実行するレビューの補完として、
GitHub Copilot のエージェントモードで以下を確認:
- セキュリティ: SQL injection / XSS / 認証漏れ
- パフォーマンス: N+1クエリ / 不要な再レンダリング
- CLAUDE.md ルール違反 (ダミーデータ / flutter analyze エラー等)

モデル選択: Auto (GPT-4.1 / Claude Sonnet 4.6 自動選択)
```

---

## 制約発見時の更新手順

セッション中に新しい制約・制約解消を発見したら:

1. **即座に記録** (memory/ へ):
   ```
   memory/feedback_correction_YYYYMMDD_[instance].md
   ```

2. **本ドキュメントを更新**:
   - 該当インスタンスの制約カタログ表を更新
   - `✅ 可 (YYYY-MM-DD 確認)` または `❌ 不可 (YYYY-MM-DD 確認)` で日付を付記

3. **推奨プロンプトを更新**:
   - 制約が解消された場合、プロンプトから回避策コメントを削除
   - 新制約が発見された場合、プロンプトに注意書きを追加

4. **COMPRESSED_PROMPT_V3.md の分担表を更新** (PowerShell版 が担当、緊急時はどのインスタンスも可):
   - `cross-instance-prs/` に変更提案を投函

---

## 変更ログ

| 日付 | 変更内容 | 担当 |
|---|---|---|
| 2026-04-16 | 初版作成。WEB版制約確認・Routines追加・モデル設定・推奨プロンプト追加 | VSCode版#79 |
