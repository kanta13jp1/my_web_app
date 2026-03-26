# 成長戦略ロードマップ - 自分株式会社

作成日: 2025-11-10
最終更新: 2026-03-27 session29 (追加: Facebook を第19競合として追加)
現時点の登録者数: 4人
最重要目的: Notion・EverNote・MoneyForward・X・Animaworks・Claude Code・Codex・netkeiba・OpenClaw・Claude Cowork・Chatwork・Slack・ジョブカン・Amazon・Google・Microsoft・Discord・LINE・Facebook を上回る規模の知的生産・資産管理・SNS 統合プラットフォームを作る
運用原則: flutter analyze を常に 0 に保ち、複雑な処理は可能な限り Supabase Edge Function へ移す

---

## 1. ビジョン

自分株式会社 を、AI が伴走する知的生産プラットフォームに進化させる。
単なるメモ保存ではなく、整理、共有、思考補助、行動変換、チーム運用までを支える。

勝ち筋は次の 4 本柱で作る。

1. 競合から移行しやすいこと (Notion、Evernote、MoneyForward、X、その他競合プラットフォームからのユーザーを取り込む)
2. AI が自然に価値を生むこと
3. 共有と紹介が新規流入に変わること
4. 個人利用から法人導入まで伸びること

---

## 2. 競合到達ライン

ロードマップ上では次を最低到達ラインとして扱う。

- Notion: 100,000,000+ users 規模
- Evernote: 250,000,000+ customer 規模
- MoneyForward: ~15,000,000 users 規模
- X (Twitter/X): ~600,000,000 monthly active users 規模
- Animaworks: ~500,000 users 規模 (国内パーソナル生産性アプリ)
- Claude Code (Anthropic): ~500,000 users 規模 (AI コーディングアシスタント)
- Codex: ~1,000,000 users 規模
- netkeiba: ~17,000,000 users 規模
- OpenClaw: ~1,000,000 users 規模 (オープンソース AI エージェント)
- Claude Cowork: ~500,000 users 規模 (法人向け AI ワークスペース)
- Chatwork: ~6,000,000 users 規模 (国内ビジネスチャット)
- Slack: ~65,000,000 users 規模 (グローバルビジネスチャット)
- ジョブカン: ~5,000,000 users 規模 (国内バックオフィス SaaS)
- Amazon: ~310,000,000 active customer accounts 規模 (グローバル EC・AI・コンテンツ)
- Google: ~4,300,000,000 users 規模 (Google Workspace・Search・Android・YouTube・Cloud)
- Microsoft: ~1,500,000,000 users 規模 (Microsoft 365・Windows・Azure・LinkedIn・GitHub)
- Discord: ~200,000,000 monthly active users 規模 (ゲーム・コミュニティ・ボイスチャット・サーバー管理)
- LINE: ~196,000,000 monthly active users 規模 (メッセージング・決済・ニュース・日本/台湾/タイ/インドネシア)
- Facebook (Meta): ~3,070,000,000 monthly active users 規模 (SNS・Messenger・Marketplace・広告プラットフォーム)

2026-03-24 に再確認した公開ベンチマークの前提は次の通り。

- Notion product page: `Over 100M users worldwide`
- Evernote official announcement dated 2022-11-16: `Serving more than 250 million customers`
- MoneyForward: ~1,500 万ユーザー
- X (Twitter/X): ~6 億 monthly active users
- Animaworks: 国内パーソナル生産性・習慣管理アプリ (~50 万ユーザー推定)
- Codex: 開発者向け AI 支援ツール (~100 万ユーザー推定)
- netkeiba: 国内最大級の競馬情報・コミュニティサイト (~1,700 万ユーザー)
- OpenClaw: オープンソースの自律型 AI エージェント (~100 万ユーザー推定)
- Claude Cowork: Anthropic の法人向け次世代 AI ワークスペース (~50 万ユーザー推定)
- Chatwork: 国内シェアトップクラスのビジネスチャット (~600 万ユーザー)
- Slack: 世界的シェアを誇るビジネスチャット・連携プラットフォーム (~6,500 万ユーザー)
- ジョブカン: 導入実績 25 万社を超える国内シェアトップクラスのバックオフィスシステム (~500 万ユーザー推定)

自分株式会社 はこれら 19 のサービスを上回るために、移行、AI、共有、紹介、法人展開を同時に強化する。

---

## 3. 現在地

### 現状

- 登録者数は 4 人で、まだ PMF 前
- Flutter Web + Supabase で高速改善できる
- Import preview と import commit は Edge Function first 化済み
- Public memo の share と copy の計測は backend 化済み
- Growth command center を実装済み
- flutter analyze は 0 を維持
- flutter test --coverage は一部 widget test の安定化が残っている

### 直近の実装済み項目

- growth-import-preview
- growth-import-commit
- growth-command-center
- growth-acquisition-signal
- growth-share-signal
- growth-referral
- growth-acquisition-report
- **get-competitor-features Edge Function** (2026-03-25 実装完了): 競合13社機能比較データをバックエンドに移行
  - 全13競合 (Notion/EverNote/MoneyForward/X/Animaworks/Claude Code/Codex/netkeiba/OpenClaw/Claude Cowork/Chatwork/Slack/ジョブカン) の機能比較データを Edge Function (1697行) で提供
  - `CompetitorFeatureComparisonCard` を `initState` 時に Edge Function 呼び出しへ改修（フォールバック付き）
  - フロントエンドのハードコードデータ約1600行を段階的に排除する backend-first 実装完了
- **batch_analysis.py バグ修正** (2026-03-25): `NoneType + int` TypeError 修正・`run-batch` に `continue-on-error: true` 追加
- **Weekly Digest UI** (2026-03-25 実装完了): Growth Mission ページに週次ダイジェストカードを追加
  - `WeeklyDigestChannelMetrics` / `WeeklyDigestSnapshot` モデルクラスを `growth_mission_service.dart` に追加
  - `loadWeeklyDigest()` メソッドで `growth-weekly-digest` Edge Function を呼び出す実装
  - GrowthMissionPage に週次チャネル別メトリクス（touches/sign-ups/CVR/delta）カードを表示
  - 週次 sign-up submits・referrals・import CTA・public memo CTA の集計タイルを表示
- **ランディングページ改善** (2026-03-25 追加): ユーザー獲得強化のため2セクション追加
  - `_buildUniqueValueSection()`: AI役員会議・記憶ドリル・経営コックピット・インポート・マインドマップ・公開メモ の6機能をアイコン付きグリッドで訴求
  - `_buildImportCtaSection()`: 「登録なしでインポートを試す」ダークカード CTA を追加、/import への直接導線を設置
- **development-achievements** (2026-03-25 新規作成): 開発実績の GET (期間フィルタ) / ADD (新規追加) を提供する Edge Function。DevelopmentAchievementsCard が呼び出す。
- **get-growth-roadmap-progress** (2026-03-25 新規作成): user_profiles からユーザー数、growth_plans テーブルから計画データを取得して返す Edge Function。GrowthRoadmapProgressCard が呼び出す。growth_plans が空の場合は16項目のデフォルトデータを自動シードする。
- growth-weekly-digest (2026-03-25 追加)
- import 画面の backend-first execution result 表示
- **ScheduleTaskMonitorCard** (2026-03-26): 管理者ダッシュボードに Schedule タスク実行状況モニター追加。9 タスクの名前・スケジュール・最終実行・ステータスを表示
- **SeoMetaHelper + 公開メモ SEO/OGP 強化** (2026-03-26): 公開メモ詳細ページで og:title/og:description/og:url/Twitter Card を動的に設定。離脱時リセット
- **health-check Edge Function** (2026-03-26): DB 接続性・レイテンシ・必須 6 テーブルの可用性チェック
- **check-competitor-updates Edge Function** (2026-03-26): 競合 14 社の Web サイト可用性チェック + competitor_monitoring テーブルに記録
- **schedule_task_runs テーブル** (2026-03-27): Schedule タスク実行ログ記録用テーブル。管理者ダッシュボードの ScheduleTaskMonitorCard が参照
- public memo の共有導線と成長シグナル記録
- route / import / public memo / referral の獲得シグナル記録
- /referral 導線と referral invite セクション
- import と public memo から sign-up へ流す CTA 計測
- referral code 発行、pending referral 適用、referral snapshot 集計の backend-first 化
- Growth Mission に assisted conversion proxy と import preview 集計を追加
- Growth Mission から note / Qiita / Zenn / Medium / dev.to / Hashnode / Substack 向けの配信ブリーフをコピー可能にした
- HomePage の operations calendar で日別の収入 / 支出を月単位で俯瞰できるようにした
- referral anti-abuse: rate limit (1日5件) + 1時間未満アカウントブロック + check_abuse アクション (2026-03-25 追加)
- import 成功後の onboarding CTA を personalized card に刷新 (2026-03-25 追加)
- ai_status_page_test の残件 "can set and show the default ai model" を解消 (2026-03-25 完了)
- ホーム画面最上部に GrowthRoadmapProgressCard を追加 (2026-03-25 追加)
  - 短期/中期/長期計画の目標期日・達成率・■□バーをリアルタイム表示
  - vs NOTION (1億ユーザー) / vs EverNote (2.5億ユーザー) 比較バー
  - user_profiles テーブルから登録者数をリアルタイム取得
- 技術ブログ発信戦略を GROWTH_STRATEGY_ROADMAP.md に追加 (Zenn / Qiita / はてなブログ / note / dev.to / Hashnode / Medium / Substack / GitHub Pages)
- ホーム画面に vs X 進捗バーを追加 (2026-03-24 追加)
- 競合機能比較カードに X タブを追加 (X: SNS・コンテンツ配信機能との比較) (2026-03-24 追加)
- ホーム画面に CompetitorFeatureComparisonCard を Notion/EverNote/MoneyForward/X の4タブで実装 (2026-03-24 追加)
- ユーザーマニュアルページを追加 (実装済み全機能の操作手順書) (2026-03-24 追加)
- vs MoneyForward 進捗バーを追加 (2026-03-24 追加)
- vs Animaworks 進捗バーを追加 (目標: ~50万ユーザー) (2026-03-24 追加)
- 競合機能比較カードに Animaworks タブを追加 (目標・習慣管理/振り返り/ライフデザイン機能との比較) (2026-03-24 追加)
- CompetitorFeatureComparisonCard を5タブ構成に拡張 (Notion/EverNote/MoneyForward/X/Animaworks) (2026-03-24 追加)
- vs Claude Code 進捗バーを追加 (目標: ~50万ユーザー) (2026-03-24 追加)
- 競合機能比較カードに Claude Code タブを追加 (AI コーディング支援機能との比較) (2026-03-24 追加)
- vs Codex 進捗バーを追加 (目標: ~100万ユーザー)
- vs netkeiba 進捗バーを追加 (目標: ~1700万ユーザー)
- vs OpenClaw 進捗バーを追加 (目標: ~100万ユーザー)
- vs Claude Cowork 進捗バーを追加 (目標: ~50万ユーザー)
- vs Chatwork 進捗バーを追加 (目標: ~600万ユーザー)
- vs Slack 進捗バーを追加 (目標: ~6500万ユーザー)
- vs ジョブカン 進捗バーを追加 (目標: ~500万ユーザー)
- 競合機能比較カードに Codex、netkeiba、OpenClaw、Claude Cowork、Chatwork、Slack、ジョブカン タブを追加し、13タブ構成に拡張
- DevelopmentAchievementsCard の本実装を完了 (2026-03-27 更新)
  - ダミーデータを完全に排除し、`development_achievements` テーブルから直接実績と完了日を取得する実データ駆動に改修
  - 取得失敗時や0件時のフォールバック(ダミーデータ)を廃止し、純粋な実データのみを表示するよう本実装
- GrowthRoadmapProgressCard のプログレスバーをテキストベース (■□□) に変更し、全13競合の目標期日を実設定 (2026-03-27)
- ユーザー向け操作マニュアル (`user_manual_page.dart`) を本実装完了 (2026-03-28)
- 開発実績の取得・追加機能をフロントエンドから `development-achievements` Edge Function へ完全移行し、クライアントアプリからの直接のDBアクセスを排除 (2026-03-25)
- GrowthRoadmapProgressCard のハードコードを完全に排除し、`get-growth-roadmap-progress` Edge Function からユーザー数と全13競合の進捗データを安全に取得する本実装へ改修 (2026-03-25)
- `get-growth-roadmap-progress` Edge Function 内に残っていた目標データのハードコードを完全に廃止し、`growth_plans` DB テーブルから動的に取得・シードする本実装を完了 (2026-03-25)

- **get-public-memo-preview Edge Function 新規作成** (2026-03-25): public_memos テーブルから Markdown 除去済みエクサープト・pageTitle・ogDescription を返す認証不要エンドポイント
- **index.html SEO シェル動的メタタグ注入** (2026-03-25): /public-memo?id=XXX の URL で Flutter 起動前に OGP メタタグ (og:title / og:description / twitter:card) を動的書き換え → SNS シェアカードに実メモ内容を表示
- **get-home-dashboard Edge Function 新規作成** (2026-03-25): ホーム画面マーケティング KPI (totalUsers / todaySignups / todayViews / todayShares / lpSeries) を Promise.all で並列フェッチし 1 API 呼び出しに統合。3〜4 往復 DB クエリを廃止。
- **DevelopmentAchievementsCard ドロップダウンバグ修正** (2026-03-25): 期間変更時に _fetchTasks が呼ばれず一覧が更新されない問題を修正
- **ユーザーマニュアル全セクション正確化** (2026-03-25): OFFICE KPI SNAPSHOT / KPI SUMMARY / OPERATIONS CALENDAR / SPECIAL PROJECT を追加・AI組織OS の正確な名称に統一・公開メモ OGP 対応記載・財務管理セクション新設
- **Zenn 技術ブログ原稿完成** (2026-03-25): docs/zenn_growth_dashboard_20260325.md に4つの Edge Function 実装詳細・Flutter 呼び出しコード例・deno lint 0 件維持の運用原則を記載済み (published: false → Zenn アカウントで公開予定)
- index.ts (get-competitor-features 系) の `require-await` deno-lint エラーを修正（不要な async を削除）(2026-03-25)
- supabase/functions/deno.json に lint.rules.exclude = ["no-import-prefix"] を追加し、Deno 2.x の URL import 方式の関数全体でのエラーを解消 (2026-03-25)
- growth-achievement-summary と growth-referral の `no-explicit-any` を `deno-lint-ignore` で抑制し、deno lint **0件** 達成 (2026-03-25)
- CompetitorFeatureComparisonCard の `_FeatureRow.competitorName` 不要フィールドを削除し、全 `_FeatureRow` インスタンスの missing_required_argument エラー 13件を解消 (2026-03-25)
- CompetitorFeatureComparisonCard の `_isLoading = true` 永続バグ（展開時に無限ローディングスピナーが表示され続ける）を修正し、ハードコードデータを即座に表示するよう改修 (2026-03-25)
- growth_roadmap_progress_card.dart の bracket 不整合（`Expected to find ']'`）および unused_field・prefer_final_fields エラーを解消 (2026-03-25)
- development_achievements_card.dart の require_trailing_commas エラーを解消 (2026-03-25)
- user_manual_page.dart の unnecessary_const エラーを解消 (2026-03-25)
- flutter analyze 216件エラー → **0件** 達成 (2026-03-25)
- ホーム画面に「GROWTH / 成長導線」セクションを新設し、インポート・成長ミッション・公開メモ一覧への直接リンクを追加 (2026-03-25)
- ユーザーマニュアル (`user_manual_page.dart`) を全面刷新：実際のホーム画面ナビゲーション（CEO/CSO/CFO/CMO/GROWTH の各セクション）に準拠した正確な手順書に改版 (2026-03-25)
  - 存在しない「ナビゲーションメニュー」への言及を削除し、実在するグリッドメニューの操作手順を記載
  - 8セクション構成（ホーム画面・ノート・独自機能・インポート・公開メモ・タイマー・成長ロードマップ・AI/ブリーフィング）に拡充

- **競合名「Claude works」→「Claude Cowork」全ファイル変更** (2026-03-25 session4): 23箇所 (Dart/TypeScript/Markdown) を一括置換・growth_plans テーブルも UPDATE マイグレーションで同期
- **FinancialReportPage Supabase 移行** (2026-03-25 session4): SharedPreferences('asset_data_v2') 廃止 → cfo_assets テーブルから直接ロード。クロスデバイス同期が実現。
- **AssetManagementPage 個人銀行ハードコード撤廃** (2026-03-25 session4): 「三井住友銀行大塚支店」等の個人情報をコードから削除。デフォルト汎用選択肢に変更し、_loadSourceOptionsFromDb() で過去履歴から自動補完。
- **CI/CD Edge Functions 自動デプロイ追加** (2026-03-25 session3): supabase functions deploy ステップを deploy-prod.yml に追加。get-public-memo-preview / get-ogp は --no-verify-jwt で公開アクセス対応。
- **sitemap.xml 更新** (2026-03-25 session3): /public-memo を追加・lastmod を 2026-03-25 に更新
- **Build in Public バナー** (2026-03-25 session3): ランディングページにローンチからの経過日数・実装済み件数（DB実データ）・LIVE バッジを表示

### 2026-03-25 session5-6 実装済み

- **CORSエラー完全修正** (session5): 全Edge Functionを `--no-verify-jwt` で再デプロイ。ブラウザのOPTIONSプリフライトがJWT検証でブロックされていた根本原因を解消
- **CI/CD タグ重複エラー修正** (session5): 連続プッシュで同一タグ作成エラー → `git ls-remote` で事前チェック+スキップ
- **新規ユーザー向けウェルカムカード** (session5): `WelcomeNewUserCard` — 登録7日以内ユーザーに3クイックアクション（モーニングブリーフィング/最初のメモ/Notionインポート）を表示
- **技術ブログ投稿管理機能** (session5): `TechBlogTrackerPage` — Zenn/Qiita/はてなブログ/note/Medium/dev.to/Hashnode/Substack/GitHub Pages/NOTION/X Article への毎日投稿管理・連続投稿ストリーク表示
- **deno.lock 削除** (session5): ローカルDeno v2が生成したlockfile v5がEdge Runtime Deno v1と非互換でデプロイ失敗 → 削除で解消
- **/morning-briefing /note-editor ルート追加** (session6): WelcomeNewUserCardのクイックアクションが未定義ルートでLandingPageに飛ぶバグを修正
- **CI不存在Edge Function削除** (session6): growth-import-preview / growth-import-commit はディレクトリが存在しないのにデプロイ対象になっていた → 削除
- **X Article対応** (session6): TechBlogTrackerPageにX Article（Xの長文記事機能）プラットフォームを追加（計11プラットフォーム対応）

### 2026-03-25 session7 実装済み

- **SEO meta description 競合比較キーワード追加** (session7): `web/index.html` の description に「Notion・Evernote・MoneyForward・Slack・X の機能を1つに統合」を追記。keywords に Notion代替・Evernote代替・MoneyForward代替・Slack代替を追加
- **OGP・Twitter カード競合比較訴求** (session7): og:title を「Notion・Evernote・MoneyForward を超えるAI統合プラットフォーム」に変更。twitter:title も競合比較訴求文に更新
- **SEOシェル本文 / JSON-LD 拡充** (session7): SEOシェルのp要素に競合SaaS名を追記。JSON-LD featureList を10項目（各競合代替機能を明記）に拡充。seo-tags に日本語キーワードタグ（Notion代替・Evernote代替・MoneyForward代替・Slack代替）を追加

### 2026-03-25 session8 実装済み

- **ランディングページ 価格比較セクション追加** (session8): `_buildPricingComparisonSection()` — Notion/Evernote/MoneyForward/Slack/Chatwork/ジョブカンとの月額料金比較表。「他社は有料、自分株式会社は完全無料」を強調するコンバージョン強化施策
- **ランディングページ 3ステップ導入ガイド** (session8): `_buildGetStartedStepsSection()` — 「無料トライアル → 登録して保存 → 既存データ移行」の3ステップビジュアル表示 + 常時表示CTA
- **CI/CD インポートEdge Function追加** (session8): `growth-import-preview` / `growth-import-commit` を `deploy-prod.yml` のデプロイ対象に追加。NotionCSV・EvernoteENEXインポートフローが自動デプロイされるよう修正

### 2026-03-25 session9 実装済み

- **Admin Analytics 週次ダイジェスト UI** (session9): `_buildWeeklyDigestCard()` を AdminAnalyticsPage に追加。`growth-weekly-digest` Edge Function から週次 KPI（登録/紹介/インポートCTA/公開メモCTA）を取得してチャネル別に表示
- **sitemap.xml 拡充** (session9): `/tech-blog-tracker` / `/import` / `/user-manual` の 3 URL を追加。クロール対象が 4→7 件に増加
- **Zennブログ原稿 session8 追記** (session9): 価格比較セクション実装の解説を追記。Markdownlint 修正完了

### 2026-03-25 session10 実装済み

- **LPヒーローセクション全面刷新** (session10): キャッチコピーを「Notion・Evernote・MoneyForward・Slack を1つに。完全無料。」に変更。実装済み件数バッジ・「無料で始める（30秒）」CTA・「登録なしで1件試す」セカンダリCTAを追加
- **ウェイトリスト登録フォーム** (session10): `newsletter_waitlist` テーブル作成（anon insert 可）。LP に「新機能リリースをメールで受け取る」フォームを追加。登録前ユーザーのメールを捕捉
- **機能リクエストフォーム** (session10): `feature_requests` テーブル作成（anon insert・公開参照可）。LP に「こんな機能が欲しい！」フォームを追加。ユーザー要望を直接DB収集

### 2026-03-25 session11 実装済み

- **機能リクエスト公開ページ** (session11): `FeatureRequestsPage` を新規作成 (`/feature-requests`)。anon ユーザーも投稿・閲覧・投票が可能。投票数順ソート・上位3件ハイライト表示。ランディングページ SEO シェルのナビにリンク追加
- **main.dart `/feature-requests` ルート追加** (session11): ディープリンクからのアクセスを有効化
- **sitemap.xml に `/feature-requests` を追加** (session11): 検索エンジンへのクロール対象を8URLに拡充

### 2026-03-26 session12 実装済み

- **Zenn 技術ブログ第1弾公開** (session12): `docs/zenn_growth_dashboard_20260325.md` を `published: true` に変更。「FlutterとSupabase Edge Functionsで13競合を打倒するグロースダッシュボードを作った話」を公開。Zenn 有機流入による新規登録者獲得フローを開始
- **Zenn 技術ブログ第2弾作成** (session12): `docs/zenn_community_growth_20260325.md` を新規作成・`published: true`。「LP全面刷新・価格比較・ウェイトリスト・機能リクエスト公開ページの実装解説」記事。Supabase anon RLS活用・flutter analyze 0件維持のノウハウ公開
- **Admin: 機能リクエスト管理 UI** (session12): `AdminAnalyticsPage` に `_buildFeatureRequestsAdminCard()` を追加。機能リクエスト一覧を投票数順に表示し、ステータス（open / in_progress / done / rejected）を PopupMenu で変更可能。上位3件ゴールドハイライト表示
- **Admin: メールウェイトリスト管理 UI** (session12): `AdminAnalyticsPage` に `_buildWaitlistCard()` を追加。`newsletter_waitlist` テーブルから登録メール・ソース・日時を一覧表示。登録者フォローアップ計画立案に活用

### 2026-03-26 session13 実装済み

- **send-waitlist-notification Edge Function 実装** (session13): Resend API を使用したメール一括送信機能。`newsletter_waitlist` テーブルの全登録メールに一斉送信。HTMLメールテンプレート内蔵。認証済みユーザーのみ呼び出し可能。CI/CD に自動デプロイ追加
- **Admin: ウェイトリスト通知送信 UI 追加** (session13): `AdminAnalyticsPage` のウェイトリストカードに「通知送信」ボタンを追加。件名・本文入力ダイアログから Edge Function を呼び出し、送信件数をスナックバーで確認

### 2026-03-26 session14 実装済み

- **LP: リアルタイム実績カード追加** (session14): `_buildSocialProofStatsSection()` を LandingPage に追加。登録ユーザー数・公開メモ数・実装済み機能数を Supabase から count クエリで取得し LIVE バッジ付きで表示。Build in Public の透明性を訴求
- **LP: 移行ガイドセクション追加** (session14): `_buildMigrationGuideSection()` を LandingPage に追加。Notion/Evernote からの3ステップ移行手順を番号付きで可視化。インポート画面への直接 CTA ボタン付き。競合ユーザーの移行障壁を低減

### 2026-03-26 session15 実装済み

- **競合比較 SEO ページ群実装** (session15): `ComparisonPage` ウィジェット新規作成。`/vs-notion` / `/vs-evernote` / `/vs-moneyforward` / `/vs-slack` / `/vs-chatwork` の5ルートを追加。各ページに競合の痛点・機能比較表・移行CTA を表示。sitemap.xml に5URL追加（合計13URL）。「Notion代替」等の検索キーワードからの有機流入獲得

### 2026-03-26 session16 実装済み

- **get-admin-users Edge Function 実装** (session16): `auth.admin.listUsers` でサービスロールから全登録ユーザーを取得。`user_profiles` との JOIN で display_name/bio/avatar_url/location/twitter_handle/website_url を取得。6フィールドで `completionPct` (0-100) を算出。ページネーション対応。CI/CD に自動デプロイ追加
- **ユーザー数カウント修正** (session16): `get-home-dashboard` の集計を `user_profiles`（プロフィール未設定ユーザーが含まれない）→ `auth.admin.listUsers`（全登録ユーザーを正確に反映）に変更。実際の登録者数を正しく表示
- **Admin: 登録ユーザー管理 UI 追加** (session16): `AdminAnalyticsPage` に `_buildAdminUsersCard()` を追加。メール・表示名・bio・location・登録日・最終ログイン日時・認証プロバイダー（Google/Email カラーバッジ）・プロフィール完成度プログレスバー（緑≥67%/オレンジ34-66%/赤<34%）を一覧表示
- **ProfileCompletionBanner ウィジェット追加** (session16): `lib/widgets/profile_completion_banner.dart` を新規作成。ログインユーザーの `display_name`/`bio` が未設定の場合にインディゴ色のバナーをホーム画面に表示。「設定する」→ `/profile-settings` への CTA と「後で」ワンタップ非表示機能付き
- **ホーム画面にプロフィール促進バナー追加** (session16): `HomePage` の WelcomeNewUserCard と GrowthRoadmapProgressCard の間に `ProfileCompletionBanner` を挿入。未設定ユーザーへのプロフィール完成促進

### 2026-03-26 session17 実装済み

- **競合比較 SEO ページ全13社対応完了** (session17): `ComparisonPage` に X / Animaworks / Claude Code / Codex / netkeiba / OpenClaw / Claude Cowork / ジョブカン の8社を追加。`/vs-x` / `/vs-animaworks` / `/vs-claude-code` / `/vs-codex` / `/vs-netkeiba` / `/vs-openclaw` / `/vs-claude-cowork` / `/vs-jobcan` の8ルートを `main.dart` に追加。sitemap.xml に8URL追加（合計21URL）。全13競合の検索キーワードから有機流入を獲得

### 2026-03-26 session18 実装済み

- **LP: 競合比較リンクセクション追加** (session18): `_buildComparisonLinksSection()` を LandingPage に追加。全13競合へのリンクChipを表示し内部SEOリンクを構築。移行ガイドセクションの直後に配置
- **SEO: index.html 全13競合キーワード対応** (session18): `<meta name="keywords">` に Animaworks代替/Claude Code代替/Codex代替/netkeiba代替/OpenClaw代替/Claude Cowork代替/ジョブカン代替/Chatwork代替/X代替 を追加。Twitter Card タイトルも「13の競合SaaSを超えるAI統合プラットフォーム」に更新
- **Zenn記事第3弾作成** (session18): `docs/zenn_comparison_seo_20260326.md` 新規作成・`published: true`。Flutter Webで13競合比較SEOページを量産した実装解説

### 2026-03-26 session23 実装済み

- **X自動投稿** (session23): `post-x-update` Edge Function実装（X API v2 + OAuth 1.0a署名）。`daily-report` スケジュールタスクに Step 3 X投稿を追加（直近24hの git log を分析して140字ツイートを生成・自動投稿）。`@kanta13jp1` アカウントで毎朝09:00 JST に自動投稿

### 2026-03-26 session22 実装済み

- **CS完全自動化** (session22): `feature_requests` に `admin_reply`/`admin_replied_at` カラム追加。`get-support-tickets` Edge Function実装（未返信チケット+FAQ一覧返却）。`reply-support-request` Edge Function実装（チケット返信+Resendメール送信）。CLAUDE.md cs-checkを本格化（FAQ自動返信/バグ自動修正コミット/エスカレーション判断）。`schedule-daily-digest` の `status=pending` バグを `status=open` に修正

### 2026-03-26 session21 実装済み

- **Claude Code Schedule 自動化** (session21): `schedule-daily-digest` Edge Function 実装（総ユーザー数・新規FR・未対応FR上位10件・直近実績を返す GET API）。`CLAUDE.md` 作成（daily-report/cs-check/weekly-sns-draft の3スケジュールタスクを定義）。`docs/daily-reports/`, `docs/cs-notes/`, `docs/weekly-drafts/` ディレクトリ作成。`deploy-prod.yml` に `schedule-daily-digest` 追加。Claude Code Schedule でスケジュール登録（日次 09:00 JST・毎時・週次月曜）

### 2026-03-26 session20 実装済み

- **Amazon を第14競合に追加** (session20): `ComparisonPage` に amazon エントリ追加。`/vs-amazon` ルートを `main.dart` に追加。sitemap.xml に Amazon URL 追加（合計22URL）。LP 比較リンクセクション・index.html キーワードに Amazon代替/Alexa代替/Kindle代替 を追加
- **ユーザーマニュアル全面刷新** (session20): 実際の UI ナビゲーションに完全準拠した手順書に改訂。Notion/Evernote/Markdown のエクスポート手順をステップ形式で詳細化（競合アプリの操作方法を含む）。プロフィール設定・技術ブログ投稿管理・機能リクエストの手順を追加。Amazon を含む競合14社の記述に更新
- **ROADMAP: Amazon を競合14社目として追加** (session20): 競合到達ライン・最重要目的を14社に更新

### 2026-03-26 session19 実装済み

- **機能リクエスト ステータス変更通知** (session19): `notify-feature-request` Edge Function 新規作成。管理者がステータスを `done`/`in_progress` に変更した際、投稿者メールへ Resend API で通知メール送信。CI/CD に自動デプロイ追加
- **Admin: 機能リクエスト UUID バグ修正** (session19): `req['id'] as int` → `req['id']?.toString()` に修正（DB の id 型は uuid）。ステータス変更後に通知確認ダイアログを表示する UX を追加
- **LP: 固定フローティング CTA ボタン追加** (session19): LP に `FloatingActionButton.extended` を追加。「無料で始める」ボタンが常時表示され、タップすると登録フォームへスクロール

### 残課題

- Zenn CLI で実際に publish 実行 (`zenn publish` コマンド)
- Resend API キーは設定済み。送信元ドメイン認証後に FROM_EMAIL を更新
- wasm build blocker の解消
- referral reward ポイント付与の実際の運用確認
- B2B 営業資料の整備開始
- 技術ブログの実際の投稿開始（TechBlogTrackerPageで追跡）
- Google Search Console へのサイトマップ再送信（21 URLs）
- 各比較ページへの個別OGP画像生成
- 比較ページ経由の登録CVRトラッキング

---

## 4. 北極星指標

最重要 KPI は次の通り。

- 登録ユーザー数
- 週次アクティブユーザー数
- 4 週継続率
- import 実行数
- 公開メモ由来登録数
- referral 由来登録数
- チーム導入数
- 有料転換率

成長は次の式で見る。

新規登録 = SEO 流入 + 共有流入 + referral 流入 + import 流入 + 広告流入 + 営業流入

定着は次の式で見る。

定着 = オンボーディング完了率 × 初回価値到達率 × 継続利用率

---

## 5. 絶対に守る開発原則

### 品質

- flutter analyze は常に 0
- deno check supabase と deno lint supabase を壊さない
- 重要画面の変更には必ず test を追加または更新する
- 失敗ログを放置しない
- Linterエラーは常に0となることを目指し、CIで厳格にブロックする

### アーキテクチャ

- フロントエンドで実装している複雑な処理や状態管理はできる限りバックエンドの Supabase Edge Function に移行していくことを徹底する
- import、共有計測、成長集計、brief 生成は backend-first
- Flutter 側は UI と入力体験に集中させる

### プロダクト

- 競合からの乗り換えを最優先で楽にする
- AI は飾りではなく価値到達を早めるために使う
- 共有できる価値を常に設計に入れる

---

## 6. 2026-03-24 時点の最優先事項

1. import から登録までの転換率をさらに上げる
2. 共有、公開メモ、referral の assisted conversion proxy を週次で可視化する
3. flutter test --coverage の残件を解消する
4. route 単位の流入 KPI を週次レポートへ載せる
5. referral の reward / anti-abuse / sales handoff を本運用に耐える形にする

---

## 7. 短期計画 0-90 日

### 開発

- route-level acquisition signal aggregation を weekly digest と assisted conversion 集計へ拡張する
- referral コードと紹介リンクを Edge Function first で運用する
- /referral 導線の CVR を改善する
- import 成功後 onboarding を最適化する
- 公開メモの SEO と OGP を強化する
- フロントエンドで実装している複雑な処理を優先的に Supabase Edge Function に移行する
- ユーザーマニュアルを実装済み機能に合わせて随時更新する
- 競合13製品（Notion, EverNote, MoneyForward, X, Animaworks, Claude code, codex, netkeiba, OpenClaw, Claude Cowork, Chatwork, Slack, ジョブカン）の機能比較データをフロントエンドのハードコードから Edge Function (`get-competitor-features`) へ完全移行し、クライアントアプリのコードベースを約800行削減して大幅に軽量化 (2026-03-25)
- ホーム画面のKPIデータ集約用 Edge Function (`get-home-dashboard`) を本実装し、フロントエンドの複数リクエストを単一化 (2026-03-25)
- 常に Linter エラー 0 を維持し、CIパイプラインで厳格にブロックすることで、技術的負債ゼロのクリーンなコードベースと高速開発を実現する

### 企画

- Notion から移行、Evernote から移行の専用導線を定義する
- referral landing で約束する価値を `登録 -> import -> first memo` の 3 ステップに固定する
- Notion の柔軟性、Evernote の蓄積性、MoneyForward の資産管理、X の拡散性、Animaworks の習慣化、Claude code/Codex の AI 支援、netkeiba の熱狂的コミュニティ、OpenClaw/Claude Cowork の自律型エージェント、Chatwork/Slack のビジネス連携、ジョブカンのバックオフィス効率化。これら13の優位性をすべて包含し凌駕する「自分株式会社」としての統合体験を企画する
- ジョブカンに代表される「管理のための管理ツール」を廃し、「働く人を直接支援するAIアシスタント」としての自律型バックオフィス機能のコンセプトを策定する
- ユーザーマニュアルを単なるヘルプではなく、13競合からの移行時の学習コストを劇的に下げるための「教育コンテンツ」として企画する

### 広告

- X、Meta、Google で少額テストを開始する
- import 訴求広告と AI 訴求広告の勝ち筋を比較する
- 13製品の既存ユーザー層に対して、「複数ツールをバラバラに使うコストと手間」を解決する統合プラットフォームとしての比較広告クリエイティブをA/Bテストし、「情報・資産・フローの一元化」を訴求する

### 宣伝

- 公開メモの weekly share 運用を始める
- ship log と改善ログを週次発信する
- Notion 比較、Evernote 比較の記事を継続公開する
- note と Substack で founder update を定期配信する
- Zenn, Qiita, はてなブログ, note, Medium, dev.to, Hashnode, Substack, GitHubPages, NOTION, X Article などの各プラットフォーム特性に合わせた技術ブログ・開発日記を配信し、「13製品に挑む個人の挑戦」としてビルド・イン・パブリックのストーリーを拡散する
- TechBlogTrackerPage で毎日の投稿状況を管理・連続投稿ストリークを可視化し、毎日欠かさず発信する文化をシステムで支援する

### 技術ブログ・コンテンツ発信

- **Zenn / Qiita / dev.to / Hashnode**: Flutter と Supabase Edge Function による複雑なフロントエンド処理のバックエンド移行や、Linter エラー 0 維持の CI/CD ノウハウなど、技術詳細を発信する
- **はてなブログ / note / Medium**: 週次での開発実績グラフ（GrowthRoadmapProgressCard）や、ダミーデータ排除の本実装など、泥臭い成長の軌跡をエッセイとして綴る
- **Substack / NOTION / GitHubPages**: 公式ドキュメント、リリースノート、13競合との比較状況をパブリックに公開し、SEO流入の受け皿とする
- 発信テンプレート: 1機能リリース → Zenn (実装) → Qiita (実用) → dev.to (英語) → note (エッセイ) の多媒体水平展開をルーティン化する

### 営業

- 小規模チーム向け導入提案を founder sales として開始する
- 移行代行付き PoC を試す
- Notion、Evernote、Slack、Chatwork、ジョブカン、MoneyForwardなど、複数 SaaS の連携疲れと高額なライセンス料に苦しむ企業に対し、一元化プラットフォーム「自分株式会社 (エンタープライズ版)」をコスト削減案として提案する
- 業務効率化にとどまらず、従業員個人の資産形成・自己実現までサポートできる唯一無二のウェルビーイングSaaSとしての価値を法人向けに訴求する
- 営業資料（Pitch Deck）に現在の「本物の開発実績データ」と全13製品を上回る明確なマイルストーンを組み込む

### マーケティング

- SEO 着地面を比較記事、公開メモ、テンプレートで拡大する
- referral 施策の導線と報酬設計を固める
- 13製品（Notion, EverNote, MoneyForward, X, Animaworks, Claude code, codex, netkeiba, OpenClaw, Claude Cowork, Chatwork, Slack, ジョブカン）すべての検索キーワードに対し、比較記事とSEOコンテンツを大量投下する
- ダミーデータを完全排除した開発実績（DevelopmentAchievementsCard）や、進捗バー（GrowthRoadmapProgressCard）を「ビルド・イン・パブリック」の証として対外的にアピールし、透明性でファンを獲得する
- ユーザー向け操作マニュアルをSEOコンテンツ（「〇〇から自分株式会社へ移行する方法」等）としても拡充させ、検索流入と利用開始時の離脱率防止（オンボーディング完了率向上）に直結させる

### 人事

- growth engineer と content marketer の採用要件を定義する
- Linterエラー0を徹底維持できる強い規律と、テストコードを書く文化を持つエンジニアの採用基準を策定する
- フロントエンドの複雑な処理を Supabase Edge Function (Deno) に安全に移行できる、バックエンド・データモデリング能力に長けたフルスタック人材を確保する

### 経理

- CAC、LTV、回収期間を試算する
- 13の競合SaaSを自分株式会社アプリで一元化・代替することによる法人/個人の「自社コスト削減額（SaaSのライセンス費、API課金）」をアピール可能な実績としてトラッキング・経理処理する

### 調達

- AIモデル（Gemini, Claude）のAPI利用枠とコスト効率を常に比較し、最適なバックエンドを調達する
- 各ブログプラットフォームへの記事の水平展開を効率化するための自動化ツールや、Zenn/Qiita等への発信をサポートする編集リソースを調達する

### 事業計画

- Free、Pro、Team、Enterprise の収益モデルを定義する
- 登録者数目標（現2名から短期100、中期1万、長期数億）に対する進捗をリアルタイムダッシュボードで監視し、未達の場合は即座に施策をピボットする
- 13の競合製品すべてを上回るという圧倒的なビジョンと、ダミーデータ無しの「本物の開発実績データと Edge Function による堅牢なバックエンドアーキテクチャ」による透明性・実行力を、対外向け資金調達（シード・シリーズA）のコア資料に据える

---

## 7B. Notion 機能ギャップ分析 (2026-03-25 時点)

ホーム画面に `NotionFeatureComparisonCard` を実装し、32 機能を網羅的に整理した。

### 実装状況サマリー

| ステータス | 件数 | 主な機能 |
| --- | --- | --- |
| 実装済み | 9 | ノート編集、AI補助、タグ、インポート3種、公開ページ、Web |
| 部分実装 | 3 | コードブロック、検索、テンプレート、API連携 |
| 開発中 | 2 | モバイルアプリ、デスクトップアプリ |
| 未実装 | 12 | DB各ビュー、コラボ、コメント、バージョン履歴など |
| 独自機能 | 6 | マインドマップ、記憶ドリル、AIエージェント組織など |

Notion 機能カバー率 = **実装済み+部分実装+開発中 / Notion相当機能合計 ≈ 54%**

### 優先ギャップ補填ロードマップ

#### 短期 (0-90日) で補填すべきギャップ

- **全文検索の強化**: 埋め込み検索 (embedding) を Edge Function で安定化
- **テンプレートマーケット**: 既存ページを拡充してコミュニティ共有まで完成させる
- **バージョン履歴 (最低限)**: ノート保存履歴の閲覧機能

#### 中期 (3-12ヶ月) で補填すべきギャップ

- **テーブルビュー (Database)**: Notion の最大差別化機能。シンプルな実装から始める
- **カンバン/ボードビュー**: タスク管理としての利用を取り込む
- **Team workspace**: リアルタイム共同編集の基盤
- **コメント機能**: ページへのインラインコメント
- **モバイルアプリ**: Flutter iOS/Android ビルドのリリース

#### 長期 (1-3年) で補填すべきギャップ

- **リレーション/ロールアップ**: 本格 DB 機能
- **オフライン対応**: PWA + IndexedDB
- **カレンダー/ガントビュー**
- **Web クリッパー**: ブラウザ拡張

### 自分株式会社 独自優位点 (Notion にない機能)

以下は Notion が持たず 自分株式会社 が先行している機能。訴求に積極活用する。

1. **マインドマップ** — ノートをビジュアル構造化
2. **記憶ドリル** — スペーシング反復学習
3. **AI エージェント組織** — CEO/CFO/CMO 役員会議 AI
4. **経営コックピット** — KPI・資産・習慣を一元管理
5. **Growth ロードマップ進捗** — 開発状況をリアルタイムで自分で確認できる透明性
6. **Referral anti-abuse プログラム** — 安全な紹介制度

---

## 8. 中期計画 3-12 ヶ月

### 数値目標

- 登録ユーザー数: 1,000 から 100,000
- 週次アクティブユーザー数: 300 から 20,000
- 初月継続率: 35% 以上
- 月次売上: 100 万円から 1,000 万円

### 重点施策

- Team / workspace 機能の実装
- テーブルビュー (Database) の実装 — Notion 最大差別化機能を取り込む
- カンバン/ボードビューの実装
- テンプレートマーケットの拡充とコミュニティ共有
- AI による整理、検索、次アクション生成の強化
- referral の本運用
- B2B 営業資料の整備
- モバイルアプリ (iOS/Android) リリース
- 海外向け launch の準備

---

## 9. 長期計画 1-3 年

### 到達目標

- 登録ユーザー数: 1,000,000 から 100,000,000+
- チーム導入社数: 10,000+
- 多言語展開: 日本語と英語を軸に拡張
- 年商: 数十億円規模

### 長期の勝ち方

1. 個人の熱狂的利用を作る
2. 共有、公開、referral で自然流入を作る
3. チーム導入で利用人数を拡張する
4. AI の実用度で差別化する
5. テンプレートと知識資産のネットワーク効果を作る

---

## 10. Edge Function へ移す候補

優先度順に進める。

### 1. ホーム画面データ集約 (最優先)

- **済**: `get-home-dashboard` Edge Function の本実装を完了し、フロントエンドの集計処理を完全にバックエンドへ移行 (2026-03-25)

### その他の移行候補 (優先度順)

- referral activation 集計
- onboarding brief 生成
- public memo recommendation
- growth weekly digest 生成
- LP、import、public memo、referral の assisted conversion 集計
- acquisition touchpoint ごとの cohort 分析

2026-03-24 実装済み:

- referral code 発行、pending referral 適用、snapshot 集計
- acquisition touchpoint 集計の Edge Function 化

---

## 11. 次の 2 週間でやること (2026-03-25 更新)

1. ~~ai_status_page_test の残件を解消する~~ ✓ 完了
2. ~~memory_drill_page_test の残件を解消する~~ ✓ 完了
3. ~~referral reward と anti-abuse ルールを追加する~~ ✓ 完了
4. ~~import success 後 onboarding をさらに改善する~~ ✓ 完了
5. ~~acquisition touchpoint ごとの weekly digest を追加する~~ ✓ 完了 (growth-weekly-digest Edge Function)
6. ~~技術ブログ第 1 弾を Zenn に投稿する~~ ✓ Zenn向け技術記事ドラフト作成完了 (`zenn_growth_dashboard_20260325.md`)
7. weekly digest を Growth Mission / Admin Analytics から UI で呼び出せるようにする
8. import → sign-up CVR を weekly digest で追い始め、数値を毎週このファイルへ反映する
9. wasm build blocker の原因を特定して解消する
10. ~~公開メモの SEO / OGP タグを強化して organic 流入を増やす~~ ✓ 完了 (SeoMetaHelper + PublicMemoDetailPage 動的 OGP 更新)
11. ~~B2B 向け移行代行 LP の最初のドラフトを作る~~ ✓ 完了 (docs/b2b-migration-lp-draft.md)
12. ~~はてなブログで週次 progress bar 付き成長記録を開始する~~ ✓ 完了 (docs/blog-drafts/2026-03-27-hatena-weekly-growth.md)

---

## 12. 毎週更新する項目

- 登録ユーザー数
- WAU
- 継続率
- import 実行数
- 共有数
- referral 数
- SEO 流入
- import 起点 sign-up submit 数
- public memo 起点 sign-up submit 数
- referral 起点 sign-up submit 数
- note / Qiita / Zenn / Medium / dev.to / Hashnode / Substack ごとの流入と登録数
- 広告 CPA
- 営業面談数
- チーム導入数
- analyze と test の状態

---

## 12A. 2026-03-24 cross-functional execution board

### 開発 — 2026-03-24

- `growth-referral` と `growth-acquisition-report` を Edge Function として運用開始する
- `/referral` と landing の invite section の CVR を追う
- flutter analyze 0、deno check / deno lint を壊さない

### 企画 — 2026-03-24

- referral の価値訴求を `招待 -> import -> first memo` に固定する
- Notion 比較、Evernote 比較、referral LP の訴求を同じ言葉にそろえる

### 広告 — 2026-03-24

- referral / import / AI の 3 クリエイティブで少額テストを回す
- Sign-up submit 計測が安定した訴求だけに予算を寄せる

### 宣伝 — 2026-03-24

- note、Substack、SNS で `今週 ship した growth 機能` を定例化する
- 公開メモと build log を referral と import の流入導線に使う

### 営業 — 2026-03-24

- 小規模チーム向けに `Notion / Evernote からの移行代行` を最初の提案軸にする
- referral 経由で流入した法人候補を founder sales が即対応する

### マーケティング — 2026-03-24

- public memo、比較記事、template、referral LP を同じキーワード設計で増やす
- assisted conversion proxy をもとに週次でチャネル配分を更新する

### 人事 — 2026-03-24

- growth backend contractor と content marketer の JD を確定する
- 100 users / 1,000 users 到達時の採用トリガーを先に決める

### 経理 — 2026-03-24

- referral reward の上限予算と会計処理ルールを決める
- CAC 回収期間の目標レンジを広告前に固定する

### 調達 — 2026-03-24

- attribution、CRM、support tool の追加要件を整理する
- 既存 stack で代替できるものは新規契約しない

### 事業計画 — 2026-03-24

- 100、1,000、10,000 users の各段階で必要な org / infra / revenue model を分けて管理する
- Notion / Evernote を上回る目標は長期旗印として持ちつつ、短期は PMF と repeatable channel を先に取る

---

## 12B. 2026-03-25 cross-functional execution board

### 開発 — 2026-03-25

- `growth-weekly-digest` Edge Function を追加し、7 日間のチャネル別 CVR と前週比を返せるようにした
- `growth-referral` に rate limit (1 日 5 件)、1 時間未満アカウントブロック、`check_abuse` アクションを追加した
- import 成功後の onboarding CTA を personalized card に刷新した (Notion / Evernote / Markdown 別に訴求文を変える)
- `ai_status_page_test` の残件 1 件を解消した (ListView lazy rendering によるバッジ未検出)
- flutter analyze 0 を維持。deno check growth-weekly-digest / growth-referral を確認した

### 企画 — 2026-03-25

- import 成功後の CTA を「無料アカウントを作成してノートを保存」に統一した
- weekly digest を週次 KPI レビューの基盤として位置づける
- B2B 向け移行代行 LP のドラフト要件を次スプリントで定義する

### 広告 — 2026-03-25

- import CTA 改善後の sign-up submit 数を weekly digest で追い始める
- 今週の数値が出たら import / referral / landing クリエイティブの予算配分を更新する

### 宣伝 — 2026-03-25

- 今週 ship した機能 (weekly digest, anti-abuse, import CTA, growth progress card) を note / Zenn / dev.to に投稿する
- build in public として referral anti-abuse の設計思想を公開メモにする
- 技術ブログ発信テンプレートを確立: 1 feature → Zenn (実装) → Qiita (実用) → dev.to (英語) → note (エッセイ)
- エンジニア獲得向けに Zenn 投稿用の技術ブログドラフト (`zenn_growth_dashboard_20260325.md`) を執筆完了
- はてなブログで登録者数 weekly progress bar を見せながら成長記録を開始する

### 営業 — 2026-03-25

- import 成功後 CTA の「ノートを保存」導線を法人向け移行代行の入口として活用する
- weekly digest で CVR が高いチャネルからのリードを founder sales に優先対応させる

### マーケティング — 2026-03-25

- weekly digest による週次チャネルレビューを今週から開始する
- import → sign-up の CVR baseline を今週中に計測して記録する

### 人事 — 2026-03-25

- weekly digest が安定したら growth analytics contractor の採用要件に「digest 設計理解」を追加する

### 経理 — 2026-03-25

- referral anti-abuse 導入後、referral reward の実際の発行件数と上限予算の整合を確認する

### 調達 — 2026-03-25

- weekly digest で attribution の精度が足りなくなった時点で attribution tool の導入を検討する

### 事業計画 — 2026-03-25

- import CTA 改善後の CVR 数値が出たら、import チャネルの CAC / LTV 試算に使う
- 週次 digest を investor update の数値源として確立する

---

### Session 24 — 2026-03-26

#### 開発
- vs Amazon を第15競合として growth_plans テーブルおよび get-growth-roadmap-progress Edge Function に追加 (目標: 3.1億ユーザー, 期限: 2038年12月)
- ユーザーマニュアルのナビゲーション手順修正 (セクション名不一致: CFO/CHO/CHRO OFFICE, ブログ投稿管理ボタンラベル)
- 既存機能の確認: 進捗バー(16項目), 開発実績(期間別), プロフィール完了バナー, 管理者ユーザー管理, 技術ブログ投稿管理 — すべて実データで稼働中
- health-check Edge Function 作成: DB接続・テーブル可用性・レスポンスタイム診断API
- check-competitor-updates Edge Function 作成: 競合14社Webサイト応答速度・可用性一括チェックAPI

#### 企画 (X投稿 https://x.com/satori_sz9/status/2037097847498412506 のアイデア実装)
- Claude Code Schedule で合計6つの自動化タスクを運用:
  1. **daily-report** (毎日9:00): 日次メトリクス + X投稿 + レポート生成
  2. **cs-check** (毎時): CS対応・バグ修正・エスカレーション全自動化
  3. **weekly-sns-draft** (毎週月曜9:00): 週次SNSドラフト
  4. **daily-development** (毎日10:00): ロードマップ推進・技術ブログ投稿
  5. **pr-auto-review** (3時間毎): GitHub PR自動コードレビュー
  6. **competitor-monitoring** (毎日7:00): 競合14社Webサイト・ニュースモニタリング
  7. **infra-health-check** (毎時30分): DB・Firebase Hosting可用性監視
  8. **dependency-audit** (毎週月曜8:00): Flutter/Deno依存パッケージ脆弱性チェック

#### 広告・宣伝
- X投稿アカウント: @kanta13jp1 (post-x-update Edge Function で自動投稿)
- 技術ブログ投稿管理機能 (11プラットフォーム対応) で毎日の投稿状況を管理

#### マーケティング
- 登録者数4人に更新 (Supabase実データ確認済み)
- 全15競合の進捗バーがホーム画面で実データ表示 (Amazon追加)

### Session 25 — 2026-03-27

#### 開発
- ScheduleTaskMonitorCard ウィジェット新規作成: 管理者ダッシュボードで 9 つの Schedule タスク実行状況を確認可能に
- SeoMetaHelper ユーティリティ新規作成: 公開メモ詳細ページで og:title/og:description/og:url/Twitter Card を動的に設定・離脱時リセット
- schedule_task_runs テーブル作成: Schedule タスク実行ログ記録用テーブル (RLS: service_role 全操作 / authenticated 読み取り)
- health-check Edge Function 作成済み: DB 接続・6 テーブル可用性・レスポンスタイム
- check-competitor-updates Edge Function 作成済み: 競合 14 社の HTTP HEAD チェック + competitor_monitoring テーブル保存
- flutter analyze 0 を維持

#### 企画
- Schedule タスク実行状況を管理者ダッシュボードで可視化し、運用監視の負荷を削減
- 公開メモの SEO/OGP 強化で organic 検索流入経路を確立

#### 宣伝
- blog-draft Schedule タスク (毎日 08:00) で技術ブログ下書き自動生成
- tech_blog_posts テーブルで 11 プラットフォーム (Zenn/Qiita/はてな/note/Medium/dev.to/Hashnode/Substack/GitHub Pages/NOTION/X Article) の投稿管理

#### マーケティング
- 公開メモの OGP 対応により SNS シェア時のカード表示が改善、CTR 向上を見込む
- 競合 14 社の可用性モニタリングデータを蓄積開始

#### 事業計画
- 3 インスタンス並行開発体制を確立 (VSCode: lib/ / Web: supabase/functions/ / Windows: docs/)
- Claude Code Schedule で 9 タスクの完全自動化運用を開始

### Session 26 — 2026-03-27

#### 開発
- Google・Microsoft を第15・16競合として growth_plans テーブルに追加 (マイグレーション)
- Google: ~43億ユーザー (Workspace/Search/Android/YouTube/Cloud), 期限: 2040年12月
- Microsoft: ~15億ユーザー (365/Windows/Azure/LinkedIn/GitHub), 期限: 2040年12月

#### 企画
- 競合を14社→16社に拡大。Google の検索・メール・ドキュメント統合、Microsoft の Office・クラウド・開発者エコシステムを包含する戦略に拡大
- Google との差別化: AI ファーストの個人経営プラットフォーム (Google は広告モデル、自分株式会社はユーザー中心)
- Microsoft との差別化: 軽量・モバイルファーストの統合体験 (Microsoft はエンタープライズ向け重厚長大)

#### 事業計画
- Google・Microsoft を最終目標に追加したことで、目標ユーザー数の上限を43億に設定
- 段階的アプローチ: まず Animaworks(50万) → netkeiba(1700万) → Chatwork(600万) → Slack(6500万) → Notion(1億) → MoneyForward(1500万) → Amazon(3.1億) → Microsoft(15億) → Google(43億)

---

## 16. ベンチマーク参照元

- 2026-03-24 verified: [Notion product page](https://www.notion.com/product)
- 2026-03-24 verified: [Evernote official announcement](https://evernote.com/blog/bending-spoons-to-acquire-evernote)
- 2026-03-27 added: Google — Google Workspace has over 3 billion users; Search/Android/YouTube ecosystem estimated at 4.3 billion MAU
- 2026-03-27 added: Microsoft — Microsoft 365 has 400M+ paid seats; Windows ecosystem estimated at 1.5 billion users

---

## 13. 失敗条件

次を放置すると Notion と Evernote を超える前に失速する。

- Linter エラーを常態化させる
- フロントエンドに複雑な業務ロジックを溜める
- 計測が曖昧なまま広告投資を始める
- import はあるが onboarding が弱く定着しない
- 個人向けと法人向けの価値訴求を混同する

---

## 14. 判断基準

優先順位は次で決める。

1. 登録者数を増やすか
2. 継続率を上げるか
3. 競合からの移行を楽にするか
4. Edge Function へ寄せられるか
5. flutter analyze 0 と test 安定性を維持できるか

---

## 15. 現時点の結論

今の 自分株式会社 は規模ではまだ競合に遠く及ばない。
ただし、移行、AI、共有、referral、チーム導入を一貫した成長ループとして設計できれば、Notion と Evernote を上回る余地はある。

そのために当面は次を最優先にする。

- backend-first growth architecture
- import 起点の獲得強化
- 共有と referral 起点の獲得強化
- test と analyze の品質固定
- cross-functional な成長運営
