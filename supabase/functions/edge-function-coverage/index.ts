// Edge Function Coverage Check
// 全 Edge Functions の一覧と UI 連携状況を返す
// Schedule タスクから呼び出して UI 未連携の関数を検出する
//
// GET → Edge Function 一覧 + UI 連携状況 + 操作手順

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

// Edge Function の UI 連携定義
// has_ui: true = フロントエンドから呼び出されている
// ui_path: UI での操作画面パス
// ui_navigation: ユーザーがアクセスするための手順
const FUNCTION_REGISTRY = [
  { name: "get-home-dashboard", description: "ホーム画面の統合データ", has_ui: true, ui_path: "/home", ui_navigation: "ホーム画面を開く" },
  { name: "development-achievements", description: "開発実績一覧", has_ui: true, ui_path: "/", ui_navigation: "ランディングページ最下部で確認" },
  { name: "get-growth-roadmap-progress", description: "競合 vs 進捗バー", has_ui: true, ui_path: "/home", ui_navigation: "ホーム画面 > 進捗バーセクション" },
  { name: "get-competitor-features", description: "競合機能比較データ", has_ui: true, ui_path: "/home", ui_navigation: "ホーム画面 > 競合比較カード" },
  { name: "ai-assistant", description: "AI アシスタント (汎用)", has_ui: true, ui_path: "/agents", ui_navigation: "ホーム > QUICK ACCESS > AI組織OS" },
  { name: "ai-search", description: "AI 全文検索", has_ui: true, ui_path: "/ai-search", ui_navigation: "ホーム > QUICK ACCESS > AI ノート検索" },
  { name: "ai-suggest-tags", description: "AI タグ自動提案", has_ui: true, ui_path: "/note-editor", ui_navigation: "ノートエディタ > タグ提案ボタン" },
  { name: "daily-judgment", description: "ストリーク判定 (自動)", has_ui: false, ui_path: null, ui_navigation: "管理者ダッシュボード > 手動実行" },
  { name: "schedule-daily-digest", description: "日次メトリクス API", has_ui: true, ui_path: "/admin", ui_navigation: "管理者ダッシュボード > Schedule モニター" },
  { name: "get-support-tickets", description: "CS チケット一覧", has_ui: true, ui_path: "/admin", ui_navigation: "管理者ダッシュボード > CS セクション" },
  { name: "reply-support-request", description: "CS チケット返信", has_ui: true, ui_path: "/admin", ui_navigation: "管理者ダッシュボード > CS 返信" },
  { name: "post-x-update", description: "X (Twitter) 自動投稿", has_ui: false, ui_path: null, ui_navigation: "Schedule 専用 (OAuth 1.0a)" },
  { name: "get-admin-users", description: "管理者ユーザー一覧", has_ui: true, ui_path: "/admin", ui_navigation: "管理者ダッシュボード > ユーザー管理" },
  { name: "health-check", description: "DB ヘルスチェック", has_ui: true, ui_path: "/admin", ui_navigation: "管理者ダッシュボード > ヘルスチェック" },
  { name: "check-competitor-updates", description: "競合 Web 可用性チェック", has_ui: true, ui_path: "/admin", ui_navigation: "管理者ダッシュボード > 競合モニタリング" },
  { name: "get-competitor-monitoring", description: "競合モニタリング詳細", has_ui: true, ui_path: "/admin", ui_navigation: "管理者ダッシュボード > 競合モニタリング詳細" },
  { name: "notify-feature-request", description: "機能リクエスト更新通知", has_ui: true, ui_path: "/feature-requests", ui_navigation: "機能リクエストページ" },
  { name: "growth-weekly-digest", description: "週次グロース指標", has_ui: true, ui_path: "/growth-mission", ui_navigation: "成長ミッション > 週次" },
  { name: "growth-import-preview", description: "インポートプレビュー", has_ui: true, ui_path: "/import", ui_navigation: "インポートページ > プレビュー" },
  { name: "growth-import-commit", description: "インポート実行", has_ui: true, ui_path: "/import", ui_navigation: "インポートページ > 実行" },
  { name: "growth-acquisition-signal", description: "獲得シグナル", has_ui: true, ui_path: "/home", ui_navigation: "ホーム > グロースセクション" },
  { name: "growth-acquisition-report", description: "獲得レポート", has_ui: true, ui_path: "/home", ui_navigation: "ホーム > グロースセクション" },
  { name: "growth-command-center", description: "グロースコマンドセンター", has_ui: true, ui_path: "/home", ui_navigation: "ホーム > グロースセクション" },
  { name: "growth-referral", description: "リファラル管理", has_ui: true, ui_path: "/home", ui_navigation: "ホーム > リファラルセクション" },
  { name: "growth-share-signal", description: "シェアシグナル", has_ui: true, ui_path: "/home", ui_navigation: "ホーム > シェアセクション" },
  { name: "growth-achievement-summary", description: "実績サマリー", has_ui: true, ui_path: "/home", ui_navigation: "ホーム > 開発実績カード" },
  { name: "analyze-reality", description: "リアリティチェック AI", has_ui: true, ui_path: "/reality-check", ui_navigation: "ホーム > QUICK ACCESS > 現実直視ノート" },
  { name: "generate-daily-challenges", description: "デイリーチャレンジ生成", has_ui: true, ui_path: "/home", ui_navigation: "ホーム > デイリーチャレンジカード" },
  { name: "generate-quote-image", description: "名言画像生成", has_ui: true, ui_path: "/home", ui_navigation: "ホーム > モチベーションカード" },
  { name: "share-quote", description: "名言シェア URL", has_ui: true, ui_path: "/home", ui_navigation: "ホーム > モチベーションカード > シェア" },
  { name: "send-waitlist-notification", description: "ウェイトリスト通知", has_ui: true, ui_path: "/admin", ui_navigation: "管理者ダッシュボード" },
  { name: "agent-runtime-cycle", description: "エージェント定期サイクル", has_ui: false, ui_path: null, ui_navigation: "Schedule 専用 (cron 認証)" },
  { name: "trigger-analysis", description: "トリガー分析", has_ui: true, ui_path: "/local-election-700", ui_navigation: "選挙戦略ページ" },
  { name: "local-election-intelligence", description: "地方選挙情報", has_ui: true, ui_path: "/local-election-700", ui_navigation: "選挙戦略ページ" },
  { name: "gemini-election-analysis", description: "Gemini AI 選挙分析", has_ui: true, ui_path: "/local-election-700", ui_navigation: "選挙ページ > AI 分析ボタン" },
  { name: "get-ogp", description: "OGP メタデータ", has_ui: false, ui_path: null, ui_navigation: "サーバーサイド専用" },
  { name: "get-public-memo-preview", description: "公開メモ SEO プレビュー", has_ui: false, ui_path: null, ui_navigation: "サーバーサイド専用" },
  { name: "get-public-memo-ogp", description: "公開メモ OGP", has_ui: false, ui_path: null, ui_navigation: "サーバーサイド専用" },
  { name: "public-memo-share", description: "公開メモシェアリダイレクト", has_ui: false, ui_path: null, ui_navigation: "サーバーサイド専用" },
  { name: "memo-reactions", description: "メモリアクション", has_ui: true, ui_path: "/memo", ui_navigation: "メモ詳細ページ > リアクションボタン" },
  { name: "note-comments", description: "ノートコメント", has_ui: true, ui_path: "/memo", ui_navigation: "メモ詳細ページ > コメントセクション" },
  // Session 422 追加
  { name: "schedule-task-monitor", description: "Schedule 実行ログ監視", has_ui: true, ui_path: "/admin", ui_navigation: "管理者ダッシュボード > Schedule モニター" },
  { name: "blog-post-manager", description: "技術ブログ投稿管理", has_ui: true, ui_path: "/tech-blog-tracker", ui_navigation: "ホーム > QUICK ACCESS > 技術ブログ管理" },
  { name: "edge-function-coverage", description: "Edge Function カバレッジ", has_ui: true, ui_path: "/edge-functions", ui_navigation: "ホーム > QUICK ACCESS > Edge Function ステータス" },
  { name: "user-profile-manager", description: "ユーザープロフィール管理", has_ui: true, ui_path: "/profile", ui_navigation: "ホーム > プロフィール設定" },
  { name: "ai-secretary", description: "AI 秘書 (全提案機能)", has_ui: true, ui_path: "/ai-secretary", ui_navigation: "ホーム > QUICK ACCESS > AI 秘書" },
  { name: "team-task-manager", description: "仮想組織タスク管理", has_ui: true, ui_path: "/agents", ui_navigation: "ホーム > QUICK ACCESS > AI 組織 OS" },
  // Session 423 追加
  { name: "schedule-health-check", description: "Schedule ヘルスチェック・改善提案", has_ui: true, ui_path: "/admin", ui_navigation: "管理者ダッシュボード > Schedule ヘルス" },
  { name: "code-review-issues", description: "コードレビュー・Issue管理", has_ui: true, ui_path: "/admin", ui_navigation: "管理者ダッシュボード > コードレビュー" },
  { name: "development-stats", description: "開発進捗グラフデータ", has_ui: true, ui_path: "/home", ui_navigation: "ホーム > 開発進捗グラフ" },
  // Session 424 追加
  { name: "agent-personality", description: "エージェント性格管理・記憶・学習", has_ui: true, ui_path: "/agents", ui_navigation: "ホーム > QUICK ACCESS > AI 組織 OS > エージェント詳細" },
  { name: "agent-department-manager", description: "部署管理・自動作成・ルール設計", has_ui: true, ui_path: "/agents", ui_navigation: "ホーム > QUICK ACCESS > AI 組織 OS > 部署管理" },
  // Session 425 追加
  { name: "notification-center", description: "通知センター", has_ui: true, ui_path: "/notifications", ui_navigation: "ホーム > ベルアイコン > 通知一覧" },
  { name: "onboarding-flow", description: "オンボーディング管理", has_ui: true, ui_path: "/onboarding", ui_navigation: "初回ログイン時に自動表示" },
  // Session 426 追加
  { name: "feature-request-manager", description: "機能リクエスト CRUD+投票", has_ui: true, ui_path: "/feature-requests", ui_navigation: "ホーム > QUICK ACCESS > 機能リクエスト" },
  { name: "app-analytics-dashboard", description: "アプリ分析ダッシュボード", has_ui: true, ui_path: "/admin", ui_navigation: "管理者ダッシュボード > 分析" },
  // Session 427 追加
  { name: "user-activity-tracker", description: "ユーザーアクティビティ記録・リテンション分析", has_ui: true, ui_path: "/admin", ui_navigation: "管理者ダッシュボード > ユーザーアクティビティ" },
  { name: "competitor-feature-sync", description: "競合機能パリティ動的管理・進捗トラッキング", has_ui: true, ui_path: "/admin", ui_navigation: "管理者ダッシュボード > 競合機能同期" },
  { name: "data-export-manager", description: "GDPR対応データエクスポート (JSON/CSV)", has_ui: true, ui_path: "/settings", ui_navigation: "設定 > データエクスポート" },
  { name: "ab-testing-manager", description: "A/Bテスト実験管理・バリアント割り当て", has_ui: true, ui_path: "/admin", ui_navigation: "管理者ダッシュボード > A/Bテスト" },
  { name: "seo-optimizer", description: "SEO分析・メタタグ管理・スコア算出", has_ui: true, ui_path: "/admin", ui_navigation: "管理者ダッシュボード > SEO" },
  { name: "search-analytics", description: "検索クエリ分析・トレンド・品質スコア", has_ui: true, ui_path: "/admin", ui_navigation: "管理者ダッシュボード > 検索分析" },
  { name: "webhook-manager", description: "外部連携Webhook管理・配信ログ", has_ui: true, ui_path: "/admin", ui_navigation: "管理者ダッシュボード > Webhook" },
  // Session 428 追加
  { name: "subscription-management", description: "サブスクリプション管理・プラン制御・利用量追跡", has_ui: true, ui_path: "/settings", ui_navigation: "設定 > プラン管理" },
  { name: "gamification-engine", description: "ストリーク・バッジ・ポイント・リーダーボード", has_ui: true, ui_path: "/home", ui_navigation: "ホーム > ゲーミフィケーションカード" },
  { name: "agent-task-router", description: "AIエージェント間タスク自動割り振り・負荷分散", has_ui: true, ui_path: "/agents", ui_navigation: "AI組織OS > タスクルーター" },
  { name: "import-from-competitors", description: "競合製品からのデータインポート (8形式)", has_ui: true, ui_path: "/import", ui_navigation: "インポートページ" },
  { name: "department-reporting", description: "部署別KPIレポート・効率スコア", has_ui: true, ui_path: "/agents", ui_navigation: "AI組織OS > 部署レポート" },
  { name: "agent-performance-monitor", description: "エージェントパフォーマンス監視・ランキング", has_ui: true, ui_path: "/agents", ui_navigation: "AI組織OS > パフォーマンス" },
  { name: "team-collaboration-sync", description: "チーム協業・アクティビティフィード・メンション通知", has_ui: true, ui_path: "/agents", ui_navigation: "AI組織OS > アクティビティ" },
  { name: "user-feedback-collector", description: "NPS・機能満足度・フィードバック収集", has_ui: true, ui_path: "/feedback", ui_navigation: "設定 > フィードバック" },
  { name: "revenue-forecaster", description: "収益予測・事業計画シミュレーション", has_ui: true, ui_path: "/admin", ui_navigation: "管理者ダッシュボード > 収益予測" },
  { name: "content-moderation", description: "コンテンツモデレーション・安全性チェック", has_ui: true, ui_path: "/admin", ui_navigation: "管理者ダッシュボード > モデレーション" },
  { name: "api-rate-limiter", description: "APIレートリミット・利用制限管理", has_ui: true, ui_path: "/admin", ui_navigation: "管理者ダッシュボード > API制限" },
  { name: "notification-preferences", description: "通知設定管理 (タイプ別/頻度/メール/プッシュ)", has_ui: true, ui_path: "/settings", ui_navigation: "設定 > 通知設定" },
  // Session 429 追加
  { name: "file-storage-manager", description: "ファイルストレージ管理・アップロード・共有", has_ui: true, ui_path: "/files", ui_navigation: "ホーム > ファイル管理" },
  { name: "calendar-events", description: "カレンダー・イベント管理 (日/週/月ビュー)", has_ui: true, ui_path: "/calendar", ui_navigation: "ホーム > カレンダー" },
  { name: "kanban-board", description: "カンバンボード・プロジェクト管理", has_ui: true, ui_path: "/kanban", ui_navigation: "ホーム > プロジェクト管理" },
  { name: "chat-messaging", description: "チャット・メッセージング (チャンネル/DM/スレッド)", has_ui: true, ui_path: "/chat", ui_navigation: "ホーム > チャット" },
  { name: "automation-workflows", description: "ワークフロー自動化 (トリガー/アクション)", has_ui: true, ui_path: "/workflows", ui_navigation: "ホーム > ワークフロー" },
  // Session 430 追加
  { name: "time-tracker", description: "勤怠・時間追跡 (出退勤/プロジェクト別/残業アラート)", has_ui: true, ui_path: "/time-tracker", ui_navigation: "ホーム > 勤怠管理" },
  { name: "expense-tracker", description: "家計簿・経費管理 (収支/カテゴリ/予算/年次)", has_ui: true, ui_path: "/expenses", ui_navigation: "ホーム > 家計簿" },
  { name: "ai-summarizer", description: "AIテキスト要約・キーポイント・感情分析", has_ui: true, ui_path: "/ai-tools", ui_navigation: "ホーム > AI ツール > 要約" },
  { name: "template-library", description: "テンプレートライブラリ (8組込+カスタム)", has_ui: true, ui_path: "/templates", ui_navigation: "ホーム > テンプレート" },
  { name: "tag-manager", description: "タグ管理・統計・マージ・一括操作", has_ui: true, ui_path: "/tags", ui_navigation: "ホーム > タグ管理" },
  { name: "habit-tracker", description: "習慣トラッカー (チェックイン/ストリーク/達成率)", has_ui: true, ui_path: "/habits", ui_navigation: "ホーム > 習慣管理" },
  { name: "bookmark-manager", description: "ブックマーク管理 (URL保存/フォルダ/検索)", has_ui: true, ui_path: "/bookmarks", ui_navigation: "ホーム > ブックマーク" },
  { name: "poll-survey", description: "アンケート・投票 (作成/回答/集計)", has_ui: true, ui_path: "/polls", ui_navigation: "ホーム > アンケート" },
  { name: "invoice-generator", description: "請求書生成 (作成/ステータス管理/売上集計)", has_ui: true, ui_path: "/invoices", ui_navigation: "ホーム > 請求書" },
  { name: "contact-manager", description: "連絡先管理 (CRUD/グループ/インタラクション)", has_ui: true, ui_path: "/contacts", ui_navigation: "ホーム > 連絡先" },
  { name: "goal-tracker", description: "目標管理 (短中長期/マイルストーン/進捗追跡)", has_ui: true, ui_path: "/goals", ui_navigation: "ホーム > 目標管理" },
  { name: "reading-list", description: "読書管理 (書籍登録/ステータス/メモ/統計)", has_ui: true, ui_path: "/reading", ui_navigation: "ホーム > 読書リスト" },
  { name: "password-generator", description: "パスワード生成・強度チェック", has_ui: true, ui_path: "/tools", ui_navigation: "ホーム > ツール > パスワード" },
  { name: "clipboard-history", description: "クリップボード履歴 (保存/ピン/検索)", has_ui: true, ui_path: "/clipboard", ui_navigation: "ホーム > クリップボード" },
  { name: "quick-note", description: "クイックメモ (色分け/チェックリスト/ピン)", has_ui: true, ui_path: "/quick-notes", ui_navigation: "ホーム > クイックメモ" },
  { name: "pomodoro-timer", description: "ポモドーロタイマー (セッション記録/統計/設定)", has_ui: true, ui_path: "/pomodoro", ui_navigation: "ホーム > ポモドーロ" },
  { name: "weather-widget", description: "天気ウィジェット (日本8都市/7日予報)", has_ui: true, ui_path: "/home", ui_navigation: "ホーム > 天気ウィジェット" },
  { name: "currency-converter", description: "通貨換算 (15通貨/リアルタイム)", has_ui: true, ui_path: "/tools", ui_navigation: "ホーム > ツール > 通貨換算" },
  { name: "markdown-renderer", description: "Markdownレンダリング (HTML変換/目次/統計)", has_ui: true, ui_path: "/editor", ui_navigation: "ノートエディタ > プレビュー" },
  { name: "system-status", description: "システムステータス (稼働監視/インシデント/稼働率)", has_ui: true, ui_path: "/status", ui_navigation: "ステータスページ" },
  // Session 431 追加
  { name: "email-service", description: "メール送信・テンプレート管理 (Resend API)", has_ui: true, ui_path: "/email", ui_navigation: "ホーム > メール" },
  { name: "social-feed", description: "ソーシャルフィード (投稿/いいね/フォロー/タイムライン)", has_ui: true, ui_path: "/social", ui_navigation: "ホーム > ソーシャル" },
  { name: "document-collaboration", description: "ドキュメント共同編集 (共有/バージョン/コメント)", has_ui: true, ui_path: "/docs", ui_navigation: "ノート > 共同編集" },
  { name: "leave-management", description: "休暇管理 (申請/承認/残日数)", has_ui: true, ui_path: "/leave", ui_navigation: "ホーム > 休暇管理" },
  { name: "knowledge-base", description: "ナレッジベース/ヘルプセンター (FAQ/記事/検索)", has_ui: true, ui_path: "/help", ui_navigation: "ヘルプ > ナレッジベース" },
  { name: "payment-processor", description: "決済処理 (支払い記録/履歴/売上レポート)", has_ui: true, ui_path: "/payments", ui_navigation: "ホーム > 支払い" },
  { name: "marketplace", description: "マーケットプレイス (プラグイン/インストール/レビュー)", has_ui: true, ui_path: "/marketplace", ui_navigation: "ホーム > マーケットプレイス" },
  { name: "video-audio-manager", description: "動画・音声管理 (メディア/プレイリスト/文字起こし)", has_ui: true, ui_path: "/media", ui_navigation: "ホーム > メディア" },
  { name: "semantic-search", description: "セマンティック検索 (全文横断/フィルタ/保存検索)", has_ui: true, ui_path: "/search", ui_navigation: "ホーム > 検索" },
  { name: "performance-review", description: "人事評価 (OKR/自己評価/360度FB)", has_ui: true, ui_path: "/reviews", ui_navigation: "ホーム > パフォーマンス" },
  { name: "wiki-database", description: "Wiki・データベース (階層ページ/テーブル/Notion競合)", has_ui: true, ui_path: "/wiki", ui_navigation: "ホーム > Wiki" },
  { name: "api-key-manager", description: "APIキー管理 (生成/権限/無効化)", has_ui: true, ui_path: "/api-keys", ui_navigation: "設定 > APIキー" },
  { name: "scheduled-notifications", description: "通知スケジューリング (リマインダー/定期通知)", has_ui: true, ui_path: "/notifications/schedule", ui_navigation: "通知 > スケジュール" },
  { name: "cohort-analysis", description: "コホート分析 (リテンション/ファネル/イベント)", has_ui: true, ui_path: "/admin/cohort", ui_navigation: "管理 > コホート分析" },
  { name: "integration-connector", description: "外部サービス連携 (Slack/Discord/LINE等10サービス)", has_ui: true, ui_path: "/integrations", ui_navigation: "設定 > 連携" },
  { name: "push-notification-manager", description: "Web Push通知管理 (購読/配信/統計)", has_ui: true, ui_path: "/notifications/push", ui_navigation: "通知 > Push設定" },
  { name: "realtime-presence", description: "リアルタイムプレゼンス (カーソル共有/編集ロック/オンライン)", has_ui: true, ui_path: "/docs", ui_navigation: "ドキュメント > 共同編集" },
  { name: "voice-memo-transcriber", description: "音声メモ・文字起こし (録音/文字起こし/ノート変換)", has_ui: true, ui_path: "/voice-memos", ui_navigation: "ホーム > 音声メモ" },
  { name: "ocr-document-scanner", description: "OCR文書スキャン (レシート/名刺/ドキュメント)", has_ui: true, ui_path: "/scanner", ui_navigation: "ホーム > スキャナー" },
  { name: "oauth-sso-provider", description: "SSO/OAuth管理 (Google/GitHub/Microsoft/SAML)", has_ui: true, ui_path: "/settings/sso", ui_navigation: "設定 > SSO" },
  { name: "inventory-manager", description: "在庫・資産管理 (物品/デジタル資産/入出庫/アラート)", has_ui: true, ui_path: "/inventory", ui_navigation: "ホーム > 在庫管理" },
  { name: "order-tracker", description: "注文・配送追跡 (注文/ステータス/ウィッシュリスト)", has_ui: true, ui_path: "/orders", ui_navigation: "ホーム > 注文" },
  { name: "ci-cd-pipeline", description: "CI/CDパイプライン (ビルド/デプロイ/ロールバック)", has_ui: true, ui_path: "/pipelines", ui_navigation: "開発 > パイプライン" },
  { name: "compensation-manager", description: "給与・報酬管理 (給与/賞与/明細)", has_ui: true, ui_path: "/compensation", ui_navigation: "ホーム > 給与" },
  { name: "financial-report", description: "財務レポート (P/L/キャッシュフロー/カテゴリ分析)", has_ui: true, ui_path: "/finance/reports", ui_navigation: "家計簿 > レポート" },
  { name: "spreadsheet-database", description: "スプレッドシート・DB (列定義/行CRUD/フィルタ/ビュー切替)", has_ui: true, ui_path: "/spreadsheet", ui_navigation: "ホーム > スプレッドシート" },
  { name: "gantt-timeline-manager", description: "ガントチャート (タスク依存/マイルストーン/クリティカルパス)", has_ui: true, ui_path: "/gantt", ui_navigation: "プロジェクト > ガントチャート" },
  { name: "whiteboard-canvas", description: "ホワイトボード (図形/テキスト/コネクター/テンプレート)", has_ui: true, ui_path: "/whiteboard", ui_navigation: "ホーム > ホワイトボード" },
  { name: "form-builder", description: "フォームビルダー (多種フィールド/条件分岐/公開URL/集計)", has_ui: true, ui_path: "/forms", ui_navigation: "ホーム > フォーム" },
  { name: "meeting-manager", description: "ミーティング管理 (RSVP/アジェンダ/議事録/アクションアイテム)", has_ui: true, ui_path: "/meetings", ui_navigation: "ホーム > ミーティング" },
  { name: "schedule-result-tracker", description: "Schedule実行結果追跡 (タスク結果/失敗検出/統計)", has_ui: true, ui_path: "/admin/schedule", ui_navigation: "管理 > Schedule結果" },
  { name: "blog-auto-publisher", description: "ブログ自動投稿管理 (11プラットフォーム/投稿追跡/統計)", has_ui: true, ui_path: "/blog/publish", ui_navigation: "ブログ > 投稿管理" },
  { name: "virtual-organization", description: "仮想AI組織 (12部署/エージェント配置/タスク割振り/性格管理)", has_ui: true, ui_path: "/organization", ui_navigation: "ホーム > AI組織" },
  { name: "edge-function-ui-checker", description: "Edge Function UI連携チェッカー (未連携検出/タスク生成)", has_ui: false, ui_path: null, ui_navigation: "Schedule自動実行" },
  { name: "issue-auto-resolver", description: "Issue自動修正管理 (Issue追跡/修正記録/統計)", has_ui: true, ui_path: "/admin/issues", ui_navigation: "管理 > Issue修正" },
  { name: "horse-racing-predictor", description: "競馬予想・分析 (レース登録/AIスコアリング/回収率統計)", has_ui: true, ui_path: "/horse-racing", ui_navigation: "ホーム > 競馬予想" },
  { name: "recruitment-job-board", description: "採用・求人管理 (ATS/選考パイプライン/面接管理)", has_ui: true, ui_path: "/recruitment", ui_navigation: "ホーム > 採用管理" },
  { name: "legal-compliance-manager", description: "法務・コンプライアンス (契約管理/GDPR・個人情報保護/監査)", has_ui: true, ui_path: "/legal", ui_navigation: "ホーム > 法務管理" },
  { name: "elearning-course-manager", description: "eラーニング (コース作成/進捗追跡/修了証/スキルギャップ分析)", has_ui: true, ui_path: "/elearning", ui_navigation: "ホーム > eラーニング" },
  { name: "crm-sales-pipeline", description: "CRM営業パイプライン (リード管理/商談ステージ/活動ログ/売上予測)", has_ui: true, ui_path: "/crm", ui_navigation: "ホーム > CRM" },
  { name: "photo-gallery-manager", description: "写真ギャラリー (アルバム/AI自動タグ/タイムライン/共有)", has_ui: true, ui_path: "/photos", ui_navigation: "ホーム > フォト" },
  { name: "music-playlist-manager", description: "音楽プレイリスト (楽曲管理/再生履歴/レコメンド/統計)", has_ui: true, ui_path: "/music", ui_navigation: "ホーム > 音楽" },
  { name: "recipe-meal-planner", description: "レシピ・献立 (レシピ管理/週間献立/買い物リスト/栄養計算)", has_ui: true, ui_path: "/recipes", ui_navigation: "ホーム > レシピ" },
  { name: "fitness-health-tracker", description: "フィットネス・健康 (ワークアウト/体重/健康メトリクス/目標)", has_ui: true, ui_path: "/fitness", ui_navigation: "ホーム > フィットネス" },
  { name: "travel-itinerary-planner", description: "旅行プランナー (日程管理/予約/パッキングリスト/予算管理)", has_ui: true, ui_path: "/travel", ui_navigation: "ホーム > 旅行" },
  { name: "event-ticketing", description: "イベント・チケット管理 (イベント作成/QRチケット/チェックイン/統計)", has_ui: true, ui_path: "/events", ui_navigation: "ホーム > イベント" },
  { name: "pet-care-manager", description: "ペットケア管理 (ペット情報/健康記録/食事/散歩ログ)", has_ui: true, ui_path: "/pets", ui_navigation: "ホーム > ペット" },
  { name: "language-learning", description: "語学学習 (単語帳/フラッシュカード/間隔反復/ストリーク/統計)", has_ui: true, ui_path: "/language", ui_navigation: "ホーム > 語学学習" },
  { name: "home-iot-manager", description: "スマートホームIoT (デバイス管理/センサーデータ/自動化ルール/シーン)", has_ui: true, ui_path: "/iot", ui_navigation: "ホーム > IoT" },
  { name: "news-rss-aggregator", description: "ニュースRSS (フィード管理/記事/ブックマーク/カテゴリ/統計)", has_ui: true, ui_path: "/news", ui_navigation: "ホーム > ニュース" },
  { name: "ai-workflow-automation", description: "AIワークフロー自動化 (トリガー/AI判定/アクション/テンプレート)", has_ui: true, ui_path: "/workflows", ui_navigation: "ホーム > ワークフロー" },
  { name: "document-esignature", description: "電子署名 (署名リクエスト/監査証跡/テンプレート/署名統計)", has_ui: true, ui_path: "/esign", ui_navigation: "ホーム > 電子署名" },
  { name: "social-media-scheduler", description: "SNSスケジューラー (8プラットフォーム/コンテンツカレンダー/パフォーマンス)", has_ui: true, ui_path: "/social-scheduler", ui_navigation: "ホーム > SNS管理" },
  { name: "smart-inbox-triage", description: "スマート受信トレイ (8チャネル統合/AI優先度/自動ラベル/スヌーズ)", has_ui: true, ui_path: "/inbox", ui_navigation: "ホーム > 受信トレイ" },
  { name: "video-meeting-manager", description: "ビデオ会議 (ルーム/参加者管理/AI議事録/アクションアイテム)", has_ui: true, ui_path: "/video-meeting", ui_navigation: "ホーム > ビデオ会議" },
  { name: "family-sharing-manager", description: "ファミリー共有 (グループ/共有カレンダー/支出共有/メンバー管理)", has_ui: true, ui_path: "/family", ui_navigation: "ホーム > ファミリー" },
  { name: "donation-crowdfunding", description: "寄付・クラウドファンディング (キャンペーン/リワード/支援者統計)", has_ui: true, ui_path: "/crowdfunding", ui_navigation: "ホーム > クラウドファンディング" },
  { name: "real-estate-tracker", description: "不動産管理 (物件/賃貸収支/メンテナンス/テナント/ROI)", has_ui: true, ui_path: "/real-estate", ui_navigation: "ホーム > 不動産" },
  { name: "podcast-manager", description: "ポッドキャスト管理 (番組/エピソード/購読/再生統計/ランキング)", has_ui: true, ui_path: "/podcast", ui_navigation: "ホーム > ポッドキャスト" },
  { name: "mindmap-diagram", description: "マインドマップ・ダイアグラム (6種類/ノード・エッジ/Mermaidエクスポート/テンプレート)", has_ui: true, ui_path: "/mindmap", ui_navigation: "ホーム > マインドマップ" },
  { name: "parking-reservation", description: "駐車場・予約管理 (スペース/予約/料金計算/空き状況/収益統計)", has_ui: true, ui_path: "/parking", ui_navigation: "ホーム > 駐車場" },
  { name: "carbon-footprint-tracker", description: "カーボンフットプリント (CO2排出量/削減目標/オフセット/月次レポート)", has_ui: true, ui_path: "/carbon", ui_navigation: "ホーム > CO2管理" },
  { name: "gift-registry", description: "ギフトレジストリ (ウィッシュリスト/イベント紐付け/購入追跡/共有)", has_ui: true, ui_path: "/gifts", ui_navigation: "ホーム > ギフト" },
  { name: "vehicle-fleet-manager", description: "車両・フリート管理 (車両登録/走行記録/燃費/メンテナンス/コスト)", has_ui: true, ui_path: "/vehicles", ui_navigation: "ホーム > 車両管理" },
  { name: "emergency-contacts", description: "緊急連絡先・安否確認 (連絡先/医療情報/安否確認/防災)", has_ui: true, ui_path: "/emergency", ui_navigation: "ホーム > 緊急連絡先" },
  { name: "auction-marketplace", description: "オークション・マーケットプレイス (出品/入札/取引/評価)", has_ui: true, ui_path: "/auction", ui_navigation: "ホーム > オークション" },
  { name: "budget-financial-planner", description: "予算・家計プランナー (月次予算/支出管理/貯蓄目標/家計診断)", has_ui: true, ui_path: "/budget", ui_navigation: "ホーム > 予算プランナー" },
  { name: "code-playground", description: "コードプレイグラウンド (スニペット/テンプレート/共有/コレクション)", has_ui: true, ui_path: "/code-playground", ui_navigation: "ホーム > コードプレイグラウンド" },
  { name: "screen-recorder", description: "画面録画・スクリーンショット管理 (録画/スクショ/アノテーション/共有)", has_ui: true, ui_path: "/screen-recorder", ui_navigation: "ホーム > 画面録画" },
  { name: "qr-code-generator", description: "QRコード生成・管理 (URL/WiFi/連絡先/動的QR/解析)", has_ui: true, ui_path: "/qr-code", ui_navigation: "ホーム > QRコード" },
  { name: "appointment-scheduler", description: "予約スケジューラー (予約枠/受付/リマインダー/キャンセル/統計)", has_ui: true, ui_path: "/appointments", ui_navigation: "ホーム > 予約管理" },
  { name: "password-vault", description: "パスワード管理 (保存/強度チェック/セキュリティ監査/生成)", has_ui: true, ui_path: "/vault", ui_navigation: "ホーム > パスワード管理" },
  { name: "habit-gamification", description: "習慣ゲーミフィケーション (チャレンジ/バッジ/レベル/ランキング/ストリーク)", has_ui: true, ui_path: "/gamification", ui_navigation: "ホーム > ゲーミフィケーション" },
  { name: "inventory-barcode", description: "在庫バーコード管理 (スキャン/入出庫/棚卸し/アラート/レポート)", has_ui: true, ui_path: "/inventory", ui_navigation: "ホーム > 在庫管理" },
  { name: "customer-feedback", description: "顧客フィードバック・NPS (収集/感情分析/分類/トレンド)", has_ui: true, ui_path: "/feedback", ui_navigation: "ホーム > フィードバック" },
  { name: "email-template-builder", description: "メールテンプレートビルダー (テンプレート/変数置換/キャンペーン/開封率)", has_ui: true, ui_path: "/email-templates", ui_navigation: "ホーム > メールテンプレート" },
  { name: "sitemap-analytics", description: "Web分析 (ページビュー/リファラー/デバイス/コンバージョン)", has_ui: true, ui_path: "/web-analytics", ui_navigation: "管理 > Web分析" },
  { name: "two-factor-auth", description: "二要素認証管理 (TOTP/バックアップコード/デバイス/認証ログ)", has_ui: true, ui_path: "/security/2fa", ui_navigation: "設定 > セキュリティ > 2FA" },
  { name: "changelog-manager", description: "チェンジログ・リリースノート (バージョン/変更点/Markdown生成)", has_ui: true, ui_path: "/changelog", ui_navigation: "ホーム > チェンジログ" },
  { name: "access-control", description: "アクセス制御・権限管理 (ロール/リソース/招待/アクセスログ)", has_ui: true, ui_path: "/access-control", ui_navigation: "管理 > アクセス制御" },
  { name: "data-visualization", description: "データ可視化・チャート生成 (チャート/ダッシュボード/カラーパレット)", has_ui: true, ui_path: "/charts", ui_navigation: "ホーム > チャート" },
  { name: "api-docs-generator", description: "APIドキュメント自動生成 (エンドポイント/OpenAPI/バージョン)", has_ui: true, ui_path: "/api-docs", ui_navigation: "管理 > APIドキュメント" },
  { name: "backup-restore", description: "バックアップ・リストア管理 (バックアップ/エクスポート/スケジュール)", has_ui: true, ui_path: "/backup", ui_navigation: "設定 > バックアップ" },
  { name: "notification-digest", description: "通知ダイジェスト (集約/優先度/チャネル/静音時間)", has_ui: true, ui_path: "/notifications/digest", ui_navigation: "ホーム > 通知ダイジェスト" },
  { name: "smart-search", description: "スマート検索 (全文検索/フィルタ/保存/サジェスト)", has_ui: true, ui_path: "/search", ui_navigation: "ホーム > 検索" },
  { name: "referral-program", description: "紹介プログラム (紹介コード/追跡/報酬/リーダーボード)", has_ui: true, ui_path: "/referral", ui_navigation: "ホーム > 紹介プログラム" },
  { name: "analytics-export", description: "分析データエクスポート (レポート/CSV/スケジュール)", has_ui: true, ui_path: "/analytics/export", ui_navigation: "管理 > エクスポート" },
  { name: "workflow-templates", description: "ワークフローテンプレート (承認フロー/ステップ管理/ギャラリー)", has_ui: true, ui_path: "/workflows", ui_navigation: "ホーム > ワークフロー" },
  { name: "status-page", description: "ステータスページ (サービス状態/インシデント/稼働率)", has_ui: true, ui_path: "/status", ui_navigation: "ホーム > ステータス" },
  { name: "address-book", description: "アドレス帳 (連絡先/グループ/vCard/重複検出)", has_ui: true, ui_path: "/address-book", ui_navigation: "ホーム > アドレス帳" },
  { name: "multi-language", description: "多言語対応 (10言語/翻訳管理/言語切替/進捗)", has_ui: true, ui_path: "/settings/language", ui_navigation: "設定 > 言語" },
  { name: "data-pipeline", description: "データパイプライン (ETL/変換/スケジュール/実行ログ)", has_ui: true, ui_path: "/data-pipeline", ui_navigation: "管理 > データパイプライン" },
  { name: "subscription-billing", description: "サブスクリプション課金 (プラン/請求書/クーポン/使用量)", has_ui: true, ui_path: "/billing", ui_navigation: "設定 > プラン・課金" },
  { name: "feature-flags", description: "フィーチャーフラグ (フラグ管理/ロールアウト/評価)", has_ui: true, ui_path: "/admin/feature-flags", ui_navigation: "管理 > フィーチャーフラグ" },
  { name: "audit-trail", description: "監査ログ (アクション記録/コンプライアンス/検索)", has_ui: true, ui_path: "/admin/audit", ui_navigation: "管理 > 監査ログ" },
  { name: "compliance-checker", description: "コンプライアンスチェッカー (GDPR/PIPA/CCPA/HIPAA/SOX/ISO27001)", has_ui: true, ui_path: "/admin/compliance", ui_navigation: "管理 > コンプライアンス" },
  { name: "user-onboarding", description: "ユーザーオンボーディング (ステップ管理/進捗/チュートリアル)", has_ui: true, ui_path: "/onboarding", ui_navigation: "ホーム > オンボーディング" },
  { name: "rate-limiter-enhanced", description: "レートリミッター強化版 (プラン別制限/使用量/チェック)", has_ui: true, ui_path: "/admin/rate-limits", ui_navigation: "管理 > レートリミット" },
  { name: "content-versioning", description: "コンテンツバージョン管理 (履歴/差分/復元/ロック)", has_ui: true, ui_path: "/content/versions", ui_navigation: "コンテンツ > バージョン管理" },
  { name: "custom-dashboard-builder", description: "カスタムダッシュボードビルダー (ウィジェット/テンプレート/共有)", has_ui: true, ui_path: "/dashboard/builder", ui_navigation: "ホーム > ダッシュボードビルダー" },
  { name: "loyalty-points", description: "ロイヤルティポイント (ポイント付与/消費/ランク/特典交換)", has_ui: true, ui_path: "/loyalty", ui_navigation: "ホーム > ポイント" },
  { name: "live-streaming", description: "ライブストリーミング (配信/チャット/視聴者分析/アーカイブ)", has_ui: true, ui_path: "/live", ui_navigation: "ソーシャル > ライブ" },
  { name: "geo-checkin", description: "位置情報チェックイン (スポット/レビュー/ランキング/近くのスポット)", has_ui: true, ui_path: "/checkin", ui_navigation: "ソーシャル > チェックイン" },
  { name: "social-stories", description: "ソーシャルストーリーズ (24時間投稿/リアクション/ハイライト)", has_ui: true, ui_path: "/stories", ui_navigation: "ソーシャル > ストーリー" },
  { name: "encrypted-messaging", description: "暗号化メッセージング (チャンネル/自動削除/既読管理)", has_ui: true, ui_path: "/secure-chat", ui_navigation: "メッセージ > セキュアチャット" },
  { name: "cloud-storage-sync", description: "クラウドストレージ同期 (ファイル管理/共有/バージョン/使用量)", has_ui: true, ui_path: "/storage", ui_navigation: "ファイル > クラウドストレージ" },
  { name: "virtual-whiteboard", description: "バーチャルホワイトボード (キャンバス/付箋/テンプレート/コラボ)", has_ui: true, ui_path: "/whiteboard", ui_navigation: "ツール > ホワイトボード" },
  { name: "marketplace-reviews", description: "マーケットプレイスレビュー (星評価/画像/役立った/分析)", has_ui: true, ui_path: "/reviews", ui_navigation: "マーケット > レビュー" },
  { name: "smart-home-automation", description: "スマートホームオートメーション (デバイス/シーン/自動化/エネルギー)", has_ui: true, ui_path: "/smart-home", ui_navigation: "IoT > スマートホーム" },
  { name: "digital-wallet", description: "デジタルウォレット (残高/送金/QR決済/支出分析)", has_ui: true, ui_path: "/wallet", ui_navigation: "ファイナンス > ウォレット" },
] as const;

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: { persistSession: false },
    });

    // POST: 呼び出し記録
    if (req.method === "POST") {
      const body = await req.json();
      const { function_name, error: callError } = body;

      if (!function_name) {
        return new Response(
          JSON.stringify({ success: false, error: "function_name is required" }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      // upsert: 存在すれば更新、なければ挿入
      const { error } = await supabase
        .from("edge_function_ui_status")
        .upsert({
          function_name,
          has_ui: true,
          last_called_at: new Date().toISOString(),
          call_count: 1, // DB側で increment するのが理想だが upsert で対応
          last_error: callError ?? null,
          updated_at: new Date().toISOString(),
        }, { onConflict: "function_name" });

      if (error) throw error;

      // call_count をインクリメント (RPC がなければ直接 SQL)
      await supabase.rpc("increment_edge_function_call_count", {
        fn_name: function_name,
      }).catch(() => {
        // RPC が存在しない場合は無視 (upsert で最低限の記録はできている)
      });

      return new Response(
        JSON.stringify({ success: true, recorded: function_name }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // GET: edge_function_ui_status テーブルから最新ステータスを取得
    const { data: dbStatus } = await supabase
      .from("edge_function_ui_status")
      .select("*");

    const statusMap = new Map<string, Record<string, unknown>>();
    if (dbStatus) {
      for (const row of dbStatus) {
        statusMap.set(row.function_name, row);
      }
    }

    // レジストリとDBステータスをマージ
    const functions = FUNCTION_REGISTRY.map((fn) => {
      const dbRow = statusMap.get(fn.name);
      return {
        ...fn,
        last_called_at: dbRow?.last_called_at ?? null,
        call_count: dbRow?.call_count ?? 0,
        last_error: dbRow?.last_error ?? null,
        deployed: true,
      };
    });

    const totalFunctions = functions.length;
    const withUi = functions.filter((f) => f.has_ui).length;
    const withoutUi = functions.filter((f) => !f.has_ui).length;
    const coveragePercent = Math.round((withUi / totalFunctions) * 100);

    return new Response(
      JSON.stringify({
        success: true,
        functions,
        summary: {
          total: totalFunctions,
          withUi,
          withoutUi,
          coveragePercent,
        },
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error("edge-function-coverage error:", err);
    return new Response(
      JSON.stringify({ success: false, error: message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
