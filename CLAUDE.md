# 自分株式会社 — Claude Code 設定

## プロジェクト概要

Flutter Web + Supabase のAI統合ライフマネジメントアプリ。
Notion・Evernote・MoneyForward・Slack・X・Amazon など21競合の機能を1つに統合。
本番URL: <https://my-web-app-b67f4.web.app/>

### 技術スタック

- **フロントエンド**: Flutter Web (Dart)
- **バックエンド**: Supabase (PostgreSQL + Edge Functions / Deno)
- **ホスティング**: Firebase Hosting
- **CI/CD**: GitHub Actions (push to main → 自動デプロイ)
- **メール**: Resend API
- **永続メモリ**: claude-mem (SQLite + Gemini圧縮) + 自作auto-capture hooks

### 競合21社

notion, evernote, moneyforward, slack, chatwork, x, animaworks,
claude-code, codex, netkeiba, openclaw, claude-cowork, jobcan, amazon,
google, microsoft, discord, line, facebook, liven, github

---

## デザインシステム参照 (UI生成時に必ず参照)

**毎セッション必須ツールチェーン** (Rule 19+20): `Claude Code` × `Nanobanana API` × `Figma MCP` × `AIDesigner MCP` × `design-skills` サブエージェント × `docs/DESIGN.md` を組み合わせて UI を改善する。加えて (Rule 20) **Playwright / Context7 / GitHub MCP / Magic / Code Review / Superpowers** の6MCPを積極活用する。詳細は `.github/COMPRESSED_PROMPT_V3.md` Rule 19/20 参照。

UIコンポーネントを新規作成・修正する際は、以下のファイルを参照してデザイントークンを適用すること:

- **自分株式会社デザイントークン**: `docs/DESIGN.md`
- **日本語UIリファレンス (awesome-design-md-jp)**:
  - `docs/design-systems/note/DESIGN.md` — note.com (teal #5ac8b8, line-height 2.0, 620px幅)
  - `docs/design-systems/freee/DESIGN.md` — freee (blue #2864f0, 4pxグリッド, システムフォント)
  - `docs/design-systems/smarthr/DESIGN.md` — SmartHR (blue #0077c7, Yu Gothicマッピング, 8pxグリッド)
  - `docs/design-systems/apple/DESIGN.md` — Apple JP (SF Pro JP, ピルボタン, #1d1d1f)
  - `docs/design-systems/wired/DESIGN.md` — WIRED.jp (黒×黄, body全体にpalt, 角張りデザイン)
  - `docs/design-systems/template/DESIGN.md` — 新サービス追加用テンプレート

**重要ルール**:

- 日本語本文の `letter-spacing` は原則 0（見出しのみ使用可）
- 本文の `line-height` は最低 1.5（推奨 1.7〜2.0）
- Yu Gothic を使う場合は `@font-face` で Medium→400 マッピングを使う
- `font-feature-settings: "palt" 1` は見出し・ナビのみ適用（本文には非適用が原則）

---

## 開発ルール (常に適用)

1. **`flutter analyze` を常に0エラー維持** — コード変更後は必ずチェック
2. **`deno lint` を常に0エラー維持** — Edge Function 変更後は必ずチェック
3. **`docs/GROWTH_STRATEGY_ROADMAP.md` を毎回更新** — 変更内容をセッション記録に追記
4. **ダミーデータ禁止** — 必ずSupabaseのリアルデータを使用
5. **Edge Functionファースト** — 複雑なロジックはバックエンドに移動
6. **シンプルさ優先** — 明示的に依頼されていない機能は追加しない
7. **EFハードキャップ: 50本以下 (Tier1/Tier2廃止)** — `deploy-prod.yml` にデプロイするEFは常に50本以下に維持する。Tier1/Tier2の分類は廃止。全てのEFはデプロイ済みとして管理する。新規機能追加時は必ず以下のいずれかの方法で対応すること: (a) **既存hubへのaction追加** (最優先 — EF数が増えない), (b) **既存EFのaction統合** (2本以上をhubに合流してスロット確保), (c) 新規EF作成は既存EFを統合して50本以下を維持した場合のみ許可。現在のhub構成: `core-hub`・`growth-hub`・`ai-hub`・`admin-hub`・`app-hub`・`schedule-hub`・`tools-hub`・`media-hub`・`enterprise-hub`・`social-commerce-hub`・`lifestyle-hub` + standalone 4本 = 計15本
8. **毎セッション: Web/モバイル表示チェック（必須）** — セッション開始時または実装後に、本番URL `https://my-web-app-b67f4.web.app/` の主要ページをWebとモバイル両方の表示で確認し、レイアウト崩れ・テキスト切れ・ボタン重複・スクロール不具合を発見して修正する。特にホーム画面・AI大学・LP・ランキングページを重点確認する
9. **毎セッション: GitHub Actions ワークフロー最適化チェック（必須）** — `.github/workflows/` を見直し、以下を確認・修正する: (a) 常にエラーになるステップ・ジョブを削除または無効化、(b) 同一ジョブの二重起動（push + workflow_call 競合など）を防ぐ、(c) timeout-minutes が実態と合っているか、(d) `continue-on-error: true` の乱用がデプロイ遅延を招いていないか。修正後は `docs/GROWTH_STRATEGY_ROADMAP.md` にセッション記録として追記する
10. **毎セッション: `docs/` 戦略ドキュメント全件分析・開発計画反映** — 以下の常設ドキュメントを読み、(a) 矛盾・鮮度切れを修正、(b) 未着手タスク・ブロッカーを `COMPRESSED_PROMPT_V3.md` の「実装待ち」セクションに追記する。
   - 対象: `docs/CICD_SETUP_GUIDE.md`, `docs/CONTRIBUTING.md`, `docs/MULTI_INSTANCE_COORDINATION.md`, `docs/README.md`, `docs/DESIGN_TOOLING_SETUP.md`, `docs/technical/*.md`, `docs/roadmaps/*.md`, `docs/user-docs/*.md`
   - 除外 (自動生成・アーカイブ): `docs/daily-reports/`, `docs/cs-notes/`, `docs/blog-drafts/`, `docs/blog/`, `docs/competitor-reports/`, `docs/incident-reports/`, `docs/security-audit/`, `docs/archive/`, `docs/email-templates/`, `docs/weekly-drafts/`
11. **毎セッション: AI大学コンテンツ → 開発ワークフロー反映（必須）** — `ai_university_content` テーブルの最新 `news` カテゴリ（または NotebookLM に蓄積した AI ニュース）を開発に活かす。以下の観点で評価し、有望なものは `GROWTH_STRATEGY_ROADMAP.md` の次回優先タスクに追記する:
   - **モデルアップグレード**: 新モデル (例: Gemini 2.5 / Claude 4 / GPT-5) が利用可能になったら既存 EF (`ai-assistant`, `daily-judgment`, `gemini-election-analysis` など) のモデルパラメータを更新
   - **新 API 機能の取り込み**: 音声生成 (Voxtral) / リアルタイム検索 (Perplexity Sonar) / 画像生成など新機能を既存機能に統合できないか検討
   - **コスト最適化**: より安価・高速なモデルが登場したらバッチ処理 EF (`batch_analysis.py`, `competitor-monitoring` など) での採用を検討
   - **差別化機能のヒント**: 競合 AI プロバイダーの新機能からユーザー価値を逆算し、未実装機能のアイデアとして追加
   - **実施手順**: (1) `notebooklm ask "各プロバイダーの最新ニュースから開発に使えそうな機能・APIを抽出して"` → (2) 既存 EF・ページとの接続可能性を評価 → (3) 実装可能なものは即 ROADMAP へ追記 → (4) 今セッションで対応できるものは実装

12. **毎セッション: UI改善ツールチェーン実行（全インスタンス・必須）** — `Claude Code` × `Nanobanana API` × `Figma MCP` × `AIDesigner MCP` × `design-skills` サブエージェント × `docs/DESIGN.md` を毎セッション組み合わせて UI を 1ページ以上改善する。詳細は `.github/COMPRESSED_PROMPT_V3.md` Rule 19 および `docs/DESIGN_TOOLING_SETUP.md`（正式手順書）参照。

   **改善ワークフロー（既存画面改善時）**:
   1. **`design-skills` サブエージェント起動**: 主要ページ (ホーム / AI大学 / LP / ランキング) を `docs/DESIGN.md` (Orange+Indigo ダークテーマ) と照合し、デザイントークン違反・改善点を列挙
   2. **Figma MCP** (`/design-review`): 既存デザインの余白・タイポ・コンポーネント構造を読み「今あるものに合わせる」基準を取得
   3. **AIDesigner MCP** (`/design-component`): Desktop/Mobile 両方で改善案 2〜3 案を生成
   4. **Nanobanana API**: カラーパレット・コンポーネント案を生成してデザイン候補を拡張
   5. **実装**: 採用案を `lib/` に反映 → `flutter analyze 0エラー` → commit

   **制約**: `docs/DESIGN.md` に反する提案は採用しない / `Theme.of(context)` + `ThemeService` を優先 / 日本語本文の `letter-spacing: 0`・`line-height: 1.7〜2.0` を維持

13. **毎セッション: 6 MCPプラグイン活用（Rule 20・必須）** — `.mcp.json` に設定済みの以下6プラグインを積極的に使う。APIキーはローカル設定済み (`.mcp.json` は `.gitignore` 管理、gitに含めない)。

   | プラグイン | 使用タイミング | 主なツール/コマンド |
   | --- | --- | --- |
   | **Playwright** | UI変更後の動作確認・E2Eテスト (Rule 8 自動化) | `playwright_navigate` / `playwright_click` / `playwright_screenshot` |
   | **Context7** | 外部ライブラリ・API使用時 | プロンプトに `use context7` を付けると最新ドキュメント参照・ハルシネーション抑制 |
   | **GitHub MCP** | PR作成・Issue操作 (Rule 9 補完) | `create_pull_request` / `list_issues` / `create_issue` |
   | **Magic (21st.dev)** | UIコンポーネント新規生成 (Rule 12 補完) | `/ui <説明>` でデザイン品質の高いコンポーネントを生成 |
   | **Code Review** | 実装後の自動レビュー | `code_review` ツールでセキュリティ・パフォーマンスを自動チェック |
   | **Superpowers** | 構造化ワークフロー強化 | `superpowers:tdd` / `superpowers:debug` / `superpowers:plan` スキル |

   **活用方針**:
   - Rule 8 (Web/モバイル確認) → **まず Playwright でスクリーンショット自動取得** してから手動確認を補完
   - 外部ライブラリの使い方を調べるとき → `use context7` を先頭に付けて最新仕様を参照
   - PR を作るとき → `gh` CLI の代わりに **GitHub MCP** を使うと会話の流れで直接作成可能
   - 新しいUIウィジェットを作るとき → **Magic MCP** でベースを生成してから `docs/DESIGN.md` トークンを適用
   - 実装が一段落したら → **Code Review MCP** でセキュリティ・品質チェックを自動実行

---

## Multi-AI ワークフロー（毎回必ず実行）

**設計思想**: Claude Code 4インスタンス (VSCode/Windowsアプリ/PowerShell/WEB版) を主軸に、Gemini Code Assist・CODEX・GitHub Copilot を補完役で活用。
「どの処理をどの AI に振るか」を設計することで、月 $20 プランで $200 相当の作業を実現する。
Claude のトークンは「判断・編集・統合」のみに使い、重い分析は Google (NotebookLM/Gemini) に無料で投げる。

### インスタンス別 推奨モデル / 制約表

| インスタンス | 推奨モデル | 推奨モード | 主な制約 |
| --- | --- | --- | --- |
| **VSCode版** | `claude-sonnet-4-6` | 通常 (Flutter解析は深い思考要) | なし |
| **Windowsアプリ版** | `claude-sonnet-4-6` | 通常 + CAVEMAN節約 | なし。`PYTHONUTF8=1` 必須 |
| **PowerShell版** | ルーティン: `claude-haiku-4-5` / 設計: `claude-sonnet-4-6` | `/fast` (定型作業) | なし |
| **WEB版** | `claude-sonnet-4-6` (変更不可の場合あり) | 通常 | `notebooklm` / `flutter analyze` / `deno lint` / ローカルCLI **不可** |

**WEB版代替パターン**:
- `notebooklm ask` → WebSearch で代替
- `flutter analyze` → 実行不可→ VSCode版に cross-instance-pr で検証依頼
- `deno lint` → 実行不可 → EF変更は VSCode版に依頼
- git commit → GitHub MCP (`mcp__plugin_github_github__create_or_update_file`) で代替

### AI振り分け早見表

| タスク | 最適ツール | 理由 |
| --- | --- | --- |
| 行レベル補完 | GitHub Copilot | 最速・ゼロ待機 |
| 5分以内の修正 | Copilot Inline Chat | コンテキスト取得コスト不要 |
| 500行超リファクタリング | Gemini Code Assist | 長コンテキスト強み |
| SQL/アルゴリズム最適化 | OpenAI CODEX | コード特化モデル |
| 設計・戦略・ルール遵守 | Claude Code | Memory + プロジェクト文脈 |
| ブログ・競合リサーチ | Claude Code WEB版 (WebSearch/WebFetch) | ローカルCLI不要・GitHub MCP対応 |
| NotebookLM Deep Research | Windowsアプリ版 (notebooklm CLI) | WEB版は notebooklm 不可 |
| クオータ使用状況確認 | `quota-monitor.yml` Dashboard | Supabase `ai_quota_usage` テーブル |

### マルチエージェント協調パターン (新機能設計時に参照)

新しい自動化・AI機能を設計するとき、以下の5パターンから選ぶ。**最も単純なパターンから始めて、行き詰まったら進化させる。**

| パターン | 採用基準 | このプロジェクトでの実例 |
| --- | --- | --- |
| **Generator-Verifier** | 品質が最重要。評価基準を明文化できる | `claude-agent-review.yml` (PR生成→Claudeレビュー) / `ci-auto-fix.yml` (修正→CI再実行) / `/deep-research` (NotebookLM生成→Claude統合) |
| **Orchestrator-Subagent** | タスク分解が明確。サブタスクが短時間で完結 | `cs-check.yml` (FAQ返信/バグ修正/エスカレーション) / `github-issue-fix.yml` (Issue一覧→1件ずつ処理) / Claude Code Schedule (計画→実行→コミット) |
| **Agent Teams** | 並行独立した長時間タスク。成果物が互いに干渉しない | **4インスタンス並行開発** (VSCode/Windowsアプリ/PowerShell/WEB版) + Gemini Code Assist / CODEX / GitHub Copilot 補完 / `ai-university-update.yml` (60プロバイダー 2時間毎 RSS) + Claude Schedule (4時間毎 NotebookLM Deep Research) |
| **Message Bus** | イベント駆動。エコシステムが成長する | `workflow-failure-handler.yml` (失敗イベント→Issue→`cs-check`) / `feedback-issue-resolved.yml` (Issueクローズ→通知メール) / `edge-function-audit.yml` (EF未接続→Issue→`github-issue-fix`) |
| **Shared State** | エージェントが互いの発見を活用。単一障害点を避けたい | `memory/` + NotebookLM Master Brain (セッション横断知識) / Supabase DB (全EFが読み書き) / `COMPRESSED_PROMPT_V3.md` (全インスタンス共有状態) |

**新機能設計フロー**:

```text
品質ゲートが必要? → Generator-Verifier
↓ No
ステップが事前確定? → Orchestrator-Subagent
↓ No
長時間の独立タスク? → Agent Teams (= 新インスタンス/新ワークフロー)
↓ No
イベント駆動で拡張性が必要? → Message Bus (= 新 workflow_run トリガー)
↓ No
エージェント間でリアルタイム共有が必要? → Shared State (= Supabase テーブル活用)
```

**推奨スタート**: ほとんどのユースケースは **Orchestrator-Subagent** から始める。
行き詰まった箇所を観察してから他パターンに進化させる。

### セッション開始: Master Brain + claude-mem 参照

セッション開始時に必ず以下を確認する:

```text
C:\Users\kanta\.claude\projects\C--Users-kanta-GitHub-my-web-app\memory\MEMORY.md
```

前回の成功パターン・禁止事項・新規発見を読んで、セッションの出発点とする。
記憶が消える弱点を「3層メモリシステム」で補う:

| 層 | ツール | 用途 |
| --- | --- | --- |
| **L1: セッション内** | claude-mem (SQLite + Gemini圧縮) | 全ツール使用を自動記録・ベクター検索 |
| **L2: セッション間** | 自作auto-capture hooks (mdファイル) | git commit履歴・インスタンス間共有 |
| **L3: プロジェクト横断** | NotebookLM Master Brain | 深い調査・長期アーキテクチャ知識 |

**claude-mem Worker 起動**: セッション開始前に `npx claude-mem start` を実行すること (Bun必須)。
Worker が起動していない場合は hook がスキップされるだけで、エラーにはならない。

**アーキテクチャ・意思決定・好みの質問には必ず Master Brain に問い合わせる**:

> プロジェクトのアーキテクチャ・過去の技術的意思決定・ユーザーの設計上の好みに
> 関する質問には、回答する前に必ず以下で Master Brain を参照する:
>
> ```bash
> notebooklm use jibun-master-brain
> notebooklm ask "過去の意思決定: [質問内容]"
> ```
>
> 例: 「なぜ Supabase を選んだか」「Edge Function の設計方針は」
> 「過去に試して失敗したアプローチは何か」など

これにより、複数セッションにまたがる設計の一貫性を保てる。
メモリが圧縮されてもセッション横断の知見が失われない。

### ゼロトークンリサーチ: `/deep-research` で NotebookLM に委譲（必須）

以下のいずれかに該当する場合は **必ず** `notebooklm` CLI を使う:

| 条件 | Claude 消費 | NotebookLM 委譲後 |
| --- | --- | --- |
| 3ファイル以上を同時に読む | ~150K tokens | ~5K tokens |
| URLを分析する | ~60K tokens | ~2K tokens |
| 競合21社のリサーチ | ~80K tokens | ~3K tokens |
| ドキュメント全体を俯瞰する | ~100K tokens | ~4K tokens |

**native CLI コマンド（推奨）**:

```bash
# ノートブック作成 → ソース追加 → 質問 → 成果物生成
notebooklm create "My Research Project"
notebooklm source add "./transcript.md"          # ファイル
notebooklm source add "https://example.com/doc"  # URL
notebooklm source add --type youtube "https://youtube.com/watch?v=..." # YouTube
notebooklm ask "3つの主要テーマは？"

# 成果物を自動生成（Google インフラで無料処理）
notebooklm generate slide-deck "要点をスライドにまとめて"
notebooklm generate flashcards "重要用語を中心に"
notebooklm generate mind-map
notebooklm generate data-table "主要概念を比較"
notebooklm generate audio "deep dive focusing on key findings" --wait
notebooklm generate quiz "難易度中程度"
notebooklm generate infographic
notebooklm download slide-deck  # ローカルに保存

# Web Deep Research（自律的にWebを調査してレポート生成）
notebooklm source add-research "advanced Flutter Web performance optimization 2026"
notebooklm research wait  # 調査完了まで待機
notebooklm ask "調査結果のサマリーを教えて"
```

**ラッパースクリプト（互換用）**:

```bash
# セットアップ確認
PYTHONUTF8=1 python notebooklm_research.py --setup

# トピック検索（旧方式・互換維持）
PYTHONUTF8=1 python notebooklm_research.py "競合21社の最新動向"
PYTHONUTF8=1 python notebooklm_research.py --files lib/pages/landing_page.dart docs/DESIGN.md --query "UIと設計の整合性"
PYTHONUTF8=1 python notebooklm_research.py --url "https://..." --query "要約して"
```

認証未完了の場合:

```text
notebooklm login が必要です:
  pip install "notebooklm-py[browser]"
  playwright install chromium
  notebooklm login
```

### エキスパートAIエージェント構築: DBS フレームワーク

NotebookLM の Deep Research で収集した知識をカスタムスキルに変換する手順:

1. **Deep Research 実行**: `notebooklm source add-research "対象ドメインの専門的なクエリ"` で数百ページを自律調査
2. **DBS フレームワークで分類**:
   - **D (Direction)** = 意思決定ツリー・手順・エラー回復ロジック → `SKILL.md` のコア
   - **B (Blueprints)** = テンプレート・ガイドライン・分類ルール → サポートファイル
   - **S (Solutions)** = API呼び出し・データ処理・計算など確定的コード → スクリプト
3. **`/skill-creator` でスキル化**: DBS 出力を貼り付けて `/skill-creator` を実行 → SKILL.md 自動生成・テスト

### スキル管理

```bash
notebooklm skill install   # NotebookLM スキルを ~/.claude/skills/ にインストール
notebooklm skill status    # インストール状況確認
notebooklm skill show      # スキル内容表示
notebooklm skill uninstall # アンインストール
```

プロジェクトスキル: `.claude/skills/<name>/SKILL.md` (このリポジトリで共有可)
個人スキル: `~/.claude/skills/<name>/SKILL.md` (全プロジェクトで使用可)

### セッション終了: `/wrap-up` で学習を永続保存（必須）

作業完了後、必ず `/wrap-up` を実行する:

1. ローカル memory/ に保存:
   - 成功パターン → `memory/feedback_success_YYYYMMDD.md`
   - 失敗・禁止事項 → `memory/feedback_correction_YYYYMMDD.md`
   - 新規発見 → `memory/project_YYYYMMDD.md`
2. **NotebookLM Master Brain にソースとして蓄積**（認証済みの場合のみ）:

   ```bash
   # セッション要約をファイルに保存してからソース追加（テキスト直送より確実）
   notebooklm use <jibun-master-brain-notebook-id>
   notebooklm source add "./memory/feedback_success_YYYYMMDD.md"
   notebooklm source add "./memory/project_YYYYMMDD.md"
   ```

   Master Brain が蓄積されれば `notebooklm ask "過去の成功パターンは？"` で横断検索可能。

3. 未完了タスク → `MEMORY.md` 末尾にコメント記録
4. **次回タスク候補を必ず提案** — **特に未完了タスクが 0 件の場合は必須**。セッション終了時に次回実施タスク候補 3〜5件を優先度付き表で提示する（詳細フォーマットは `.claude/commands/wrap-up.md` の Step 6 参照）

**これを怠るとセッション間の記憶が消え、同じ失敗を繰り返す。**

### NotebookLM セットアップ状態

- **インストール**: `pip install "notebooklm-py[browser]"` + `playwright install chromium`
- **認証**: `notebooklm login` (ブラウザで Google ログイン、一度だけ必要)
- **スキルインストール**: `notebooklm skill install` (Claude Code と統合)
- **確認**: `notebooklm status` または `PYTHONUTF8=1 python notebooklm_research.py --setup`
- **注意**: Windows では `PYTHONUTF8=1` を付けて実行 (CP932 エンコードエラー回避)
- **cookie 期限切れ時**: `notebooklm login` で再認証 (30秒)
- **cookie ファイル保護**: `~/.notebooklm/storage_state.json` は絶対に git commit しないこと（= Google セッション情報）

---

## Claude Code Schedule 自動化タスク

> **注意**: 以下のタスクは Claude Code Schedule (定期実行) 用の指示です。
> スケジュール実行時は、下記の SCHEDULE_TASK 環境変数で実行するタスクを判別してください。

### 環境変数 (スケジュール実行時に必要)

```text
SUPABASE_DIGEST_URL=https://smmkxxavexumewbfaqpy.supabase.co/functions/v1/schedule-daily-digest
SUPABASE_SERVICE_KEY=<Supabase service_role key>
GITHUB_PAT=<GitHub Personal Access Token (repo + pull_requests スコープ)>
```

### X アカウント

X への自動投稿先: **@kanta13jp1**
投稿は `post-x-update` Edge Function 経由 (OAuth 1.0a で署名済み)

---

### Task: daily-report (毎朝 09:00 JST に実行)

> **アーキテクチャ**: GitHub Actions `daily-report.yml` が 07:30 JST に先行実行し、
> Supabase API 取得・X投稿・競合モニタリングを行う（プロキシ制限なし）。
> Claude Schedule (09:00 JST) はその結果を読み込み、AI分析・GitHub Issue修復・
> Schedule健全性チェックを担当する。

以下のステップを順番に実行してください:

#### Step 1: GitHub Actions 生成済みレポートを確認・データ取得

まず今日付のレポートが GitHub Actions によって既に生成されているか確認する:

```bash
# 今日のレポートファイルが存在するか確認
ls docs/daily-reports/YYYY-MM-DD.md 2>/dev/null
```

**ケース A: ファイルが存在し `<!-- generated-by: github-actions -->` を含む場合**

Read ツールでファイルを読み込み、概要セクション（ユーザー数・リクエスト数等）を
そのまま利用する。Step 3・Step 4 は Actions 実施済みとしてスキップ可。

**ケース B: ファイルが存在しない場合（Actions 未実行 or 失敗）**

以下の Supabase API を試みる（Claude Code Web 環境ではプロキシにより失敗する場合がある）:

```http
GET https://smmkxxavexumewbfaqpy.supabase.co/functions/v1/schedule-daily-digest
Authorization: Bearer <SUPABASE_SERVICE_KEY>
```

失敗した場合は git log ベースのフォールバックレポートを生成する。

#### Step 2: 日次レポートを生成・保存 (AI分析を付加)

ファイルパス: `docs/daily-reports/YYYY-MM-DD.md`

- ケース A: Actions 生成ファイルの末尾に `## AI分析 (Claude Schedule)` セクションを追記
- ケース B: 以下フォーマットで新規作成

```markdown
# 自分株式会社 日次レポート YYYY-MM-DD

## 概要
- **総ユーザー数**: {users.total}人
- **本日の新規機能リクエスト**: {featureRequests.newToday}件
- **未対応機能リクエスト**: {featureRequests.openCount}件

## 本日の新規機能リクエスト
{newTodayList が空でない場合: リスト表示。空の場合: "なし"}

## 注目の未対応リクエスト (投票数上位)
{topOpen を投票数順にリスト表示}

## 直近の開発実績
{recentAchievements をリスト表示}

## 競合動向
{Actions が実施済みの場合はスキップ。未実施の場合はフォールバック記録}

## AI分析 (Claude Schedule)
AIとして、上記データを踏まえた優先対応事項を3点提案する。
特に投票数の多い機能リクエストや、ユーザー成長に繋がるアクションを優先。
```

#### Step 3: X (Twitter) に投稿

> **注意**: Actions 生成レポートに `## X投稿` セクションがあり `✅ 投稿成功` と記載されている場合はスキップ。

Actions が失敗 or 未実行の場合のみ実行:

```http
POST https://smmkxxavexumewbfaqpy.supabase.co/functions/v1/post-x-update
Authorization: Bearer <SUPABASE_SERVICE_KEY>
Content-Type: application/json
{ "text": "<140字以内. カジュアルトーン. #buildinpublic #FlutterWeb>" }
```

#### Step 4: 競合モニタリング

> **注意**: Actions 生成レポートに `## 競合動向` セクションがある場合はスキップ。

Actions が失敗 or 未実行の場合のみ WebFetch で Notion / Evernote / Slack を確認し、
`## 競合動向` セクションとして記録する。

#### Step 5: コミット

```bash
git add docs/daily-reports/YYYY-MM-DD.md
git commit -m "自動: 日次レポート YYYY-MM-DD"
git push origin main
```

---

### Task: cs-check (毎時 実行)

CS対応・バグ修正・エスカレーションを完全自動化する。

#### Step 1: 未返信チケットを取得

WebFetch で以下を呼び出す:

```http
GET https://smmkxxavexumewbfaqpy.supabase.co/functions/v1/get-support-tickets
Authorization: Bearer <SUPABASE_SERVICE_KEY>
```

レスポンスから `tickets` (未返信) と `faq` (FAQ一覧) を取得する。
チケットが0件なら処理を終了（コミット不要）。

#### Step 2: 各チケットを判断・対応

チケットごとに以下を判断する:

#### ケース A: FAQ で答えられる

- `faq` 一覧と照合し、類似する質問が見つかれば FAQ の回答を参考に返信文を生成
- POST で返信:

```http
POST https://smmkxxavexumewbfaqpy.supabase.co/functions/v1/reply-support-request
Authorization: Bearer <SUPABASE_SERVICE_KEY>
Content-Type: application/json
{ "id": "<ticket_id>", "reply": "<返信文(日本語)>", "newStatus": "open" }
```

#### ケース B: バグの可能性がある (タイトル・説明に「動かない」「エラー」「できない」「バグ」等)

1. 関連する Dart/TypeScript ソースを `lib/` または `supabase/functions/` から読んで原因を特定
2. 修正可能な軽微なバグ（typo、null チェック漏れ、ロジック誤りなど）であれば:
   a. コードを修正
   b. `flutter analyze` を実行し 0 エラーを確認（Dart の場合）
   c. `git add -p && git commit -m "fix: <バグ内容>" && git push origin main` でコミット
   d. 返信文に「修正しました。本番デプロイまで数分お待ちください」と記載して返信
3. 複雑な修正が必要な場合はエスカレーション (ケース C)

#### ケース C: 返金・課金・退会・緊急 or 判断困難

- エスカレーションとしてマーク:

```json
{ "id": "<ticket_id>", "escalate": true }
```

- `docs/cs-notes/YYYY-MM-DD-HH.md` にエスカレーション内容を記録

#### Step 3: CS ノートを記録してコミット

対応内容の記録を `docs/cs-notes/YYYY-MM-DD-HH.md` に保存:

```markdown
# CS チェック YYYY-MM-DD HH:00

## 対応済み (FAQ返信)
- [タイトル] → 返信送信

## 対応済み (バグ修正)
- [タイトル] → 修正コミット: <commit hash>

## エスカレーション (要人間対応)
- [タイトル] → 理由: <判断できなかった理由>

## スキップ (投票0・重複など)
- なし
```

コミット:

```bash
git add docs/cs-notes/
git commit -m "自動: CS チェック YYYY-MM-DD HH:00"
git push origin main
```

チケットが0件 or 全てスキップの場合はコミット不要。

#### Step 4: GitHub PR レビュー (GITHUB_PAT が設定されている場合)

```bash
gh pr list --state open --json number,title,additions,deletions,files
```

各PRに対して以下の観点でコードレビューを実施:

- セキュリティ (SQL injection, XSS, 認証漏れ)
- パフォーマンス (N+1クエリ、不要な再レンダリング)
- Lintエラー・型エラー
- CLAUDE.md のルール違反 (ダミーデータ使用、flutter analyze エラーなど)

指摘がある場合は `gh pr comment <number> --body "<レビューコメント>"` で投稿。
既にコメント済みの内容は重複投稿しない。

#### Step 5: インフラ・ヘルスチェック

以下のエンドポイントを WebFetch で確認し、異常があれば cs-notes に記録する:

```http
GET https://smmkxxavexumewbfaqpy.supabase.co/functions/v1/get-home-dashboard
GET https://smmkxxavexumewbfaqpy.supabase.co/functions/v1/development-achievements
GET https://my-web-app-b67f4.web.app/
```

- HTTP 200 以外のレスポンス → `docs/cs-notes/YYYY-MM-DD-HH.md` の末尾に `## インフラ異常` として記録
- タイムアウト (10秒以上) も異常として記録
- 全て正常なら記録不要

---

### Task: github-issue-fix (毎日 10:00 JST に実行)

GitHub Issues を自動チェックし、修正可能なものを自動対応する。

#### Step 1: オープンIssueを取得

```bash
gh issue list --state open --json number,title,body,labels --limit 30
```

#### Step 2: 各Issueを判断・対応

**ケース A: Edge Function UI導線チェック (`[自動] Edge Function UI導線チェック`)**

- Issue body から未接続の Edge Function 名リストを抽出
- `lib/widgets/edge_function_summary_card.dart` を読んで、既に追加済みかを確認
- 未追加の場合: `edge_function_summary_card.dart` の関数リストに追加
- `flutter analyze` で0エラーを確認後、コミット
- Issue に対して解決コメントを投稿: `gh issue comment <number> --body "✅ UI接続を追加しました。コミット: <hash>"`
- Issue をクローズ: `gh issue close <number>`

**ケース B: flutter analyze エラー (`[自動] flutter analyze`)**

- エラー内容を読んで、修正可能なら修正
- `flutter analyze` で0エラーを確認後、コミット・クローズ

**ケース C: 判断困難または手動対応が必要**

- `docs/cs-notes/YYYY-MM-DD-github-issues.md` にメモを残す
- Issue はそのまま維持

#### Step 3: コミット・プッシュ

```bash
git add -A
git commit -m "fix: GitHub Issue 自動対応 YYYY-MM-DD"
git push origin main
```

変更がない場合はコミット不要。

---

### Task: weekly-sns-draft (毎週月曜 09:00 JST に実行)

#### Step 1: 先週の実績サマリーを生成

`docs/daily-reports/` の直近7日分を読み込み、週次サマリーを作成:

ファイルパス: `docs/weekly-drafts/YYYY-MM-DD-week.md`

```markdown
# 週次 SNS 投稿ドラフト (YYYY-MM-DD 週)

## X (Twitter) 投稿ドラフト (140字以内)

[ドラフト1: ユーザー数の進捗]
自分株式会社、今週もビルド継続中🚀
現在 {users.total}人が使用中。
14の競合SaaSを超えるAI統合アプリを無料で体験:
https://my-web-app-b67f4.web.app/ #buildinpublic

[ドラフト2: 機能開発の進捗]
今週実装した機能: {直近の実績タイトルを2-3個}
コツコツ積み上げ中💪 #FlutterWeb #Supabase

## Zenn 記事ネタ提案
1. {今週の実装内容から技術記事ネタを3つ提案}
```

#### Step 2: 依存パッケージの脆弱性チェック

`pubspec.yaml` と `supabase/functions/` の deno import URLを読み込み、以下を確認:

- 古いバージョンのパッケージ (メジャーバージョンが2以上古い)
- 既知の脆弱性パターン (CVEなど)

問題があれば週次ドラフトに `## 依存パッケージ注意` セクションを追加して記録する。

コミット:

```bash
git add docs/weekly-drafts/
git commit -m "自動: 週次SNSドラフト YYYY-MM-DD"
```

---

### Task: pr-auto-review (3時間ごとに実行)

GitHub PRの自動コードレビュー。

1. `gh pr list --state open` でオープンPRを確認
2. 各PRの差分を取得し、セキュリティ・パフォーマンス・ロジックバグの観点でレビュー
3. 指摘があれば `gh pr review` でコメント投稿
4. 問題なければ approve
5. **CI失敗PR対応**: `ci-auto-fix.yml` が `dart fix --apply` + `deno fmt` を自動適用済みの場合は
   その結果コメントを確認し、残存エラーがあれば追加コメントで手動修正を促す。
   `ci-auto-fix.yml` 未実行の場合は `gh run list --branch <branch>` で CI ログを確認して
   修正可能なエラー (deprecated API / import typo 等) があればコードを直接修正してコミット。

---

### Task: competitor-monitoring (毎日 07:00 JST に実行)

競合21社のWebサイト・機能変更モニタリング。

1. `check-competitor-updates` Edge Function で可用性チェック
2. WebSearch で各競合の最新ニュースを検索
3. `docs/competitor-reports/YYYY-MM-DD.md` にレポート作成
4. 重要な変更があれば GROWTH_STRATEGY_ROADMAP.md にも反映

---

### Task: infra-health-check (毎時30分に実行)

インフラヘルスチェック。

1. `health-check` Edge Function で DB・テーブル・レスポンスタイムを確認
2. Firebase Hosting (<https://my-web-app-b67f4.web.app/>) の可用性を確認
3. 異常時のみ `docs/incident-reports/YYYY-MM-DD-HH.md` にレポート作成

---

### Task: dependency-audit (毎週月曜 08:00 JST に実行)

依存パッケージの脆弱性チェック。

1. `flutter pub outdated` で古いパッケージを確認
2. Deno Edge Functions の import URL バージョンを確認
3. 脆弱性があればパッチ更新 or レポート作成 (`docs/security-audit/YYYY-MM-DD.md`)
4. `flutter analyze` と `deno lint` で0エラーを確認

---

### Task: blog-draft (毎日 08:00 JST に実行)

技術ブログの下書きを生成し、投稿管理テーブルに記録する。

#### Step 1: 直近の開発内容を確認

```bash
git log --oneline --since="7 days ago"
```

直近7日間のコミット一覧を取得する。

#### Step 2: ブログ下書きを生成・保存 (日本語 + 英語の2ファイル)

**日本語版** (Qiita 投稿用): `docs/blog-drafts/YYYY-MM-DD.md`

```markdown
---
title: "{実装内容を技術的に面白く表現したタイトル}"
tags: Flutter,Supabase,buildinpublic,個人開発
published: false
---

# {タイトル}

## はじめに
{なぜこの機能を作ったか、どんな課題を解決するか}

## 実装方法
{Flutter/Supabase での具体的な実装手順、コードスニペット付き}

## 詰まったポイント
{実際にハマった部分と解決策}

## まとめ
{今後の展望、リポジトリ/サービスへのリンク}

---
自分株式会社: https://my-web-app-b67f4.web.app/
#FlutterWeb #Supabase #buildinpublic #個人開発
```

**英語版** (dev.to 投稿用): `docs/blog-drafts/YYYY-MM-DD-en.md`

```markdown
---
title: "{English title — same technical content}"
tags: Flutter,Supabase,buildinpublic,webdev
published: false
---

# {English Title}

## Introduction
{Why this feature was built, what problem it solves}

## Implementation
{Flutter/Supabase step-by-step, with code snippets}

## Challenges
{What was tricky and how it was solved}

## Conclusion
{Next steps, links}

---
Building in public: https://my-web-app-b67f4.web.app/
#FlutterWeb #Supabase #buildinpublic
```

> **注意**: 日本語版と英語版は同じ技術内容を扱うが、それぞれの文化・読者に合わせた表現で書くこと。英語版は dev.to の読者向けに direct/concise なスタイルで。

#### Step 3: 投稿記録をSupabaseに保存 (`blog-post-manager` EF)

`blog-post-manager` EF の POST で `blog_posts` テーブルに下書きを登録:

```http
POST https://smmkxxavexumewbfaqpy.supabase.co/functions/v1/blog-post-manager
Authorization: Bearer <SUPABASE_SERVICE_KEY>
Content-Type: application/json
{
  "title": "<タイトル案1>",
  "draft_path": "docs/blog-drafts/YYYY-MM-DD.md",
  "target_platforms": ["qiita", "devto"],
  "content_preview": "<本文最初の200字>"
}
```

レスポンスの `post.id` (UUID) を Step 4 で使用する。

※ `blog_posts` テーブルのスキーマ:

```sql
id uuid, title text, draft_path text, status text (draft/posted/skipped),
target_platforms text[], posted_at timestamptz, url text, created_at timestamptz
```

#### Step 4: 自動投稿 (`blog-auto-publisher` EF)

Step 3 で登録した `post.id` と本文全体を使って実投稿:

```http
POST https://smmkxxavexumewbfaqpy.supabase.co/functions/v1/blog-auto-publisher
Authorization: Bearer <SUPABASE_SERVICE_KEY>
Content-Type: application/json
{
  "action": "auto_publish",
  "id": "<post.id>",
  "content": "<本文下書きのMarkdown全文>",
  "tags": ["Flutter", "Supabase", "buildinpublic"]
}
```

**投稿先と必要なシークレット**:

| プラットフォーム | Supabaseシークレット | 設定方法 |
| --- | --- | --- |
| Qiita | `QIITA_ACCESS_TOKEN` | Qiita設定のトークン発行ページでトークン発行 |
| dev.to | `DEVTO_API_KEY` | dev.to設定のExtensionsページで API key 発行 |
| Zenn | — | GitHubリポジトリ連携のため手動 (Zenn CLIは別途) |

シークレット未設定の場合、そのプラットフォームはスキップされ `results.{platform}.error` に理由が記録される。
少なくとも1プラットフォームに投稿成功すると `blog_posts.status` が `'posted'` に更新される。

#### Step 5: コミット

```bash
git add docs/blog-drafts/YYYY-MM-DD.md docs/blog-drafts/YYYY-MM-DD-en.md
git commit -m "自動: ブログ下書き YYYY-MM-DD (日本語+英語)"
git push origin main
```

開発活動がない日 (コミット0件) はスキップ可。

#### Step 6: blog-publish.yml をディスパッチ (両言語を投稿)

```bash
# Qiita (日本語) + dev.to (英語) を同時投稿
gh workflow run blog-publish.yml \
  -f draft_path="docs/blog-drafts/YYYY-MM-DD.md" \
  -f draft_path_en="docs/blog-drafts/YYYY-MM-DD-en.md" \
  -f platforms="qiita,devto" \
  -f dry_run="false"
```

`draft_path_en` を省略した場合は Qiita のみ投稿 (dev.to スキップ)。

---

### AI大学 キラーコンテンツ化方針（毎セッション検討必須）

AI大学はユーザー数拡大のための**最重要差別化機能**。毎セッションで必ず以下の3Stepを実行する。

#### 目標 KPI

| KPI | 目標 | 測定方法 |
| --- | --- | --- |
| 週次アクティブ学習者率 | 登録ユーザーの 40% 以上 | ai_university_scores.studied_at |
| クイズ完了率 | 初回訪問の 60% 以上 | SharedPreferences → Supabase 移行後 |
| シェア転換率 | 学習完了の 10% 以上 | share_plus イベント計測 |
| ランキング参加率 | 学習者の 30% 以上 | ai_university_leaderboard ビュー |
| 連続学習日数 (ストリーク) | 平均 7 日以上 | ai_university_streaks テーブル |

#### 毎セッション 3Step（必須）

**Step A: ホームカード改善 (VSCode版)**

毎セッション必ず `lib/widgets/ai_university_home_card.dart` を見直す:

- 学習済みプロバイダー数・クイズ正解数・ストリーク日数を動的表示できるか？
- タップ時のCTA文言・ボタン色を改善できるか？
- 新規ユーザーと復帰ユーザーで表示を出し分けられるか？

**Step B: バイラル機能強化 (VSCode版)**

シェア・ランキング・バッジで口コミ拡散を加速する:

- **シェア文言 A/B テスト**: 「X 社を制覇」「クイズ全問正解」等バリエーションを試す
- **ランキングUI** (`ai_university_ranking_page.dart`): 週次TOP10・全体ランキング表示
- **バッジシステム** (`ai_university_badges` テーブル): 達成条件別バッジ発行・シェア誘導
- **SNSカード生成**: シェア時にOGP画像で「何社学習済み」を視覚化

**Step C: リテンション強化 (Windowsアプリ版 migration + VSCode版 EF)**

一度使ったユーザーが戻ってくる仕掛けを入れる:

- **学習ストリーク** (`ai_university_streaks`): 連続学習日数バッジ → 7日/30日/100日
- **学習リマインダー** (`notification-center` EF 連携): 3日未学習でプッシュ
- **コンテンツ鮮度表示**: 「X日前に更新」を AI大学ページに表示
- **パーソナライズ**: 学習済みプロバイダーを次回訪問時に先頭表示

#### 実装ロードマップ（優先度順）

| 優先度 | 機能 | 担当インスタンス | 状態 |
| --- | --- | --- | --- |
| ✅ | ランキングUI (`ai_university_ranking_page.dart`) | VSCode版 | ✅ 完了 (VSCode版#53) |
| ✅ | `ai-university-content` EF (GET/UPSERT) | Web版 | ✅ 完了 (Web版#28, PR#317) |
| ✅ | `ai_university_scores` スコア書込み (EF + Dart) | Web版+VSCode版 | ✅ 完了 (VSCode版#54 + Web版#33) |
| ✅ | `ai_university_streaks` EF + ストリークUI | Web版+VSCode版 | ✅ 完了 (Web版#29, VSCode版#54) |
| ✅ | `ai_university_badges` バッジ発行 EF | Web版 | ✅ 完了 (Web版#29/#33, PR#317) |
| ✅ | シェア文言 A/B テスト (3バリエーション) | VSCode版 | ✅ 完了 (VSCode版#54) |
| ✅ | ホームカード: ストリーク日数表示 | VSCode版 | ✅ 完了 (VSCode版#54) |
| ✅ | SNS シェア画像生成 (OGP カード) | VSCode版 | ✅ 完了 (VSCode版#56) |
| 🟢 中 | 学習リマインダー通知 (定期バッチ) | VSCode版 | EF action 実装済み / バッチ未設定 |
| 🔵 低 | 他ユーザー学習状況表示 | VSCode版 | 未実装 |

#### 既存実装（改善のベースライン）

| 機能 | 実装場所 | 改善ポイント |
| --- | --- | --- |
| ホーム最上部カード | `ai_university_home_card.dart` | ストリーク表示を追加 |
| シェア機能 | `gemini_university_v2_page.dart` `_shareProgress()` | バリエーション追加 |
| クイズ達成度 | SharedPreferences `ai_univ_answered_quizzes` | Supabase に移行してクロスデバイス対応 |
| プロバイダー無制限 | DB 駆動タブ (9社対応済み) | 毎セッションで新プロバイダー検討 |
| コンテンツ自動更新 | `ai-university-update.yml` (2時間毎) + Claude Schedule (4時間毎・NotebookLM) | ai-university-content EF 完成後にフル稼働 |
| DB スキーマ | `ai_university_scores` + `leaderboard` ビュー | EF とUI接続が未完了 |

---

### Task: ai-university-update (毎4時間実行)

> **アーキテクチャ**: GitHub Actions `ai-university-update.yml` が2時間毎に RSS ベースの軽量更新を行う。
> Claude Schedule (毎4時間) は NotebookLM Deep Research で**より深い情報**を収集してリッチなコンテンツを上書きする。
> 両者が同じ `ai_university_content.news` レコードを UPSERT するため、後から書いた方が最新版になる。

AI大学コンテンツを最新情報に自動更新する。**プロバイダー数は固定せず**、重要性が高い新興AIプロバイダーを毎回検討して随時追加する。

#### 現在の登録プロバイダー

```text
google, openai, anthropic, microsoft, meta, x, deepseek, mistral, perplexity, groq, cohere, core, amazon, stability, huggingface, nvidia, ibm, sakana, baidu, oracle, reka, aleph_alpha, together_ai, fireworks_ai, replicate, writer, ai21, voyage, elevenlabs, openrouter, ollama, runway, suno, ideogram, udio, luma, kling, pika, assemblyai, twelve_labs, qwen, moonshot, midjourney, hailuo, adobe_firefly, 01ai, coze, apple, databricks, samsung, zhipu, character_ai, inflection, allenai, naver, adept, cerebras, prover, lmsys, falcon_tii
```

登録済みプロバイダーは `ai_university_content` テーブルの `provider` カラム個別値で確認できる。

#### Step 0: 新規プロバイダー候補を検討（毎回必須）

WebSearch で「AI provider new model release 2026」を検索し、以下の観点で新規追加候補を評価する:

| 評価基準 | 追加する | 見送る |
| --- | --- | --- |
| 技術的革新性 | 新アーキテクチャ・SOTA達成 | 既存モデルの軽微な更新のみ |
| 利用可能性 | API公開済み・広く利用可能 | クローズドβのみ |
| 話題性 | SNS/ニュースで大きく取り上げ | マイナーな言及のみ |

**候補プロバイダー例** (評価対象 — 追加済みでない場合):

```text
Mistral AI    (mistral)   — 欧州発オープンソース、Mistral Large/Small
Cohere        (cohere)    — エンタープライズRAG特化、Command R+
Perplexity AI (perplexity)— AI検索エンジン、独自LLM
Amazon        (amazon)    — Amazon Nova/Bedrock、AWS AI統合
Apple         (apple)     — Apple Intelligence、オンデバイスAI
Baidu         (baidu)     — ERNIE Bot、中国最大AI
Samsung       (samsung)   — Gauss、オンデバイスAI
```

**新規追加が決まったら**:

1. `supabase/migrations/YYYYMMDDXXXXXX_seed_{provider}_ai_university.sql` を作成し overview / models / api の3カテゴリで初期コンテンツを seed
2. `lib/pages/gemini_university_v2_page.dart` の `_providerMeta` マップに表示設定を追加（任意: 未登録でもタブは自動生成されるが色・絵文字がデフォルトになる）
3. `_fallback` マップ（同ファイル）にフォールバック markdown を追加
4. `_quizzes` マップ（同ファイル）にクイズを追加（任意）
5. `ai-university-update.yml` の検索クエリリストにプロバイダーを追加
6. COMPRESSED_PROMPT_V3.md の「現在の登録プロバイダー」リストを更新

#### Step 1: NotebookLM Deep Research で最新AIニュースを収集（必須）

GitHub Actions の RSS 更新より深い情報を取得するため、必ず NotebookLM を使う:

```bash
# 全プロバイダーを一括でリサーチ (専用ノートブック or Master Brain)
notebooklm use jibun-master-brain
notebooklm source add-research "Google Gemini OpenAI GPT Anthropic Claude Microsoft Copilot Meta LLaMA xAI Grok DeepSeek Mistral Perplexity latest AI news releases API changes 2026"
notebooklm research wait
notebooklm ask "各AIプロバイダー (Google/OpenAI/Anthropic/Microsoft/Meta/xAI/DeepSeek/Mistral/Perplexity) の最新ニュース・モデルリリース・API変更をプロバイダー別に日本語でまとめてください"
```

認証切れの場合: `notebooklm login` で再認証 (30秒)。
NotebookLM が利用不可の場合は WebSearch にフォールバック:

```text
WebSearch フォールバック (各プロバイダーごと):
- Google:    "Google Gemini AI latest news models 2026"
- OpenAI:    "OpenAI GPT o1 o3 latest news 2026"
- Anthropic: "Anthropic Claude latest news models 2026"
- Microsoft: "Microsoft Copilot Azure OpenAI latest 2026"
- Meta:      "Meta AI LLaMA latest news 2026"
- X/xAI:    "xAI Grok latest news models 2026"
- DeepSeek: "DeepSeek AI latest news models 2026"
- Mistral:  "Mistral AI latest news models 2026"
- Perplexity: "Perplexity AI Sonar latest news 2026"
```

各プロバイダーの公式ブログ・リリースノートも参照する:

```text
https://blog.google/technology/ai/
https://openai.com/news/
https://www.anthropic.com/news
https://blogs.microsoft.com/ai/
https://ai.meta.com/blog/
https://x.ai/blog
https://api-docs.deepseek.com/news/
```

#### Step 2: `ai_university_content` テーブルを UPSERT で更新

`ai-university-content` EF (または Supabase REST API) で各プロバイダーの `news` カテゴリレコードを更新する:

```http
POST https://smmkxxavexumewbfaqpy.supabase.co/functions/v1/ai-university-content
Authorization: Bearer <SUPABASE_SERVICE_KEY>
Content-Type: application/json
{
  "action": "upsert_news",
  "provider": "google",
  "title": "Google AI 最新ニュース (YYYY-MM-DD)",
  "content": "## 今週の最新情報\n\n[取得した内容をMarkdown形式で]",
  "published_at": "YYYY-MM-DD"
}
```

または Supabase REST API を直接使用:

```bash
curl -X POST \
  "https://smmkxxavexumewbfaqpy.supabase.co/rest/v1/ai_university_content" \
  -H "apikey: <SUPABASE_SERVICE_KEY>" \
  -H "Authorization: Bearer <SUPABASE_SERVICE_KEY>" \
  -H "Content-Type: application/json" \
  -H "Prefer: resolution=merge-duplicates" \
  -d '{"provider":"google","category":"news","title":"...","content":"...","published_at":"YYYY-MM-DD"}'
```

#### Step 3: 更新サマリーを記録してコミット

変更内容を `docs/daily-reports/YYYY-MM-DD.md` の末尾に追記:

```markdown
## AI大学コンテンツ更新 (ai-university-update)
- Google: Gemini 2.x 最新リリース情報を更新
- OpenAI: o3 mini 料金改定情報を追加
- DeepSeek: V3 新バージョン情報を追加
- 新規追加: [プロバイダー名] — [追加理由]
- ...（各プロバイダーの更新内容）
```

```bash
git add docs/daily-reports/ supabase/migrations/ .github/workflows/
git commit -m "自動: AI大学コンテンツ更新 YYYY-MM-DD"
git push origin main
```

---

## ディレクトリ構成 (主要)

```text
lib/
  main.dart              # ルーティング
  pages/
    landing_page.dart    # LP (比較リンク、FAB CTA)
    comparison_page.dart # 競合比較ページ (21社)
    user_manual_page.dart
    admin_analytics_page.dart
supabase/
  functions/             # Deno Edge Functions
  migrations/            # SQL migration files
docs/
  GROWTH_STRATEGY_ROADMAP.md  # 開発記録 (毎回更新)
  daily-reports/         # Claude Schedule が生成する日次レポート
  cs-notes/              # Claude Schedule が生成する CS チェックメモ
  weekly-drafts/         # Claude Schedule が生成する週次SNSドラフト
  competitor-reports/    # Claude Schedule が生成する競合モニタリングレポート
  incident-reports/      # Claude Schedule が生成するインシデントレポート
  security-audit/        # Claude Schedule が生成する脆弱性チェックレポート
web/
  index.html             # SEO meta tags
  sitemap.xml            # 22 URLs
```

## Supabase Edge Function 一覧

| Function | 用途 |
| --- | --- |
| `schedule-daily-digest` | Claude Schedule 用の日次メトリクス API |
| `get-support-tickets` | Claude Schedule 用: 未返信チケット+FAQ一覧 |
| `reply-support-request` | Claude Schedule 用: チケット返信・エスカレーション |
| `get-home-dashboard` | ホーム画面統合データ |
| `notify-feature-request` | 機能リクエスト更新通知メール |
| `growth-weekly-digest` | 週次グロース指標 |
| `development-achievements` | 開発実績一覧 |
| `get-admin-users` | 管理者用ユーザー一覧 |
| `daily-judgment` | AI デイリー判定 |
| `ai-assistant` | AI アシスタント |
| `post-x-update` | X (Twitter) 自動投稿 (@kanta13jp1) |
| `get-growth-roadmap-progress` | 進捗バーデータ (21競合+短中長期) |
| `get-competitor-features` | 競合21社の機能比較データ |
| `health-check` | インフラヘルスチェック |
| `check-competitor-updates` | 競合21社のWebサイト可用性チェック |

---

## 開発実績の記録方法

新しい機能を実装したら必ず `supabase/migrations/` に seed ファイルを作成:

```sql
-- Session XX: 実装内容の概要
INSERT INTO development_achievements (title, description, completed_at)
VALUES ('タイトル', '詳細説明', 'YYYY-MM-DD')
ON CONFLICT DO NOTHING;
```

## マイグレーションファイルの命名規則

`YYYYMMDDXXXXXX_descriptive_name.sql`
例: `20260326000010_seed_achievements_session20.sql`
