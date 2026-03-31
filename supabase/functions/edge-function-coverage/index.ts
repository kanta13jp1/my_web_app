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
