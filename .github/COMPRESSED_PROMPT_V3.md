# 自分株式会社 統合プロンプト（圧縮版 v3）

## 🎯 ミッション

Flutter Web + Supabase で **21競合を統合するAIライフマネジメントアプリ** を構築。
本番: <https://my-web-app-b67f4.web.app/> / 実ユーザー: **4人** / **完成と言えるまで自己レビューを繰り返すこと**。

---

## 🔀 3インスタンス + Multi-AI 並行開発スコープ（2026-04-17 更新 — WEB版廃止 / v2.1.111対応）

> 詳細制約ログ・最新機能・次回推奨プロンプト: **`docs/INSTANCE_CONFIG.md`** 参照（正式版。`docs/instance-constraints.md` は段階的廃止中）。
> 新制約発見時はそのファイルに即追記し、この表の制約列も同時更新すること。

### Claude Code 3インスタンス構成 (WEB版 2026-04-17 廃止)

| インスタンス | 担当範囲 | 推奨モデル | 推奨モード | 主な制約 |
| --- | --- | --- | --- | --- |
| **VSCode版** | `lib/` + `supabase/functions/` + `docs/DESIGN.md` | `claude-opus-4-7` (設計) / `claude-sonnet-4-6` (通常) | 通常 / `/effort high` / Sonnet 4.6 + `ultrathink` | なし |
| **Windowsアプリ版** | `docs/` + `supabase/migrations/` + notebooklm CLI専任 | `claude-opus-4-7` (設計) / `claude-sonnet-4-6` (通常) | 通常 + CAVEMAN / Routines活用 | `PYTHONUTF8=1` 必須 / xlsxロック注意 |
| **PowerShell版** | `.github/workflows/` + `.mcp.json` + `docs/INSTANCE_CONFIG.md` | 定型: `haiku-4-5` / 設計: `claude-opus-4-7` | `/fast` (定型) / `/effort high` (設計) | GHA `${{}}` は env:ブロック経由 |
| ~~**WEB版**~~ | **廃止 (2026-04-17)** — GitHub MCP 不安定・境界違反 → 3インスタンス制に統一 | — | — | — |
| **Claude Schedule** | 自動タスク専用 (daily-report/cs-check/blog-draft等) | **git push 不可** (IP allowlist + 歴史的diverge) | 全ファイル更新は `mcp__plugin_github_github__create_or_update_file` 経由 | — |

### Claude 最新機能 活用ガイド (v2.1.111 対応・2026-04-17 更新)

| 機能 | 対応インスタンス | 使い所 |
| --- | --- | --- |
| **Opus 4.7 `/effort xhigh`** 🆕 | 全インスタンス | Adaptive Thinking の新 effortレベル (high と max の間)。アーキテクチャ設計・競合戦略で使用 |
| **`/ultrareview`** 🆕 | 全インスタンス | 並列マルチエージェントによる包括的コードレビュー。EF実装後・PR作成前の必須チェックに推奨 (`gh pr review` 代替) |
| **`/less-permission-prompts`** 🆕 | PowerShell版 | トランスクリプトスキャン→`.claude/settings.json` 自動許可リスト提案 |
| **PowerShell tool** 🆕 | PowerShell版 | `CLAUDE_CODE_USE_POWERSHELL_TOOL=1` でオプトイン (段階ロールアウト) |
| **Windows SessionStart hook 修正** 🆕 | Windowsアプリ版 | `CLAUDE_ENV_FILE` と SessionStart hook が Windows で正常動作 |
| **Extended Thinking (ultrathink)** | VSCode / Windowsアプリ / PowerShell | 複雑UI設計・DB schema・アーキテクチャ決定。**`claude-sonnet-4-6` 必須** (Opus 4.7 は非対応) |
| **Adaptive Thinking** | 全インスタンス | `claude-opus-4-7` + `/effort` で思考量自動調整 |
| **`/recap`** (v2.1.108+) | 全インスタンス | セッション開始時に前セッション作業サマリー自動生成 |
| **Routines** | Windowsアプリ版専任 | Desktop版専用サーバーレススケジューラ (Max 15回/日) |
| **Interleaved Thinking** | 全インスタンス | ツール実行中にも思考を継続。多ステップタスクで自動適用 |
| **CAVEMANモード** | Windowsアプリ / PowerShell 主体 | コミュニケーショントークン～75%削減 |

### 外部AI 最新モデル・機能

| AI | 最新モデル | 主な機能 | このプロジェクトでの用途 |
| --- | --- | --- | --- |
| **GitHub Copilot** | GPT-4o / Claude Sonnet / Gemini Pro 選择可 | Inline補完 / Copilot Edits (複数ファイル同時編集) / Copilot Workspace (Issue→PR自動) / `@workspace` | VSCode版: EditsでFlutter多ファイル編集 / PS版: `gh copilot suggest` |
| **Gemini Code Assist** | Gemini 2.5 Pro (2Mトークン) / Flash | Agent mode / Flutter/Dart特化 / 大規模リファクタ | EF全体横断分析 / Dart大規模リファクタ |
| **OpenAI CODEX** | o3 (最強推論) / o4-mini (高速低コスト) / Codex CLI | SQL最適化 / アルゴリズム / ターミナル直実行 | Supabaseクエリ最適化 / PS版: `codex` CLI |

### AI選択フロー

```text
行レベル補完                  -> GitHub Copilot Inline (Ctrl+Enter)
複数ファイル同時編集 (VSCode)    -> Copilot Edits
複雑なDart/Flutter              -> Gemini 2.5 Pro (長コンテキスト+Flutter特化)
SQL / アルゴリズム最適化          -> CODEX o3/o4-mini
設計・戦略・長期判断            -> Claude Code (Memory + ROADMAP)
複雑な推論・アーキテクチャ       -> Claude Extended Thinking (opus/sonnet)
ブログ / 競合リサーチ           -> Windowsアプリ版 (WebSearch/WebFetch + notebooklm CLI)
NotebookLM Deep Research      -> Windowsアプリ版専任 (notebooklm CLI)
Issue -> PR 全自動              -> Copilot Workspace
```

### 制約発見時の更新フロー（全インスタンス共通）

```text
Step 1: docs/instance-constraints.md の「制約発見ログ」に追記
Step 2: この表の制約列を更新
Step 3: memory/feedback_correction_YYYYMMDD.md に記録
Step 4: cross-instance-pr で他インスタンスへ周知
```

### セッション開始時 バージョンチェック（全インスタンス必須）

詳細: `docs/tool-versions.md` / チェックスクリプト: `scripts/check_versions.py`

| インスタンス | 実行コマンド | 更新時のアクション |
| --- | --- | --- |
| VSCode / Windowsアプリ / PowerShell | `PYTHONUTF8=1 python3 scripts/check_versions.py` | 制約解消チェックリストを確認し `docs/tool-versions.md` を更新 |

**新モデルリリース時**: `ai-assistant` EF の `DEFAULT_SYNTHESIS_MODEL` + 各 EF のモデルパラメータを更新する。

### クオータ監視 (quota-monitor.yml 毎日 09:00 JST)

| ツール | 監視方法 | アラート閃値 |
| --- | --- | --- |
| Claude (Anthropic API) | `/v1/usage` | 月次 $50 |
| OpenAI (CODEX) | `/v1/usage` | 月次 $20 |
| Gemini Code Assist | Google Cloud Monitoring | 月次クオータ 80% |
| GitHub Copilot | `/user/copilot_billing` | シート数上限近接 |

**緊急横断権限**: blocking 時は `docs/cross-instance-prs/YYYYMMDD_<内容>.md` に提案をコミット。担当インスタンスが次セッションで採否。
**競合回避パターン**: `git stash -> git pull --rebase origin main -> git push -> git stash pop`
---

## 🏆 競合21社（全機能を統合して超える）

notion, evernote, moneyforward, x, animaworks, claude-code, codex, netkeiba, openclaw, claude-cowork, chatwork, slack, jobcan, amazon, google, microsoft, discord, line, facebook, liven, github

---

## 📊 必須実装（ホーム画面21本の進捗バー）

各競合1本ずつ **短期/中期/長期目標** + 現在達成率を表示。`get-growth-roadmap-progress` EF がデータ源。

---

## 🧩 コア機能リスト（実装済み含む）

| # | 機能 | 状態 | 主要EF / 担当 |
| --- | --- | --- | --- |
| 1 | **競合機能比較ページ** (21社×機能マトリクス) | ✅ | `get-competitor-features` |
| 2 | **EF UI導線カバレッジ** (未接続→GitHub Issue自動生成) | ✅ | `edge-function-coverage` |
| 3 | **開発実績タイムライン** | ✅ | `development-achievements` |
| 4 | **ブログ自動投稿** (Zenn/Qiita/note/dev.to等, `blog_posts`テーブル管理) | ✅ | `blog-post-manager`, `blog-auto-publisher` |
| 5 | **モバイルギターレコーディングスタジオ** (H.264録画 + X自動シェア + AI演奏評価) | ✅ | `guitar-recording-studio` |
| 6 | **AI仮想秘書** (日次判定・タスク提案・スケジュール管理) | ✅ | `daily-judgment`, `ai-assistant` |
| 7 | **地方選挙インテリジェンス** (47都道府県×1年先×週末X投稿) | ✅ LP済 | `local-election-intelligence`, `gemini-election-analysis` |
| 8 | **バイラル動画パイプライン** (自動生成→投稿→効果測定) | ✅ LP済 | `viral-video-ad-generator`, `x-media-post`, `viral-growth-engine` |
| 9 | **Real Value YouTube競合分析** | ✅ CI/CD自動化済 | Python: `fetch_yt.py` + `update_tsv.py` → `youtube-analysis.yml` 毎日11:00 JST |
| 10 | **メモ画像貼り付け** (Note/Notion風ドラッグ&ドロップ + クリップボードペースト → Supabase Storage) | ✅ | `memo-image-upload` (VSCode版) |
| 11 | **ユーザーフィードバックパイプライン** (フォーム投稿→お礼メール+GH Issue+管理者一覧+スケジュール自動修正+リリース通知メール) | ✅ | `submit-feedback`, `notify-feature-request` |
| 12 | **コンソールエラー自動フィードバック投稿** (`FlutterError.onError` → `submit-feedback` EF に `type=auto_error` 自動送信) | ✅ | `submit-feedback` (VSCode版: `lib/utils/error_reporter.dart` + `main.dart`) |
| 13 | **思考妨害排除ガード** (デジタル/衝動/SNS 依存をブロック・断ち切り日数追跡 — 競合21社に存在しない唯一の機能) | ✅ LP済 | `lib/pages/abstinence_guard_page.dart` (VSCode版) |
| 14 | **ブログ記事実投稿パイプライン** (下書き自動生成済み → Zenn/Qiita/note への実投稿自動化) | ✅ | `blog-post-manager`, `blog-auto-publisher` |
| 15 | **見栄ガード** (かっこつけない・見栄をはらない仕組み — 衝動的自己顕示を可視化・抑制) | ✅ LP済 | `lib/pages/` (VSCode版) |
| 16 | **浪費トラッキング** (投資を除いた資産放出の記録・可視化) | ✅ LP済 | `lib/pages/` (VSCode版) |
| 17 | **12部署仮想組織 / AI秘書ゴール設定** (Slack・Chatwork・ジョブカン対抗軸) | ✅ LP済 | `AgentOrgPage` (VSCode版) |
| 18 | **コンビニ経営シミュレーション** (`conveni_stores` テーブル連携) | ✅ LP済 | `lib/pages/` (VSCode版) |
| 19 | **友達招待 / 紹介コード** (ReferralShareCard — ホーム画面常設) | ✅ LP済 | `lib/widgets/` (VSCode版) |
| 20 | **ノートコメント + 絵文字リアクション + OGP シェア** (Notion/Evernote 対抗ソーシャル連携) | ✅ LP済 | `lib/pages/` (VSCode版) |
| 21 | **通知センター** (NotificationsPage — `notification-center` EF 連携) | ✅ LP済 | `lib/pages/` (VSCode版) |
| 22 | **電子署名** (法人・フリーランス向け — GitHub DocuSign 連携と直接競合) | ✅ LP済 | EF: `e-signature` 系 (VSCode版) |
| 23 | **集中タイマー** (ポモドーロ/ディープフォーカス — 思考妨害排除ガードと連携) | ✅ LP済 | `lib/pages/` (VSCode版) |
| 24 | **AI文章アシスタント** (文章作成・推敲・要約) | ✅ LP済 | `lib/pages/` (VSCode版) |
| 25 | **浪費耐性トレーニング** (浪費トラッキングと連携した行動変容トレーニング) | ✅ LP済 | `lib/pages/` (VSCode版) |
| 26 | **語学学習** (フラッシュカード・発音練習・進捗管理) | ✅ LP済 | `lib/pages/` (VSCode版) |
| 27 | **レシピ管理** (食材管理・献立提案・栄養分析) | ✅ LP済 | `lib/pages/` (VSCode版) |
| 28 | **旅行計画** (行程管理・現地情報・費用管理) | ✅ LP済 | `lib/pages/` (VSCode版) |
| 29 | **ペット管理** (健康記録・ワクチン管理・日記) | ✅ LP済 | `lib/pages/` (VSCode版) |
| 30 | **フォトギャラリー** (AI分類・思い出管理・共有) | ✅ LP済 | `lib/pages/` (VSCode版) |
| 31 | **マイAIエージェント** (ユーザー定義タスク自動化フロー — Notion Custom Agents 対抗) | ✅ LP済 | `lib/pages/ai_agent_page.dart` + `my-ai-agent` EF (VSCode版) |
| 32 | **習慣ゲーミフィケーション** (ポイント・バッジ・ストリーク — Habitica 競合) | ✅ LP済 | `lib/pages/` (VSCode版) |
| 33 | **コードプレイグラウンド** (ブラウザ内コード実行・学習環境) | ✅ LP済 | `lib/pages/` (VSCode版) |
| 34 | **不動産管理** (物件管理・賃料追跡・投資分析) | ✅ LP済 | `lib/pages/` (VSCode版) |
| 35 | **eラーニング** (コース管理・進捗・資格対策 — Duolingo/Udemy 競合) | ✅ LP済 | `lib/pages/` (VSCode版) |
| 36 | **車両管理** (車検・保険・燃費・整備記録) | ✅ LP済 | `lib/pages/` (VSCode版) |
| 37 | **採用ボード** (求職管理・応募追跡・面接スケジュール) | ✅ LP済 | `lib/pages/` (VSCode版) |
| 38 | **IoTダッシュボード** (デバイス連携・センサーデータ可視化) | ✅ LP済 | `lib/pages/` (VSCode版) |
| 39 | **法務管理** (契約書管理・法的期限追跡) | ✅ LP済 | `lib/pages/` (VSCode版) |
| 40 | **メールテンプレート管理** (ビジネス/プライベート定型文) | ✅ LP済 | `lib/pages/` (VSCode版) |
| 41 | **2FA セキュリティ** (多要素認証強化 — セキュリティ差別化) | ✅ LP済 | `lib/pages/` (VSCode版) |
| 42 | **公開ギターギャラリー** (録音UGC公開共有 — sitemap/OGP済) | ✅ LP済 | `guitar-recording-studio` `public_gallery` action (VSCode版) |
| 43 | **月次カレンダービュー** (TableCalendar — スケジュール管理強化) | ✅ LP済 | `lib/pages/` (VSCode版) |
| 44 | **SaaSデータインポート** (Notion/Evernote/Markdown → 一括インポートUI+EF) | ✅ LP済 | `lib/pages/import_page.dart` + `growth-import-preview`, `growth-import-commit` (VSCode版) |
| 45 | **アクティビティフィード** (行動ログ・達成記録タイムライン — Discord/Slack対抗) | ✅ LP済 | `lib/pages/activity_feed_page.dart` (VSCode版) |
| 46 | **報酬・達成バッジ** (ポイント・バッジ獲得ゲーミフィケーション) | ✅ LP済 | `lib/pages/rewards_page.dart` (VSCode版) |
| 47 | **支払いリマインダー** (月次サブスク・公共料金・ローン返済 — MoneyForward対抗) | ✅ LP済 | `lib/pages/payment_reminder_page.dart` (VSCode版) |
| 48 | **マインドマップ** (ノード追加・拡大縮小スクロール — アイデア整理・思考可視化) | ✅ LP済 | `lib/pages/` (VSCode版) |
| 49 | **ビデオ会議・ミーティング管理** (ビデオ通話・会議室予約・議事録自動生成 — Zoom/Meet対抗) | ✅ LP済 | `lib/pages/video_meeting_page.dart`, `meeting_manager_page.dart` (VSCode版) |
| 50 | **スマート受信箱** (AIメール・通知・タスク自動分類・優先度付け) | ✅ LP済 | `lib/pages/smart_inbox_triage_page.dart` (VSCode版) |
| 51 | **パスワード金庫** (ゼロ知識暗号化・自動入力・セキュリティ監査 — 1Password対抗) | ✅ LP済 | `lib/pages/password_vault_page.dart` (VSCode版) |
| 52 | **ポッドキャスト管理** (制作・公開・リスナー分析 — Anchor/Spotify対抗) | ✅ LP済 | `lib/pages/podcast_manager_page.dart` (VSCode版) |
| 53 | **スクリーン録画** (ブラウザ録画・即時共有 — Loom対抗) | ✅ LP済 | `lib/pages/screen_recorder_page.dart` (VSCode版) |
| 54 | **オークション・マーケットプレイス** (フリマ・出品・決済 — メルカリ/ヤフオク対抗) | ✅ LP済 | `lib/pages/auction_marketplace_page.dart` (VSCode版) |
| 55 | **音声メモ文字起こし** (AI自動文字起こし・要約 — Otter.ai対抗) | ✅ LP済 | `lib/pages/voice_memo_transcriber_page.dart` (VSCode版) |
| 56 | **仮想ホワイトボード** (コラボキャンバス — Miro/FigJam対抗) | ✅ LP済 | `lib/pages/virtual_whiteboard_page.dart` (VSCode版) |
| 57 | **ワークフロー自動化** (トリガー&アクション ノーコード自動化 — Zapier対抗) | ✅ LP済 | `lib/pages/workflow_automation_page.dart` (VSCode版) |
| 58 | **QRコード生成** (URL・テキスト→QR即時変換・共有) | ✅ LP済 | `lib/pages/qr_code_generator_page.dart` (VSCode版) |
| 59 | **AI役員会議 (MAGI)** (CEO/CFO/CMO/CHRO AIペルソナが多角的アドバイス — 競合21社に存在しない独自機能) | ✅ LP済 | `lib/pages/cfo_office_page.dart`, `cho_office_page.dart`, `chro_office_page.dart`, `cmo_office_page.dart` (VSCode版) |
| 60 | **記憶ドリル** (忘却曲線に基づく反復学習 — Evernoteにはない学習機能) | ✅ LP済 | `lib/pages/memory_drill_page.dart` (VSCode版) |
| 61 | **経営コックピット** (収支・資産・KPIを一画面で管理 — MoneyForward代替) | ✅ LP済 | `lib/pages/home_page.dart` (VSCode版) |
| 62 | **公開メモ・SEO** (メモをURLで共有・知識アウトプットが集客につながる) | ✅ LP済 | `lib/pages/public_memo_directory_page.dart` (VSCode版) |
| 63 | **性格診断 (16タイプ MBTI)** (MBTIベース自己分析・学習スタイル最適化・恋愛相性診断) | ✅ LP済 | `lib/pages/personality_test_questions_page.dart` (VSCode版) |
| 64 | **アクセス制御・権限管理** (ロール設定・ユーザー権限・アクセスログ — ジョブカン対抗) | ✅ LP済 | `lib/pages/access_control_page.dart` (VSCode版) |
| 65 | **在庫・バーコード管理** (商品スキャン・在庫追跡・入出庫記録 — Amazon対抗) | ✅ LP済 | `lib/pages/inventory_barcode_page.dart` (VSCode版) |
| 66 | **テンプレート広場** (6カテゴリ18種テンプレート即適用 — Notionマーケットプレイス対抗) | ✅ LP済 | `lib/pages/template_marketplace_page.dart` (VSCode版) |
| 67 | **パーソナルダッシュボード** (ノート・タスク・習慣・集中時間KPIチャート可視化 — Notion 3.4対抗) | ✅ LP済 | `lib/pages/personal_dashboard_page.dart` (VSCode版) |
| 68 | **Google カレンダー同期** (アプリ予定 ↔ Google カレンダー双方向同期・複数カレンダー管理) | ✅ LP済 | `lib/pages/google_calendar_sync_page.dart` (VSCode版) |
| 69 | **MoneyForward 連携** (銀行・証券・クレカ残高自動取り込み・総資産管理 — MoneyForward対抗) | ✅ LP済 | `lib/pages/money_forward_page.dart` (VSCode版) |
| 70 | **Slack 通知連携** (タスク・習慣・リクエストをSlackチャンネルへリアルタイム通知 — Slack対抗) | ✅ LP済 | `lib/pages/slack_notification_page.dart` (VSCode版) |
| 71 | **マイスキル (AIプロンプト再利用)** (よく使うプロンプトをスキル保存・1タップ再利用 — Slackワークフロービルダー対抗) | ✅ LP済 | `lib/pages/my_skills_page.dart` (VSCode版) |
| 72 | **チームチャット** (チャンネル別リアルタイムメッセージング — Discord/LINE対抗) | ✅ LP済 | `lib/pages/team_chat_page.dart` (VSCode版) |
| 73 | **ヘルスコーチ** (歩数・カロリー・睡眠・水分AI統合分析 — Liven対抗) | ✅ LP済 | `lib/pages/health_coach_page.dart` (VSCode版) |
| 74 | **ショッピングリスト** (買い物リスト・価格管理・購入チェック — Amazon対抗) | ✅ LP済 | `lib/pages/shopping_list_page.dart` (VSCode版) |
| 75 | **Discord 通知連携** (Webhook URLでタスク完了・習慣達成をDiscordチャンネルに自動通知 — Discord対抗) | ✅ LP済 | `lib/pages/discord_notification_page.dart` (VSCode版) |
| 76 | **LINE 通知連携** (LINE Notifyトークンでタスク・習慣・ゴール達成をLINEに自動通知 — LINE対抗) | ✅ LP済 | `lib/pages/line_notification_page.dart` (VSCode版) |
| 77 | **GitHub PR 管理** (GitHubリポジトリのPR一覧・レビュー状況・統計をアプリ内で一元管理 — GitHub対抗) | ✅ LP済 | `lib/pages/github_pr_page.dart` (VSCode版) |
| 78 | **思考妨害パターン診断** (4質問で衝動・時間帯・前兆サインを特定し禁欲ガード自動設定 — THOUGHT_INTERRUPT_ELIMINATOR #T2) | ✅ LP済 | `lib/pages/thought_interrupt_diagnosis_page.dart` (VSCode版) |
| 79 | **週次 Slip パターンレポート** (30日間のslipを曜日・時間帯・要因別に集計しストリーク・改善トレンドを可視化) | ✅ LP済 | `lib/pages/weekly_slip_report_page.dart` (VSCode版) |
| 80 | **ゴール追跡** (OKR形式スモールゴール〜人生目標管理・進捗追跡・マイルストーン — Google/Notion対抗) | ✅ LP済 | VSCode版 |
| 81 | **AIサマリー** (ノート・タスク・習慣データをAIが自動要約・1日/週/月インサイト生成) | ✅ LP済 | VSCode版 |
| 82 | **収益予測** (過去データ×市場トレンドでAIが収益予測・キャッシュフロー可視化 — MoneyForward対抗) | ✅ LP済 | VSCode版 |
| 83 | **ブックマーク同期** (ブラウザ↔アプリ双方向同期・AI自動タグ付け・検索 — Notion対抗) | ✅ LP済 | VSCode版 |
| 84 | **天気・環境ウィジェット** (現在地天気・気温・紫外線をダッシュボード表示・AI活動提案) | ✅ LP済 | VSCode版 |
| 85 | **アフィリエイト管理** (リンク管理・クリック追跡・報酬分析・AI収益最適化) | ✅ LP済 | `lib/pages/affiliate_marketing_page.dart` (VSCode版) |
| 86 | **CRM・営業パイプライン** (リード管理・商談ステージ・成約予測 — Salesforce対抗) | ✅ LP済 | `lib/pages/crm_sales_pipeline_page.dart` (VSCode版) |
| 87 | **スプレッドシートDB** (フィルタ・ソート・数式・API連携の多機能データ管理 — Notion対抗) | ✅ LP済 | `lib/pages/spreadsheet_database_page.dart` (VSCode版) |
| 88 | **SNS投稿スケジューラー** (X/Instagram/Facebook最適時間自動予約・AI改善提案) | ✅ LP済 | `lib/pages/social_media_scheduler_page.dart` (VSCode版) |
| 89 | **サブスク課金管理** (請求・顧客管理・解約防止分析の自動化 — Stripe対抗) | ✅ LP済 | `lib/pages/subscription_billing_page.dart` (VSCode版) |
| 90 | **アドレス帳・人脈管理** (連絡先・交流履歴・SNSリンク・人脈グラフ — LinkedIn対抗) | ✅ LP済 | `lib/pages/address_book_page.dart` (VSCode版) |
| 91 | **読書リスト管理** (読みたい本・読了記録・AI推薦 — 書評SNS対抗) | ✅ LP済 | `lib/pages/reading_list_page.dart` (VSCode版) |
| 92 | **ワードローブ管理** (所持服登録・コーデ提案・購入計画のAI最適化) | ✅ LP済 | `lib/pages/wardrobe_page.dart` (VSCode版) |
| 93 | **カーボンフットプリント** (CO2排出量自動計算・可視化・持続可能生活設計) | ✅ LP済 | `lib/pages/carbon_footprint_tracker_page.dart` (VSCode版) |
| 94 | **タイムトラッキング** (プロジェクト別作業時間自動記録・AI分析 — Toggl対抗) | ✅ LP済 | `lib/pages/time_tracker_page.dart` (VSCode版) |
| 95 | **Wikiデータベース** (階層式Wiki・社内マニュアル・ナレッジベース — Confluence対抗) | ✅ LP済 | `lib/pages/wiki_database_page.dart` (VSCode版) |
| 96 | **WIPリミット管理** (進行中タスク上限設定・ボトルネック検出・リーンカンバン — Jira対抗) | ✅ LP済 | `lib/pages/wip_limit_page.dart` (VSCode版) |
| 97 | **技術ブログトラッカー** (Zenn/Qiita/note投稿管理・PV分析・読者獲得トレンド) | ✅ LP済 | `lib/pages/tech_blog_tracker_page.dart` (VSCode版) |
| 98 | **予約・アポイント管理** (来客・医療・会議の予約カレンダー連携 — Calendly対抗) | ✅ LP済 | `lib/pages/appointment_scheduler_page.dart` (VSCode版) |
| 99 | **API プレイグラウンド** (REST API・Supabase EFのブラウザテスト環境 — Postman対抗) | ✅ LP済 | `lib/pages/api_playground_page.dart` (VSCode版) |
| 100 | **データ分析エクスポート** (ノート・タスク・習慣・財務データのCSV/JSON/PDF一括出力) | ✅ LP済 | `lib/pages/analytics_export_page.dart` (VSCode版) |
| 101 | **駐車場予約管理** (空き確認・予約・支払い管理 — 施設・イベント会場運用) | ✅ LP済 | `lib/pages/parking_reservation_page.dart` (VSCode版) |
| 102 | **AR ナビゲーション** (拡張現実でルートをスマホ画面に重畳表示 — 競合21社に存在しない独自機能) | ✅ LP済 | `lib/pages/ar_navigation_page.dart` (VSCode版) |
| 103 | **資産管理** (不動産・株・仮想通貨・現金のポートフォリオ一元管理・AI最適化提案) | ✅ LP済 | `lib/pages/asset_management_page.dart` (VSCode版) |
| 104 | **行動・習慣ログ詳細** (1分単位行動ログ・習慣連続記録・AI生活リズム分析) | ✅ LP済 | `lib/pages/behavior_log_page.dart` (VSCode版) |
| 105 | **断捨離アシスト** (モノ・デジタル・人間関係の断捨離AI支援3ステップ) | ✅ LP済 | `lib/pages/danshari_page.dart` (VSCode版) |
| 106 | **プリズンモード** (SNS/動画完全シャットアウトの超高集中モード — 競合21社に存在しない独自機能) | ✅ LP済 | `lib/pages/prison_mode_page.dart` (VSCode版) |
| 107 | **ソーシャルフィード** (達成記録・習慣ストリーク・ノート共有タイムライン — Facebook/Discord対抗) | ✅ LP済 | `lib/pages/social_feed_page.dart` (VSCode版) |
| 108 | **意思決定チェック** (認知バイアス診断・クリアな判断支援 — 競合21社に存在しない独自機能) | ✅ LP済 | `lib/pages/decision_check_page.dart` (VSCode版) |
| 109 | **デジタルウォレット** (ポイント・ギフト券・仮想通貨・電子マネー一元管理) | ✅ LP済 | `lib/pages/digital_wallet_page.dart` (VSCode版) |
| 110 | **バーチャルペット** (タスク達成・習慣継続でペット成長するゲーミフィケーション) | ✅ LP済 | `lib/pages/virtual_pet_page.dart` (VSCode版) |
| 111 | **リアル断捨離記録** (実物写真記録・手放し数値化・身軽さ可視化) | ✅ LP済 | `lib/pages/real_world_danshari_page.dart` (VSCode版) |
| 112 | **思考アンカー** (雑念・不安・割り込みをキャプチャしアンカー変換する認知制御機能) | ✅ LP済 | `lib/pages/thought_anchor_page.dart` (VSCode版) |
| 113 | **思考キャプチャ** (0.5秒でひらめきをInboxキャプチャ・AI自動分類GTD式思考管理) | ✅ LP済 | `lib/pages/thought_capture_page.dart` (VSCode版) |
| 114 | **セマンティック検索** (意味・文脈で全データ横断検索するAI理解型検索エンジン — Notion対抗) | ✅ LP済 | `lib/pages/semantic_search_page.dart` (VSCode版) |
| 115 | **購買ログ・支出記録** (全購入品記録・家計簿自動分類・AI節約インサイト — Amazon対抗) | ✅ LP済 | `lib/pages/purchase_log_page.dart` (VSCode版) |
| 116 | **オーディオエフェクト** (ギター・楽器・音声エフェクト処理・ミキシング — GarageBand対抗) | ✅ LP済 | `lib/pages/audio_effects_processor_page.dart` (VSCode版) |
| 117 | **AI画像生成** (テキスト→画像即時生成・プレゼン/SNS/ブログ素材AIクリエイティブ — Midjourney対抗) | ✅ LP済 | `lib/pages/ai_image_generator_page.dart` (VSCode版) |
| 118 | **AI横断検索** (全データをAI横断検索するパーソナルナレッジ検索エンジン) | ✅ LP済 | `lib/pages/ai_search_page.dart` (VSCode版) |
| 119 | **現実確認チェック** (目標・計画・実績を客観スコアリング・バイアス排除意思決定支援 — 独自機能) | ✅ LP済 | `lib/pages/reality_check_page.dart` (VSCode版) |
| 120 | **相性チェック** (人・目標・習慣・ライフスタイルのAI相性スコア多角分析) | ✅ LP済 | `lib/pages/compatibility_check_page.dart` (VSCode版) |
| 121 | **サイトマップ分析** (全URL可視化・SEO健全性チェック・クロール最適化) | ✅ LP済 | `lib/pages/sitemap_analytics_page.dart` (VSCode版) |
| 122 | **顧客フィードバック** (ユーザーの声一元収集・AI分析・優先度付け — Intercom対抗) | ✅ LP済 | `lib/pages/customer_feedback_page.dart` (VSCode版) |
| 123 | **変更履歴管理** (コード・ドキュメント変更の自動追跡・Changelog自動生成) | ✅ LP済 | `lib/pages/changelog_manager_page.dart` (VSCode版) |
| 124 | **支払いチャンネル台帳** (複数支払い手段・口座のAI自動仕訳・可視化台帳) | ✅ LP済 | `lib/pages/payment_channel_ledger_page.dart` (VSCode版) |
| 125 | **AI自律エージェント** (ゴール→タスク自律分解・実行するAutoGPT超えの専用AI) | ✅ LP済 | `lib/pages/ai_agent_page.dart` (VSCode版) |
| 126 | **AI仮想秘書** (スケジュール・タスク・メール全自動管理の専属デジタル秘書) | ✅ LP済 | `lib/pages/ai_secretary_page.dart` (VSCode版) |
| 127 | **利用統計ダッシュボード** (全機能利用状況・ユーザー行動・エンゲージメントのリアルタイム可視化) | ✅ LP済 | `lib/pages/stats_page.dart` (VSCode版) |
| 128 | **タグ・カテゴリ管理** (AI自動タグ付け+手動分類の知識分類システム) | ✅ LP済 | `lib/pages/categories_page.dart` (VSCode版) |
| 129 | **AI文章添削** (日本語誤字・文法・表現のリアルタイム添削・校正エンジン) | ✅ LP済 | VSCode版 |
| 130 | **プレミアムコンテンツ販売** (ノート・テンプレート・スキル販売×収益化 — デジタル販売SaaS対抗) | ✅ LP済 | VSCode版 |
| 131 | **オンラインコミュニティ** (テーマ別コミュニティ・勉強会・習慣チャレンジ — Discord対抗) | ✅ LP済 | VSCode版 |
| 132 | **AIメンタルヘルスケア** (気分・ストレス・睡眠トラッキング＋AI改善提案 — Calm/Headspace対抗) | ✅ LP済 | `lib/pages/mental_health_tracker_page.dart` (VSCode版) |
| 133 | **フリーランス管理** (案件・請求書・契約管理 — freee/MoneyForward対抗) | ✅ LP済 | `lib/pages/freelance_manager_page.dart` (VSCode版) |
| 134 | **AIプレゼンビルダー** (スライド自動生成・テンプレート — Gamma/Canva対抗) | ✅ LP済 | `lib/pages/ai_presentation_builder_page.dart` (VSCode版) |
| 135 | **データバックアップ** (全データ自動バックアップ・クラウド同期・ワンクリック復元 — Dropbox/iCloud対抗) | ✅ LP済 | `lib/pages/data_backup_page.dart` (VSCode版) |
| 136 | **コンテンツカレンダー** (SNS投稿・ブログ・動画制作スケジュール管理) | ✅ LP済 | `lib/pages/content_calendar_page.dart` (VSCode版) |
| 137 | **家計・予算プランナー** (月次予算設定・支出追跡・AI節約提案 — MoneyForward/Zaim対抗) | ✅ LP済 | `lib/pages/home_budget_planner_page.dart` (VSCode版) |
| 138 | **ブレインダンプ** (GTD式マインドクリアリング — 頭の中の全てを書き出しAI自動分類 — Evernote対抗) | ✅ LP済 | `lib/pages/brain_dump_page.dart` (VSCode版) |
| 139 | **プロジェクト管理** (ガントチャート・スプリント計画・マイルストーン管理 — Asana/Jira対抗) | ✅ LP済 | `lib/pages/project_gantt_page.dart` (VSCode版) |
| 140 | **名刺管理** (OCR+AI連絡先自動抽出・タグ管理・人脈グラフ — Eight対抗) | ✅ LP済 | `lib/pages/business_card_manager_page.dart` (VSCode版) |
| 141 | **家族カレンダー** (家族スケジュール共有・タスク割当・誕生日管理 — Googleカレンダー対抗) | ✅ LP済 | `lib/pages/family_calendar_page.dart` (VSCode版) |

---

## 🎨 デザインシステム

- **`docs/DESIGN.md`** が唯一の真実ソース（Orange+Indigo ダークテーマ）
- **毎セッション必須ツールチェーン (Rule #19)**: `Nanobanana API` × `Figma MCP` × `AIDesigner MCP` × **`design-skills` サブエージェント** × `DESIGN.md` を組み合わせて UI 改善。詳細: `docs/DESIGN_TOOLING_SETUP.md`
- 日本語本文: `letter-spacing: 0`, `line-height: 1.7〜2.0`, `palt` は見出しのみ
- 参考デザインシステム: `docs/design-systems/` (note / freee / SmartHR / Apple JP / WIRED.jp)

---

## 🛠 開発ルール（常時適用）

1. **`flutter analyze` 常に 0エラー** — CI強制ゲート（`continue-on-error` 禁止）
2. **`deno lint` 常に 0エラー** — CI強制ゲート（`denoland/setup-deno@v2`）
3. **`docs/GROWTH_STRATEGY_ROADMAP.md` を毎回更新** — セッション記録を末尾追記
4. **ダミーデータ禁止** — Supabase 実データ必須
5. **Edge Function ファースト** — 複雑ロジックはバックエンドに移動
6. **シンプルさ優先** — 依頼外機能の追加禁止
7. **EFハードキャップ: 50本以下 (Tier1/Tier2廃止)** — `deploy-prod.yml` にデプロイするEFは常に50本以下 (現在15本)。新規機能は必ず既存hubのaction追加で対応。新規EF作成は既存EFを統合して50本以下を維持した場合のみ許可。Hub構成: standalone 4本 + macro-hub 6本 + mega-hub 5本 = 15本
8. **毎セッション: 矛盾チェック（全インスタンス）** — 実装 (`lib/` / `supabase/functions/`) / 設計書 (`docs/DESIGN.md` / `docs/GROWTH_STRATEGY_ROADMAP.md`) / ユーザーマニュアル (`lib/pages/user_manual_page.dart`) を照合し、矛盾があれば修正する
9. **毎セッション: markdownlint（全インスタンス）** — `npx markdownlint-cli --dot "docs/**/*.md" ".github/**/*.md" "CLAUDE.md"` を実行し指摘があれば修正する（自動生成・アーカイブは `.markdownlintignore` で除外済み）
10. **毎セッション: docs/ 戦略ドキュメント全件分析・開発計画反映（全インスタンス）** — `docs/` 配下の常設ドキュメント（自動生成・アーカイブを除く）を全件読み、以下を実施する: (a) 矛盾・鮮度切れを修正、(b) 未着手タスク・ブロッカーを `COMPRESSED_PROMPT_V3.md` の「実装待ち」セクションに追記。対象: `docs/CICD_SETUP_GUIDE.md` / `docs/CONTRIBUTING.md` / `docs/MULTI_INSTANCE_COORDINATION.md` / `docs/README.md` / `docs/DESIGN_TOOLING_SETUP.md` / `docs/technical/*.md` / `docs/roadmaps/*.md` / `docs/user-docs/*.md`。除外: `docs/daily-reports/`, `docs/cs-notes/`, `docs/blog-drafts/`, `docs/blog/`, `docs/competitor-reports/`, `docs/incident-reports/`, `docs/security-audit/`, `docs/archive/`, `docs/email-templates/`, `docs/weekly-drafts/`
11. **セッション開始: Master Brain 参照（必須）** — `memory/MEMORY.md` を必ず読んで前回の成功パターン・禁止事項・発見を最初に把握する。「記憶が消える弱点」を永続メモリで補う
12. **重い分析は `/deep-research` 必須** — 3ファイル以上の同時分析・URL調査・競合リサーチ・大量ドキュメント俯瞰 → `notebooklm` CLI で NotebookLM に委譲。Claude は「判断・編集・統合」にこそトークンを使う。`notebooklm source add-research` で Web Deep Research、`notebooklm generate` でスライド/フラッシュカード/音声等を無料生成
13. **セッション終了: `/wrap-up` 必須** — 作業完了後は必ず `/wrap-up` を実行して学習を `memory/` に永続保存。怠るとセッション間の記憶が消え、同じ失敗を繰り返す
14. **`/wrap-up` 内: 次回タスク候補の提案（必須）** — 未完了タスクの有無に関わらず、セッション終了時に必ず次回実施タスク候補 3〜5件を優先度付きで提案する。提案元: ①未完了タスク ②COMPRESSED_PROMPT_V3「実装待ち」 ③GROWTH_STRATEGY_ROADMAP「次回優先」 ④競合脅威タスク ⑤タスク T-1 技術記事投稿。フォーマットは `wrap-up.md` の Step 6 に従う
15. **毎セッション: AI大学キラーコンテンツ改善検討（全インスタンス）** — AI大学はユーザー獲得最重要機能。毎セッションで以下を必ず検討する: (a) 新規AIプロバイダー追加候補 (WebSearch → 技術革新性・API公開・話題性で評価)、(b) ランキング・達成バッジ・学習連続日数など未実装機能を1件以上進める、(c) ホームバナー (`AiUniversityHomeCard`) のクリック率向上策 (文言・デザイン改善)。詳細は `CLAUDE.md` の「AI大学 キラーコンテンツ化方針」セクションおよび本ファイルの「機能強化 #T3」を参照
16. **毎セッション: Web/モバイル表示チェック（VSCode版 専任・修正）** — VSCode版は `flutter analyze 0エラー` 確認後、本番 `https://my-web-app-b67f4.web.app/` の主要ページ(ホーム/AI大学/LP/ランキング)をWeb・モバイル両方で確認し、レイアウト崩れ・テキスト切れ・ボタン重複・スクロール不具合を修正する。**他2インスタンスは確認のみ可・修正は VSCode版 に cross-instance-pr で依頼**
17. **毎セッション: GitHub Actions ワークフロー最適化チェック（PowerShell版 専任）** — PowerShell版が `.github/workflows/` を毎セッション見直す: (a) 常にエラーになるステップを無効化、(b) push + workflow_call 二重起動防止、(c) `continue-on-error: true` 乱用排除、(d) timeout-minutes 実態確認。**加えて全ブランチの CI 失敗を監視し `.github/ci-failures/<sha>.json` に記録する（他インスタンスは次セッション冒頭で確認）**。改善後は ROADMAP に記録する
18. **毎セッション: AI大学コンテンツ → 開発ワークフロー反映（全インスタンス）** — `ai_university_content` の最新 `news` または NotebookLM Master Brain に蓄積した AI ニュースを開発に活かす。評価軸: (a) **モデルアップグレード** — 新モデルが利用可能なら既存 EF (`ai-assistant`/`daily-judgment`/`gemini-election-analysis` 等) のモデルパラメータを更新、(b) **新 API 機能取り込み** — 音声生成・リアルタイム検索・画像生成など新機能を既存機能に統合できないか検討、(c) **コスト最適化** — より安価なモデルが登場したらバッチ処理 EF への採用を検討、(d) **差別化機能のヒント** — 競合 AI の新機能からユーザー価値を逆算して未実装機能のアイデアを ROADMAP に追記。実施手順: `notebooklm ask "最新AIニュースから開発に使えそうな機能・APIを抽出して"` → 既存 EF との接続可能性を評価 → ROADMAP 追記 → 即対応可能なものは今セッションで実装
19. **毎セッション: UI改善ツールチェーン実行（VSCode版 専任）** — VSCode版のみ必須。`Claude Code` × `Nanobanana API` × `Figma MCP` × `AIDesigner MCP` × `design-skills` サブエージェント × `docs/DESIGN.md` を組み合わせて毎セッション UI を 1ページ以上改善する。**実施手順**: (1) `design-skills` サブエージェントで改善対象ページを `docs/DESIGN.md` と照合し「DESIGN.md 違反箇所・改善提案」を列挙、(2) **Figma MCP** でデザインコンポーネントを参照、(3) **AIDesigner MCP** でDesktop/Mobile 両対応改善案を生成、(4) **Nanobanana API** でデザインアセットを取得しコードに反映、(5) `lib/` に実装 → `flutter analyze 0エラー` → commit → ROADMAP 記録。**他2インスタンスはデザイン違反 lint レポート生成まで（コード修正は VSCode版 の cross-instance-pr へ）**。詳細: `docs/DESIGN_TOOLING_SETUP.md`

---

## 🤖 外部AI統合詳細（GitHub Copilot / Gemini Code Assist / CODEX）

Claude Code 4インスタンスを主軸に、以下3ツールを補完役割で活用。Claude Code のトークンを「判断・設計・統合」に集中させ、反復的な補完・実装支援は外部AIに委譲する。

### GitHub Copilot

GitHub Copilot は VS Code 内での **即座のコード補完・インライン Chat・PR 自動レビュー** を担当。Claude Code Schedule との役割分担で開発を加速。

### インスタンス別の GitHub Copilot 使用パターン

| 場面 | 使用方法 | 期待される成果 |
| --- | --- | --- |
| **コード補完（即座）** | `Ctrl+Enter` でインライン候補表示・受け入れ | 30-50% のコード時間削減・typo 自動修正 |
| **インライン Chat** | `Ctrl+I` で「`I#` 修正内容」を入力 | 単発修正・簡易リファクタリング 5分以内 |
| **Copilot Chat** | サイドバー Chat で複雑な判断・設計相談 | アーキテクチャ検討・パフォーマンス改善提案 |
| **PR Auto-Review** | `claude-agent-review.yml` による全PR自動レビュー | セキュリティ・ルール違反を自動検出・修正提案 |
| **コンテキスト活用** | `.github/COMPRESSED_PROMPT_V3.md` をシステムプロンプトに含める | プロジェクト文脈を理解した補完・提案 |

### 使用禁止パターン（ルール違反）

| 禁止パターン | 理由 | 推奨代替 |
| --- | --- | --- |
| ❌ ダミーデータ生成 | Rule #4 「ダミーデータ禁止」 | `supabase_flutter` で実データ取得 |
| ❌ `flutter analyze` エラー受け入れ | Rule #1 「常に 0エラー」 | Copilot に「flutter analyze 0エラーで修正」指示 |
| ❌ 複雑ロジックをフロントに配置 | Rule #5 「Edge Function ファースト」 | Copilot に「Edge Function として実装」指示 |
| ❌ 依頼外の大量機能追加 | Rule #6 「シンプルさ優先」 | Copilot に「最小限の実装」と明示指示 |
| ❌ セキュリティ考慮なしの API 実装 | セキュリティリスク | PR `claude-agent-review.yml` でレビュー必須 |

### Copilot Chat の推奨プロンプトパターン

```text
// 複雑な判断が必要な時
"このプロジェクトはFlutter Web + Supabase です。
COMPRESSED_PROMPT_V3.md の開発ルール #1-#19 に従い、
[具体的な問題・要望] について設計してください。"

// パフォーマンス改善
"このコードは [N+1クエリ/重い処理] を含む。
Supabase Edge Function への移行方法と手順を提案してください。"

// AI大学機能改善（Rule #15 連携）
"AI大学の [具体的な改善]。
毎セッション3Step (Step A: ホームカード / Step B: バイラル / Step C: リテンション) の内どれに該当しますか？"

// UI改善（Rule #19 連携）
"この UI コンポーネントを docs/DESIGN.md のカラートークン [具体色] を使って改善してください。
毎セッション UI改善チェーン (design-skills / Figma MCP / AIDesigner MCP) に合わせた修正をお願いします。"
```

### GitHub Copilot と Claude Code の役割分担

| 作業内容 | GitHub Copilot | Claude Code |
| --- | --- | --- |
| **行レベルのコード補完** | ✅ リアルタイム補完 | ❌ 不要 |
| **簡易修正（5分以内）** | ✅ `Ctrl+I` で即対応 | ❌ オーバーキル |
| **コード理解・リファクタリング** | ✅ 候補提示・Chat で検討 | ✅ 詳細実装・テスト |
| **プロジェクトルール統合** | ✅ コンテキスト活用 | ✅ ルール厳格適用 |
| **複雑な設計・判断** | 🟡 候補提示のみ | ✅ **最終判断・実装** |
| **セッション横断メモリ** | ❌ 不可 | ✅ `/wrap-up` で永続化 |
| **自動デプロイ・CI/CD** | ❌ 不可 | ✅ GitHub Actions 統合 |
| **長期計画・戦略** | ❌ 不可 | ✅ ROADMAP 更新 |

### `.github/COMPRESSED_PROMPT_V3.md` を Copilot のシステムプロンプトに含める方法

VS Code の `settings.json` に以下を追加:

```json
{
  "github.copilot.advanced": {
    "extra_headers": {},
    "debug.overrideSslVerification": false
  },
  "[markdown]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode",
    "editor.formatOnSave": true
  },
  "copilot.chat.projectContext": [
    ".github/COMPRESSED_PROMPT_V3.md",
    "docs/DESIGN.md",
    "CLAUDE.md"
  ]
}
```

これにより、Copilot Chat で質問する際に自動的にプロジェクトのルール・デザイン仕様を参照可能になります。

### Quality Gate（Copilot 提案を受け入れる前のチェックリスト）

Copilot からの提案を `accept` する前に必ず以下を確認:

- [ ] `flutter analyze` で新エラーが出ていないか？（Rule #1）
- [ ] ダミーデータを使っていないか？（Rule #4）
- [ ] Edge Function のスロット数が増えていないか？（Rule #7 EFハードキャップ）
- [ ] セキュリティ的に問題ないか？ （`ANTHROPIC_API_KEY` など機密がコミットされていないか）
- [ ] 依頼のスコープ内の修正か？（Rule #6 シンプルさ優先）
- [ ] 元のプロジェクト方針に一貫しているか？ （Notion/Supabase/Flutter Web 標準に従っているか）

### Gemini Code Assist 使用ガイド

**強み**: 長いコンテキスト（100K+）・Google API 知識・テスト自動生成

```text
// Gemini Code Assist で推奨する用途
1. 長い Dart ファイルのリファクタリング (500行以上)
2. Supabase Edge Function の Deno テスト生成
3. Google Calendar / Firebase 連携の実装支援
4. データモデル設計のレビューと改善提案

// 使用禁止パターン
❌ プロジェクト固有のルール (Rule #1-#19) を無視した提案を受け入れる
❌ EFハードキャップ (50本) を超える新 EF 生成
```

**VS Code での設定**: 拡張機能「Gemini Code Assist」をインストール → Google アカウントでサインイン

### OpenAI CODEX 使用ガイド

**強み**: コード特化・SQL生成・アルゴリズム最適化・多言語変換

```text
// CODEX で推奨する用途
1. Supabase PostgreSQL クエリの最適化 (N+1解消・インデックス設計)
2. Python スクリプト (fetch_yt.py / notebooklm_research.py) の改善
3. TypeScript Edge Function のアルゴリズム実装
4. Dart ↔ TypeScript コード変換支援

// API エンドポイント (Edge Function から呼び出す場合)
POST https://api.openai.com/v1/chat/completions
Authorization: Bearer $OPENAI_API_KEY
model: "gpt-4.1" | "o4-mini" | "codex-mini-latest"
```

**Supabase Secret**: `OPENAI_API_KEY` を設定済みの場合、`ai-assistant` EF の CODEX モードで利用可能

---

## ⚙️ GitHub Actions CI/CD（全20ワークフロー）

**全20本に完備済み**: `concurrency:` + `timeout-minutes:` + `$GITHUB_STEP_SUMMARY` + `permissions:`

| ワークフロー | トリガー | 特記事項 |
| --- | --- | --- |
| `ci.yml` | PR + push (staging/develop) ※main は deploy-prod が workflow_call で実行 | flutter analyze **強制** + deno lint **強制** + EF未分類警告 |
| `deploy-prod.yml` | push → main | CI再利用 + バージョン自動生成 + GitHub Release |
| `deploy-staging.yml` | push → staging | CI再利用 + staging channel デプロイ |
| `deploy-dev.yml` | push → develop | CI再利用 + dev channel デプロイ |
| `daily-report.yml` | 07:30 JST 毎日 | Supabase API + X投稿 + 競合モニタリング (Claude Scheduleの1.5時間前) |
| `cs-check.yml` | 毎時 :07 | CS自動対応 + PR自動レビュー + ヘルスチェック |
| `edge-function-audit.yml` | 毎時 :47 | EF UI導線カバレッジチェック + GitHub Issue自動生成 (timeout 10分) |
| `infra-health-check.yml` | 毎時 :37 | Firebase + 重要EF 6件監視 |
| `cron-batch.yml` | 毎6時間 (10:00/16:00/22:00/04:00 JST) + dispatch | Python分析バッチ — schedule 復活済み (PS#本セッション, 2026-04-16)。`SUPABASE_SERVICE_ROLE_KEY` / `GEMINI_API_KEY` シークレット要確認 |
| `dependency-audit.yml` | 月曜 08:00 JST | `pub outdated` + Deno import 固定チェック + **Deno std 古バージョン検出** + **pubspec.yaml 未固定パッケージ検出** |
| `claude-agent-review.yml` | PR (main/staging/develop) | **Claude Managed Agents** — PRオープン即時AIレビュー (`ANTHROPIC_API_KEY` 必須) |
| `feedback-issue-resolved.yml` | issues: [closed] | `user-feedback` ラベル Issue クローズ → `notify-feature-request` EF でリリース通知メール |
| `workflow-failure-handler.yml` | workflow_run: [completed] | 主要11ワークフロー失敗時 → GitHub Issue自動生成 (`workflow-failure` ラベル) → `cs-check` が自動修復 |
| `youtube-analysis.yml` | 毎日 11:00 JST | YouTube競合分析スナップショット (`fetch_yt.py` + `update_tsv.py`) → `updated_table.tsv` 更新・PR自動マージ |
| `ci-auto-fix.yml` | workflow_run: CI Checks 失敗時 | PR の `dart fix --apply` + `deno fmt` 自動修復コミット → 結果をPRにコメント |
| `blog-publish.yml` | workflow_dispatch | 技術記事手動投稿 (Qiita/dev.to) — `draft_path` / `platforms` / `dry_run` 入力、投稿後 frontmatter `published:true` 更新 |
| `ai-university-update.yml` | **2時間毎** + dispatch | AI大学コンテンツ自動更新 (18プロバイダー RSS → Supabase UPSERT → PR auto-merge)。Claude Schedule (4時間毎) が NotebookLM でリッチコンテンツを上書き |
| `ai-university-reminder.yml` | ⚠️ 新規 (2026-04-16) | AI大学学習リマインダー通知 (未実装学習者向け) |
| `horse-racing-update.yml` | ⚠️ 新規 (2026-04-16) | 競馬AI予想パイプラインの定期更新 (JRA/NAR データ取得・モデル学習) |

**dependabot**: Actions + pub + pip を毎週月曜自動PR (`flutter-version: '3.38.x'`)

### CI/CD 品質基準（達成済み事項）

- アクション最新化: `codecov@v5` / `softprops/action-gh-release@v2` / `supabase-cli v2.84.2`
- セキュリティ: 読み取り専用4本に `persist-credentials: false` (edge-function-audit / dependency-audit / cron-batch / claude-agent-review) / `ci.yml` に Firebase/Google 認証ファイル検出
- 堅牢性: Slack webhook `--max-time 10 || true` / 全3環境の notify に `continue-on-error: true`
- ビルド統一: 全環境 `--no-tree-shake-icons` 適用
- EF 管理: **ハードキャップ50本以下** (Tier1/Tier2廃止 / 現在15本デプロイ済み) / 15本構成: standalone 4本(get-home-dashboard/ai-assistant/growth-weekly-digest/guitar-recording-studio) + macro-hub 6本(core/growth/ai/admin/app/schedule) + mega-hub 5本(tools/media/enterprise/social-commerce/lifestyle) / 新規機能は必ず既存hubのaction追加で対応
- **Claude Managed Agents 統合** (`claude-agent-review.yml`): static解析では検出できないルール違反・EF上限・アーキテクチャを PR 毎に自動レビュー
- **フィードバックパイプライン** (`feedback-issue-resolved.yml`): Issue クローズ → HTML comment から `feature_request_id`/`app_feedback_id` 抽出 → PR cross-reference 取得 → リリース通知メール

---

## ⏰ Claude Code Schedule タスク（9本）

> GitHub Actions と **並行・補完**する関係。Actions がデータ収集・投稿を担当し、Claude Schedule が AI分析・コード修正を担当。

| Task | 時刻 | 内容 |
| --- | --- | --- |
| `daily-report` | 09:00 JST | Actions生成レポート確認 → AI分析追記 → X投稿(失敗時のみ) → commit |
| `cs-check` | 毎時 | 未返信チケット → FAQ返信 / バグ修正 / エスカレーション → PR自動レビュー |
| `github-issue-fix` | 10:00 JST | Open Issue → EF UI導線追加 / analyze エラー修正 → クローズ |
| `weekly-sns-draft` | 月 09:00 | 週次SNSドラフト + Zenn記事ネタ + 依存脆弱性チェック |
| `pr-auto-review` | 3時間毎 | セキュリティ/パフォ/バグ観点のPRレビュー |
| `competitor-monitoring` | 07:00 JST | 競合21社の可用性 + 最新ニュース調査 |
| `infra-health-check` | 毎時 :30 | `health-check` EF + Firebase Hosting 確認 |
| `dependency-audit` | 月 08:00 | `pub outdated` + Deno import バージョン検査 |
| `blog-draft` | 08:00 JST | 直近7日コミット → ブログ下書き → `blog_posts` テーブル登録 |
| `ai-university-update` | **4時間毎** | NotebookLM Deep Research → 18プロバイダー最新ニュースを Supabase UPSERT (GH Actions の RSS より深い情報で上書き) |

---

## 🔑 環境変数（Schedule 実行時）

```text
SUPABASE_DIGEST_URL=https://smmkxxavexumewbfaqpy.supabase.co/functions/v1/schedule-daily-digest
SUPABASE_SERVICE_KEY=<service_role key>
GITHUB_PAT=<repo + pull_requests スコープ>
```

X投稿先: **@kanta13jp1** (`post-x-update` EF, OAuth 1.0a 署名済み)

---

## 📁 主要ディレクトリ

```text
lib/pages/               # 219ページ (landing / comparison / user_manual / admin_analytics / personal_dashboard / my_skills 等)
lib/widgets/             # 共通ウィジェット (edge_function_summary_card.dart 等)
supabase/functions/      # Deno Edge Functions 250本 (デプロイ済み: 15本 / ハードキャップ50本以下 / Tier1/Tier2廃止)
supabase/migrations/     # YYYYMMDDXXXXXX_descriptive_name.sql
.github/workflows/       # 17本 (品質基準完備済み)
docs/
  GROWTH_STRATEGY_ROADMAP.md  # 全戦略・セッション記録 (毎回更新)
  DESIGN.md                   # デザイントークン (唯一の真実ソース)
  daily-reports/              # 日次レポート (GitHub Actions 生成)
  cs-notes/                   # CS チェックメモ
  weekly-drafts/              # 週次 SNS ドラフト
  blog-drafts/                # ブログ下書き
  competitor-reports/         # 競合モニタリング
  incident-reports/           # インシデントレポート
  security-audit/             # 脆弱性チェックレポート
web/index.html           # SEO meta tags
web/sitemap.xml          # URL マップ
```

---

## 📦 Edge Functions（Schedule連携 + 主要機能）

**Schedule連携 (必須)**:
`schedule-daily-digest` / `get-support-tickets` / `reply-support-request` / `get-home-dashboard` / `post-x-update` / `get-growth-roadmap-progress` / `get-competitor-features` / `health-check` / `check-competitor-updates`

**主要機能 EF**:
`guitar-recording-studio` / `local-election-intelligence` / `gemini-election-analysis` / `blog-post-manager` / `blog-auto-publisher` / `ai-assistant` / `daily-judgment` / `viral-video-generator` / `viral-growth-pipeline` / `development-achievements` / `edge-function-coverage` / `app-analytics-dashboard` / `submit-feedback` / `notify-feature-request` / `notification-center` / `onboarding-flow` / `seo-optimizer` / `ab-testing-manager` / `competitor-feature-sync` / `user-activity-tracker` / `webhook-manager` / `data-export-manager` / `viral-video-ad-generator` / `x-media-post` / `viral-growth-engine` / `viral-share-engine`

> **EFハードキャップ50本** (Tier1/Tier2廃止 / VSCode版#61): `deploy-prod.yml` のデプロイリスト15本のみ管理。新機能は既存hubのaction追加のみ。新規EF作成時は既存EFを統合して50本以下を維持すること。Hub構成: standalone 4本 + macro-hub 6本 + mega-hub 5本 = 15本。

---

## 🔜 実装待ち（他インスタンスへの指示）

### セッション 2026-04-16 VSCode版#76: 完了

**実施内容**: `horse_racing_predictor_page.dart` コードレビュー + デザイントークン統一

- ✅ UIコード全件レビュー（Null安全・型安全・デザイン整合性）
- ✅ Orange色 `0xFFFF6D00` → `0xFFFF6B35` に統一（9箇所）
- ✅ Gradient色 `0xFFFF9800` → `0xFFFF8C5A` に統一
- ✅ TabBar / AppBar / SegmentedButton / Info Container / Status / Prediction / History / Accuracy タブ全部改修
- ✅ `flutter analyze` 0エラー確認
- ✅ git commit `5bd60bde` / commit `6a9cab47` (ROADMAP更新) 完了

**セッション記録**: `docs/GROWTH_STRATEGY_ROADMAP.md` に記録済み

---

### ~~機能 #12~~: ✅ 全インスタンス解決済み

*(過去の解決済みタスク（機能 #12〜#32、バグ #B1, #B3, #B4、機能 #44）はアーカイブされ、プロンプトサイズ最適化のため削除されました。)*

### 現在のアクティブなタスク・課題

| タスク / 課題 | 担当 | 優先度 | 詳細 |
| --- | --- | --- | --- |
| **モバイルアプリ (iOS/Android) 対応** | VSCode版 | 🟡中 | Flutter モバイルビルド環境の整備と動作検証 |
| **Notion API 連携のメモリ最適化** | Web版 | 🟡中 | `growth-import-preview` EF の再帰ブロック取得時のメモリ使用量最適化 |
| **AI大学 新規プロバイダー検討** | Windows版 | 🟢低 | 79社目以降のプロバイダー（Reflection AI 公開時・AMI Labs API公開時・Muse Spark 等）の追加評価 |

### CI/CD改善 #C1: 2026-03-27 日次レポート分析からの反映 (PowerShell版#21, 2026-04-11)

**背景**: 2026-03-27 レポートで「競合監視3社のみ」「X投稿リトライなし」「Supabase API接続ブロック」が課題として確認。

| 課題 | 対応 | ステータス |
| --- | --- | --- |
| Supabase API接続ブロック (エグレスプロキシ) | `daily-report.yml` を GitHub Actions に移管し07:30 JSTに先行実行 | ✅ 解決済み (PS#19) |
| 競合監視が3社のみ (Notion/Evernote/Slack) | 7社に拡大: Slack/GitHub/Notion/Evernote/Discord/LINE/X | ✅ 解決済み (PS#21) |
| X投稿失敗時のリトライなし | 失敗時に20秒後1回リトライを追加 | ✅ 解決済み (PS#21) |
| ユーザー数4人で停滞 (2026-03-27〜2026-04-11) | LP機能追加・Zenn/Qiita自動投稿稼働中 → 継続監視 | 🔄 対応中 |

> ✅ **Windows版#21/#22 対応済み**: ユーザー獲得停滞緊急度記録。下書き54本(Zenn形式17本)蓄積確認 → タスク T-1 として計画化。

### タスク T-1: 技術記事の実投稿実行 (最優先・即実行可能)

> ※コア機能リストの番号と競合しないよう「タスク T-1」として管理する。

**背景**: 2026-03-27/28 レポートで「Zenn/Qiita記事の即日公開がユーザー獲得の最優先施策」と複数回提言。パイプライン完成済み・下書き大量蓄積の今こそ実行フェーズ。

**現状 (2026-04-12 PS#40 で第2弾 Qiita 投稿ブロッカー解消)**:

- **下書き合計 54本** (`docs/blog-drafts/` 全体 / 内 Zennフロントマター形式 17本)
- `QIITA_ACCESS_TOKEN` / `DEVTO_API_KEY` ✅ Supabase シークレット設定済み (Windows版#23)
- ✅ **投稿済み**:
  - Qiita: [Claude Code Schedule でCS自動化](https://qiita.com/kanta13jp1/items/38f0383e0ea01b787900)
  - dev.to: [How I Automated CS with Claude Code Schedule](https://dev.to/kanta13jp1/how-i-automated-cs-bug-fixes-and-competitor-monitoring-with-claude-code-schedule-18a6)
  - Zenn: `2026-03-28-zenn-database-view.md` `published: true` でデプロイ済み
  - dev.to ✅ [Flutter WebでSupabaseを使ったアプリ内通知センター](https://dev.to/kanta13jp1/flutter-webdesupabasewoshi-tutaapurinei-tong-zhi-sentawoshi-zhuang-sitahua-50g3) (PS#37)
- ✅ **blog-publish.yml Qiita 403 修正済み** (PS#40, commit `08bc6c37`): Zenn形式 `topics:` フロントマターに対応していなかったバグを修正。`grep -E '^(tags|topics):'` + 空タグデフォルト値 `Flutter,Supabase,buildinpublic` を追加。
- ✅ **Qiita 投稿成功** (2026-04-12): `2026-03-31-notification-center.md` → [https://qiita.com/kanta13jp1/items/68d26f0fe4224fd17de7](https://qiita.com/kanta13jp1/items/68d26f0fe4224fd17de7)
- ✅ **第4弾 投稿成功** (2026-04-12): `2026-03-28-note-comments.md` → Qiita: [https://qiita.com/kanta13jp1/items/d90cff103a6ce55c6192](https://qiita.com/kanta13jp1/items/d90cff103a6ce55c6192) / dev.to 投稿成功
- ✅ **第5弾 投稿成功** (2026-04-12): `2026-04-01-workflow-automation-video-meeting.md` → Qiita: [https://qiita.com/kanta13jp1/items/0d55915a3553f85e495d](https://qiita.com/kanta13jp1/items/0d55915a3553f85e495d) / dev.to 投稿成功
- ✅ **第8弾 投稿成功** (PS#46, 2026-04-12): `2026-04-12-ai-university-20-providers-hub-architecture.md` → Qiita: [https://qiita.com/kanta13jp1/items/acb09db86b8be8b02819](https://qiita.com/kanta13jp1/items/acb09db86b8be8b02819) / dev.to 投稿成功
- ✅ **第9弾 投稿成功** (PS#47, 2026-04-12): `2026-04-12-cors-fix-ef-hub-migration.md` → Qiita: [https://qiita.com/kanta13jp1/items/03bd942f926b2b215daf](https://qiita.com/kanta13jp1/items/03bd942f926b2b215daf) / dev.to 投稿成功
- ✅ **第10弾 投稿成功** (PS#47, 2026-04-12): `2026-04-09-pomodoro-focus-timer.md` → Qiita: [https://qiita.com/kanta13jp1/items/344f2a9ab557dc240c81](https://qiita.com/kanta13jp1/items/344f2a9ab557dc240c81) / dev.to 投稿成功
- ✅ **第34弾 投稿成功** (PS#54, 2026-04-13): `2026-04-13-sql-shell-quoting-artifact-fix.md` → Qiita+dev.to / EN版: https://dev.to/kanta13jp1/how-a-bash-quoting-artifact-broke-our-production-postgresql-deploy-3n66
- ✅ **第35弾 投稿成功** (PS#55, 2026-04-13): `2026-04-12-blog-publish-automation-github-actions-en.md` → dev.to: https://dev.to/kanta13jp1/how-i-published-21-technical-articles-in-one-day-using-github-actions-supabase-8cm
- ✅ **第36弾 投稿成功** (PS#56, 2026-04-13): `2026-04-13-three-instance-parallel-dev.md` → Qiita: https://qiita.com/kanta13jp1/items/cd4ba18c7329700edf80 / dev.to: https://dev.to/kanta13jp1/running-3-parallel-claude-code-instances-to-triple-my-solo-dev-velocity-2g2p
- ✅ **第37弾 投稿成功** (Gemini CLI, 本セッション): `2026-04-13-horse-racing-ai-pipeline.md` → Qiita+dev.to
- ✅ **第38弾 投稿成功** (Gemini CLI, 本セッション): `2026-04-13-ai-university-54-providers-milestone-en.md` → dev.to
- ✅ **第39弾 投稿成功** (Gemini CLI, 本セッション): `2026-04-13-sql-shell-quoting-artifact-fix-en.md` → dev.to
- ✅ **第40弾 投稿成功** (Gemini CLI, 本セッション): `2026-04-13-three-instance-parallel-dev-en.md` → dev.to
- ✅ **第41弾 投稿成功** (VSCode版#77 Design-Skills, 2026-04-16): `2026-04-11-personal-dashboard-notion-competitor.md` → Qiita+dev.to
- ✅ **第42弾 投稿成功** (VSCode版#77 Design-Skills, 2026-04-16): `2026-04-10-dns-domain-manager.md` → Qiita+dev.to
- ✅ **第43〜53弾**: 各インスタンスで投稿済み (詳細は GROWTH_STRATEGY_ROADMAP.md 参照)
- ✅ **第54弾 投稿成功** (PS版#83, 2026-04-17): `2026-04-17-voice-ai-chat-conversation-memory.md` → Qiita+dev.to
- ✅ **第55弾 投稿成功** (PS版#84, 2026-04-17): `2026-04-13-claude-mem-persistent-memory.md` → Qiita: https://qiita.com/kanta13jp1/items/d157ccf8a081f14dcd79 / dev.to: https://dev.to/kanta13jp1/adding-persistent-memory-to-claude-code-with-claude-mem-plus-a-diy-lightweight-alternative-2pgb
- ✅ **第56弾 投稿成功** (PS版#84, 2026-04-17): `2026-04-13-ai-university-54-providers-milestone.md` → Qiita: https://qiita.com/kanta13jp1/items/336edeef74459c3c061e / dev.to: https://dev.to/kanta13jp1/building-an-ai-learning-platform-with-54-providers-in-3-days-flutter-supabase-2l06
- ✅ **第57弾 投稿成功** (PS版#85, 2026-04-17): `2026-04-12-ai-university-40-providers-deploy-fix.md` → Qiita: https://qiita.com/kanta13jp1/items/75df563eeaf92b222743 / dev.to: https://dev.to/kanta13jp1/how-a-missing-unique-constraint-broke-our-production-supabase-deploy-postgresql-on-conflict-3i9a
- ✅ **第58弾 投稿成功** (PS版#85, 2026-04-17): `2026-04-10-budget-ai-advisor.md` → Qiita: https://qiita.com/kanta13jp1/items/548a75bbc309488d8d98 / dev.to: https://dev.to/kanta13jp1/building-a-moneyforward-beating-ai-budget-advisor-in-flutter-web-supabase-claude-3b9f
- ✅ **第59弾 dev.to成功** / Qiita 429継続 (PS版#85, 2026-04-17): `2026-04-12-blog-publish-automation-github-actions.md` → dev.to: https://dev.to/kanta13jp1/how-i-published-21-technical-articles-in-one-day-using-github-actions-supabase-4585
- ✅ **第60弾 dev.to成功** / Qiita 429継続 (PS版#85, 2026-04-17): `2026-04-12-horse-racing-ai-pipeline.md` → dev.to: https://dev.to/kanta13jp1/building-a-fully-automated-horse-racing-ai-prediction-pipeline-with-flutter-supabase-21b2
- ✅ **第61弾 dev.to成功** (PS版#86, 2026-04-17): `2026-03-27-devto-schedule-automation-en.md` → dev.to: https://dev.to/kanta13jp1/how-i-automated-cs-bug-fixes-and-competitor-monitoring-with-claude-code-schedule-25bd
- ✅ **第62弾 dev.to成功** (PS版#86, 2026-04-17): `2026-04-17-web-instance-retired-en.md` → dev.to: https://dev.to/kanta13jp1/why-i-killed-my-4th-claude-code-instance-lessons-from-multi-agent-indie-dev-44fa
- ✅ **第54弾 EN補投** (PS版#86, 2026-04-17): `2026-04-17-voice-ai-chat-conversation-memory-en.md` → dev.to: https://dev.to/kanta13jp1/implementing-voice-ai-chat-with-conversation-memory-in-flutter-web-web-speech-api-supabase-34h1
- ⚠️ **Qiita 日次rate limit**: 2026-04-17 に4本投稿後に429。翌日リトライ (第59・60弾 Qiita未投稿)
- ⚠️ **blog-publish.yml Step5**: GITHUB_TOKEN はブランチ保護 (require PR) をバイパス不可。published:true 更新は手動マージが必要。BLOG_PAT シークレット設定で完全自動化可能。

- ✅ **第63弾 dev.to成功** / Qiita 429 (PS版#88, 2026-04-17): `2026-04-12-ai-university-34-providers.md` → dev.to: https://dev.to/kanta13jp1/building-an-ai-learning-platform-for-34-providers-in-flutter-web-supabase-auto-updated-every-2-kb9
- ✅ **第64弾 dev.to成功** / Qiita 429 (PS版#88, 2026-04-17): `2026-04-13-ai-university-41-providers-tabs.md` → dev.to: https://dev.to/kanta13jp1/from-34-to-41-ai-providers-notion-style-tab-blocks-in-flutter-web-2n2a

- ✅ **第65弾 dev.to成功** (PS版#89, 2026-04-17): `2026-03-31-embedding-similarity.md` → dev.to: https://dev.to/kanta13jp1/building-a-text-similarity-lab-with-gemini-embeddings-flutter-web-cosine-similarity-visualizer-3bno
- ✅ **第66弾 dev.to成功** (PS版#89, 2026-04-17): `2026-03-28-edge-functions-cicd.md` → dev.to: https://dev.to/kanta13jp1/how-i-deploy-36-supabase-edge-functions-via-github-actions-with-4-parallel-claude-code-instances-46g7

- ✅ **第67弾 dev.to成功** (PS版#90, 2026-04-17): `2026-04-07-ai-writing-assistant-upgrade.md` → dev.to: https://dev.to/kanta13jp1/one-edge-function-three-ai-writers-meeting-minutes-x-threads-blog-drafts-4pfh
- ✅ **第68弾 dev.to成功** (PS版#90, 2026-04-17): `2026-04-02-gantt-timeline.md` → dev.to: https://dev.to/kanta13jp1/building-a-gantt-chart-that-beats-notions-timeline-view-flutter-web-supabase-226a

- ✅ **第69弾 dev.to成功** (PS版#91, 2026-04-17): `2026-04-04-goal-tracker-bookmark-sync.md` → dev.to: https://dev.to/kanta13jp1/goal-tracker-bookmark-sync-in-one-day-flutter-333-buildcontext-trap-edge-function-first-39i3
- ✅ **第70弾 dev.to成功** (PS版#91, 2026-04-17): `2026-04-08-x-viral-pipeline-catalog-expansion.md` → dev.to: https://dev.to/kanta13jp1/building-a-viral-loop-guitar-recording-auto-post-to-x-fire-and-forget-pattern-1i0n

- ✅ **第71弾 dev.to成功** (PS版#92, 2026-04-17): `2026-04-01-focus-timer-ai-writing.md` → dev.to: https://dev.to/kanta13jp1/building-forest-grammarly-competitors-in-flutter-web-pomodoro-timer-ai-writing-assistant-1m43
- ✅ **第72弾 dev.to成功** (PS版#92, 2026-04-17): `2026-04-03-gamification-code-realestate.md` → dev.to: https://dev.to/kanta13jp1/3-features-in-one-day-gamification-code-playground-real-estate-tracker-flutter-supabase-564e
- ✅ **第73弾 dev.to成功** (PS版#93, 2026-04-17): `2026-04-05-calendar-view-guitar-studio.md` → TableCalendar O(1)イベントルックアップ
- ✅ **第74弾 dev.to成功** (PS版#93, 2026-04-17): `2026-03-31-notification-center.md` → RLS user_id IS NULLブロードキャスト
- ✅ **第75弾 dev.to成功** (PS版#93, 2026-04-17): `2026-04-01-workflow-automation-video-meeting.md` → AIワークフロー/SNS/ビデオ会議
- ✅ **第76弾 dev.to成功** (PS版#93, 2026-04-17): `2026-04-02-wiki-timetracker-voicememo.md` → Wiki/TimeTracker/VoiceMemo
- ✅ **第77弾 dev.to成功** (PS版#93, 2026-04-17): `2026-04-09-pomodoro-focus-timer.md` → CustomPainter円形タイマー
- ✅ **第78弾 dev.to成功** (PS版#93, 2026-04-17): `2026-04-12-cors-fix-ef-hub-migration.md` → EF 94→15本hub統合
- ✅ **第79弾 dev.to dispatched** (PS版#93, 2026-04-17): `2026-04-11-personal-dashboard-notion-competitor.md` → FractionallySizedBox棒グラフ
- ✅ **第80弾 dev.to dispatched** (PS版#93, 2026-04-17): `2026-04-10-dns-domain-manager.md` → TabController FAB + colorSchemeトークン

**次回候補 (第103弾以降)**:

| 優先度 | 下書き | 媒体 |
| --- | --- | --- |
| 🔴 | 第59・60・63・64弾 Qiita リトライ | Qiita 15:00 UTC以降 (JST翌日0:00) |
| 🔴 | 第98〜102弾 Qiita リトライ (FSRS・EF Hub・ブログ自動化・AI大学DBタブ・FSRS復習カード) | Qiita 15:00 UTC以降 |
| ✅ | 第98弾 FSRS Spaced Repetition Flutter + Supabase → success | dev.to |
| ✅ | 第99弾 EF Hub-and-Action Architecture 50本制限突破 → success | dev.to |
| ✅ | 第100弾 ブログ自動投稿パイプライン GitHub Actions × Supabase EF → success | dev.to |
| ✅ | 第101弾 DB駆動動的タブ AI大学 Zero-Config プロバイダー追加 → success | dev.to |
| ✅ | 第102弾 FSRS復習カウンター × ホームカード統合 → success | dev.to |

**推定ROI**: #buildinpublic / #FlutterWeb / #Supabase / #Notion タグで開発者コミュニティに到達 → ユーザー4人からの脱却。

### CI/CD改善 #C2: 2026-03-28 日次レポート分析からの反映 (PowerShell版#22, 2026-04-11)

**背景**: 2026-03-28 は GitHub Actions 移行当日。cs-check が「PR経由コミット」で実装されたが、ブランチ名衝突・push rejected が頻発 (commit #234/#235)。daily-report.yml は PS#19 で直接 push 化済みだが cs-check.yml は未対応だった。

| 課題 | 対応 | ステータス |
| --- | --- | --- |
| cs-check.yml / daily-report.yml の直接プッシュ | GITHUB_TOKEN はブランチ保護をバイパス不可 → PR→マージ方式に戻す (PS#25) | ✅ 解決済み (PS#25) |
| 12部署仮想組織 & EdgeFunctionSummaryCard の LP 掲載 | LP 実装済み (機能 #17 / VSCode#24) | ✅ 解決済み |

### CI/CD改善 #C3: 2026-03-29 日次レポート分析からの反映 (PowerShell版#23, 2026-04-11)

**背景**: cs-check / blog-draft / edge-function-audit の3ワークフローが正常稼働中を確認。新規課題は最小権限修正のみ。

| 課題 | 対応 | ステータス |
| --- | --- | --- |
| edge-function-audit.yml `pull-requests: write` が過剰 (`gh pr` 未使用) | `pull-requests: read` に変更 (最小権限の原則) | ✅ 解決済み (PS#23) |
| cs-check/blog-draft/edge-function-audit の稼働確認 | 3ワークフローとも正常動作を確認 | ✅ 確認済み |

### CI/CD改善 #C4: 2026-03-31 日次レポート分析からの反映 (PowerShell版#24, 2026-04-11)

**背景**: AI分析提言3「新規EFに deno test を追加し CI で自動実行する体制を整える」。ci.yml に deno test ステップが存在せず、flutter test の結果も Job Summary に表示されていなかった。

| 課題 | 対応 | ステータス |
| --- | --- | --- |
| ci.yml に `deno test` ステップなし | `deno test` ステップ追加 (`continue-on-error: true`)。`*.test.ts` 未存在時はスキップ。将来テスト追加時に自動実行 | ✅ 解決済み (PS#24) |
| `flutter test` の結果が Job Summary に未表示 | `id: flutter_test` / `id: deno_test` 追加、Job Summary にテスト結果行を追加 | ✅ 解決済み (PS#24) |

> **Web版へ**: 主要EF (`notification-center` / `feature-request-manager` / `onboarding-flow`) に `*.test.ts` を追加すると CI で自動テストが走る体制が整った。

### CI/CD改善 #C6: docs/ 戦略ドキュメント分析からの反映 (PowerShell版#27, 2026-04-11)

**背景**: 2026-04-11 初回 docs/ 戦略ドキュメント全件分析 (新ルール #10 初回実施)。計24ドキュメントを横断分析し、CI/CD スコープに影響する2件の技術的負債を特定。

| 課題 | 対応 | ステータス |
| --- | --- | --- |
| `deno.land/std@0.168.0` 古化 (238本・2023年版) | `dependency-audit.yml` に古バージョン検出ステップを追加 | ✅ 解決済み (PS#27) |
| `pubspec.yaml` の `http: any` (バージョン制約なし) | `dependency-audit.yml` に unconstrained deps チェックを追加 | ✅ 解決済み (PS#27) |
| 多数の技術文書が2025年時点の旧情報 (GitHub Secrets未設定・Backend Migration未着手 等) | アーカイブ済み通知を先頭に追記 — Windows版#28/#29 実施 | ✅ 解決済み (Windows版#28/#29) |

**アーカイブ対応済み (Windows版#28/#29)**:

| ファイル | 対応バージョン |
| --- | --- |
| `docs/technical/BACKEND_MIGRATION_PLAN.md` | Windows版#28 ✅ |
| `docs/technical/GEMINI_MIGRATION_GUIDE.md` | Windows版#28 ✅ |
| `docs/technical/REFACTORING_PLAN.md` | Windows版#28 ✅ |
| `docs/CICD_SETUP_GUIDE.md` | Windows版#29 ✅ |

### CI/CD改善 #C5: 2026-04-02〜2026-04-10 日次レポート分析 (PowerShell版#26, 2026-04-11)

**背景**: 2026-04-02〜2026-04-10 の9日分レポートを一括分析。全報告を横断すると以下の重複パターンが確認された。

| 課題 | 分析結果 | ステータス |
| --- | --- | --- |
| Supabase API接続ブロック (全9日分レポート) | CI/CD改善 #C1 で解決済み (daily-report.yml GitHub Actions移管) | ✅ 確認済み |
| X投稿失敗 (全9日分) | CI/CD改善 #C1 で解決済み (daily-report.yml Step5 + リトライ) | ✅ 確認済み |
| 競合監視3社のみ | CI/CD改善 #C1 で解決済み (7社に拡大) | ✅ 確認済み |
| cs-check.yml / daily-report.yml GH006 | CI/CD改善 #C2 で解決済み (PR→マージ方式) | ✅ 確認済み |
| deno test CI未統合 | CI/CD改善 #C4 で解決済み | ✅ 確認済み |
| 全10ワークフローに GITHUB_STEP_SUMMARY 未追加 | PS#27 (2026-04-09) で解決済み (別セッション) | ✅ 確認済み |
| workflow-failure-handler.yml 未追加 | PS#27 (2026-04-09) で解決済み — 失敗時 Issue 自動生成 + cs-check 自動修復 | ✅ 確認済み |

**新規追加改善なし**: 2026-04-02〜2026-04-10 のレポートで提言された全CI/CD改善は既に対応済みを確認。

### ユーザーリクエスト上位 (2026-04-08 確認)

> feature_requests 投票上位。優先度順に実装検討する。

1. **モバイルアプリ (iOS/Android)** — Flutter モバイルビルド対応
*(その他の上位リクエスト（Notionインポート強化、MoneyForward連携、Slack連携、Googleカレンダー同期）はすべて実装済み)*

### 競合脅威対応タスク (2026-04-11 Claude Schedule 競合モニタリングから追加)

| タスク | 競合 | インスタンス | 優先度 |
| --- | --- | --- | --- |
| ~~`admin_analytics_page.dart` 拡張~~: `personal_dashboard_page.dart` 新規作成で対応済み (daily-dev 2026-04-11) | Notion 3.4 ダッシュボードビュー | VSCode版 | ✅ 完了 |
| ~~`ai-assistant` EF: マイスキル登録・再利用機能~~: `my_skills_page.dart` + EF 4アクション実装済み (daily-dev#2, PS#本セッション) | Slack AI 再利用スキル | Web版 | ✅ 完了 |
| ~~`pr-auto-review` Schedule: CI失敗自動 fix コミット機能~~: `ci-auto-fix.yml` 新規作成で対応済み (PS#30) | GitHub Copilot Autopilot | PowerShell版 | ✅ 完了 |

### 機能強化 #T2: THOUGHT_INTERRUPT_ELIMINATOR 拡張 (VSCode + Windows版スコープ)

**背景**: `docs/technical/THOUGHT_INTERRUPT_ELIMINATOR_DESIGN.md` に未着手タスク5件を確認 (VSCode#36, 2026-04-11)

| 作業内容 | インスタンス | 優先度 |
| --- | --- | --- |
| ~~`abstinence_slips` テーブル作成 (マイグレーション)~~ ✅ 完了 (`20260411002400_create_abstinence_slips.sql` RLS + インデックス付き, daily-dev#4, 2026-04-11) | Windows版 | ✅ 完了 |
| ~~思考妨害パターン診断UI (4質問形式)~~ ✅ 完了 (`thought_interrupt_diagnosis_page.dart` + LP#78 + route `/thought-interrupt-diagnosis`) | VSCode版 | ✅ 完了 |
| ~~リアルタイム介入ウィジェット (ホーム画面衝動ボタン)~~ ✅ 完了 (`lib/widgets/thought_interrupt_quick_widget.dart` + ホーム禁欲ガードパネルに組込み) | VSCode版 | ✅ 完了 |
| ~~週次パターンレポート (slip 分析・タイムスタンプ集計)~~ ✅ 完了 (`weekly_slip_report_page.dart` + LP#79 + route `/weekly-slip-report`, PS#33, 2026-04-11) | VSCode版 | ✅ 完了 |
| AI介入提案 (`ai-assistant` EF に slip パターン渡し) | Web版 | 🟢 低 |

### ~~markdownlint 残件 (Windows版スコープ)~~ ✅ 解決済み (PS#33, 2026-04-11)

`docs/GROWTH_STRATEGY_ROADMAP.md` の MD029/MD032/MD012/MD034 を修正済み。

### ~~CI/CD バグ #B5~~: ✅ 解決済み (PowerShell版#35, 2026-04-11)

**背景**: Windows版#30 (2026-04-11) で `blog-publish.yml` 経由の Qiita/dev.to 投稿を試みた際に2問題を確認。

| 問題 | 詳細 | 対応 |
| --- | --- | --- |
| title 抽出失敗 (Zenn フォーマット) | CRLF 行末 + 引用符パターン | `tr -d '\r'` + `sed "s/^['\"]//;s/['\"]$//"` で修正 (PS#35) |
| GH006 Step5 保護ブランチ直接 push | `git push origin main` → ブランチ保護違反 | PR 作成→自動マージ方式に変更 (PS#35) |

**dev.to 投稿済み (PS#37)**: `2026-03-31-notification-center.md` → [dev.to投稿完了](https://dev.to/kanta13jp1/flutter-webdesupabasewoshi-tutaapurinei-tong-zhi-sentawoshi-zhuang-sitahua-50g3)。**Qiita ✅ 投稿完了 (2026-04-12)**: [https://qiita.com/kanta13jp1/items/68d26f0fe4224fd17de7](https://qiita.com/kanta13jp1/items/68d26f0fe4224fd17de7)

### AI大学 キラーコンテンツ化方針（毎回必ず実行）

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

### 機能強化 #T3: AI大学 マルチプロバイダー対応 + 毎週自動更新 (Windows版#30〜#31, 2026-04-11)

**背景**: `gemini_university_v2_page.dart` が Gemini 特化のハードコードコンテンツ。**プロバイダー数は固定せず毎セッションで追加候補を検討**し、毎週 Claude Schedule が最新情報を自動更新する仕組みに改修。

#### 現在の登録プロバイダー (PS版#3 Session43: 182社)

```text
google, openai, anthropic, microsoft, meta, x, deepseek, mistral, perplexity, groq, cohere, core, amazon, stability, huggingface, nvidia, ibm, sakana, baidu, oracle, reka, aleph_alpha, together_ai, fireworks_ai, replicate, writer, ai21, voyage, elevenlabs, openrouter, ollama, runway, suno, ideogram, udio, luma, kling, pika, assemblyai, twelve_labs, qwen, moonshot, midjourney, hailuo, adobe_firefly, 01ai, coze, apple, databricks, samsung, zhipu, character_ai, inflection, allenai, naver, adept, cerebras, prover, lmsys, falcon_tii, black_forest_labs, liquid_ai, snowflake, cognition, scale_ai, poolside, harvey, manus, hedra, heygen, recraft, krea, tencent, bytedance, inception_labs, world_labs, runware, sambanova, lightricks, arcee_ai, minimax, moondream, rakuten_ai, pfn, siliconflow, novita_ai, deepinfra, nebius, fal_ai, fish_audio, atlas_cloud, mira_network, gmi_cloud, inworld, coreweave, lambda_labs, hyperbolic, anyscale, cerebrium, magic_ai, jina_ai, stepfun, modular, radixark, baseten, baichuan, lepton, krutrim, deepgram, did, cartesia, tavus, synthesia, play_ht, descript, wandb, modal, pinecone, langchain, llamaindex, qdrant, roboflow, lightning_ai, weave, oxen_ai, predibase, argilla, dify, decart, goodfire, nous_research, v0, windsurf, hume_ai, glean, vapi, e2b, firecrawl, weaviate, livekit, higgsfield, browserbase, tavily, nomic_ai, chroma, upstage, modal, runpod, scale_ai, baseten, arize_ai, langsmith, comet_ml, braintrust, galileo, prefect, confident_ai, crewai, patronus_ai, autogen, agno, haystack, zenml, vllm, ragas
```

新規プロバイダーを追加するたびにこのリストを更新する。

#### 完了済み (Windows版#30〜#31)

| 作業内容 | 状態 |
| --- | --- |
| `ai_university_content` テーブル作成 | ✅ `20260411003000_create_ai_university_content.sql` |
| 6プロバイダー初期コンテンツ seed (google/openai/anthropic/microsoft/meta/x) | ✅ `20260411003200_seed_ai_university_content.sql` |
| DeepSeek 初期コンテンツ seed (overview/models/api) | ✅ `20260411003400_seed_deepseek_ai_university.sql` |
| `CLAUDE.md` に `ai-university-update` スケジュールタスク追加 (随時拡張対応) | ✅ 毎週月曜 11:00 JST |
| `ai-university-update.yml` ワークフロー (DeepSeek 含む7プロバイダー) | ✅ PS#35 + Windows版#31 |

#### 完了済み (VSCode版#51〜#52, 2026-04-11)

| 作業内容 | 状態 |
| --- | --- |
| `gemini_university_v2_page.dart`: DB駆動タブ・プロバイダー数無制限・シェア・達成度永続化 | ✅ VSCode版#51〜#52 |
| `AiUniversityHomeCard` ウィジェット: ホーム最上部バナー・プログレスバー・シェアボタン | ✅ VSCode版#52 |
| `home_page.dart` 最上部に `AiUniversityHomeCard` 追加 | ✅ VSCode版#52 |
| `ai_university_scores` テーブル + leaderboard ビュー (migration) | ✅ VSCode版#52 |
| CLAUDE.md: AI大学キラーコンテンツ化方針 + 毎セッション確認事項を追加 | ✅ VSCode版#52 |
| `_providerMeta`: DeepSeek/Mistral/Cohere/Perplexity/Amazon 追加 | ✅ VSCode版#51 |
| Claude Code Schedule `ai-university-update` タスク登録 | ✅ PS#35 |

#### 完了済み (Windows版#32, 2026-04-11)

| 作業内容 | 状態 |
| --- | --- |
| `ai_university_streaks` テーブル (連続学習日数) migration | ✅ `20260411003800_create_ai_university_streaks.sql` |
| `ai_university_badges` テーブル (達成バッジ) migration | ✅ `20260411004000_create_ai_university_badges.sql` |
| CLAUDE.md: AI大学キラーコンテンツ化方針を KPI・3Step・ロードマップで大幅強化 | ✅ Windows版#32 |

#### 未完了 (各インスタンスへ指示)

*(全て完了済みのためクリア)*

#### `ai_university_badges` テーブルスキーマ

```sql
badge_id      text PRIMARY KEY  -- 'first_study'|'quiz_master'|'streak_7d'|'all_providers' など
user_id       uuid (FK auth.users)
badge_name    text              -- 表示名 (例: 「AI探求者」)
icon_emoji    text              -- バッジ絵文字
condition     text              -- 達成条件の説明文
awarded_at    timestamptz       -- 取得日時
is_public     boolean           -- ランキング・シェアに表示するか
```

#### `ai_university_streaks` テーブルスキーマ

```sql
user_id       uuid PRIMARY KEY (FK auth.users)
current_streak int              -- 現在の連続学習日数
longest_streak int              -- 過去最長記録
last_studied_date date          -- 最終学習日 (毎学習時に更新)
streak_updated_at timestamptz
```

#### 新規プロバイダー追加手順 (毎セッション Step 0 として実施)

```text
1. WebSearch で新興AI動向を調査
2. 技術革新性・API公開状況・話題性の3軸で評価
3. supabase/migrations/YYYYMMDDXXXXXX_seed_{provider}_ai_university.sql を作成
   - overview / models / api の3レコードを INSERT ON CONFLICT DO NOTHING
4. lib/pages/gemini_university_v2_page.dart の _providerMeta マップに表示設定を追加
5. 同ファイルの _fallback マップにフォールバック markdown を追加
6. 同ファイルの _quizzes マップにクイズを追加 (任意)
7. .github/workflows/ai-university-update.yml に検索クエリを追加
8. COMPRESSED_PROMPT_V3.md「現在の登録プロバイダー」リストを更新
9. CLAUDE.md Step 1 の検索クエリ・公式URLに追加
```

**次回追加候補**: Cohere standalone API (cohere2) / Voyage AI (voyage) / Mistral standalone (mistral2)
**追加完了 (Windows版#44)**: Oracle AI / Reka AI — migration適用済み (`20260412010000/011000_seed_*_ai_university.sql`)
**追加完了 (Windows版#45)**: Aleph Alpha / Together AI — migration適用済み (`20260412012000/013000_seed_*_ai_university.sql`)
**追加完了 (Windows版#46)**: Fireworks AI / Replicate — migration適用済み (`20260412014000/015000_seed_*_ai_university.sql`)
**追加完了 (Windows版#47)**: Writer / AI21 Labs — migration適用済み (`20260412016000/017000_seed_*_ai_university.sql`)
**Apple Intelligence: 見送り** (API非公開・統合OS機能のみ・開発者向け教材として不適)
**追加完了 (Windows版#33)**: Mistral AI / Perplexity AI — migration適用済み (`20260412000100/000200_seed_*_ai_university.sql`)
**追加完了 (Windows版#34)**: Groq — migration適用済み (`20260412001000_seed_groq_ai_university.sql`) / VSCode版へ UI追加 cross-instance-pr 発行済み
**追加完了 (Windows版#35)**: Cohere / Amazon — migration適用済み (`20260412002000/003000_seed_*_ai_university.sql`) / VSCode版へ UI追加 cross-instance-pr 発行済み
**追加完了 (Windows版#36)**: Stability AI — migration適用済み (`20260412004000_seed_stability_ai_university.sql`) / VSCode版へ UI追加 cross-instance-pr 発行済み
**追加完了 (Windows版#37)**: Hugging Face — migration適用済み (`20260412005000_seed_huggingface_ai_university.sql`) / VSCode版へ UI追加 cross-instance-pr 発行済み
**追加完了 (Windows版#38)**: Nvidia NIM — migration適用済み (`20260412006000_seed_nvidia_ai_university.sql`) / VSCode版へ UI追加 cross-instance-pr 発行済み
**追加完了 (Windows版#39)**: IBM watsonx — migration適用済み (`20260412007000_seed_ibm_ai_university.sql`) / VSCode版へ UI追加 cross-instance-pr 発行済み
**追加完了 (Windows版#40)**: Sakana AI — migration適用済み (`20260412008000_seed_sakana_ai_university.sql`) / VSCode版へ UI追加 cross-instance-pr 発行済み
**追加完了 (Windows版#41)**: Baidu ERNIE — migration適用済み (`20260412009000_seed_baidu_ai_university.sql`) / VSCode版へ UI追加 cross-instance-pr 発行済み

#### `ai_university_content` テーブルスキーマ

```sql
provider    text  -- 'google' | 'openai' | ... | 追加自由
category    text  -- 'models' | 'api' | 'pricing' | 'news' | 'tutorial' | 'overview'
title       text
content     text  -- Markdown形式
source_url  text
published_at date
sort_order  int
is_active   boolean
updated_at  timestamptz  -- 自動更新トリガー付き
```

#### `ai-university-content` EF 仕様 (VSCode版)

```typescript
// action: 'get_all' → 全プロバイダーのコンテンツ一覧
// action: 'get_by_provider' → provider 指定で絞り込み
// action: 'upsert_news' → Claude Schedule が毎週呼び出してニュース更新
// RLS: SELECT は全ユーザー / INSERT/UPDATE はサービスロールのみ
```

---

## ⚡ マルチエージェント協調パターン (新機能設計時に参照)

新しい自動化・AI機能を設計するとき、以下の5パターンから選ぶ。**最も単純なパターンから始めて行き詰まったら進化させる**。

| パターン | 採用基準 | このプロジェクトでの実例 |
| --- | --- | --- |
| **Generator-Verifier** | 品質最重要・評価基準を明文化できる | `claude-agent-review.yml` / `ci-auto-fix.yml` / `/deep-research`(NLM生成→Claude統合) |
| **Orchestrator-Subagent** | タスク分解が明確・短時間で完結するサブタスク | `cs-check.yml` / `github-issue-fix.yml` / Claude Code Schedule全般 |
| **Agent Teams** | 並行独立した長時間タスク | **3インスタンス並行開発** / `ai-university-update.yml`(6プロバイダー RSS有効) + Claude Schedule (4時間毎 NotebookLM) |
| **Message Bus** | イベント駆動・エコシステムが成長する | `workflow-failure-handler.yml` → Issue → `cs-check` / `feedback-issue-resolved.yml` |
| **Shared State** | エージェントが互いの発見を活用・単一障害点を避けたい | `memory/` + NotebookLM Master Brain / Supabase DB / `COMPRESSED_PROMPT_V3.md` |

**選択フロー**: 品質ゲート必要→Generator-Verifier / ステップ確定→Orchestrator-Subagent / 長時間独立→Agent Teams / イベント駆動→Message Bus / リアルタイム共有→Shared State

**推奨スタート**: 大半のユースケースは **Orchestrator-Subagent** から始め、行き詰まったら進化させる。

---

## 🤖 ゼロトークンリサーチ + Master Brain ワークフロー

**目的**: 重いドキュメント分析を NotebookLM に委譲して Claude のトークンを節約し、セッション間で学習を蓄積する。$20プランで$200相当の作業を実現。

### スラッシュコマンド

| コマンド | 定義ファイル | 用途 |
| --- | --- | --- |
| `/deep-research <トピック/ファイルパス>` | `.claude/commands/deep-research.md` | NotebookLM に分析委譲 → Claude が結果を整理 |
| `/wrap-up` | `.claude/commands/wrap-up.md` | セッション末尾: 学習を `memory/` に永続保存 |
| `/notebooklm` | `notebooklm skill` | NotebookLM 全機能へのダイレクトアクセス |

### native CLI コマンド（推奨）

```bash
# ノートブック操作
notebooklm create "プロジェクト名"
notebooklm list
notebooklm use <notebook-id>     # 部分ID可 (例: "jibun")

# ソース追加 (最大50本 free / 300本 pro)
notebooklm source add "./file.md"               # ローカルファイル
notebooklm source add "https://example.com"     # URL
notebooklm source add --type youtube "https://youtube.com/watch?v=..."
notebooklm source add-research "クエリ"         # Web Deep Research (自律調査)
notebooklm research wait                        # 調査完了まで待機

# 質問・応答
notebooklm ask "主要テーマを3点まとめて"

# 成果物生成 (Google インフラで無料処理)
notebooklm generate slide-deck "要点をまとめて"
notebooklm generate flashcards "重要用語中心に"
notebooklm generate mind-map
notebooklm generate data-table "概念を比較"
notebooklm generate audio "deep dive" --wait
notebooklm generate quiz / infographic / video
notebooklm download <type>       # ローカルに保存

# スキル管理
notebooklm skill install         # ~/.claude/skills/ にインストール
notebooklm skill status
```

### ラッパースクリプト（互換用）

```bash
PYTHONUTF8=1 python notebooklm_research.py "テキスト"
PYTHONUTF8=1 python notebooklm_research.py --files f1.dart --query "質問"
PYTHONUTF8=1 python notebooklm_research.py --url "https://..." --query "要約して"
PYTHONUTF8=1 python notebooklm_research.py --setup
# Master Brain に保存 (wrap-up時)
PYTHONUTF8=1 python notebooklm_research.py --add-to-master-brain memory/project_20260411.md
# 成果物生成
PYTHONUTF8=1 python notebooklm_research.py --generate slide-deck
# リサーチ→生成→Master Brain 一括
PYTHONUTF8=1 python notebooklm_research.py "Flutter最新動向" --generate flashcards --add-to-master-brain memory/project_today.md
```

- **注意**: 非公式ライブラリ。undocumented Google API のため突然の仕様変更あり
- **cookie 保護**: `~/.notebooklm/storage_state.json` は git commit 禁止 (= Google セッション情報)
- **cookie 期限切れ時**: `notebooklm login` で再認証 (30秒)

### DBS フレームワーク: エキスパートスキル構築

Deep Research で収集した知識をカスタム Claude Code スキルに変換:

```text
D (Direction)  = 意思決定ロジック・手順 → SKILL.md のコア
B (Blueprints) = テンプレート・ガイドライン → サポートファイル
S (Solutions)  = API呼び出し・計算コード → スクリプト
```

→ DBS 分類後に `/skill-creator` を実行すると SKILL.md が自動生成・テストされる。

### Master Brain (memory/)

保存先: `C:\Users\kanta\.claude\projects\C--Users-kanta-GitHub-my-web-app\memory\`

| ファイルパターン | 内容 |
| --- | --- |
| `feedback_success_YYYYMMDD.md` | 成功パターン・承認されたアプローチ |
| `feedback_correction_YYYYMMDD.md` | 修正・禁止事項 |
| `project_YYYYMMDD.md` | 新規発見・プロジェクト固有の仕様 |

`/wrap-up` 時に `notebooklm source add <memory-file>` で Master Brain に蓄積 → `notebooklm ask` で全セッション横断検索可能。

---

> **インスタンス別スコープ早見表**: `lib/` + `supabase/functions/` + `docs/DESIGN.md` → **VSCode版** / `docs/` (DESIGN.md除く) + `supabase/migrations/` (seed + schema) → **Windowsアプリ版** / `.github/` + `.mcp.json` + `docs/MULTI_INSTANCE_COORDINATION.md` → **PowerShell版** / `memory/` + `docs/GROWTH_STRATEGY_ROADMAP.md` (末尾追記) + `docs/cross-instance-prs/` + `COMPRESSED_PROMPT_V3.md` (数値更新) → **全インスタンス共有**
## Current 2-Instance Override (2026-05-05)

Canonical development flow is now exactly two human-operated instances:

- Claude Code #1 (Windows app): architecture, research, docs, UX triage, WBS design/spec, and old Win/VSCode/PS#1/PS#3/PS#4/WEB/mobile lanes.
- Codex #1 (Windows app): implementation, CI, GitHub PR work, Edge Functions, workflows, and old Codex/PS#2/PS#5/PS#6 lanes.
- User and Automation remain non-development lanes for manual decisions, scheduled jobs, and GitHub Actions.

Any 3-instance, 12-fleet, Codex#2, or PS#1-6 routing below this section is historical legacy context only. New sessions must not start extra AI instances or extra dev servers unless explicitly requested by the user.
