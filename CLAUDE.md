# 自分株式会社 — Claude Code 設定

> **注意 (一時対応)**: 現在 `Claude` がクォータ制限に達しているため、他担当のタスクは一時的に `Codex` に引き継いで開発を進めます。該当の再割当は `docs/WBS.md` と WBS データ本体に反映し、Claude の利用が再開次第、必要に応じてロールバックまたは調整を行います。


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

**毎セッション必須ツールチェーン** (Rule 19+20+21): `Claude Code` × `Nanobanana API` × `Figma MCP` × `AIDesigner MCP` × `design-skills` サブエージェント × **`frontend-design` プラグイン** × **`Claude Design` (Anthropic Labs SaaS)** × `docs/DESIGN.md` を組み合わせて UI を改善する。加えて (Rule 20) **Playwright / Context7 / GitHub MCP / Magic / Code Review / Superpowers** の6MCPを積極活用する。詳細は `.github/COMPRESSED_PROMPT_V3.md` Rule 19/20/21 参照。

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

## 開発ルール (詳細は ~/.claude/hooks/inject-rules.txt 参照)

> **重要 (Win版#131 移行)**: 行動ルール (behavioral rules) は `~/.claude/hooks/inject-rules.txt` に
> 移行済。UserPromptSubmit hook で毎ターン system-reminder として注入される。
> CLAUDE.md には **facts (技術スタック / EF 一覧 / コマンド)** のみ残す。
>
> Distyl AI 研究: 指示 500 個 → 最高精度モデルで 68% 遵守。1 回読みの CLAUDE.md は
> 訓練済みの癖に負ける。毎ターン強制注入の hook は system-reminder 形式で優先度高。

### inject-rules.txt 注入 rule (毎ターン system-reminder)

| Hook ルール | 内容 | 移行元 CLAUDE.md Rule |
| --- | --- | --- |
| `[INSTANCE]` | セッション冒頭で Win/PS/VSCode 確認 | — |
| `[PHILOSOPHY-22]` | docs/PHILOSOPHY.md 9 原則チェック | Rule 17 (旧 22) |
| `[AI-DEV-23]` | docs/AI_DEV_PRINCIPLES.md 7 原則チェック | Rule 18 (旧 23) |
| `[AUTO-REPLY]` | author == 自分 で必ず skip + cap | — |
| `[DART-FORMAT]` | dart format → flutter analyze 0 → push | Rule 1 + 2 |
| `[REBASE]` | git fetch + log 確認 → pull --rebase | — |
| `[WORKDIR-ISOLATION]` | 10 インスタンス別 worktree 必須 | — |
| `[STASH-SAFETY]` | git stash 危険・WIP commit 推奨 | — |
| `[CAVEMAN]` | 通信 fragments OK・code は normal | — |
| `[MEMORY-DECAY]` | memory/ タイムスタンプ + shadow + cleanup | — |
| `[WBS-SYNC]` | 毎セッション wbs.priority_for_instance + update_progress | — |
| `[INSTANCE-ROLES]` | 10 インスタンス役割分担 | — |
| `[CONCURRENCY]` | deploy-prod cancel-in-progress: false | — |
| `[ROADMAP-LOG]` | docs/GROWTH_STRATEGY_ROADMAP.md 毎セッション末尾追記 | Rule 3 |
| `[REAL-DATA]` | ダミーデータ禁止・Supabase リアルデータ使用 | Rule 4 |
| `[EF-FIRST]` | 複雑ロジックは Edge Function に移動 | Rule 5 |
| `[EF-CAP-50]` | deploy-prod EF ≤ 50・hub action 追加最優先 | Rule 7 |
| `[NO-SCOPE-CREEP]` | 明示依頼ない機能を勝手に追加禁止 | Rule 6 |
| `[UI-VERIFY]` | 毎セッション本番 UI チェック (Playwright + design-skills) | Rule 8 |
| `[CONSTRAINT-LOG]` | 新制約発見 → instance-constraints.md + cross-instance-pr | Rule 15 |

### CLAUDE.md に残す Facts セクション (本ファイル下記参照)

- 技術スタック / 競合 21 社
- デザインシステム参照 (DESIGN.md / 競合別 DESIGN.md)
- Multi-AI ワークフロー (インスタンス分担表)
- Schedule 自動化タスク (cron 設定)
- AI 大学キラーコンテンツ化方針
- ディレクトリ構成 / EF 一覧
- Rule 16 (Claude Design ワークフロー) — slash command 一覧 (facts)
- Rule 13 (6 MCPプラグイン) — プラグイン早見表 (facts)
- Rule 14 (バージョンチェック) — `/session-start-check` skill 委譲済

### 手動チェック (skill 化) — hook では強制せず

- `/session-start-check` (Rule 14 + 10 + 並行衝突)
- `/rule17-wf-health` (Rule 9 — PS版#1 専任)
- `/blog-publish-cleanup` (T-1 関連 — PS版#2 専任)
- `/wrap-up` (Rule 3 + Philosophy Alignment + 次回タスク提案)

---

## Multi-AI ワークフロー（毎回必ず実行）

**設計思想**: Claude Code 5インスタンス (VSCode/Windowsアプリ/PowerShell/WEB/📱スマホ版) を主軸に、Gemini Code Assist・CODEX・GitHub Copilot を補完役で活用。
「どの処理をどの AI に振るか」を設計することで、月 $20 プランで $200 相当の作業を実現する。
Claude のトークンは「判断・編集・統合」のみに使い、重い分析は Google (NotebookLM/Gemini) に無料で投げる。

### インスタンス別 推奨モデル / 制約表

| インスタンス | 推奨モデル | 推奨モード | 作業ディレクトリ | 主な制約 |
| --- | --- | --- | --- | --- |
| **VSCode版** | `claude-haiku-4-5` (Auto Mode) | 通常 (重い設計は sonnet-4-6 に一時切替可) | `C:/Users/kanta/GitHub/my_web_app` (main repo) | なし |
| **Windowsアプリ版** | `claude-haiku-4-5` (Auto Mode) | 通常 + CAVEMAN節約 | `C:/Users/kanta/GitHub/my_web_app_win` (win-main branch) | なし。`PYTHONUTF8=1` 必須 |
| **PowerShell版** | ルーティン: `claude-haiku-4-5` / 設計: `claude-sonnet-4-6` | `/fast` (定型作業) | `C:/Users/kanta/GitHub/my_web_app_ps` (ps-main branch) | なし |
| **WEB版** | `claude-sonnet-4-6` (変更不可の場合あり) | 通常 | GitHub MCP のみ | `notebooklm` / `flutter analyze` / `deno lint` / ローカルCLI **不可** |
| **📱 スマホ版** | `claude-sonnet-4-6` | 通常 (画像分析重視) | GitHub MCP のみ | ローカルCLI **不可** / git/dart/flutter **不可** / **GitHub MCP のみ** で git 操作。**実機 UAT・モバイル不具合トリアージ専用** |

**Worktree 運用ルール (PS版・Win版 必須)**:
- セッション開始時: `cd C:/Users/kanta/GitHub/my_web_app_ps` (PS版) or `my_web_app_win` (Win版) で作業開始
- `git pull --rebase origin main` で最新を取得 (stash 不要 — uncommitted 変更なし前提)
- commit 後: `git push origin ps-main:main` (PS版) / `git push origin win-main:main` (Win版) で origin/main に push
- push 後: `git pull --rebase origin main` で ps-main/win-main を最新に同期
- **git stash 禁止**: uncommitted 変更は即 commit か WIP commit (`git commit -m "WIP"`) で退避
- main repo (`C:/Users/kanta/GitHub/my_web_app`) は **VSCode版専任** — PS版・Win版は絶対に編集しない

**WEB版代替パターン**:
- `notebooklm ask` → WebSearch で代替
- `flutter analyze` → 実行不可→ VSCode版に cross-instance-pr で検証依頼
- `deno lint` → 実行不可 → EF変更は VSCode版に依頼
- git commit → GitHub MCP (`mcp__plugin_github_github__create_or_update_file`) で代替

**📱 スマホ版運用パターン**:
- 本番モバイル (iPhone/Android) で実機検証 → screenshot 添付 → GitHub Issue 自動作成
- 軽量修正 (1ファイル数行) は GitHub MCP で完結 → PR 作成
- 重い修正は `docs/cross-instance-prs/YYYYMMDD_mobile_<title>.md` で VSCode版/Win版に handoff
- 専用 skill: `.claude/skills/mobile-bug-triage/SKILL.md` (Issue テンプレ + WCAG/Touch target チェックリスト)
- **強み = 実機検証** (iOS Safari の細かい挙動・PWA 動作・touch gesture は Playwright で再現困難)

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

> **詳細移管**: Schedule タスク全件 (daily-report / cs-check / github-issue-fix /
> weekly-sns-draft / pr-auto-review / competitor-monitoring / infra-health-check /
> dependency-audit / blog-draft / ai-university-update + AI大学キラーコンテンツ化方針) は
> [`docs/SCHEDULE_TASKS.md`](docs/SCHEDULE_TASKS.md) に移管 (Win版#131 part 6)。
>
> 環境変数 (`SUPABASE_DIGEST_URL` / `SUPABASE_SERVICE_KEY` / `GITHUB_PAT`) は同 docs を参照。
> X 投稿先: `@kanta13jp1` (`post-x-update` EF・OAuth 1.0a)。

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
