# インスタンス設定・制約カタログ — 自分株式会社 マルチAI開発ガイド

**作成**: 2026-04-16 (VSCode版#79)
**最終更新**: 2026-04-16 (PowerShell版 — v2.1.110 新機能統合・/recap公式Learning Mode・WEB版役割再定義・CODEX/Gemini/Copilot詳細化)
**更新責任者**: 制約を発見したインスタンスが随時更新。構造変更は PowerShell版 が担当。

> **このドキュメントの目的**: 各AIインスタンスの「できること・できないこと」を一元管理し、
> セッション冒頭の自動確認と役割分担の最適化に使用する。
> **毎セッション冒頭に必ずこのドキュメントを参照して推奨プロンプトを確認すること。**

 --- 

## Rule 22: セッション開始チェックリスト（毎セッション必須）

### Step 1: Claude Code バージョン確認 (ローカルインスタンスのみ)

```bash
CURRENT=$(claude --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
LATEST=$(npm show @anthropic-ai/claude-code dist-tags.latest)
echo "現在: $CURRENT / 最新: $LATEST"
[ "$CURRENT" != "$LATEST" ] && npm update -g @anthropic-ai/claude-code && echo "更新完了"
```

**現在の確認済みバージョン**: `2.1.110` (確認日: 2026-04-16, PowerShell版)
> `/doctor` 実行済み: playwright MCP 重複エントリを修正 (local scope削除, project scope `.mcp.json` に統一)

### Step 2: バージョン更新があった場合 — 必須アクション

```bash
# WebFetch でリリースノートを確認
# URL: https://github.com/anthropics/claude-code/releases
# または: https://claudefa.st/blog/guide/changelog
```

| 確認項目 | 対応アクション |
| --- | --- |
| **新機能追加** | 本ドキュメント「新機能追跡ログ」に追記 → 開発フローへの組み込み可否を判断 → 有用なら CLAUDE.md の該当 Rule に追記 or 新 Rule 追加 |
| **WEB版制約の解消** | 下記 WEB版制約カタログの該当行を削除 → WEB版推奨プロンプトを更新 → 役割分担を見直す |
| **ローカル版の制約解消** | 同様に制約カタログを更新 → 推奨プロンプトを更新 |
| **新モデル追加** | 「利用可能モデル」表を更新 → インスタンス別モデル推奨を見直し |
| **Routines 上限変更** | Routines セクションの上限数値を更新 |
| **新モード追加 (Learning Mode 等)** | 「モード・モデル指定ガイド」に追記 → 推奨プロンプトを更新 |

**制約解消時の役割分担見直し例**:
- WEB版で `git CLI` が使えるようになった → PowerShell版との役割重複を整理
- WEB版で `notebooklm` が使えるようになった → Rule 21 の WEB版制限を解除

### Step 3: フォールバックAIツールのバージョン確認

```bash
# GitHub Copilot CLI
gh copilot --version 2>/dev/null || echo "copilot-cli: not installed"
# リリースノート: https://github.blog/changelog/ (copilot で検索)

# Codex CLI (OpenAI)
codex --version 2>/dev/null || echo "codex: not installed"
# リリースノート: https://github.com/openai/codex/releases

# Gemini Code Assist: VS Code 拡張 → "Google Cloud Code" → バージョン確認
# リリースノート: https://cloud.google.com/code/docs/vscode/release-notes
```

**現在の確認済みバージョン (2026-04-16)**:

| ツール | バージョン | 状態 |
| --- | --- | --- |
| Claude Code CLI | 2.1.110 | ✅ 最新 |
| GitHub Copilot CLI | — | ❌ 未インストール |
| Codex CLI (OpenAI) | — | ❌ 未インストール |
| Gemini Code Assist | VS Code拡張で確認 | VSCode インスタンスで確認 |

### Step 4: 変更ログ・推奨プロンプトに記録

更新があった場合は本ドキュメント末尾の「変更ログ」に追記し、
影響を受ける推奨プロンプトを更新して git push する (PowerShell版 が担当)。

 --- 

## 新機能追跡ログ（バージョン更新時に追記）

| バージョン | 機能名 | 概要 | 開発フロー組み込み | 担当インスタンス |
| --- | --- | --- | --- | --- |
| **2.1.108** | **`/recap` 🆕 公式 Learning Mode** | セッション開始時に `/recap` → 前セッション作業サマリーを自動生成。**WEB版でも動作** | ✅ 全推奨プロンプト Step 1 に追加済み | 全インスタンス |
| **2.1.108** | **`ENABLE_PROMPT_CACHING_1H` 🆕** | キャッシュTTL を5分→1時間に延長。長いセッションのトークンコスト最適化 | ⚠️ 要設定: ローカル `.env` or shell profile | ローカルインスタンス |
| **2.1.105** | **PreCompact hook 🆕** | コンパクション前にフック実行。`exit 2` でブロック → 記憶消失防止 | ⚠️ 要設定: `.claude/hooks/pre-compact` 追加検討 | 全インスタンス |
| **2.1.105** | **`/proactive` (= `/loop` alias) 🆕** | `/loop` の別名。会話内で反復タスクを起動しやすい | ✅ 利用可能 | 全インスタンス |
| **2.1.110** | **`/tui` フルスクリーンモード 🆕** | フリッカーなし全画面表示。`/focus` で要約ビュー切替 | ⚠️ 任意 | ローカルインスタンス |
| **2.1.110** | **Push notifications 🆕** | Remote Control 設定後、長時間タスク完了をモバイルに通知 | ⚠️ 要設定: Windowsアプリ版 Remote Control | Windowsアプリ版 |
| **2.1.110** | **`/doctor` MCP重複検出 🆕** | 複数スコープで同一MCP定義があると警告 (`f` キーで one-click 修正) | ✅ 毎セッション `/doctor` 実行 (PowerShell版担当) | PowerShell版 |
| **2.1.98** | **Monitor tool 🆕** | バックグラウンドスクリプトのイベントをストリーミング監視 | ✅ GHA 長時間ジョブ監視に活用可 | ローカルインスタンス |
| 2.1.x (2026-04) | **Routines** | Desktop版専用サーバーレス自動化スケジューラ | ✅ 組み込み済み (Windowsアプリ版専任) | Windowsアプリ版 |
| 2.1.x (2026-04) | **Extended Thinking (ultrathink)** | 5段階思考トリガー (`think`〜`ultrathink`) | ✅ 各推奨プロンプトに追加済み | 全インスタンス |
| 2.1.x (2026) | **Adaptive Thinking** | Opus 4.6/Sonnet 4.6 が effort 値に応じて思考量を自動調整 | ✅ WEB版 Opus 4.6 使用に反映済み | 全インスタンス |
| 2.1.x (2026) | **Cross-session Memory** | セッション間でユーザー情報・設計方針を記憶 | ✅ `memory/` + NotebookLM Master Brain で実装済み | 全インスタンス |
| — | *(次のバージョン更新時に追記)* | | | |

 --- 

## Learning Mode — コードベース学習システム

**v2.1.108 で `/recap` コマンドが追加され、公式の Learning Mode が実装された。**
セッション開始時に `/recap` を実行すると前回の作業サマリーが自動生成される。**WEB版でも動作する。**

### `/recap` — 公式 Learning Mode (v2.1.108+)

```
/recap
```

- セッション復帰時に「前回何をしていたか」を即座に把握できる
- 全インスタンス共通で動作 (WEB版 ✅ / ローカル版 ✅)
- 設定: `/config` → `recap` を有効化

### 4層学習アーキテクチャ (更新版)

| 層 | 仕組み | タイミング | WEB版可否 |
| --- | --- | --- | --- |
| **L0: 公式リキャップ** | `/recap` — 前セッション作業サマリーを自動生成 | セッション開始時に手動実行 | ✅ 可 |
| **L1: セッション内リアルタイム** | claude-mem (SQLite + Gemini圧縮) — ツール呼び出しを自動記録 | 自動 (hooks) | ❌ 不可 |
| **L2: セッション間永続** | `memory/` mdファイル — 成功/失敗パターン・プロジェクト状態 | `/wrap-up` 時 | ❌ 不可 (GitHub MCP経由で参照可) |
| **L3: プロジェクト横断深層** | NotebookLM Master Brain — アーキテクチャ決定・競合調査 | `/wrap-up` 時に source add | ❌ 不可 |

### セッション開始時の「Learning Mode」手順 (全インスタンス共通)

```bash
# Step 0: [全インスタンス共通] /recap で前セッションのサマリーを確認
/recap

# Step 1: memory/MEMORY.md を読んで前回の成功パターン・禁止事項を確認
# (CLAUDE.md の system-reminder で自動ロードされる)

# Step 2: git log で直近の変更を把握 (別インスタンスの作業を把握) ← ローカルのみ
git log --oneline -5

# Step 3: 作業ファイルのコンテキストを読む (ローカル: 3ファイル未満なら直接Read/3以上はNotebookLM)
# ローカル: notebooklm use jibun-master-brain && notebooklm ask "今日の作業コンテキスト"
# WEB版: GitHub MCP → list_commits で直近コミットを確認

# Step 4: MEMORY.md の pending タスクを確認して今日の作業を決定
```

### Learning Mode でのモデル活用指針

| 判断の種類 | 推奨モデル | 推奨思考レベル |
| --- | --- | --- |
| 定型実装 (lint修正・minor bug fix) | Sonnet 4.6 | なし (デフォルト) |
| 新機能設計・EF実装 | Sonnet 4.6 | `think deeply` |
| アーキテクチャ判断・大規模リファクタ | Opus 4.6 | `ultrathink` |
| 競合調査・戦略判断 (WEB版向け) | **Opus 4.6** | `ultrathink` |
| NotebookLM連携 (ローカル版) | Sonnet 4.6 | — (NotebookLMが重い処理を担当) |
| `/recap` 後の方針決定 | Sonnet 4.6 | `think` | |

 --- 

## インスタンス制約カタログ（確認済み）

### Claude Code VSCode版

| 機能 | 状態 | 確認日 | 備考 |
| --- | --- | --- | --- |
| ローカルCLI実行 | ✅ 可 | 2026-04-16 | `flutter analyze`, `deno lint`, `gh`, `git` 全て可 |
| notebooklm CLI | ✅ 可 | 2026-04-16 | Rule 21 対応済み |
| Playwright MCP | ✅ 可 | 2026-04-16 | `.mcp.json` 設定済み |
| Figma MCP | ✅ 可 | 2026-04-16 | Rule 19 で活用 |
| GitHub MCP | ✅ 可 | 2026-04-16 | PR作成に活用 |
| Hooks | ✅ 可 | 2026-04-16 | `.claude/hooks/` 設定済み |
| Skills | ✅ 可 | 2026-04-16 | `~/.claude/skills/` |
| flutter analyze | ✅ 可 | 2026-04-16 | 毎コミット前に必須 |
| deno lint | ✅ 可 | 2026-04-16 | EF変更後に必須 |
| Routines | ❌ 不可 | 2026-04-16 | Desktop専用機能 |
| デフォルトモデル | Sonnet 4.6 | — | |

### Claude Code Windowsアプリ版 (Desktop)

| 機能 | 状態 | 確認日 | 備考 |
| --- | --- | --- | --- |
| ローカルCLI実行 | ✅ 可 | 2026-04-16 | Windowsパス規則あり |
| PYTHONUTF8=1 | ✅ 必須 | 2026-04-16 | 日本語ファイル編集時に常に付加 |
| notebooklm CLI | ✅ 可 | 2026-04-16 | |
| Routines | ✅ **利用可能** | 2026-04-16 | **Desktop版専用！ 積極活用推奨** |
| `.github/workflows/` 直接編集 | ❌ 禁止 | — | PowerShell版の担当 |
| デフォルトモデル | Sonnet 4.6 | — | |

### Claude Code PowerShell版 (Windows Terminal)

| 機能 | 状態 | 確認日 | 備考 |
| --- | --- | --- | --- |
| ローカルCLI実行 | ✅ 可 | 2026-04-16 | PowerShell構文注意 |
| gh CLI | ✅ 可 | 2026-04-16 | `.github/workflows/` 編集の主担当 |
| deno lint/test | ✅ 可 | 2026-04-16 | |
| notebooklm CLI | ✅ 可 | 2026-04-16 | |
| Routines | ❌ 不可 | 2026-04-16 | ターミナル版、Desktop不可 |
| デフォルトモデル | Sonnet 4.6 | — | |

### Claude Code WEB版 (claude.ai/code) ← **制約多数・要確認**

> WEB版の制約はバージョン更新で解消される場合あり。毎セッション開始時に確認して更新する。

**確認済み制約一覧** (2026-04-16 調査):

| 機能 | 状態 | 確認日 | 代替手段 |
| --- | --- | --- | --- |
| notebooklm CLI | ❌ **不可** | 2026-04-16 | WebSearch + WebFetch で直接リサーチ |
| flutter analyze | ❌ **不可** | 2026-04-16 | コード読んで静的チェックのみ |
| deno lint | ❌ **不可** | 2026-04-16 | VSCode版に依頼 (cross-instance-pr) |
| gh CLI | ❌ **不可** | 2026-04-16 | **GitHub MCP** を使用 |
| git CLI | ❌ **不可** | 2026-04-16 | **GitHub MCP** (push_files 等) |
| ローカルファイルシステム | ❌ **不可** | 2026-04-16 | GitHub リポジトリ経由のみ |
| ローカルHooks | ❌ **不可** | 2026-04-16 | — |
| Routines | ❌ **不可** | 2026-04-16 | Windowsアプリ版が担当 |
| WebSearch | ✅ **可** | 2026-04-16 | Deep Research の代替として活用 |
| WebFetch | ✅ **可** | 2026-04-16 | URL調査・競合分析に活用 |
| GitHub MCP | ✅ **可** | 2026-04-16 | PR作成・Issue管理・コードレビュー |
| Playwright MCP | ⚠️ 要確認 | — | MCP設定が共有されている場合のみ可 |
| Skills (スラッシュコマンド) | ⚠️ 一部制限 | 2026-04-16 | 一部未対応あり |
| `--teleport` CLI→Web | ❌ **不可** | 2026-04-16 | 逆方向 (Web→CLI) は可 |
| デフォルトモデル | **Opus 4.6** | — | CLI不可の分、思考力で補完 |

**WEB版の役割 (制約を踏まえた最適分担)**:
- WebSearch/WebFetch での AI プロバイダー調査・競合分析
- GitHub MCP 経由の PR コードレビュー・Issue 管理
- ブログ英語版生成・品質レビュー
- Opus 4.6 + ultrathink でのアーキテクチャレビュー (実行不要の純粋推論タスク)
- `docs/research/` へのリサーチ成果物保存 (GitHub MCP 経由)

 --- 

## モード・モデル指定ガイド

### 利用可能モデル (2026-04-16 時点)

| モデルID | 用途 | context | 出力上限 | 特徴 |
| --- | --- | --- | --- | --- |
| `claude-opus-4-6` | 複雑な設計判断・競合調査 | 1M tokens | 128K | 最高品質、コスト高 |
| `claude-sonnet-4-6` | **日常の実装 (デフォルト推奨)** | 1M tokens | 64K | バランス型 |
| `claude-haiku-4-5-20251001` | 定型ルーティン・クイックチェック | 200K tokens | 8K | 高速・低コスト |

### 拡張思考 (Extended Thinking) トリガー

| キーワード | 思考レベル | 推奨使用シーン |
| --- | --- | --- |
| *(なし)* | デフォルト | lint 修正・定型 edit |
| `think` | Lv.1 | 設計確認・方針チェック |
| `think deeply` | Lv.2 | 新機能設計・中程度の判断 |
| `think harder` | Lv.3 | 複雑バグ・パフォーマンス問題 |
| `think very hard` | Lv.4 | アーキテクチャ設計・大規模リファクタ |
| `ultrathink` | Lv.5 (最大) | 全体設計・競合戦略・クリティカルな判断 |

### `/fast` モード

`/fast` コマンドで Opus 4.6 の **出力速度を向上** させる。モデルは変わらない。
定型パッチ・lint fix など応答速度が重要な場面で活用。

### インスタンス別モード推奨

| インスタンス | 通常タスク | 複雑タスク | 備考 |
| --- | --- | --- | --- |
| **VSCode版** | Sonnet 4.6 + `think deeply` | Sonnet 4.6 + `ultrathink` | 新ページ・EF実装 |
| **VSCode版 (定型)** | Sonnet 4.6 + `/fast` | — | lint fix・token置換 |
| **Windowsアプリ版** | Sonnet 4.6 | Sonnet 4.6 + `think` | docs更新・provider追加 |
| **PowerShell版** | Sonnet 4.6 + `think deeply` | Opus 4.6 + `ultrathink` | CI/CD設計 |
| **WEB版** | **Opus 4.6** + `think deeply` | **Opus 4.6** + `ultrathink` | CLI不可の分、思考力で補完 |

 --- 

## インスタンス別 役割分担 (確定版 2026-04-16)

### VSCode版 (Claude Code CLI + VS Code)

| 項目 | 内容 |
| --- | --- |
| **Write 権限** | `lib/` (Flutter UI) + `supabase/functions/` + `docs/DESIGN.md` |
| **専任ルール** | Rule 8/16 (表示チェック) / Rule 19 (UI改善) / Rule 12 (Design Toolchain) |
| **必須チェック** | `flutter analyze 0エラー` + `deno lint 0エラー` |
| **モデル** | Sonnet 4.6 (通常) / Opus 4.6 + ultrathink (アーキテクチャ判断) |
| **禁止** | `docs/` (DESIGN.md除く) · `.github/` の直接編集 |

### Windowsアプリ版 (Claude Code Desktop)

| 項目 | 内容 |
| --- | --- |
| **Write 権限** | `docs/` (DESIGN.md除く) + `supabase/migrations/` |
| **専任ルール** | Rule 10 (docs全件分析) / AI大学プロバイダー追加 / **Routines 設定管理** |
| **Routines 上限** | Max: 15回/日 / Pro: 5回/日 |
| **モデル** | Sonnet 4.6 (通常) / Opus 4.6 + think deeply (設計判断) |
| **禁止** | `lib/` · `supabase/functions/` · `.github/` の編集 |

### PowerShell版 (Claude Code CLI + Windows Terminal)

| 項目 | 内容 |
| --- | --- |
| **Write 権限** | `.github/workflows/` + `docs/MULTI_INSTANCE_COORDINATION.md` + `docs/INSTANCE_CONFIG.md` |
| **専任ルール** | Rule 17 (CI/CD最適化) / バージョン確認 / インスタンス設定管理 (本ドキュメント) |
| **モデル** | Sonnet 4.6 (通常) / Opus 4.6 + think deeply (ワークフロー設計) |
| **禁止** | `lib/` · `supabase/functions/` |

### WEB版 (claude.ai/code)

| 項目 | 内容 |
| --- | --- |
| **Write 権限** | `docs/blog-drafts/` + `docs/research/` (GitHub MCP 経由) |
| **専任ルール** | WebSearch/WebFetch 直接リサーチ / GitHub MCP PR・Issue管理 |
| **モデル** | **Opus 4.6** (CLIが使えない分、思考力で補完) |
| **制約** | notebooklm・flutter analyze・deno lint・gh・git CLI 全て不可 |
| **代替** | GitHub MCP (gh代替) / WebSearch+WebFetch (notebooklm代替) |
| **禁止** | CLI依存タスク全般 |

 --- 

## フォールバックAI詳細設定 (Claude レート制限到達時のみ)

> **通常運用**: Claude Code 4インスタンスのみ使用。
> フォールバックは `quota-monitor.yml` が $50超過/429 を検知した場合のみ発動。

### GitHub Copilot (常時 PR 自動レビュー + フォールバック)

| 設定項目 | 推奨値 | 備考 |
| --- | --- | --- |
| モデル選択 | **Auto** | GPT-4.1 / GPT-5 mini / Claude Haiku から自動最適化 |
| Agent Mode | ✅ 有効化 | 複数ファイル横断タスク対応 |
| PR Review モデル | Claude Sonnet 4.6 or GPT-4.1 | GitHub Copilot モデル選択画面から設定 |
| インストール | VS Code: "GitHub Copilot" + "GitHub Copilot Chat" | 両方インストール推奨 |
| ファイル対象 | `.yml` / `.sql` / `.md` | Claude 429時のフォールバック |
| 常時用途 | PR 自動レビュー (`claude-agent-review.yml` の補完) | |
| バージョン確認 | `gh copilot --version` | ❌ 2026-04-16 時点で未インストール |
| リリースノート | https://github.blog/changelog/ (copilot で検索) | |

**インストール手順** (未インストールの場合):
```bash
gh extension install github/gh-copilot
```

### CODEX CLI (OpenAI) フォールバック

| 設定項目 | 推奨値 | 備考 |
| --- | --- | --- |
| 主な用途 | `.py` / `.ts` ファイル | Python スクリプト・EF TypeScript draft |
| モデル | GPT-5.2-Codex (デフォルト) | コード特化 |
| 発動条件 | Claude 429 / $50超過 のみ | 通常は不使用 |
| バージョン確認 | `codex --version` | ❌ 2026-04-16 時点で未インストール |
| リリースノート | https://github.com/openai/codex/releases | |

**インストール手順** (未インストールの場合):
```bash
npm install -g @openai/codex
```

**CODEX 使用時の注意**:
- プロジェクトコンテキストが限定的 → 編集対象ファイル + 関連型定義を手動貼り付け
- CLAUDE.md のルールを冒頭に要約して渡す
- 完了後は必ず `flutter analyze` / `deno lint` で Claude Code インスタンスが検証

### Gemini Code Assist フォールバック

| 設定項目 | 推奨値 | 備考 |
| --- | --- | --- |
| 主な用途 | `.dart` ファイル IDE 補完 | Flutter/Dart に最適化 (Google製) |
| モデル | Gemini 2.5 Pro (VS Code 拡張設定) | |
| 発動条件 | Claude 429 / $50超過 のみ | |
| インストール | VS Code 拡張: "Google Cloud Code" | VSCode版のみ |
| バージョン確認 | VS Code Extensions パネルで確認 | |
| リリースノート | https://cloud.google.com/code/docs/vscode/release-notes | |

 --- 

## Routines 詳細設定 (Windowsアプリ版専任)

### 概要

Routines は Claude Code Desktop の自動化機能。**PC をオフにしても Anthropic クラウドで実行**。

```
Routine = プロンプト + リポジトリ + コネクター + トリガー
```

**トリガー**: スケジュール (毎時/毎日/毎週) / API 呼び出し / GitHub イベント

**使用上限**:
- Pro: 5回/日
- Max: 15回/日
- Team/Enterprise: 25回/日

### GitHub Actions → Routines 移行候補

| GHA ワークフロー | 移行可否 | 理由 |
| --- | --- | --- |
| `ai-university-update.yml` (2時間毎) | ✅ 移行推奨 | NotebookLM連携が主処理。Routine化でGHA削減 |
| `blog-draft.yml` (毎日) | ✅ 移行推奨 | 毎日スケジュールに最適 |
| `competitor-monitoring.yml` (毎日) | ✅ 移行推奨 | WebSearch/WebFetch Routine に最適 |
| `claude-agent-review.yml` | ✅ GitHub イベントトリガーに移行可 | PR作成時に自動起動 |
| `infra-health-check.yml` (毎時) | ⚠️ 要注意 | 毎時15回超 = Max上限超過の可能性 |
| `deploy-prod.yml` | ❌ 移行不可 | Supabase/Firebase デプロイ権限が必要 |

**→ Windowsアプリ版が次セッションで Routines 設定を実施すること**

 --- 

## 各インスタンス推奨プロンプト (毎セッション冒頭に使用)

> 制約が変化した場合はこのセクションを更新する (PowerShell版 が担当)。

### VSCode版 推奨プロンプト

```
このインスタンスはVSCode版です。担当: lib/ + supabase/functions/

【Step 0: /recap — 公式 Learning Mode】
/recap
→ 前セッションのサマリーを確認してから作業開始

【Step 1: バージョン確認 + /doctor】
claude --version && npm show @anthropic-ai/claude-code dist-tags.latest
/doctor
→ バージョンが古ければ: npm update -g @anthropic-ai/claude-code
→ 更新あり: https://github.com/anthropics/claude-code/releases でリリースノート確認
→ 新機能 → docs/INSTANCE_CONFIG.md の「新機能追跡ログ」に追記 (cross-instance-pr 経由で PowerShell版に依頼)

【Step 2: Learning Mode — コンテキスト確認】
git log --oneline -5
# MEMORY.md は system-reminder で自動ロード済み
# 3ファイル以上参照する場合: notebooklm use jibun-master-brain → notebooklm ask "今日の作業コンテキスト"

【Step 3: 今日のタスク候補 (優先度順)】
1. Rule 8: Playwright で https://my-web-app-b67f4.web.app/ を確認 → コンソールエラー修正
2. Rule 19: design-skills サブエージェント起動 → 本日のUI改善1ページ実施
3. cross-instance-prs/ の pending 確認 → 処理
4. AI大学v2: docs/superpowers/plans/ の続き

【推奨思考モード】
新ページ実装・EF設計: "think deeply してから実装してください"
アーキテクチャ全体: "ultrathink して最適な実装を提案してください"
定型修正: /fast モードで高速処理

【キャッシュ最適化 (任意)】
# 1時間キャッシュTTL を有効化 (長時間セッション向け)
export ENABLE_PROMPT_CACHING_1H=1

【フォールバックAI (Claude 429時のみ)】
.dart → Gemini Code Assist (VS Code: Cmd+Shift+P → "Gemini: Start Chat")
.py/.ts → codex (npm install -g @openai/codex でインストール後)
```

### Windowsアプリ版 推奨プロンプト

```
このインスタンスはWindowsアプリ版 (Claude Code Desktop) です。担当: docs/ + supabase/migrations/

【Step 0: /recap — 公式 Learning Mode】
/recap
→ 前セッションのサマリーを確認してから作業開始

【Step 1: バージョン確認 + Routines確認】
claude --version && npm show @anthropic-ai/claude-code dist-tags.latest
→ バージョンが古ければ: npm update -g @anthropic-ai/claude-code
→ 更新あり: リリースノート確認 → 制約解消があれば INSTANCE_CONFIG.md を更新
# Routines: Desktop アプリ → Routines タブで確認 (上限: Pro 5回/日 / Max 15回/日)
# Push notifications: Desktop → Remote Control → Enable push notifications (v2.1.110+)

【Step 2: Learning Mode — コンテキスト確認】
git log --oneline -5
PYTHONUTF8=1 notebooklm use jibun-master-brain
notebooklm ask "直近セッションの変更内容と今日取り組むべき優先タスクは？"

【Step 3: 今日のタスク候補 (優先度順)】
1. Routines 設定: ai-university-update / blog-draft を Routine 化できるか検討
   → Desktop: Routines タブ → New Routine → スケジュール設定
2. /ai-university-add-provider で新規プロバイダー候補を評価・追加 (PYTHONUTF8=1 必須)
3. Rule 10: docs/ 全件分析 → 鮮度切れ修正
4. supabase/migrations/ で AI大学v2テーブル作成

【推奨思考モード】
Routines設計: "think about the best Routine structure for ai-university-update"
provider追加 + docs修正: 通常モード (PYTHONUTF8=1 必須)
設計判断: "think deeply"

【フォールバックAI (Claude 429時のみ)】
.dart → Gemini Code Assist (Desktop版 VS Code 拡張)
.py/.ts → codex
```

### PowerShell版 推奨プロンプト

```
このインスタンスはPowerShell版です。担当: .github/workflows/ + INSTANCE_CONFIG.md

【Step 0: /recap — 公式 Learning Mode】
/recap
→ 前セッションのサマリーを確認してから作業開始

【Step 1: バージョン確認 + /doctor + フォールバックAI確認】
claude --version; npm show @anthropic-ai/claude-code dist-tags.latest
/doctor
→ バージョン更新あり: npm update -g @anthropic-ai/claude-code
→ リリースノート確認: WebFetch https://github.com/anthropics/claude-code/releases
→ 新機能 → 新機能追跡ログ更新 → 制約解消 → 役割分担見直し → 推奨プロンプト更新
gh copilot --version 2>$null; codex --version 2>$null

【Step 2: Learning Mode — コンテキスト確認】
git log --oneline -5

【Step 3: 今日のタスク候補 (優先度順)】
1. Rule 17: GH Actions 全ワークフロー健全確認
   gh run list --limit 20 --json name,status,conclusion | ConvertFrom-Json
2. docs/INSTANCE_CONFIG.md 更新 (制約変化・バージョン変更・推奨プロンプト更新)
3. T-1: 未投稿ブログのディスパッチ
   gh workflow run blog-publish.yml -f draft_path="docs/blog-drafts/YYYY-MM-DD.md" -f platforms="qiita,devto"
4. cross-instance-prs/ の pending 確認・マージ依頼処理

【推奨思考モード】
CI/CDワークフロー設計: "think deeply してから実装"
Rule 17定期チェック: 通常モード
INSTANCE_CONFIG.md 更新: 通常モード

【フォールバックAI (Claude 429時のみ)】
.yml/.sql/.md → GitHub Copilot (gh extension install github/gh-copilot)
.py/.ts → codex
```

### WEB版 推奨プロンプト

```
このインスタンスはWEB版Claude Code (claude.ai/code) です。
モデル: Opus 4.6 (CLI不可の分、思考力で補完)

【制約サマリー (2026-04-16 確認済み)】
❌ 使用不可: notebooklm CLI / flutter analyze / deno lint / gh CLI / git CLI / ローカルFS / Hooks / Routines
✅ 使用可能: /recap / WebSearch / WebFetch / GitHub MCP / Playwright MCP / Skills / Opus 4.6

【Step 0: /recap — 公式 Learning Mode (WEB版でも動作!)】
/recap
→ 前セッションのサマリーを確認。WEB版唯一の公式セッション記憶復元手段

【Step 1: バージョン・制約変更確認】
WebFetch: https://github.com/anthropics/claude-code/releases
→ WEB版で新機能が利用可能になっていないか確認
→ 制約解消があれば GitHub MCP push_files で docs/INSTANCE_CONFIG.md を更新

【Step 2: Learning Mode — 並行インスタンス確認】
GitHub MCP: list_commits({owner:"kanta13jp1", repo:"my_web_app", perPage:5})
→ 直近5コミットで VSCode版・PS版・Windowsアプリ版の作業を把握

【Step 3: 今日のタスク候補 (優先度順)】
1. ultrathink でアーキテクチャレビュー (実行不要の純粋推論タスク)
   → GitHub MCP で最新コードを確認 → 改善提案を docs/research/ に保存
2. WebSearch で AI大学新規プロバイダー候補を3軸評価
   → GitHub MCP push_files で docs/research/YYYY-MM-DD-providers.md に保存
3. GitHub MCP でオープンPRのコードレビュー
   → list_pull_requests → pull_request_read → pull_request_review_write
4. 競合21社最新動向調査 → docs/research/YYYY-MM-DD-competitors.md に保存
5. ブログ英語版の品質レビュー・改善 (GitH MCP で draft 確認 → 改善提案)

【モデル設定】
このセッションは Opus 4.6 を使用してください。
複雑な分析・アーキテクチャレビューには必ず "ultrathink" を含めてください。

【GitHub MCP 使用チートシート】
コミット確認: list_commits({owner:"kanta13jp1", repo:"my_web_app", perPage:5})
PR一覧:       list_pull_requests({state:"open"})
PR確認:       pull_request_read({pullRequestNumber: 123})
レビュー:     pull_request_review_write({pullRequestNumber:123, body:"...", event:"COMMENT"})
ファイル保存: push_files({owner:"kanta13jp1", repo:"my_web_app", branch:"main",
              files:[{path:"docs/research/YYYY.md", content:"..."}], message:"research: ..."})
Issue作成:    issue_write({owner:"kanta13jp1", repo:"my_web_app", title:"...", body:"..."})

【制約発見時の記録手順】
1. GitHub MCP push_files で docs/INSTANCE_CONFIG.md を更新
2. Issue 作成: タイトル "[制約変更] WEB版で XXX が [使用可/不可] になった"
   → PowerShell版が次セッションで INSTANCE_CONFIG.md の role 分担を見直す
```

### CODEX CLI 使用時プロンプト (Claude 429時のフォールバック)

> **インストール**: `npm install -g @openai/codex`
> **バージョン確認**: `codex --version`
> **リリースノート**: https://github.com/openai/codex/releases
> **対象ファイル**: `.py` / `.ts` のみ。`.dart` は Gemini Code Assist を使用

```
Claude が 429 エラーのため CODEX CLI で続行します。

【プロジェクトコンテキスト (必ず冒頭に貼り付け)】
---CLAUDE.md 要約---
プロジェクト: Flutter Web + Supabase (自分株式会社)
技術: Flutter (Dart) + Deno Edge Functions (TypeScript) + Python スクリプト
ルール: flutter analyze 0エラー / deno lint 0エラー / ダミーデータ禁止 / EF 50本以下
 --- 

【対象ファイルの現在の内容】
[ここにファイル内容を貼り付け — 関連型定義・import も含める]

【タスク】
[具体的な実装内容]

【完了後の必須確認】
1. VSCode版 Claude Code で flutter analyze (Dart変更時)
2. VSCode版 Claude Code で deno lint (TypeScript EF変更時)
3. 実装をClaude Code にコミット依頼
```

### GitHub Copilot 使用時プロンプト (PR Review + フォールバック)

> **インストール**: `gh extension install github/gh-copilot`
> **バージョン確認**: `gh copilot --version`
> **リリースノート**: https://github.blog/changelog/ (copilot で検索)
> **推奨モデル**: Auto (GPT-4.1 / Claude Sonnet 4.6 自動選択) または Claude Sonnet 4.6 固定

```
# PR自動レビュー (常時稼働 — claude-agent-review.yml の補完として)
以下の観点でこのPRをレビューしてください:
- セキュリティ: SQL injection / XSS / 認証漏れ / シークレットハードコーディング
- パフォーマンス: N+1クエリ / 不要な再レンダリング / 重いウィジェットのキャッシュ漏れ
- Lint: flutter analyze / deno lint エラーの可能性
- CLAUDE.md ルール違反: ダミーデータ使用 / EF 50本超過 / ダミーデータ使用

モデル選択: Auto
Agent Mode: 有効化推奨 (複数ファイル横断レビュー)

 --- 
# フォールバック (Claude 429時 — .yml/.sql/.md ファイル)
対象: [ファイルパス]
タスク: [変更内容]
プロジェクトコンテキスト: Flutter Web + Supabase / GitHub Actions / PostgreSQL
```

### Gemini Code Assist 使用時プロンプト (Flutter/Dart + フォールバック)

> **インストール**: VS Code 拡張 "Google Cloud Code" または "Gemini Code Assist"
> **バージョン確認**: VS Code Extensions パネルで確認
> **リリースノート**: https://cloud.google.com/code/docs/vscode/release-notes
> **推奨モデル**: Gemini 2.5 Pro (VS Code 拡張設定から変更可)
> **対象ファイル**: `.dart` (Flutter/Dart に最適化)

```
# 通常使用: Claude Code と並行してIDE補完として利用
# VS Code: Cmd+Shift+P → "Gemini Code Assist: Start Chat"

# フォールバック (Claude 429時 — .dart ファイル)
プロジェクト: 自分株式会社 Flutter Web アプリ
技術スタック: Flutter Web (Dart) + Supabase

【プロジェクトルール (必ず確認)】
- flutter analyze 0エラー必須
- Theme.of(context) + ThemeService を使用 (直接 Color() 禁止)
- Supabase リアルデータのみ (ダミーデータ禁止)
- docs/DESIGN.md のカラートークン使用

【現在のファイル】
[lib/ 内のファイル内容を貼り付け]

【タスク】
[具体的な実装内容]

【完了後】
1. flutter analyze でエラーを確認
2. Claude Code (VSCode版) にコミット依頼
```

 --- 

## 制約発見・解消時の更新手順

セッション中に新しい制約・制約解消を発見したら即座に記録する:

### 1. memory/ に記録 (発見インスタンスが即座に実施)

```bash
# 制約発見
memory/feedback_correction_YYYYMMDD_[instance].md

# 制約解消
memory/feedback_success_YYYYMMDD_[instance].md
```

### 2. 本ドキュメントを更新

- 制約カタログ表の該当行を更新: `✅ 可 (YYYY-MM-DD 解消)` または `❌ 不可 (YYYY-MM-DD 確認)`
- 推奨プロンプトから回避策コメントを削除 or 追加

### 3. 役割分担を見直す

制約解消により役割変更が必要な場合:

```markdown
# cross-instance-prs/YYYYMMDD_role_update.md を作成して PowerShell版に通知
```

### 4. COMPRESSED_PROMPT_V3.md の分担表を更新

PowerShell版 が担当 (緊急時は任意インスタンスが cross-instance-pr 経由で依頼)

 --- 

## 制約 Kaizen ループ (毎セッション)

```
セッション開始
    ↓
/recap + /doctor + バージョン確認
    ↓
制約カタログと現実を比較
    ├── 制約が増えた → 制約カタログ更新 → 役割分担見直し → 推奨プロンプト更新
    ├── 制約が解消した → 制約カタログ更新 → 役割拡大 → 推奨プロンプト更新
    └── 変化なし → そのまま作業へ
    ↓
作業中に制約を新発見
    → memory/feedback_correction_YYYYMMDD_[instance].md に即記録
    → Issue 作成: "[制約変更] XXX インスタンスで YYY が ZZZ になった"
    → PowerShell版 が次セッションで INSTANCE_CONFIG.md を更新
    ↓
セッション終了: /wrap-up
    → 制約変化・新機能発見 を memory/ に保存
```

 --- 

## 変更ログ

| 日付 | 変更内容 | 担当 |
| --- | --- | --- |
| 2026-04-16 | 初版作成。WEB版制約確認・Routines追加・モデル設定・推奨プロンプト追加 | VSCode版#79 |
| 2026-04-16 | 大幅改訂。WEB版制約詳細化・Learning Mode追加・フォールバックAI詳細・全インスタンス推奨プロンプト更新・制約解消フロー追加 | PowerShell版 |
| 2026-04-16 | v2.1.110 対応。/recap公式Learning Mode追加・新機能追跡ログ(v2.1.97-110)・全推奨プロンプトに/recap追加・Gemini Code Assist推奨プロンプト追加・制約KaizenループDoc追加・playwright MCP重複修正記録 | PowerShell版 |
