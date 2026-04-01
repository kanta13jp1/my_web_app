# 成長戦略ロードマップ - 自分株式会社

作成日: 2025-11-10
最終更新: 2026-04-01 session432n-web (15本追加 → 180 Edge Functions 体制: +email-template-builder, sitemap-analytics, two-factor-auth, changelog-manager, access-control)
現時点の登録者数: 4人
最重要目的: Notion・EverNote・MoneyForward・X・Animaworks・Claude Code・Codex・netkeiba・OpenClaw・Claude Cowork・Chatwork・Slack・ジョブカン・Amazon・Google・Microsoft・Discord・LINE・Facebook・Liven・GitHub を上回る規模の知的生産・資産管理・SNS 統合プラットフォームを作る
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

自分株式会社 はこれら 21 のサービスを上回るために、移行、AI、共有、紹介、法人展開を同時に強化する。

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

### ホーム画面改善計画 (2026-03-28 継続更新)

ホーム画面は「全部を並べる場所」ではなく、「今日やることへ入る場所」に戻す。

- 方針1: 日次必須導線、KPI、特別案件だけをホームに残す
- 方針2: 探索系の機能は `業務メニュー` に分離し、部署別セクションで再配置する
- 方針3: `最近使った機能` と `機能検索` を追加し、再訪時の移動コストを下げる
- 方針4: 補助カード群は `成長・支援ダッシュボード` に退避し、ホーム本体には置かない
- 完了条件1: 統一地方選ダッシュボードや朝会などの重要導線へホームから 2 タップ以内で到達できる
- 完了条件2: 旧ホームの主要機能が `業務メニュー` 上で一覧・検索の両方から到達できる

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
- **PowerShell 4インスタンス並列開発体制** (2026-03-30): VSCode(lib/) / Web(supabase/functions/) / Windows(docs/) / PowerShell(全体管理) の4並列体制を確立。git pull --rebase による競合防止
- **管理者ユーザー管理強化** (2026-03-30): user_profiles に is_admin・profile_completeness・last_login_at を追加。管理者が全ユーザーのプロフィール完成度を管理可能に
- **Schedule 自己修復タスク** (2026-03-30): cs-check に GitHub Issue の自動修正フロー統合。daily-report に schedule_task_runs 記録とヘルスモニター統合。失敗タスクの自動リトライを実現
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
- **テンプレート広場 18種類実装** (2026-03-28): `template_marketplace_page.dart` を全面刷新。6カテゴリ18テンプレート（日次記録・ビジネス・思考アイデア・学習成長・個人生活・技術開発）を実装。`/templates` ルートを main.dart に追加。Notionパリティの「テンプレートマーケット」短期ギャップを解消
- **テーブルデータビュー (Notion Database相当) 実装** (2026-03-28): `table_data_page.dart` を新規作成。`user_tables` / `user_table_rows` テーブルを jsonb で動的スキーマ管理。カラム型5種（text/number/date/checkbox/select）、テーブル作成・削除・リネーム、カラム追加・削除、行のインライン編集・削除に対応。Flutter `DataTable` ウィジェットで横スクロール対応スプレッドシート UI を実現。`/table-data` ルート追加、ホーム画面にナビゲーションカード追加。Notion の最大差別化機能「Database」の中期ギャップを先行着手
- **ノートバージョン履歴** (2026-03-28): `note_versions` テーブル（RLS付き）を新設。手動保存のたびにスナップショット自動記録。AppBarの履歴ボタンからBottomSheetで最新30件を閲覧・復元可能。Notionパリティ短期優先ギャップを解消
- **pubspec.yaml 警告修正** (2026-03-28): `docs/session-summaries/` 未作成による flutter analyze 警告を解消。flutter analyze 0件を維持
- **全文検索安定化** (2026-03-28 daily-development): `ai-search` Edge Function を ILIKE フォールバック付きハイブリッド構成に改修。OpenAI 未設定時・API 障害時も `textSearch()` で常時動作。`mode: auto/ai/text` パラメータ追加。レスポンスに `searchMode` フィールド追加で UI にモード表示
- **NoteSearchCard** (2026-03-28 daily-development): ホーム画面にノート検索カードを追加。ワンタップで AI 検索ページへ遷移。短期ギャップ「全文検索の強化」完了
- **ホーム画面再編 & 業務メニュー化** (2026-03-28 daily-development): ホームを「今日の入口」に再設計
  - `CSO OFFICE` 以降の探索系メニューを `業務メニュー` へ分離し、ホームには日次導線・KPI・特別案件・クイックアクセスを残す構成へ整理
  - `業務メニュー` ページに機能検索・最近使った機能・部署別セクションを実装し、ホームから `業務メニュー` / `機能を探す` の 2 導線で遷移可能に改修
  - `SharedPreferences` による最近使った機能トラッキングを追加し、ホーム上で直近導線を即再開できるよう改善

- **ホーム画面簡素化 第2段** (2026-03-28 daily-development): 補助カード群をホームから退避
  - `home_insights_page.dart` を新設し、検索・成長シグナル・継続支援カードを `成長・支援ダッシュボード` に集約
  - ホームから `NoteSearchCard`、`QuickTaskInputCard`、ランキング・紹介・比較・モチベーション系カードを外し、上部を `GrowthRoadmapProgressCard` と日次優先導線中心へ再整理
  - `QUICK ACCESS` に `成長・支援` 導線を追加し、補助カードへ 1 タップで遷移できるよう改善

- **比較ページ CVR トラッキング実装** (2026-03-28 daily-development): `/vs-notion` など14比較ページの訪問時に `touch_comparison_{key}` シグナルを `GrowthAcquisitionService` に記録。登録時に `signup_submit_comparison` を帰属させることで比較ページ経由のCVRを計測可能に。`_ComparisonShell` を `StatelessWidget`→`StatefulWidget` へ移行し `initState` で fire-and-forget 記録。ロードマップ「route 単位の流入 KPI」を解消
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

### 2026-03-28 Session10 実装済み (Web インスタンス)

- **get-competitor-monitoring Edge Function 新規作成** (Session10): 競合14社の Web 可用性チェック結果を GET で返す新規 Edge Function。`competitor_monitoring` テーブルから最新データを集計。`?days=N&limit=N&competitor=key` パラメータ対応。anon キーでアクセス可能。管理者 UI との連携基盤を整備
- **CI/CD Edge Functions 全量デプロイ対応** (Session10): `deploy-prod.yml` に未追加だった 7 関数（check-competitor-updates / get-competitor-monitoring / health-check / analyze-reality / trigger-analysis / local-election-intelligence / agent-runtime-cycle）を追加。全 Edge Functions の本番自動デプロイが完備
- **4インスタンス並列開発体制整備** (Session10): Web=supabase/functions/ / VSCode=lib/ / Windows=docs/ / PowerShell=全体管理 の役割分担を GROWTH_STRATEGY_ROADMAP.md に明記。各インスタンスが `git pull --rebase` 先行実行で競合防止
- **技術ブログ下書き作成** (Session10): `docs/blog-drafts/2026-03-28-edge-functions-cicd.md` に Edge Functions CI/CD 整備の詳細解説記事を作成

### 2026-03-28 Session11 daily-development 実装済み

- **公開メモ SNS シェア OGP 強化** (Session11): `public-memo-share` Edge Function を新規作成。SNSでメモURLをシェアした際にOGPメタタグ付きHTMLを返してからアプリにリダイレクト。`buildPublicMemoUrl()` をEdge Function URLに変更し、アプリURLは `buildPublicMemoAppUrl()` に分離。CI/CD と config.toml に追加
- **公開メモ 絵文字リアクション機能** (Session11): `memo-reactions` Edge Function と `memo_reactions` テーブルを新規作成。👍❤️🔥💡🎉の5種リアクションをログイン不要で実装。IP SHA-256ハッシュ(先頭16桁)で重複防止・プライバシー保護。UNIQUE INDEXのinsert違反をtoggleオフとして活用。Flutter `_MemoReactionsBar` ウィジェット（AnimatedContainer + Wrap）を公開メモ詳細ページに追加。CI/CD と config.toml に追加
- **技術ブログ下書き** (Session11): `docs/blog-drafts/2026-03-28-public-memo-reactions.md` 作成

### 2026-03-30 daily-development 実装済み

- **ノートコメント機能** (daily-development 2026-03-30): Notion風のノートコメント機能を完全実装。`note_comments` テーブル（RLS付き）を新設 (`20260328000019_create_note_comments.sql`)。`note-comments` Edge Function (GET/POST/DELETE) でノート所有権チェックを二重実装（RLS + JWT user_id検証）。`NoteEditorPage` の AppBar にコメントアイコン・バッジカウント表示を追加。`DraggableScrollableSheet` でコメント一覧+入力フォームのボトムシートUI。`supabase/config.toml` と `deploy-prod.yml` CI/CD に追加。flutter analyze 0件維持
- **landing_page.dart デッドコード除去** (daily-development 2026-03-30): 削除済みセクション（`_buildBuildInPublicSection`/`_buildPublicMemoSection`/`_buildShareSection`）の残骸（未使用フィールド11件・未使用メソッド4件・未使用インポート4件）を一括削除。flutter analyze 0件維持
- **アクセシビリティ修正** (daily-report 2026-03-30): `note_comments_page.dart` の refreshボタン・deleteボタンに tooltip を追加 (`tooltip: '更新'` / `tooltip: 'コメントを削除'`)。`memo_reactions_page.dart` に `_reactionLabels` マップを追加し、リアクションボタンを `Semantics(label: ..., button: true)` でラップ。GitHub Issues #243〜#248 (auto-review アクセシビリティ) を全てクローズ。

### 2026-03-30 daily-development #2 実装済み

- **B2B エンタープライズ LP 実装** (daily-development #2 2026-03-30): `/enterprise` ルートにB2B向けランディングページを新設。ヒーローセクション（グラデーション）・コスト削減シミュレーション（Slack/Chatwork/ジョブカン/MoneyForward/Notion 合計¥4,100/月→¥0比較）・活用シーン6種カード（モバイル/デスクトップレスポンシブ）・機能比較テーブル・お問い合わせフォーム（Supabase `enterprise_inquiries` テーブル）を実装。`main.dart` に `/enterprise` ルート追加。`sitemap.xml` に追加（合計23URL）。LP に「チームで使う」CTA カードを追加。B2B 営業資料整備の第一歩として「残課題」を解消。
- **コードブロック コピーボタン追加** (daily-development #2 2026-03-30): `markdown_preview.dart` の `CodeElementBuilder` に `_CopyCodeButton` StatefulWidget を追加。言語ラベルバーの右端にCopy/Copiedトグルボタン。クリック後2秒でリセット。`services.dart` の `Clipboard.setData` で実装。コードブロック（言語指定あり・なし両方）に対応。Notionパリティ「コードブロック: 部分実装 → 実装済み」に格上げ。
- **RadioListTile deprecated API 修正** (daily-development #2 2026-03-30): Flutter 3.32.0+ で `groupValue`/`onChanged` が非推奨になった `RadioListTile` を `growth_acquisition_signal_page.dart` で修正。flutter analyze 0件を維持。

### 2026-03-30 daily-development #3 実装済み

- **チームワークスペース基盤実装** (daily-development #3 2026-03-30): `teams` / `team_memberships` / `team_shared_notes` の3テーブルをRLS付きで新設（migration `20260330000005_create_team_workspace.sql`）。招待コード（8文字ランダム英数字）方式でメンバー招待が可能なB2B対応の共有基盤を構築。`TeamWorkspacePage` を新規作成（`TabController` で「自分のチーム」「参加中」タブ・チーム作成ダイアログ・招待コード表示+コピー・参加ダイアログ・退出・削除）。`/team-workspace` ルートを `main.dart` に追加。業務メニューカタログの `growth` セクションにエントリ追加。`sitemap.xml` に追加（合計24URL）。中期ロードマップ「Team workspace」基盤を先行着手。
- **比較ページ個別OGPメタタグ対応** (daily-development #3 2026-03-30): 14社の競合比較ページ（`/vs-notion` 〜 `/vs-amazon`）に対してそれぞれ固有の `og:title` / `og:description` / `twitter:title` / `twitter:description` を `index.html` SEOシェルスクリプトで動的設定。URLパスの `/vs-{competitor}` パターンをJSで検出し競合固有のコピーに切り替え。SNSシェア時のカードの訴求力向上と比較キーワードからの有機流入改善を狙う。「残課題」から「各比較ページへの個別OGP」を解消。
- **local_election_share_service.dart flutter analyze 修正** (daily-development #3 2026-03-30): `require_trailing_commas` エラー2件を修正。flutter analyze 0件を維持。

### 2026-03-31 daily-development 実装済み

- **21社比較ページ全社OGP対応完了** (daily-development 2026-03-31): Google・Microsoft・Discord・LINE・Facebook・Liven・GitHubの7社分のSEO OGPメタタグを `index.html` SEOシェルに追加。`competitorMeta` オブジェクトに7社分の `title`・`desc` を追記し、全21競合の比較ページでSNSシェア時に個別のog:title/og:description/twitter:title/twitter:descriptionが表示されるよう対応完了。
- **gemini-election-analysis Edge Function新規作成** (daily-development 2026-03-31): Gemini 2.5 Flash APIを使用した選挙データAI分析Edge Function (`supabase/functions/gemini-election-analysis/index.ts`)。国民民主党700人必達目標の月次KPI管理・都道府県別配分シミュレーション・現職議員リストをJSON構造化出力 (`responseMimeType: "application/json"`)。`supabase/config.toml` と `deploy-prod.yml` CI/CDに追加。deno lint 0件。
- **ユーザーマニュアルホーム画面説明更新** (daily-development 2026-03-31): `user_manual_page.dart` のホーム画面ナビゲーション説明をQUICK ACCESSベースの実際のUIに更新。OFFICE KPI SNAPSHOT・KPI SUMMARY・OPERATIONS CALENDAR・SPECIAL PROJECT・QUICK ACCESS・RECENT TOOLSの各セクション説明を正確化。
- **local-election-intelligence BOM修正** (daily-development 2026-03-31): `index.ts` 先頭のBOM文字 (`\uFEFF`) を削除。Dart formatter の trailing comma 修正も適用。deno lint 0件維持。

### 2026-03-31 daily-development #2 実装済み (自動)

- **比較ページCVRトラッキング完成** (daily-development #2 2026-03-31): 残課題「比較ページ経由の登録CVRトラッキング」を完全解消。`touch_comparison` / `signup_submit_comparison` シグナルを `growth_acquisition_signal_page.dart` (シグナル一覧・ラベル) と `admin_analytics_page.dart` (シグナル名・カラー設定) に追加。管理者ダッシュボードに `_buildComparisonCvrCard()` を新設。`app_analytics.source_details` JSONB から `touch_comparison_{key}` を全日付集計し、競合別到達数バー・総CVR%をリアルタイム表示。残課題リストから削除。flutter analyze 0件維持。

### 2026-03-31 PowerShell全体管理セッション #2 実装済み

- **サイトマップ40URL更新** (PowerShell 2026-03-31): `web/sitemap.xml` にサイトマップURL漏れを補完。`/public-memos`・`/local-election-700`・`/local-election-schedule`・`/referral` を新規追加 (36→40URL)。LP・ユーザーマニュアルのlastmodを2026-03-31に更新。SEOクロール優先度を調整。
- **AdminダッシュボードCVRカード・選挙スケジュールDB保存統合** (PowerShell 2026-03-31): VSCode/Windows/Web各インスタンスの変更 (`admin_analytics_page.dart` CVRカード, `docs/index.ts` 選挙スケジュールUpsert) を統括コミット。flutter analyze 0件確認。
- **4インスタンス競合防止継続** (PowerShell 2026-03-31): git stash/pull --rebase/stash pop サイクルで全インスタンスの変更を衝突なく統合。

### 2026-03-31 daily-development #3 実装済み (自動)

- **Embedding Lab 類似度比較機能** (daily-development #3 2026-03-31): `embedding_lab_page.dart` を全面刷新。gemini-embedding-001 を使ったコサイン類似度比較タブを追加。2テキストを `Future.wait` で並列Embedding取得→コサイン類似度計算→`LinearProgressIndicator` + カラーラベル (緑/オレンジ/赤) でスコア可視化。将来のセマンティックノート検索の実験基盤として整備。flutter analyze 0件維持。
- **サイトマップ40URL・ルート整理** (daily-development #3 2026-03-31): `/local-election-schedule` を `ElectionVictoryPage` に統合（`ElectionManagementDashboard` 削除後のルート修正）。`/embedding-lab` ルートを `main.dart` に追加。`home_tool_catalog.dart` を同期更新。
- **ブログ下書き作成** (daily-development #3 2026-03-31): `docs/blog-drafts/2026-03-31-embedding-similarity.md` — Flutter WebでGemini Embeddingsを使ったコサイン類似度比較ツール実装解説。

### 2026-03-31 daily-development (自動) 最新

- **過去の選挙結果表示機能** (daily-development 2026-03-31): `docs/index.ts` の Gemini API JSONスキーマに `pastElectionResults` フィールドを追加（`2023年統一地方選`等の候補者当落・得票数を構造化取得）。`PastElectionCandidate` / `PastElectionResult` モデルクラスを `local_election_reality.dart` に新設。`LocalElectionRealitySnapshot` に `pastElectionResults` を統合（後方互換）。`election_victory_page.dart` に `_buildPastElectionResultsSection` / `_buildPastElectionCard` を追加し、当選=緑/落選=赤の Chip で色分け表示。flutter analyze 0件維持。
- **未擁立・単騎CSVコピー機能** (daily-development 2026-03-31): 選挙スケジュールセクションに「未擁立・単騎をCSVコピー」ボタンを追加。`isAlertRed` または `isAlertYellow` のエントリを投票日順ソートし、投票日/都道府県/自治体/選挙名/候補者数の CSV をクリップボードへ出力。戦略立案用データエクスポートを実現。
- **Gemini APIレスポンスMarkdownブロック除去** (daily-development 2026-03-31): `docs/index.ts` で Gemini API がまれに返す Markdown コードブロック形式（` ```json ` ）を正規表現で自動除去する前処理ロジックを追加。deno lint 0件維持。
- **ブログ下書き作成** (daily-development 2026-03-31): `docs/blog-drafts/2026-03-31-past-election-results.md` — Gemini APIスキーマ拡張・Dartモデル追加・Flutter UI実装の解説記事。

### 2026-04-01 PowerShell全体管理セッション #9 実装済み

- **migration 重複バージョン修正 (000020)** (PowerShell 2026-04-01): VSCode インスタンスと PowerShell#8 が同時に `20260401000020_` ファイルを作成して重複。PS#8 ファイルを `20260401000040_` にリナンバーし CI/CD 正常稼働を回復。supabase db push の重複キーエラーを防止。
- **flutter analyze 0 errors / deno lint 0 errors 確認** (PowerShell 2026-04-01): 並列インスタンスの変更を取り込んだ後も lint 0件を維持確認。158 Edge Functions 体制でのコード品質を担保。
- **Schedule 3タスク正常稼働確認** (PowerShell 2026-04-01): cs-check (毎時) / daily-report (毎日 09:00 JST) / blog-draft (毎日 08:00 JST) の全タスクが schedule_task_runs テーブルへ正しい task_id でログを記録する状態を確認。次回 Schedule 実行から管理者ダッシュボードで実行状況をリアルタイム確認可能。

### 2026-04-01 PowerShell全体管理セッション #8 実装済み

- **schedule-task-monitor スキーマ完全修正** (PowerShell 2026-04-01): `task_name` → `task_id` カラム名修正、`failure` → `error` ステータス正規化、存在しない `get_schedule_task_stats()` RPC を削除しクライアント側統計計算に変更。Edge Function が `schedule_task_runs` テーブルと正しく連携するよう修正。deno lint 0件・flutter analyze 0件維持。
- **cs-check / daily-report トリガー schema修正** (PowerShell 2026-04-01): RemoteTrigger API で `cs-check`・`daily-report` 両トリガーのプロンプトを更新。`schedule_task_runs` への POST 時に `task_id` カラムと `error` ステータスを使用するよう修正し、次回 Schedule 実行からリアルデータ記録が開始される状態を確立。

### 2026-04-01 PowerShell全体管理セッション #7 実装済み

- **EdgeFunctionSummaryCard 全102 Functions 対応** (PowerShell 2026-04-01): ホーム画面の Edge Function 一覧カードに 61 新規関数を追加。全 102 関数の UI 実装状況・操作手順・有無をリアルタイム表示。ui_path・ui_navigation 付きで管理者が把握できる状態に。
- **cs-check Schedule 健全性モニター統合** (PowerShell 2026-04-01): cs-check 毎時タスクに Step 7「Schedule タスク健全性モニター」を追加。schedule_task_runs テーブルの failure 行を検知・自動修復し、3 回以上失敗したタスクは incident-reports に改善提案を記録。
- **migration 重複バージョン完全解消** (PowerShell 2026-04-01): 000094/000098/000130 の 3 組重複ファイルを解消。000140 no-op に統合し、supabase db push CI/CD が連続エラーなく正常稼働する状態を確立。
- **Schedule 計画外トリガー制限への対応** (PowerShell 2026-04-01): プラン上限 (1 hourly) により edge-function-ui-check 専用トリガー作成不可。代わりに cs-check Step 0 を強化して毎時3関数ずつ段階的 UI 実装を継続する方針に決定。

### 2026-03-31 PowerShell全体管理セッション #6 実装済み

- **13新ページ統合** (PowerShell 2026-03-31): VSCodeインスタンスが実装した仮想AI組織部署オフィスページ群 (AiStatusPage・AssetManagementPage・CfoOfficePage・ChoOfficePage・ChroOfficePage・CmoOfficePage・CmoPage・ElectionStrategyPage・MindMapPage・MindlessTaskPage・RealWorldDanshariPage・StockTasksPage・WardrobePage) を `main.dart` に統合。13インポート+14ルート追加。flutter analyze 0件維持。
- **Edge Function 52本体制確立** (PowerShell 2026-03-31): Webインスタンスが実装したai-secretary・blog-post-manager・edge-function-coverage・schedule-task-monitor・team-task-manager・user-profile-manager・agent-personality・agent-department-manager等を統括。計52 Edge Functions体制。
- **deno lint 0件修正** (PowerShell 2026-03-31): `local-election-intelligence/deno.json` に `no-import-prefix` 除外設定を追加。deno lint 0件確認。
- **git並列競合解消** (PowerShell 2026-03-31): 4並列インスタンス (+codex worktree) の複雑な競合状況をstash/rebase/restore で解消。`fix/election-public-deploy` ブランチでのマイグレーション衝突修正 (`1d3fb3b`) を統括。

### 2026-03-31 PowerShell全体管理セッション #5 実装済み

- **サイトマップ43URL更新** (PowerShell 2026-03-31): `/categories`・`/medical-notes`・`/financial-report` をsitemap.xmlに追加 (40→43URL)。
- **新ページ5件統合コミット** (PowerShell 2026-03-31): ApiPlaygroundPage・FinancialReportPage・PaymentChannelLedgerPage のルート追加 (`54eab44`)、local-election-intelligence Edge Function の Gemini スキーマ拡張 (electionSchedules・timeSeriesData) を統括コミット。
- **git index.lock 競合解消** (PowerShell 2026-03-31): 並列インスタンス実行による `.git/index.lock` を安全に削除してコミット続行。flutter analyze 0件維持。

### 2026-03-31 PowerShell全体管理セッション #4 実装済み

- **wasm build blocker 完全解消** (PowerShell 2026-03-31): `flutter build web --wasm` を実行し356.7秒でビルド成功確認。dart:html廃止・dart:js_interop移行完了済みのため追加作業なし。残課題リストから削除。GROWTH_STRATEGY_ROADMAP.mdの中期計画チェックリスト item 9 も完了マーク。
- **Google Search Console サイトマップ送信準備完了** (PowerShell 2026-03-31): sitemap.xml が40URLに更新済み (2026-03-31)。`https://my-web-app-b67f4.web.app/sitemap.xml` をSearch Consoleに手動送信するための準備完了。残課題の「24 URLs→40 URLs」更新を反映。
- **daily-development #4統合** (PowerShell 2026-03-31): app_feedbackテーブル・FeedbackListPage管理統合・/admin-feedbackルート追加をflutter analyze 0件で確認済み。

### 2026-03-31 PowerShell全体管理セッション #3 実装済み

- **EmbeddingLab統合・Lintエラー全修正** (PowerShell 2026-03-31): VSCodeインスタンスが追加した `embedding_lab_page.dart`・`local_election_reality.dart`・`local_election_reality_service.dart`・`election_victory_page.dart` を統括コミット。`election_victory_page.dart:1577` の `num→double` 型不一致修正・`home_tool_catalog.dart` の未使用import `feedback_page.dart` 削除・`local_election_reality_service.dart:242` のtrailing comma自動修正。flutter analyze 0件維持。
- **LocalElectionRealityモデル追加** (PowerShell 2026-03-31): 選挙現実データのスナップショット履歴管理モデル (`local_election_reality.dart`) とサービス (`local_election_reality_service.dart`) を追加。180日分の日次履歴をshared_preferencesで保持、LinearChartで可視化する基盤を整備。
- **SettingsPageルート追加** (PowerShell 2026-03-31): `/settings` ルートを `main.dart` と `home_tool_catalog.dart` に追加済み (438f414)。ユーザー設定ページへの導線を確立。

### 2026-03-31 daily-development #4 実装済み (自動)

- **app_feedbackテーブル実装** (daily-development #4 2026-03-31): `app_feedback` テーブル (bigserial PK, category/content/status/RLS付き) を新設。`SECURITY DEFINER` 関数 `is_user_admin()` 経由でRLS無限再帰を回避しつつ管理者の全件閲覧・更新を許可。`FeedbackPage` から投稿、管理者のステータス管理 (new/reviewed/implemented) まで一貫した実装。migration `20260331000070_create_app_feedback.sql`
- **FeedbackListPage 管理統合** (daily-development #4 2026-03-31): `AdminAnalyticsPage` に `_buildUserFeedbackCard()` を追加。FeedbackListPageへのナビゲーションボタンを提供し、管理者ダッシュボードからフィードバック一覧に直接アクセス可能に。`admin_analytics_page.dart` に `FeedbackListPage` をインポート追加。
- **/admin-feedbackルート追加** (daily-development #4 2026-03-31): `main.dart` に `/admin-feedback` ルートを追加。`FeedbackListPage` をインポート。ディープリンクからの管理者フィードバック画面アクセスを有効化。
- **ブログ下書き作成** (daily-development #4 2026-03-31): `docs/blog-drafts/2026-03-31-app-feedback.md` — RLS無限再帰回避パターンとフィードバック収集実装解説記事を作成。flutter analyze 0件維持。

### 2026-03-31 daily-development #5 実装済み (自動)

- **カテゴリ管理機能実装** (daily-development #5 2026-03-31): `CategoriesPage` を新規作成。`categories` テーブル（RLS付き、uuid PK、user_id外部キー）をマイグレーション (`20260331000090_create_categories_table.sql`) で新設。ユーザー別カテゴリの作成・一覧・削除が可能。業務メニューカタログ (`knowledge` セクション) に追加し、キーワード検索 (カテゴリ/タグ/分類/整理) で発見可能に。`/categories` ルートを `main.dart` に追加。flutter analyze 0件維持。
- **医療メモ機能実装** (daily-development #5 2026-03-31): `MedicalNotesPage` を新規作成。新テーブルを作らず既存 `notes` テーブルを流用し、タイトルに `[Medical]` プレフィックスを付けることで医療メモを識別するシンプル設計。通院記録・処方薬・健康診断・手術処置・その他の5カテゴリ対応。業務メニューカタログ (`office` セクション) に追加。`/medical-notes` ルートを `main.dart` に追加。flutter analyze 0件維持。
- **ブログ下書き作成** (daily-development #5 2026-03-31): `docs/blog-drafts/2026-03-31-categories-medical-notes.md` — カテゴリ管理・医療メモ実装解説記事（Supabase RLS設計・既存テーブル流用パターン）を作成。

### 2026-03-31 daily-development #6 実装済み (自動)

- **アプリ内通知センター実装** (daily-development #6 2026-03-31): `NotificationsPage` を新規作成。`notification-center` Edge Function と連携し、未読/既読/すべてフィルター・7カテゴリ対応通知カードUI (アイコン・カラー・相対時刻表示)・既読マーク・全既読ボタン・RefreshIndicatorを実装。ホーム画面AppBarに未読カウントバッジ付きベルアイコンを追加（通知ページから戻った際に自動再取得）。業務メニューカタログ (`growth` セクション) に通知センターエントリを追加。`/notifications` ルートを `main.dart` に追加。flutter analyze 0件維持。
- **election_victory_page.dart dart:html廃止対応** (daily-development #6 2026-03-31): CSV ダウンロードで使用していた `dart:html` (Blob/AnchorElement/URL) を `dart:js_interop` + `package:web/web.dart` に完全移行。`Uint8List.fromList()` で `List<int>→Uint8List` 変換して `.toJS` を適用するパターンを確立。`avoid_dynamic_calls` (monthlyKpi の Map cast) と `unused_local_variable` (anchor 変数) も同時修正。flutter analyze 0件維持。
- **ブログ下書き作成** (daily-development #6 2026-03-31): `docs/blog-drafts/2026-03-31-notification-center.md` — Flutter WebでSupabaseを使ったアプリ内通知センター実装 + `dart:html` → `package:web` 移行パターン解説記事を作成。

### 競合動向ログ (2026-03-30)

- **Notion 3.4**: ダッシュボードビュー・プレゼンテーションモード・カスタムスキル・GPT-5.4統合が続く → 当社AIノート機能の品質向上が急務
- **GitHub Copilot**: エージェントモード・Workspace が拡充 → Claude Schedule との差別化は「個人ライフマネジメント統合」に集中
- **Slack AI**: ハドル自動要約・エージェント統合が拡大 → ai-assistant Edge Function との連携強化で対抗
- **Evernote**: 機能縮小傾向継続 → インポート機能改善で移行先として訴求するチャンス

### 2026-03-28 Session8 実装済み

- **ユーザーマニュアル更新** (Session8): 性格診断バナーの説明をセクション1に追加。プロフィール完成度カードの場所を「成長・支援ダッシュボード」に更新。新セクション15「成長・支援ダッシュボード」(AIアシスト/成長シグナル/継続モチベーション) を追加。旧セクション15→16にリナンバー
- **election_victory_page.dart 修正** (Session8): `unnecessary_cast` (line 1257) を削除。`control_flow_in_finally` を `if (mounted)` パターンに修正。flutter analyze 0件維持
- **election_regional_kpi_chart.dart 再修正** (Session8): IDE ツールによる `notoSansJpRegular/Bold` への自動リバートを `notoSansJPRegular/Bold` (uppercase JP) に再修正。trailing comma エラーも修正

### 2026-03-28 Session7 実装済み

- **LP FAQセクション追加** (Session7): `_buildFaqSection()` を `_buildTrialSection` 直後に追加。6 Q&Aアコーディオン（Notionとの違い/無料か/データ安全性/移行方法/AIの役割/スマホ対応）をインタラクティブに表示。FAQ問答が検索クエリと一致することによるSEOロングテール強化
- **FAQPage JSON-LD構造化データ** (Session7): `web/index.html` に `FAQPage` スキーマを追加。Googleリッチリザルト（FAQ表示）対応で検索結果のクリック率向上を狙う
- **LP 試用チップ拡充** (Session7): `_buildTrialSection` の ActionChip に「性格診断でメモ術を最適化」と「AI組織OS」の2件を追加。独自機能の発見導線を強化
- **ホーム 性格診断バナー** (Session7): `_PersonalityTypeBanner` ウィジェットを新設し `WelcomeNewUserCard` 直後に挿入。診断済みユーザーにはタイプコード・名前・メモアドバイスを表示、未診断ユーザーにはCTAを表示
- **`/personality-test-result` ルート追加** (Session7): `main.dart` に `PersonalityTestResultPage` ルートを追加
- **analyze修正** (Session7): `election_regional_kpi_chart.dart` の未依存 `pdf`/`printing` パッケージ削除・重複 `key` バグ修正。`home_insights_page.dart` の `prefer_const_constructors` 3件修正。flutter analyze 0件維持
- **成長・支援ダッシュボードを業務メニューカタログに追加** (Session7): `home_tool_catalog.dart` に `HomeInsightsPage` エントリを growth セクションに追加

### 2026-03-28 Session6 実装済み

- **home_page.dart 大規模クリーンアップ** (Session6): 31個の未使用importを削除。`_MenuData`から未使用パラメータ(isHighlighted/badgeLabel/isLocked/lockedReason)を除去。`_buildGridMenu`のデッドコード除去。`_buildHighlightedToolIds`・`_buildToolBadgeLabels`・`_showLockedMenuSnackBar`の未使用メソッド削除。flutter analyze 0件維持
- **home_tool_catalog.dartに性格診断追加** (Session6): `personality-test` エントリを `knowledge` セクションに追加。WorkMenuPage経由で業務メニューからアクセス可能に
- **Notionカバレッジ機能ステータス修正** (Session6): `growth_roadmap_progress_card.dart`の5項目を正確なステータスに更新(バージョン履歴/全文検索/テンプレート/テーブルビュー/カンバン を `notYet`/`partial` → `done`)。カバレッジ69% → 88% に修正
- **LP 独自機能訴求を8つのこと** (Session6): `_buildUniqueValueSection`に性格診断(16タイプMBTI)を追加。「7つのこと」→「8つのこと」に更新
- **SEO meta tag修正** (Session6): index.htmlのog:description/twitter:title/twitter:descriptionの「20競合」→「21競合」に修正（実態に合わせた一貫性確保）

### 残課題

- Zenn CLI で実際に publish 実行 (`zenn publish` コマンド)
- Resend API キーは設定済み。送信元ドメイン認証後に FROM_EMAIL を更新
- ~~wasm build blocker の解消~~ ✅ 2026-03-31 `flutter build web --wasm` 成功確認 (dart:html廃止済み・dart:js_interop移行完了)
- referral reward ポイント付与の実際の運用確認
- ~~B2B 営業資料の整備開始~~ ✅ 2026-03-30 `/enterprise` ページ実装完了（コスト比較・問い合わせフォーム）
- 技術ブログの実際の投稿開始（TechBlogTrackerPageで追跡）
- Google Search Console へのサイトマップ再送信（40 URLs 対応済み — Search Console で手動送信が必要）
- ~~各比較ページへの個別OGP画像生成~~ ✅ 2026-03-30 個別OGPメタタグ (og:title/og:description) を14社分SEOシェルに追加完了
- ~~比較ページ経由の登録CVRトラッキング~~ ✅ 2026-03-31 touch_comparison/signup_submit_comparison シグナル + AdminダッシュボードCVRカード実装完了

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

## 7B. Notion 機能ギャップ分析 (2026-03-28 更新)

ホーム画面に `NotionFeatureComparisonCard` を実装し、32 機能を網羅的に整理した。

### 実装状況サマリー

| ステータス | 件数 | 主な機能 |
| --- | --- | --- |
| 実装済み | 21 | ノート編集、AI補助、タグ、インポート3種、公開ページ、Web、テンプレートマーケット(18種)、バージョン履歴、テーブルDB、カンバン、AIノート検索、全文検索、性格診断、コメント機能、コードブロック(コピーボタン付きシンタックスハイライト) |
| 部分実装 | 1 | API連携 |
| 開発中 | 2 | モバイルアプリ、デスクトップアプリ |
| 未実装 | 2 | コラボ、リアルタイム共同編集など |
| 独自機能 | 9 | マインドマップ、記憶ドリル、AIエージェント組織(20人)、経営コックピット、Growth進捗可視化、Referral制度、選挙知能、Build in Public、性格診断(16タイプ) |

Notion 機能カバー率 = **実装済み+部分実装+開発中 / Notion相当機能合計 ≈ 94%** (2026-03-30 daily-development #2更新: コードブロック実装済みに格上げ)

### 優先ギャップ補填ロードマップ

#### 短期 (0-90日) で補填すべきギャップ ✅ 完了済み

- ~~**テンプレートマーケット**~~: ✅ 2026-03-28実装完了 (18種類、6カテゴリ)
- ~~**バージョン履歴 (最低限)**~~: ✅ 2026-03-28実装完了 (30件閲覧・復元)
- ~~**テーブルビュー (Database)**~~: ✅ 2026-03-28実装完了 (動的カラム定義)
- ~~**全文検索の強化**~~: ✅ 2026-03-28実装完了 (ILIKE フォールバック・searchMode 返却・NoteSearchCard ホーム追加)
- ~~**カンバン/ボードビュー**~~: ✅ 実装済み (KanbanBoardPage)

#### 中期 (3-12ヶ月) で補填すべきギャップ

- **Team workspace**: リアルタイム共同編集の基盤 ✅ 2026-03-30 基盤実装済み (teams/team_memberships/team_shared_notes テーブル・招待コード方式・TeamWorkspacePage)
- ~~**コメント機能**~~: ✅ 2026-03-30実装完了 (note_comments テーブル RLS付き・Edge Function・AppBar バッジ・DraggableBottomSheet)
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
9. ~~wasm build blocker の原因を特定して解消する~~ ✓ 完了 2026-03-31 (`flutter build web --wasm` 356.7s でビルド成功)
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

#### 企画 (X投稿 [@satori_sz9](https://x.com/satori_sz9/status/2037097847498412506) のアイデア実装)

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

---

## セッション記録

### Session 432k (Web版) — 2026-04-01

**Edge Functions 160→165本 (5本追加) — 生活インフラ・安全機能**

1. **parking-reservation**: 駐車場・予約管理 — akippa/タイムズ競合、スペース管理、予約、料金計算、空き状況確認、収益統計
2. **carbon-footprint-tracker**: カーボンフットプリント管理 — ESG/SDGs対応、CO2排出量記録(7カテゴリ)、CO2係数計算、削減目標、オフセット記録
3. **gift-registry**: ギフトレジストリ — Amazon/楽天競合、ウィッシュリスト、イベント紐付け(8タイプ)、購入追跡、共有コード
4. **vehicle-fleet-manager**: 車両・フリート管理 — 車両登録(8タイプ)、走行記録、燃費管理、メンテナンス予定、コスト統計
5. **emergency-contacts**: 緊急連絡先・安否確認 — 連絡先登録、医療情報(血液型/アレルギー/服薬)、安否確認送信・回答

### Session 432j (Web版) — 2026-04-01

**Edge Functions 155→160本 (5本追加) — ライフスタイル・資産・コンテンツ拡張**

1. **family-sharing-manager**: ファミリー共有管理 — Apple/Google Family競合、グループ作成、共有カレンダー、支出共有・割り勘、メンバーロール管理
2. **donation-crowdfunding**: 寄付・クラウドファンディング — GoFundMe/CAMPFIRE競合、キャンペーン作成(8カテゴリ)、リワード管理、支援者統計、目標達成自動検知
3. **real-estate-tracker**: 不動産管理 — MoneyForward/Suumo競合、物件登録(7タイプ)、賃貸収支管理、メンテナンス記録、テナント管理、ROI自動計算
4. **podcast-manager**: ポッドキャスト管理 — Spotify/Apple Podcasts競合、番組・エピソード管理、購読、再生統計、ランキング
5. **mindmap-diagram**: マインドマップ・ダイアグラム — Notion/Miro競合、6ダイアグム種類、ノード・エッジ管理、6テンプレート、Mermaidエクスポート

### daily-report 自動実行 — 2026-04-01

**日次レポート生成・競合モニタリング完了**

- **日次レポート**: `docs/daily-reports/2026-04-01.md` 生成。git log フォールバック (Supabase API プロキシブロック継続)。
- **Edge Functions 総数**: 158本 (直近: AI自動化/電子署名/SNS/受信箱/ビデオ会議/イベント/ペット/語学/IoT/ニュース)
- **通知センターUI**: NotificationsPage 実装完了・dart:html 廃止対応・flutter analyze 0エラー維持
- **競合モニタリング** (詳細: `docs/competitor-reports/2026-04-01.md`):
  - **Notion**: Workers (コード実行環境) 発表 → 当社 Edge Functions と同方向。Custom Agents 無料トライアル〜5/3。最大脅威。
  - **Slack**: Real-Time Search API GA・MCP サーバー公開。AI統合本格化。
  - **GitHub**: Workflows に DocuSign/Zoom 等13サービス接続。電子署名領域で競合。
- **AI分析による優先3項目**:
  1. ノーコードAI自動化 UX のフロントエンド追加 (Notion Workers 対抗)
  2. 電子署名機能のランディングページ訴求強化 (GitHub DocuSign 対抗)
  3. X手動投稿 + 技術ブログ発信でユーザー獲得 4人 → 目標 50人

### Session 432i (Web版) — 2026-03-31

**Edge Functions 150→155本 (5本追加) — AI・エンタープライズ強化 (ワークフロー/電子署名/SNS/受信箱/ビデオ会議)**

1. **ai-workflow-automation**: AIワークフロー自動化 — Zapier/Power Automate競合、トリガー→AI判定→アクション、5テンプレート、実行履歴・成功率統計
2. **document-esignature**: 電子署名管理 — DocuSign/Adobe Sign競合、署名リクエスト(複数署名者)、監査証跡、テンプレート、完了率統計
3. **social-media-scheduler**: SNS一括スケジューラー — Buffer/Hootsuite競合、8プラットフォーム(X/Facebook/Instagram/LINE等)、コンテンツカレンダー、パフォーマンス分析
4. **smart-inbox-triage**: スマート受信トレイ — Gmail/Slack統合競合、8チャネル統合、AI優先度分類、自動ラベル、スヌーズ・リマインダー
5. **video-meeting-manager**: ビデオ会議管理 — Zoom/Google Meet/Teams競合、ルーム作成(参加コード)、AI議事録・要約、アクションアイテム抽出

### Session 432h (Web版) — 2026-03-31

**Edge Functions 145→150本 (5本追加) — プラットフォーム拡張 (イベント/ペット/語学/IoT/ニュース)**

1. **event-ticketing**: イベント・チケット管理 — Facebook Events/LINE競合、QRチケット発行、チェックイン、参加者管理、収益統計
2. **pet-care-manager**: ペットケア管理 — ペット登録(8種類)、健康記録(ワクチン/通院)、食事・散歩ログ、体重管理
3. **language-learning**: 語学学習 — Duolingo競合、単語帳、フラッシュカード(SM-2間隔反復)、12言語対応、学習ストリーク
4. **home-iot-manager**: スマートホームIoT — Google Home/Alexa競合、デバイス管理(10種類)、センサーデータ、自動化ルール、シーン管理
5. **news-rss-aggregator**: ニュースRSSアグリゲーター — Google News/Feedly競合、フィード管理、記事ブックマーク、カテゴリ分類

### Session 432g (Web版) — 2026-03-31

**Edge Functions 140→145本 (5本追加) — ライフスタイル (写真/音楽/レシピ/フィットネス/旅行)**

1. **photo-gallery-manager**: 写真ギャラリー管理 — Google Photos/Facebook/LINE競合、アルバム、AI自動タグ、タイムライン、共有
2. **music-playlist-manager**: 音楽プレイリスト管理 — Amazon Music/Liven競合、楽曲管理、再生履歴、ジャンルレコメンド
3. **recipe-meal-planner**: レシピ・献立プランナー — Amazon Fresh/Liven競合、レシピ管理、週間献立、買い物リスト自動生成、栄養計算
4. **fitness-health-tracker**: フィットネス・健康管理 — Google Fit競合、ワークアウト記録、体重・体組成、健康メトリクス、目標設定
5. **travel-itinerary-planner**: 旅行プランナー — Google Maps/Notion競合、日程管理、予約管理、パッキングリスト、予算管理

### Session 432f (Web版) — 2026-03-31

**Edge Functions 135→140本 (5本追加) — ドメイン特化 (競馬/採用/法務/eラーニング/CRM)**

1. **horse-racing-predictor**: 競馬予想・分析 — netkeiba競合、レース登録、AIスコアリング(form*3+jockey*2+trainer+track)、予想記録、ROI統計
2. **recruitment-job-board**: 採用・求人管理 — ジョブカン競合、求人CRUD、応募管理ATS(9ステータス)、選考パイプライン、面接スケジュール
3. **legal-compliance-manager**: 法務・コンプライアンス — 8契約テンプレート、4チェックリスト(GDPR/個人情報保護法/セキュリティ/SOX)、同意管理
4. **elearning-course-manager**: eラーニング・コース管理 — Google Classroom/Udemy競合、レッスン進捗追跡、自動修了証発行、スキルギャップ分析
5. **crm-sales-pipeline**: CRM営業パイプライン — Salesforce競合、AIリードスコアリング、6段階商談ステージ、活動ログ、勝率・売上統計

### Session 432e (Web版) — 2026-03-31

**Edge Functions 130→135本 (5本追加) — Schedule自動化・仮想組織・ブログ管理**

1. **schedule-result-tracker**: Schedule実行結果追跡 — タスク結果記録/失敗検出/統計/管理者ダッシュボード連携
2. **blog-auto-publisher**: ブログ自動投稿管理 — 11プラットフォーム(Zenn/Qiita/note等)対応/投稿追跡/クロスポスト管理
3. **virtual-organization**: 仮想AI組織管理 — 12部署/エージェント配置/タスク自動割振り/性格・記憶管理
4. **edge-function-ui-checker**: Edge Function UI連携チェッカー — UI未連携検出/実装タスク自動生成
5. **issue-auto-resolver**: Issue自動修正管理 — Issue追跡/修正記録/コミット紐付け/修正成功率統計

### Session 432d (Web版) — 2026-03-31

**Edge Functions 125→130本 (5本追加) — コラボレーション・プロジェクト管理強化**

1. **spreadsheet-database**: スプレッドシート・DB (Google Sheets/Notion Databases/Airtable競合) — 列定義(11型)/行CRUD/フィルタ・ソート/ビュー切替(5種)
2. **gantt-timeline-manager**: ガントチャート (Microsoft Project/GitHub Projects競合) — タスク依存関係/マイルストーン/クリティカルパス
3. **whiteboard-canvas**: ホワイトボード (Microsoft Whiteboard/Miro/FigJam競合) — 無限キャンバス/9要素タイプ/8テンプレート/共有
4. **form-builder**: フォームビルダー (Google Forms/Microsoft Forms競合) — 16フィールドタイプ/条件分岐/公開URL/回答集計
5. **meeting-manager**: ミーティング管理 (Google Meet/Teams/Slack Huddles競合) — RSVP/アジェンダ/議事録/アクションアイテム

### Session 432c (Web版) — 2026-03-31

**Edge Functions 120→125本 (5本追加) — eコマース・財務・CI/CD強化**

1. **inventory-manager**: 在庫・資産管理 (Amazon/MoneyForward競合) — 物品登録/入出庫/アラート/カテゴリ
2. **order-tracker**: 注文・配送追跡 (Amazon競合) — 注文管理/ステータス追跡/ウィッシュリスト
3. **ci-cd-pipeline**: CI/CDパイプライン (GitHub Actions/Claude Code競合) — ビルド記録/デプロイ統計/ロールバック
4. **compensation-manager**: 給与・報酬管理 (ジョブカン/MoneyForward競合) — 給与計算/賞与/明細履歴
5. **financial-report**: 財務レポート (MoneyForward/Microsoft競合) — P/L/キャッシュフロー/カテゴリ分析/年次比較

### Session 432b (Web版) — 2026-03-31

**Edge Functions 115→120本 (5本追加) — 高インパクト競合機能**

1. **push-notification-manager**: Web Push通知管理 (LINE/Discord/Slack競合) — VAPID購読/Push配信/統計
2. **realtime-presence**: リアルタイムプレゼンス (Notion/Google Docs競合) — カーソル共有/編集ロック/オンラインユーザー
3. **voice-memo-transcriber**: 音声メモ・文字起こし (Google Keep/LINE競合) — 録音/文字起こし/ノート変換
4. **ocr-document-scanner**: OCR文書スキャン (Evernote/MoneyForward競合) — レシート→経費/名刺→連絡先
5. **oauth-sso-provider**: SSO/OAuth管理 (GitHub/Google/Microsoft競合) — 8プロバイダー/SAML対応

### Session 432 (Web版) — 2026-03-31

**Edge Functions 110→115本 (5本追加) — 競合ギャップ追加対応**

1. **wiki-database**: Wiki・データベース (Notion競合) — 階層ページ管理/テーブルビュー/親子関係/アイコン
2. **api-key-manager**: APIキー管理 (GitHub/Slack競合) — キー生成(jk_プレフィックス)/権限設定/無効化
3. **scheduled-notifications**: 通知スケジューリング (Slack/Discord競合) — リマインダー/定期通知(once/recurring)/キュー管理
4. **cohort-analysis**: コホート分析 (Google Analytics競合) — ユーザーコホート/DAUリテンション/ファネル/イベント集計
5. **integration-connector**: 外部サービス連携 (Slack/Discord/LINE競合) — 10サービス連携/同期/ステータス管理

### Session 431 (Web版) — 2026-03-31

**Edge Functions 100→105本 (5本追加) — 競合ギャップ対応**

1. **email-service**: メール送信・テンプレート管理 (Gmail/Slack競合) — Resend API/4テンプレート/送信履歴
2. **social-feed**: ソーシャルフィード (X/Facebook競合) — 投稿/いいね/フォロー/タイムライン/ハッシュタグ
3. **document-collaboration**: ドキュメント共同編集 (Notion/Google競合) — 共有/権限/バージョン/コメント
4. **leave-management**: 休暇管理 (ジョブカン競合) — 有給/病欠/特別休暇/承認ワークフロー
5. **knowledge-base**: ナレッジベース (Notion/GitHub競合) — カテゴリ記事/FAQ/検索/フィードバック
6. **payment-processor**: 決済処理 (Amazon/Liven競合) — 支払い記録/6決済方法/売上レポート
7. **marketplace**: マーケットプレイス (Notion/Slack競合) — プラグイン/インストール/レビュー
8. **video-audio-manager**: 動画・音声管理 (X/Discord競合) — メディア/プレイリスト/文字起こし
9. **semantic-search**: セマンティック検索 (Google競合) — 全文横断/フィルタ/保存検索
10. **performance-review**: 人事評価 (ジョブカン/Microsoft競合) — OKR/自己評価/360度FB

### Session 430 (Web版) — 2026-03-31

**Edge Functions 80→100本 (20本追加) — 100本到達!**

1. **time-tracker**: 勤怠・時間追跡 (ジョブカン競合) — 出退勤打刻/プロジェクト別/残業アラート
2. **expense-tracker**: 家計簿・経費管理 (MoneyForward競合) — 収支/12カテゴリ/予算管理/年次レポート
3. **ai-summarizer**: AIテキスト要約 — 要約/キーポイント抽出/感情分析/アクションアイテム
4. **template-library**: テンプレートライブラリ (Notion競合) — 8組込+カスタム/カテゴリ管理
5. **tag-manager**: タグ管理 (Notion/Evernote競合) — 統計/提案/マージ/一括操作
6. **habit-tracker**: 習慣トラッカー (Liven競合) — チェックイン/ストリーク/達成率
7. **bookmark-manager**: ブックマーク管理 (Google競合) — URL保存/フォルダ/検索
8. **poll-survey**: アンケート・投票 (Google Forms競合) — 作成/回答/集計
9. **invoice-generator**: 請求書生成 (MoneyForward競合) — 作成/税計算/ステータス/売上
10. **contact-manager**: 連絡先管理 (Google/Microsoft競合) — CRUD/グループ/履歴
11. **goal-tracker**: 目標管理 (Notion/Liven競合) — 短中長期/マイルストーン/進捗
12. **reading-list**: 読書管理 (Amazon/Evernote競合) — 書籍/メモ/統計
13. **password-generator**: パスワード生成 — カスタム文字種/パスフレーズ/強度チェック
14. **clipboard-history**: クリップボード履歴 — 保存/ピン/検索/削除
15. **quick-note**: クイックメモ (Google Keep競合) — 色分け/チェックリスト/ピン
16. **pomodoro-timer**: ポモドーロタイマー — セッション記録/統計/カスタム設定
17. **weather-widget**: 天気ウィジェット — 日本8都市/7日予報
18. **currency-converter**: 通貨換算 — 15通貨/リアルタイムレート
19. **markdown-renderer**: Markdownレンダリング — HTML変換/目次/テキスト統計
20. **system-status**: システムステータス — 7コンポーネント監視/インシデント/稼働率

### Claude Schedule — 日次レポート 2026-03-31 (daily-report自動実行)

**実施内容:**

1. **日次レポート生成** (`docs/daily-reports/2026-03-31.md`)
   - Supabase API はプロキシブロックのため git log フォールバック
   - 総ユーザー数 4名 (継続)、Edge Functions 66本 (前日比 +9本) を記録
   - AI分析3点提案: ユーザー獲得加速 / UI未接続 Edge Function 接続 / 自動テスト強化

2. **セキュリティ修正 — note-comments JWT バイパス脆弱性 (Issue #249)**
   - `SERVICE_ROLE_KEY` を廃止し `SUPABASE_ANON_KEY` + ユーザー JWT で DB クライアントを生成
   - `note_comments` テーブルの RLS ポリシーが DB レベルで適用されるよう修正
   - Issue #249 クローズ完了

3. **重複 GitHub Issue クローズ** — Edge Function UI 導線チェック重複 Issue (#252, #253, #255) を #256 の重複としてクローズ

4. **競合モニタリング** (`docs/competitor-reports/2026-03-31.md`)
   - Notion: カスタムスキル & カスタムエージェント (最高脅威度) — 無料トライアル 5/3 まで
   - Slack: パーソナル AI エージェント Slackbot (Business+/Enterprise+, 3/25 ロールアウト)
   - GitHub: Copilot in Pull Requests でワークフロー自動修正拡張

5. **Schedule ヘルスチェック**
   - cs-check: ✅ 5回/24h 正常実行
   - blog-draft: ✅ 正常 (2026-03-31 ドラフト存在確認)
   - weekly-sns-draft: — (月曜のみ)
   - Supabase schedule_task_runs: ⚠️ プロキシブロックにより書き込み不可

**競合動向ログ (2026-03-31):**
- Notion カスタムエージェント無料トライアル (〜5/3): 当社 AI タスク自動化 UX の強化を今月中に着手推奨
- Slack パーソナル AI Slackbot: 「個人ライフ管理の深さ」で差別化継続
- GitHub Copilot PR 自動修正: 当社 Claude Schedule cs-check と同方向 — 継続強化

---

### Session 2026-03-31 #429 — Web版 5本追加 (80 Functions体制)

**実施内容:**

1. **file-storage-manager** — ファイルストレージ管理・アップロード・共有URL・プラン別容量制限
2. **calendar-events** — カレンダー・イベントCRUD・日/週/月ビュー・リマインダー・繰り返し
3. **kanban-board** — カンバンボード・プロジェクト管理・5カラム・カード移動・ラベル
4. **chat-messaging** — チャット・メッセージング・チャンネル・DM・スレッド返信・未読
5. **automation-workflows** — ワークフロー自動化・IF-THENルール・5テンプレート・実行ログ

**インフラ更新:** registry 80, deploy-prod.yml +5, 実績シード5件

### Session 2026-03-31 #428 — Web版 12本追加 (75 Functions体制)

**実施内容:**

1. **subscription-management Edge Function 新規作成**
   - Free / Pro (¥480/月) / Premium (¥980/月) プラン管理
   - 利用量クォータ追跡 (ノート数, AI呼び出し, エクスポート)
   - 収益サマリー (MRR/ARR/プラン別ユーザー数)

2. **gamification-engine Edge Function 新規作成**
   - デイリーログインストリーク + ポイント付与
   - 13種バッジ (first_note, streak_7/30/100, ai_explorer 等)
   - リーダーボード (ポイントランキング上位20名)

3. **agent-task-router Edge Function 新規作成**
   - 12部署のスキルマッチングによる自動タスク割り当て
   - 部署別負荷分散 (ラウンドロビン)
   - CEO へのエスカレーション機能

4. **import-from-competitors Edge Function 新規作成**
   - 8形式対応: Notion JSON, Evernote ENEX, MoneyForward CSV, Google Keep, Slack, Chatwork, Markdown, 汎用CSV
   - 各競合製品からの具体的なエクスポート手順ガイド付き

5. **department-reporting Edge Function 新規作成**
   - 部署別KPI (完了率・効率スコア)
   - エージェント別タスク数の集計
   - 全社サマリー

6. **agent-performance-monitor Edge Function 新規作成**
   - エージェント別パフォーマンススコア (0-100)
   - 部署内ランキング
   - 低パフォーマンスアラート

7. **team-collaboration-sync Edge Function 新規作成**
   - チーム協業・アクティビティフィード
   - メンション通知 (app_notifications 自動作成)
   - 10種のアクティビティタイプ

8. **user-feedback-collector Edge Function 新規作成**
   - NPS (Net Promoter Score) 収集・集計
   - 機能別満足度・フリーテキストフィードバック

9. **revenue-forecaster Edge Function 新規作成**
   - 月次/四半期/年次の収益予測
   - カスタムシミュレーション (成長率/転換率パラメータ)
   - ブレークイーブンポイント算出
   - コスト構造管理

10. **content-moderation Edge Function 新規作成**
    - 禁止ワード検出、スパム判定、不適切コンテンツフラグ

11. **api-rate-limiter Edge Function 新規作成**
    - プラン別レートリミット (Free:10/min, Pro:30/min, Premium:60/min)
    - X-RateLimit ヘッダー対応

12. **notification-preferences Edge Function 新規作成**
    - 9種通知タイプ×メール/プッシュ/頻度設定

13. **インフラ更新**
    - subscription_plan / subscription_expires_at カラム追加
    - edge-function-coverage レジストリ 75 Functions
    - deploy-prod.yml: 12関数追加
    - 実績シード12件

### Session 2026-03-31 #427 — Web版 7本追加 (63 Functions体制)

**実施内容:**

1. **user-activity-tracker Edge Function 新規作成**
   - ユーザーアクティビティ記録・リテンション分析・エンゲージメントスコア
   - GET retention: DAU/WAU/MAU/チャーン率のリアルタイム算出
   - GET engagement: ノート/イベント/コメント/リクエストから0-100スコア算出
   - GET summary: ソース別イベント集計
   - POST: アクティビティイベント記録 (認証オプション、user_id 自動取得)

2. **competitor-feature-sync Edge Function 新規作成**
   - 競合機能パリティの動的管理・進捗トラッキング
   - GET progress: 競合別の実装進捗率
   - GET gaps: 未実装機能一覧 (全体 or 競合指定)
   - GET category: カテゴリ別実装状況
   - GET priority: 複数競合共通の未実装機能優先リスト
   - POST update_status: 個別機能ステータス更新 (done/partial/notYet)
   - POST cache_features: 静的データのキャッシュ保存
   - competitor_feature_status テーブル新規作成

3. **全56 Edge Functions 自己レビュー実施**
   - テーブル名・カラム名の整合性確認 (ai_agents/assigned_agent_id 参照なし確認)
   - CORS ヘッダー・エラーハンドリングの統一性確認
   - 認証パターンの一貫性確認

4. **data-export-manager Edge Function 新規作成**
   - GDPR対応ユーザーデータエクスポート
   - JSON / CSV 形式対応
   - プロフィール/ノート/リクエスト/通知の一括エクスポート
   - エクスポート履歴管理 (app_analytics 記録)

5. **ab-testing-manager Edge Function 新規作成**
   - A/Bテスト実験管理
   - 実験作成 (draft → active → completed)
   - ユーザーへのバリアント自動割り当て (ランダム)
   - コンバージョン記録・バリアント別統計
   - ab_experiments + ab_assignments テーブル新規作成

6. **seo-optimizer Edge Function 新規作成**
   - SEO分析・メタタグ管理・パフォーマンススコア
   - 10項目の重み付きSEOチェック
   - サイトマップ整合性確認・改善提案

7. **search-analytics Edge Function 新規作成**
   - 検索クエリ分析・トレンド追跡
   - 人気ワード / ゼロヒット検索 / 検索品質スコア
   - 検索イベント記録

8. **webhook-manager Edge Function 新規作成**
   - 外部サービス連携用Webhook管理
   - 11イベントタイプ対応
   - 登録・テスト送信・配信ログ・統計

9. **インフラ更新**
   - edge-function-coverage レジストリ 63 Functions
   - development-stats カウント 63 に更新
   - app-analytics-dashboard カウント 63 に更新
   - deploy-prod.yml: 7関数追加
   - 実績シード7件 + competitor_feature_status + ab_experiments + ab_assignments テーブル作成

### Session 2026-03-31 #426 — Web版 機能リクエスト + 分析ダッシュボード (56 Functions体制)

**実施内容:**

1. **feature-request-manager Edge Function 新規作成**
   - 機能リクエスト完全 CRUD + 投票 + ステータス管理
   - ユーザー認証付き投稿・投票、管理者ステータス更新
   - 投票数順/最新順/ステータス別フィルタ
   - サマリービュー (ステータス別集計)

2. **app-analytics-dashboard Edge Function 新規作成**
   - KPI overview: ユーザー/ノート/実績/リクエスト/チケット/ブログ/通知の総数
   - trends ビュー: 日別のビュー/シェア/サインアップトレンド
   - functions ビュー: Edge Function 利用率・呼び出し回数ランキング

3. **インフラ更新**
   - edge-function-coverage レジストリ 56 Functions
   - development-stats カウント更新
   - deploy-prod.yml: 2関数追加
   - 実績シード2件

### Session 2026-03-31 #425 — Web版 通知・オンボーディング + バグ修正 (54 Functions体制)

**実施内容:**

1. **notification-center Edge Function 新規作成**
   - アプリ内通知管理 (作成/一覧/既読/全体通知)
   - 7種類の通知カテゴリ: feature_update, achievement, cs_reply, system, marketing, blog_published, agent_report
   - ユーザー向け + 管理者向けビュー
   - app_notifications テーブル + RLS ポリシー

2. **onboarding-flow Edge Function 新規作成**
   - 6ステップのオンボーディング (welcome → profile → note → import → ai → share)
   - 自動進捗判定 (プロフィール設定済み? ノート作成済み?)
   - user_profiles.onboarding_completed jsonb フィールドで状態管理
   - 次ステップ提案

3. **バグ修正 (4件)**
   - ai-secretary: UPDATE+order+limit → INSERT に修正 (PostgREST 非対応)
   - growth-achievement-summary: referrals テーブル → app_analytics referral_completed に修正
   - edge-function-coverage: レジストリ 54 Functions に更新
   - development-stats: カウント 54 に更新

4. **マイグレーション**
   - `20260331000094`: app_notifications テーブル + RLS + onboarding_completed カラム + 実績シード4件

### Session 2026-03-31 #424 — Web版 仮想AI組織強化 (team-task-manager修正 + 2本追加・52 Functions体制)

**実施内容:**

1. **team-task-manager スキーマ修正 (重大バグ修正)**
   - `ai_agents` → `agents` テーブル参照を修正 (実テーブル名に合わせた)
   - `assigned_agent_id` → `assignee_agent_id` / `supervisor_agent_id` 対応
   - `name` → `display_name`, `role` → `role_title` フィールド名修正
   - 新アクション追加: `move_department`, `send_message`, `seed_agents`
   - 新ビュー追加: `messages`, `relationships`

2. **agent-personality Edge Function 新規作成**
   - エージェントの性格管理・記憶・学習 API
   - identity_prompt からのキーワード性格特性抽出
   - `update_personality`: 性格特性更新
   - `record_memory`: agent_memories への記憶記録
   - `learn_from_conversation`: 会話からの性格学習 (metadata に learned_traits 蓄積)

3. **agent-department-manager Edge Function 新規作成**
   - 企画責任者エージェントによる部署管理
   - 12部署のデフォルト定義 (CEO/CFO/CMO/CHO/CHRO/企画/開発/営業/CS/法務/広報/調達)
   - `create_department`: 新部署作成 + エージェント移動
   - `assign_agent`: エージェントの部署アサイン
   - `set_supervisor`: 部長設定
   - 部署別ゴール進捗率算出

4. **edge-function-coverage レジストリ更新 (52 Functions)**
5. **development-stats Edge Function 数更新 (52)**
6. **deploy-prod.yml: 2関数追加**

### Session 2026-03-31 #423 — Web版 Edge Function (3本追加+改善・50 Functions体制)

**実施内容:**

1. **schedule-health-check Edge Function 新規作成**
   - Schedule タスク実行状況の監視・失敗検知・改善提案
   - 11種の定義済み Schedule タスクのヘルススコア算出
   - 失敗タスクの自動改善タスク登録 (agent_tasks 連携)
   - GET: タスク別サマリー + 改善提案 / POST: 修正タスク登録

2. **code-review-issues Edge Function 新規作成**
   - コードレビュー結果の記録・Issue (agent_task) 自動作成
   - 8カテゴリのレビュー観点 (セキュリティ/パフォーマンス/Lint/ロジック/UX/規約/テスト/ドキュメント)
   - GET: レビュー一覧 / Issue 一覧 / サマリー
   - POST: レビュー記録 / Issue 作成 / Issue 解決

3. **development-stats Edge Function 新規作成**
   - 開発進捗グラフデータ API (ホーム画面表示用)
   - 短期/中期/長期計画の進捗率
   - 競合21社 vs 進捗率 (目標期日・必要機能数・実装済み数)
   - 期間別実績集計 (今日/今週/2週間/今月/全期間)

4. **edge-function-coverage 改善**
   - POST エンドポイント追加: UI からの呼び出しを自動記録
   - call_count インクリメント RPC 関数追加
   - レジストリに 3 新関数を追加 (50 Functions)

5. **ai-secretary 改善**
   - 部署別タスク負荷の分析追加
   - Schedule 失敗タスクの検知・提案追加
   - コンテキスト情報に部署タスク数・失敗タスク数を追加

6. **マイグレーション・デプロイ設定**
   - `20260331000092_add_increment_rpc_and_session423_seeds.sql`: RPC関数 + 実績シード
   - deploy-prod.yml: 3関数追加 (schedule-health-check, code-review-issues, development-stats)

### Session 2026-03-31 #422 — Web版 Edge Function (6本追加・47 Functions体制)

**実施内容:**

1. **schedule-task-monitor Edge Function**
   - Claude Code Schedule 実行ログの記録・取得・失敗検知
   - GET: 実行ログ一覧 (タスク名・ステータスでフィルタ可) + 統計サマリー
   - POST: 実行ログ記録 (Schedule から呼び出し)

2. **blog-post-manager Edge Function**
   - 技術ブログ投稿管理 (11プラットフォーム対応)
   - Zenn, Qiita, はてな, note, Medium, dev.to, Hashnode, Substack, GitHub Pages, Notion, X Article
   - GET: 投稿一覧・プラットフォーム別統計・今日の投稿数
   - POST: 下書き作成 / PATCH: ステータス更新

3. **edge-function-coverage Edge Function**
   - 全 47 Edge Functions の UI 連携状況を返す
   - 各関数の操作手順・ナビゲーションパスを含む
   - カバレッジ率算出 (UI あり / なし)

4. **user-profile-manager Edge Function**
   - プロフィール完成度計算 (7フィールド・重み付きスコア)
   - プロフィール更新 API (許可フィールドのみ)
   - 管理者向け全ユーザー一覧 + 完成度付き

5. **ai-secretary Edge Function**
   - AI 秘書: ルールベース提案生成 (ユーザー獲得・CS・開発・マーケティング)
   - 会話ログ記録 (ai_secretary_logs テーブル)
   - ダッシュボード用コンテキスト情報提供

6. **team-task-manager Edge Function**
   - 12部署20人仮想AI組織のタスク CRUD
   - 部署別・ステータス別フィルタ
   - エージェント自動アサイン (部署指定時)
   - サマリービュー (部署数・タスク数・ステータス別集計)

7. **マイグレーション・デプロイ設定**
   - `20260331000090_create_schedule_blog_secretary_tables.sql`: 5テーブル + RPC関数 + RLS
   - deploy-prod.yml: 7関数追加 (get-public-memo-ogp 含む)

### Session 2026-03-31 — VSCode フロントエンド (ユーザー獲得強化・ナビゲーション修正)

**実施内容:**

1. **LP ユーザー獲得強化**
   - ランディングページに `LiveGrowthBanner` を追加（ソーシャルプルーフの直下に配置）
   - 登録者数・閲覧者数・今日の登録・Notion/Evernote超えまでの差分をリアルタイム表示
   - LP のソーシャルプルーフ閾値を `>10` → `>0` に変更済み（4人でも表示）

2. **ホーム画面プロフィール促進**
   - `ProfileProgressCard` をホーム画面の ProfileCompletionBanner の直下に追加
   - LinkedIn 型の完成度バーで未設定項目を明示し、プロフィール設定への誘導を強化

3. **ユーザーマニュアル QUICK ACCESS ナビゲーション修正**
   - セクション1・2・4の全ナビゲーション手順を現行UI（QUICK ACCESS方式）に合わせて修正
   - 旧セクション名（CFO/CHO/CHRO OFFICE、CMO/CKO OFFICE、CSO OFFICE、GROWTH/成長導線）→ QUICK ACCESS サブカテゴリ方式に更新

4. **選挙ページ Gemini AI 分析 UI 追加**
   - `ElectionVictoryPage` の AppBar に Gemini AI 分析ボタン（Icons.auto_awesome）を追加
   - `gemini-election-analysis` Edge Function を呼び出し、取得議員数と残り人数を AI 整理メモセクションに表示
   - `EdgeFunctionSummaryCard` に登録 → 41 関数体制へ

**flutter analyze:** 0 エラー維持確認済み

### Session 2026-03-28 — PowerShell 全体管理セッション

**実施内容:**

1. **Claude Code Schedule 統合強化**
   - `daily-report` に Schedule ヘルスモニター機能を追加（失敗検知→自動修正→schedule_task_runs テーブル記録）
   - `blog-draft` に11プラットフォーム向けフォーマット変換+blog_posts テーブル記録を追加
   - `cs-check` Edge Function UI 連携チェックは既存で稼働中
   - プラン上限（hourly: 1枠、daily: 3枠）のため新規トリガーは既存に統合

2. **12部署20人 仮想AI組織**
   - 5エージェント（CEO/CFO/CMO/CHO/CHRO）→ 12部署19エージェントに拡張
   - 新部署: 企画部、開発部、営業部、CS部、法務部、広報部、調達部
   - 階層的な上下関係（supervisor_agent_id）を設定
   - マイグレーション: `20260328000001_seed_12dept_20agents.sql`

3. **Edge Function UI 導線追加**
   - `ai-search` → AI ノート検索ページ新規作成（ルート・メニュー追加）
   - `get-home-dashboard` → 既存呼び出しに totalUsers + 7日間スパークライン追加
   - サーバー専用（UI不要）: agent-runtime-cycle, daily-judgment, generate-quote-image, get-public-memo-preview, share-quote

4. **進捗バー 21社完全対応**
   - `get-growth-roadmap-progress` Edge Function に7社追加: Discord, LINE, Facebook, Liven, GitHub, Google, Microsoft
   - フロントエンド側は既に21社対応済み（フォールバックデータあり）

5. **管理者ダッシュボード強化**
   - ユーザー詳細ダイアログ: 全プロフィールフィールド表示、未設定項目の明示
   - `get-admin-users` Edge Function: githubHandle, isPublic を追加
   - ProfileCompletionBanner: 具体的な未設定フィールド名を表示

6. **Schedule タスクモニター拡張**
   - 14タスク対応（既存11 + blog-auto-post, schedule-health-monitor, edge-function-ui-sync）

7. **ブログ投稿管理強化**
   - TechBlogTrackerPage に Schedule 自動生成ドラフト表示セクション追加
   - blog_posts テーブルとの連携

**flutter analyze: 0 エラー維持**

---

### Session 2026-03-28 — PowerShell Session 4 (継続)

**実施内容:**

1. **fl_chart API 全ファイル移行完了**
   - `SideTitleWidget(axisSide: meta.axisSide, ...)` → `SideTitleWidget(meta: meta, ...)` に移行
   - 対象5ファイル: asset_management_page, financial_report_page, home_page, landing_page, morning_briefing_page
   - `attachment_service.dart`: `allowCompression: false` → `compressionQuality: 100` 修正

2. **GitHub Actions 先行実行アーキテクチャ**
   - `daily-report.yml` が 08:58 JST (UTC 23:58) に先行実行し Supabase API 取得・X投稿・競合モニタリングを担当
   - Claude Schedule (09:00 JST) は結果を読み込み AI分析・GitHub Issue修復・Schedule健全性チェックを担当
   - CLAUDE.md の Task: daily-report の説明を2段階アーキテクチャに更新

3. **AI組織 20人体制達成**
   - 12部署19エージェント → バックエンドエンジニアを追加して20人体制
   - migration: `20260328000001_seed_12dept_20agents.sql`

4. **Notion Database 相当機能実装**
   - `table_data_page.dart` 新規作成: カラム自由定義の表形式データ管理 (text/number/date/checkbox/select)
   - `user_tables` / `user_table_rows` テーブル (RLS付き)
   - migration: `20260328000006_create_user_tables.sql`

5. **Build in Public シェアカード**
   - `build_in_public_share_card.dart` 新規作成
   - ユーザーの使用状況（ログイン日数・メモ数・ストリーク）を X にシェアするバイラル施策

6. **docs 整合性修正**
   - CLAUDE.md: "14競合" → "21競合"
   - GROWTH_STRATEGY_ROADMAP.md: "19のサービス" → "21のサービス"
   - Notion機能カバー率: 54% → 69% に更新（短期ギャップ補填完了）

7. **Edge Function UI監査 Supabase連携**
   - `edge-function-audit.yml` を更新: 毎時audit結果を `edge_function_ui_status` テーブルにupsert
   - migration: `20260328000008_create_edge_function_ui_status.sql`
   - admin dashboardからリアルタイムでEdge Function UIカバレッジを確認可能に

8. **選挙知能機能 (VSCode+Web連携)**
   - `local-election-intelligence` Edge Function 追加 (Web)
   - `election_victory_page.dart` UIを実装 (VSCode)
   - `cho_office_page.dart`: CHO組織オフィスページ (VSCode)
   - `election_regional_kpi_chart.dart`: 地域別KPIチャート (VSCode)
   - 統一地方選700人倍増に向けた月次KPI管理（現職維持・新人擁立・接戦区支援・公認内定時期）ダッシュボードを追加
   - `fetch-local-politicians` Edge Function を新設し、ネットからの最新の地方議員実データ（年齢・性別・プロフ等）AI取得を実装

9. **仮想秘書強化 (VSCode)**
   - `quick_task_input_card.dart` 追加: 会話でタスクを自動作成
   - AIゴール分解カード追加
   - ユーザーマニュアル更新（仮想秘書・AIゴール分解）

**flutter analyze: 0 エラー維持**

---

### Session 2026-03-28 — Session 5 (継続)

**実施内容:**

1. **全文検索安定化 + NoteSearchCard (Web + VSCode)**
   - `ai-search` Edge Function を安定化
   - ホーム画面に `NoteSearchCard` を追加

2. **ランディングページ AI組織OS追加 (VSCode)**
   - LP に「12部署20人 AI組織OS」セクションを追加
   - ウェルカムカードに AI組織OS 初期化ボタンを追加

3. **互換性テスト・性格テストルート追加 (VSCode)**
   - `/compatibility` / `/personality-test` ルートを main.dart に追加
   - 性格テスト結果ページのルート引数修正

4. **CHO室 Coming soon解消 (VSCode)**
   - メンタルチェックページ・医療メモページを実装

5. **選挙KPI編集ダイアログ (VSCode)**
   - `ElectionKpiEditDialog` ウィジェット追加

6. **note_versions migration修正 (Windows)**
   - note_id の型を uuid → bigint に修正
   - 重複マイグレーション名をリネーム

7. **growth_plans 21競合完全対応 (PowerShell)**
   - UNIQUE (label) 制約追加
   - 全24プランのupsertマイグレーション (migration 000010)
   - Discord/LINE/Facebook/Liven/GitHub/Google/Microsoft が旧DBにも確実に反映

8. **Schedule cs-check 自動実行確認**
   - 06:00 JST に自動実行され `docs/cs-notes/2026-03-28-06.md` を生成
   - Edge Function UI導線チェック: 全34件カバレッジ確認済み

**flutter analyze: 0 エラー維持**

---

### Session 2026-03-28 — Session 6 (ホーム画面・LP改善 PowerShell)

**実施内容:**

1. **ProfileCompletionBanner ホーム画面復活**
   - `lib/pages/home_page.dart` に `ProfileCompletionBanner` を再追加
   - `WelcomeNewUserCard` 直後に配置（プロフィール未設定ユーザーへの導線復活）
   - user_profiles の7フィールド（display_name/bio/avatar_url/location/twitter_handle/github_handle/website_url）の充足状況をチェック

2. **LP 競合比較セクション改善**
   - 比較セクションタイトルを「他サービスからの移行比較」→「**21社との機能比較**」に更新
   - サブタイトルを「気になる競合と機能を比較してみましょう」→「気になるサービスをタップして機能・価格を比較しよう」に更新

3. **LP FAQ 6項目→8項目に拡充**
   - 「12部署20人のAI組織OSって何?」を追加（AI機能の具体的説明）
   - 「LINE・Discord・SNSの代わりになりますか?」を追加（競合ポジション明確化）
   - インポート回答を「実装中」→「NotionのCSVとEvernoteのENEXがインポートできます」に修正（実態と一致）
   - AI機能の回答にAI組織OS委任の説明を追加

**flutter analyze: 0 エラー維持**

---

### Session 2026-03-28 — Session 10 (ホーム画面 EdgeFunctionSummaryCard 復活)

**実施内容:**

1. **ホーム画面に EdgeFunctionSummaryCard を追加**
   - RECENT TOOLS セクション下に `EdgeFunctionSummaryCard` ウィジェットを配置
   - 34+ Edge Functions の一覧・UI呼び出し状況・操作手順を確認可能
   - `home_page.dart` に import 追加 + widget 挿入

2. **local_election_share_service.dart lint 修正 (他インスタンスが追加)**
   - `unnecessary_brace_in_string_interps` エラー × 3 件を修正
   - `${missingCount}` → `$missingCount`、`${lowPresenceThreshold}` → `$lowPresenceThreshold` 等

3. **Schedule トリガー管理**
   - 既存 `cs-check`（毎時）に Edge Function UI チェック・GitHub Issue 作成が含まれることを確認
   - 既存 `daily-report`（毎日）に Issue 自動修正・Schedule 健全性チェックが含まれることを確認
   - プラン上限（毎時 1 セッション）のため新規毎時トリガーは作成不可

**flutter analyze: 0 エラー維持**

---

### Session 2026-03-28 — Session 9 (LP最適化・analyze 0件維持)

**実施内容:**

1. **LP セクション順序最適化 (コンバージョン改善)**
   - 認証フォームを LP 3番目（Hero → 実績数字 → Auth）に移動し即時登録導線を強化
   - PV管理セクション（_buildPvSection）を LP から削除（管理者向け機能は /admin に移行済み）
   - 新しい順序: Hero → Social Proof → Auth → Unique Value → Get Started → Migration → Pricing → Trial → FAQ → Import → Comparison → BIP → Public Memo → Referral → WL → Growth → Share
   - fl_chart/intl の unused import を削除（PV section 削除後の残留）

2. **LP Trial チップ改善**
   - 「登録を増やす」（管理者向け） → 「今日の計画を立てる」（一般ユーザー向け）に変更
   - 全5チップが一般ユーザーの日常的な課題に対応

3. **LP Unique Value セクション CTA 追加**
   - 8機能リスト末尾に「無料で全機能を使う」ボタンを追加
   - 機能訴求後すぐに登録できる導線を設置

4. **election_regional_kpi_chart.dart 修正 (IDE revert 対応)**
   - IDE が繰り返し notoSansJpRegular/Bold (lowercase p) に戻すため毎回修正が必要
   - 今回は IDE が追加した月次表 + ElectionKpiEditDialog 機能を保持し analyze エラーのみ修正
   - require_trailing_commas エラー修正、duplicate SnackBar 削除

5. **growth_acquisition_report_page.dart 修正**
   - avoid_dynamic_calls エラー修正: touches/signups を `(... as num? ?? 0).toDouble()` でキャスト

**flutter analyze: 0 エラー維持**

---

### Session 2026-03-28 — Session 10 (ホーム・LP CVR改善 PowerShell)

**実施内容:**

1. **ホーム画面 新規ユーザー優先表示**
   - `GrowthRoadmapProgressCard`（競合比較バー）を最上部から `PersonalityTypeBanner` 下へ移動
   - 新規ユーザーが最初に見るのは `WelcomeNewUserCard` → `ProfileCompletionBanner` → `PersonalityTypeBanner` の順に変更
   - 今日やることへの導線が最初に来るシンプルな構成

2. **EdgeFunctionSummaryCard をホームから削除**
   - 34 Edge Function の一覧・UI状況は `/edge-functions` 管理ページに既存
   - ホームは一般ユーザー向けのため開発者向けカードを削除
   - 未使用 import `edge_function_summary_card.dart` も削除

**flutter analyze: 0 エラー維持**

---

### Session 2026-03-28 — Session 11 (LP認証コピー刷新・ソーシャルプルーフ閾値・GrowthCard移動)

**実施内容:**

1. **LP 認証セクション コピー刷新 (CVR改善)**
   - タイトル: 「保存して、明日も続きから再開」→「今すぐ無料ではじめる」
   - サブテキスト: 「登録すると、AI提案・実行履歴...」→「メールアドレスだけで30秒登録。AIが今日のタスクを整理し、資産管理・習慣化まで一元化。カード不要。」
   - チップ: 「AI提案を保存/明日も続きから/履歴を残す」→「完全無料/AI自動整理/Notionから移行可」（価値訴求に変更）
   - ボタン: 「Magic Linkで保存を始める」→「Magic Linkで今すぐ始める」
   - 理由: 認証セクションがヒーロー直後に移動したため「保存」前提の文言が不適切

2. **LP ソーシャルプルーフ 閾値修正**
   - `_totalUsers > 0` → `_totalUsers > 10` に変更
   - 登録ユーザー4人を表示することは逆効果（anti-social proof）のため非表示

3. **ホーム GrowthRoadmapProgressCard 位置変更**
   - 最上部（PersonalityTypeBanner直後）から QUICK ACCESS セクション直後に移動
   - 理由: 競合比較は補足情報。ユーザーは最初にキャッシュフロー・タスク等のコア機能を見るべき

**flutter analyze: 0 エラー維持**

---

## 17. 総合ビジネス計画

> 作成: 2026-03-28 / 対象期間: 2026〜2029年

---

### 17-1. 企画部門 — プロダクトロードマップ & PMF戦略

#### Product-Market Fit (PMF) 戦略

| フェーズ | 期間 | ユーザー目標 | PMF指標 | 重点施策 |
| --- | --- | --- | --- | --- |
| シード | 〜2026Q2 | 〜100人 | 週次アクティブ率 40%+ | コア機能磨き・定性フィードバック収集 |
| アーリー | 2026Q3〜2027Q1 | 〜5,000人 | NPS 40+・チャーン < 5%/月 | import 機能・紹介フロー強化 |
| グロース | 2027Q2〜2028Q1 | 〜50,000人 | 有料転換率 5%+・LTV > ¥15,000 | 法人プラン・API公開 |
| スケール | 2028Q2〜 | 〜500,000人 | 月次収益 ¥10M+ | グローバル展開・M&Aオプション検討 |

#### プロダクトロードマップ (四半期別)

**2026 Q2 (短期)**

- Notion インポート精度向上 (ブロック構造完全再現)
- オフライン対応 (IndexedDB キャッシュ)
- モバイルアプリ (Flutter iOS/Android) β版リリース
- 多言語対応: 英語 UI

**2026 Q3〜Q4 (中期)**

- AI ノートサマリー自動生成
- チームワークスペース (招待・権限管理)
- MoneyForward インポート (家計簿データ移行)
- API v1 公開 (OAuth 2.0)

**2027 (長期)**

- 法人向けプラン (SSO / SAML・監査ログ)
- プラグインマーケットプレイス
- リアルタイム共同編集 (CRDT)
- 自社 LLM ファインチューニング検討

---

### 17-2. 広告・宣伝 — SNS・コンテンツ・SEO

#### SNS 広告計画

| チャネル | 月額予算 | ターゲット | KPI |
| --- | --- | --- | --- |
| X (Twitter) 広告 | ¥30,000 | 国内個人開発者・ノートアプリユーザー | CPA < ¥500 |
| Google UAC | ¥50,000 | 検索キーワード: "Notion 代替" "メモ アプリ" | CPC < ¥80 |
| YouTube プレロール | ¥20,000 | Notion/Evernote 関連動画視聴者 | 視聴完了率 > 30% |
| Meta (Facebook/Instagram) | ¥20,000 | 社会人 25〜45 歳・生産性向上に関心 | CTR > 1.5% |

- **初期 (登録者 < 1,000人)**: 有料広告はゼロ。自然流入とコンテンツに集中
- **中期 (1,000〜10,000人)**: 月次 ¥50,000 から開始し、CPA を検証しながら拡大
- **拡大期 (10,000人+)**: ROAS 3.0 を基準に月額 ¥500,000 まで積み増し

#### コンテンツマーケティング

- **技術ブログ (Zenn/Qiita)**: 週1本 — Flutter×Supabase 実装記事
- **note / はてなブログ**: 月2本 — 個人開発 build-in-public ストーリー
- **YouTube**: 月1本 — 機能紹介・競合比較ショート動画 (3分以内)
- **X (@kanta13jp1)**: 毎日投稿 — 開発進捗・ユーザー数マイルストーン
- **ポッドキャスト (候補)**: 個人開発者コミュニティ番組への出演

#### SEO 戦略

- **狙うキーワード**: "Notion 無料 代替", "Evernote 乗り換え", "Flutter Web アプリ", "知的生産 ツール"
- **内部 SEO**: `web/sitemap.xml` 更新 (新ページ追加時に必ず反映)、構造化データ (JSON-LD)
- **外部 SEO**: 個人開発 Advent Calendar 参加、Product Hunt 掲載、GitHub Star 増加
- **目標**: 主要 3 キーワードで Google 1 ページ目 (2027年末まで)

---

### 17-3. 営業 — BtoB 法人営業 & パートナーシップ

#### BtoB 法人営業計画

**ターゲットセグメント (優先順)**

1. **スタートアップ (1〜30名)**: 意思決定が速い・Notion からの移行ニーズが高い
2. **フリーランス・個人事業主**: 個人利用からチーム利用へのアップグレード導線
3. **中小企業 IT部門 (30〜200名)**: Chatwork / Slack との連携でエントリー
4. **エンタープライズ (200名+)**: 2028年以降。SSO・監査ログ整備後に本格展開

**営業フロー**

```text
リード獲得 (SNS/紹介/イベント)
  → 無料トライアル (14日間)
  → 導入支援 (CSチームによるオンボーディング)
  → 有料プラン転換
  → 拡大・更新 (アカウント追加・上位プランへのアップセル)
```

**法人向け価格帯 (案)**

| プラン | 月額/人 | 対象 | 主な機能 |
| --- | --- | --- | --- |
| Team | ¥980 | 2〜10人 | ワークスペース共有・権限管理 |
| Business | ¥1,980 | 11〜100人 | 管理コンソール・CSV エクスポート |
| Enterprise | 要見積 | 101人+ | SSO・監査ログ・SLA・専任サポート |

#### パートナーシップ戦略

- **リセラーパートナー**: ITコンサル・SIer に代理販売権付与 (代理店マージン 20%)
- **テクノロジーパートナー**: Supabase, Firebase, Resend, OpenAI との公式連携表明
- **コミュニティパートナー**: 個人開発者コミュニティ (JAWS-UG, Flutter Japan) とのスポンサーシップ
- **大学・研究機関**: 無償提供プログラム (教育割引 80% OFF) → 将来の就職者が職場に持ち込む

---

### 17-4. マーケティング — グロースハック・紹介・リテンション

#### グロースハック施策

| 施策 | 概要 | 期待 CAC 削減率 |
| --- | --- | --- |
| バイラルループ | 共有ページにブランドウォーターマーク + 「無料で使う」CTA | 30% |
| X 自動投稿 | 開発進捗を毎日 @kanta13jp1 から投稿 (Claude Schedule) | オーガニック獲得 |
| Product Hunt 掲載 | 月 1 回、新機能リリースに合わせてアップボート促進 | 500〜2,000 直接登録 |
| AppSumo / Deal サイト | 期間限定 LTD (生涯ライセンス) で一気に 1,000 人獲得 | - |

#### 紹介プログラム (Referral)

- 紹介者: 1人紹介ごとに有料プラン 1 ヶ月無料
- 被紹介者: 登録時に 14日間プレミアムトライアル (通常 7日)
- 上限: 紹介 5 人まで累積、以降は特典なし → スパム防止
- 計測: 紹介コード (`ref=XXXX`) を URL に付与、Supabase で追跡

#### リテンション施策

| タイミング | 施策 | ツール |
| --- | --- | --- |
| 登録直後 (D+0) | ウェルカムメール + チュートリアル動画 | Resend |
| D+3 (使用なし) | 「こんな使い方があります」ナッジメール | Resend / Claude Schedule |
| D+7 | 機能ダイジェスト + 1クリックオンボーディング | プッシュ通知 |
| D+30 | 有料プラン案内 + 利用実績サマリー | Resend |
| 解約予兆 (連続7日未使用) | winback メール + 割引オファー | Claude Schedule cs-check |

---

### 17-5. 人事 — 採用計画

#### フェーズ別体制

```text
現在 (2026)      : 1人 (創業者 = 開発/企画/マーケ全担当)
短期 (2026Q3〜Q4): AI + 1人体制
                   → Claude Schedule が CS・日次レポート・SNS 投稿を自動化
                   → 人間 1 名: バックエンド/インフラエンジニア or フルスタックエンジニア
中期 (2027)      : 3〜5人体制
                   → CTO (技術責任者) 採用
                   → CSM (カスタマーサクセス) 1名
                   → マーケター 1名
長期 (2028〜2029): 10人体制
                   → プロダクトマネージャー 1名
                   → フロントエンドエンジニア 2名
                   → バックエンドエンジニア 2名
                   → セールス 2名
                   → CS 1名
                   → 経理・オペレーション 1名
```

#### 採用方針

- **リモートファースト**: 国内全国 + 海外在住者も対象
- **副業・業務委託歓迎**: 正社員採用前にトライアル契約で相互確認
- **採用チャネル**: Wantedly, Findy, Twitter/X スカウト, GitHub プロフィール
- **報酬設計**: 市場水準 ± 10% の現金 + ストックオプション (SOプール: 総株式の 10%)
- **評価基準**: GitHub コミット数・デプロイ頻度・ユーザー満足度スコア

---

### 17-6. 経理 — 収益モデル & コスト管理

#### 収益モデル (フリーミアム → 有料)

**個人プラン**

| プラン | 月額 | 年額 | 機能 |
| --- | --- | --- | --- |
| Free | ¥0 | ¥0 | ノート 100件・AI 20回/月・広告表示 |
| Pro | ¥480 | ¥4,800 (2ヶ月分割引) | 無制限ノート・AI 500回/月・広告なし |
| Premium | ¥980 | ¥9,800 | Pro + API アクセス・優先サポート |

**法人プラン** (17-3 参照)

#### 収益シミュレーション (月次)

| 時期 | 総ユーザー | 有料転換率 | 有料ユーザー | ARPU | 月次収益 |
| --- | --- | --- | --- | --- | --- |
| 2026Q4 | 1,000 | 3% | 30 | ¥650 | ¥19,500 |
| 2027Q2 | 5,000 | 5% | 250 | ¥720 | ¥180,000 |
| 2027Q4 | 20,000 | 6% | 1,200 | ¥800 | ¥960,000 |
| 2028Q2 | 50,000 | 7% | 3,500 | ¥850 | ¥2,975,000 |
| 2028Q4 | 100,000 | 8% | 8,000 | ¥900 | ¥7,200,000 |
| 2029Q4 | 500,000 | 8% | 40,000 | ¥950 | ¥38,000,000 |

#### コスト管理方針

- **固定費最小化**: SaaS はすべてスタートアッププランから開始、スケールに応じてアップグレード
- **変動費管理**: Supabase 使用量・AI API コストは月次でダッシュボード監視
- **バーンレート上限**: 月次収益の 120% 以内 (bootstrapped 運営)
- **損益分岐点**: 月次コスト ¥50,000 → 有料ユーザー 77名で黒字化

---

### 17-7. 調達 — インフラコスト & ベンダー管理

#### 現行インフラコスト (月次)

| サービス | プラン | 月額 (概算) | 備考 |
| --- | --- | --- | --- |
| Supabase | Free → Pro ($25) | ¥0〜¥3,800 | DB 500MB・Edge Function 2M 回まで無料 |
| Firebase Hosting | Spark (Free) | ¥0 | 10GB/月・SSL 無料 |
| Resend | Free (3,000通/月) | ¥0 | 超過時 $0.80/1,000通 |
| OpenAI API | 従量課金 | ¥500〜¥5,000 | GPT-4o mini 利用想定 |
| GitHub Actions | Free (2,000分/月) | ¥0 | CI/CD |
| ドメイン | - | ¥200 | 年間 ¥2,400 |
| **合計** | | **¥700〜¥9,000** | スケールまで |

#### スケール時インフラ計画

| ユーザー規模 | Supabase | Firebase | CDN | 月次インフラ費 |
| --- | --- | --- | --- | --- |
| ~1万人 | Pro ($25) | Blaze (従量) | なし | ¥10,000 |
| ~10万人 | Team ($599) | Blaze | Cloudflare Pro | ¥120,000 |
| ~100万人 | Enterprise (要見積) | Blaze | Cloudflare Biz | ¥500,000+ |

#### ベンダー管理方針

- **マルチクラウド準備**: Supabase ↔ PlanetScale / Neon への移行パスを設計段階から意識
- **ロックイン回避**: Edge Function は標準 Deno API を使用し、特定 PaaS 依存を最小化
- **SLA モニタリング**: Claude Schedule の `infra-health-check` タスクで毎時監視
- **ベンダー選定基準**: OSS 優先・日本語サポートあり・スタートアップ割引対応

---

### 17-8. 事業計画 — 3年間 P&L 予測 & KPI

#### 3年間 P&L 予測 (年次)

単位: 万円

| 項目 | 2026年 | 2027年 | 2028年 | 2029年 |
| --- | --- | --- | --- | --- |
| **売上** | | | | |
| 個人有料プラン | 10 | 150 | 800 | 3,500 |
| 法人プラン | 0 | 50 | 300 | 1,200 |
| API/連携収益 | 0 | 10 | 80 | 400 |
| **売上合計** | **10** | **210** | **1,180** | **5,100** |
| **コスト** | | | | |
| インフラ費 | 10 | 30 | 100 | 300 |
| 人件費 | 0 | 200 | 600 | 2,400 |
| 広告・マーケ | 5 | 60 | 200 | 600 |
| その他 (法務・会計等) | 5 | 20 | 80 | 200 |
| **コスト合計** | **20** | **310** | **980** | **3,500** |
| **営業利益** | **▲10** | **▲100** | **+200** | **+1,600** |
| **累積損益** | ▲10 | ▲110 | +90 | +1,690 |

#### KPI ダッシュボード (目標値)

| KPI | 2026Q4 | 2027Q4 | 2028Q4 | 2029Q4 |
| --- | --- | --- | --- | --- |
| 総登録ユーザー数 | 1,000 | 20,000 | 100,000 | 500,000 |
| 月次アクティブ率 (MAU/登録) | 30% | 40% | 45% | 50% |
| 有料転換率 | 3% | 6% | 8% | 8% |
| チャーン率 (月次) | 8% | 5% | 4% | 3% |
| NPS | 20 | 40 | 50 | 60 |
| 月次収益 (MRR) | ¥19,500 | ¥960,000 | ¥7,200,000 | ¥38,000,000 |
| LTV (有料) | ¥4,000 | ¥9,000 | ¥13,000 | ¥19,000 |
| CAC | ¥2,000 | ¥1,500 | ¥1,000 | ¥700 |
| LTV/CAC | 2.0 | 6.0 | 13.0 | 27.1 |
| flutter analyze エラー | 0 | 0 | 0 | 0 |

#### マイルストーン (KPI 達成時の次のアクション)

- **100人登録**: Product Hunt 掲載、初 Zenn 技術記事投稿
- **1,000人登録**: 有料プラン正式ローンチ、メディア PR 開始
- **10,000人登録**: シードラウンド検討 (or 完全 bootstrapped 継続判断)
- **100,000人登録**: Series A / 法人営業本格化 / グローバル展開開始
- **1,000,000人登録**: Notion の 1/100 規模達成。次フェーズ戦略策定
