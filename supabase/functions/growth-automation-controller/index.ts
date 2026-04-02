// Growth Automation Controller Edge Function
// 成長自動化コントローラー (全自動マーケティング・投稿・広告運用)
// - 自動投稿スケジュール管理
// - A/Bテスト自動実行
// - バイラル係数モニタリング
// - 競合比較広告自動生成
// - 成長KPIダッシュボード

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type" };
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const COMPETITORS = [
  { id: "notion", name: "Notion", monthlyPrice: 1650, features: ["メモ", "タスク", "Wiki", "DB"] },
  { id: "evernote", name: "Evernote", monthlyPrice: 1100, features: ["メモ", "クリッピング", "OCR"] },
  { id: "moneyforward", name: "MoneyForward", monthlyPrice: 500, features: ["家計簿", "資産管理", "確定申告"] },
  { id: "slack", name: "Slack", monthlyPrice: 1050, features: ["チャット", "チャンネル", "連携"] },
  { id: "chatwork", name: "Chatwork", monthlyPrice: 700, features: ["チャット", "タスク", "ビデオ"] },
  { id: "x", name: "X", monthlyPrice: 1380, features: ["SNS", "スペース", "コミュニティ"] },
  { id: "discord", name: "Discord", monthlyPrice: 1050, features: ["ボイチャ", "サーバー", "Bot"] },
  { id: "line", name: "LINE", monthlyPrice: 0, features: ["チャット", "通話", "Pay"] },
  { id: "amazon", name: "Amazon Prime", monthlyPrice: 600, features: ["ECモール", "動画", "音楽"] },
  { id: "github", name: "GitHub", monthlyPrice: 700, features: ["Git", "CI/CD", "Issues"] },
];

const GROWTH_STRATEGIES = [
  { id: "viral_loop", name: "バイラルループ", description: "紹介→報酬→さらに紹介の無限ループ", priority: "high" },
  { id: "content_marketing", name: "コンテンツマーケ", description: "技術ブログ/SNS/動画で認知拡大", priority: "high" },
  { id: "competitor_migration", name: "競合移行支援", description: "他サービスからのインポート機能で移行促進", priority: "medium" },
  { id: "social_proof", name: "ソーシャルプルーフ", description: "ユーザーレビュー/実績表示で信頼獲得", priority: "medium" },
  { id: "gamification", name: "ゲーミフィケーション", description: "ポイント/バッジ/ランキングで継続率UP", priority: "medium" },
  { id: "free_forever", name: "永久無料戦略", description: "コア機能は永久無料で競合と差別化", priority: "high" },
  { id: "ai_differentiation", name: "AI差別化", description: "AIが自動で仕事を進める唯一無二の体験", priority: "high" },
];

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  try {
    const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, { auth: { persistSession: false } });
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return new Response(JSON.stringify({ success: false, error: "Authorization required" }), { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, { global: { headers: { Authorization: authHeader } } });
    const { data: { user } } = await userClient.auth.getUser();
    if (!user) return new Response(JSON.stringify({ success: false, error: "Unauthorized" }), { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } });

    if (req.method === "GET") {
      const url = new URL(req.url);
      const view = url.searchParams.get("view");

      if (view === "config") return new Response(JSON.stringify({ success: true, competitors: COMPETITORS, strategies: GROWTH_STRATEGIES }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });

      if (view === "growth_kpi") {
        // Aggregate key growth metrics
        const { count: totalUsers } = await adminClient.from("user_profiles").select("*", { count: "exact", head: true });
        const _today = new Date().toISOString().split("T")[0];
        const weekAgo = new Date(Date.now() - 7 * 86400000).toISOString();
        const { count: newUsersThisWeek } = await adminClient.from("user_profiles").select("*", { count: "exact", head: true }).gte("created_at", weekAgo);
        const { count: totalShares } = await adminClient.from("app_analytics").select("*", { count: "exact", head: true }).eq("source", "viral_share");
        const { count: totalAdViews } = await adminClient.from("app_analytics").select("*", { count: "exact", head: true }).eq("source", "ad_impression");
        const { count: totalXPosts } = await adminClient.from("app_analytics").select("*", { count: "exact", head: true }).eq("source", "x_media_post");
        const { count: totalBlogPosts } = await adminClient.from("app_analytics").select("*", { count: "exact", head: true }).eq("source", "blog_post_published");

        const monthlyCompetitorCost = COMPETITORS.reduce((sum, c) => sum + c.monthlyPrice, 0);

        return new Response(JSON.stringify({
          success: true,
          kpi: {
            totalUsers: totalUsers ?? 4,
            newUsersThisWeek: newUsersThisWeek ?? 0,
            totalShares: totalShares ?? 0,
            totalAdViews: totalAdViews ?? 0,
            totalXPosts: totalXPosts ?? 0,
            totalBlogPosts: totalBlogPosts ?? 0,
            monthlyCompetitorCostSaved: monthlyCompetitorCost,
            edgeFunctionCount: 220,
          },
          strategies: GROWTH_STRATEGIES,
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "competitor_ad_copy") {
        const competitor = url.searchParams.get("competitor") ?? "notion";
        const comp = COMPETITORS.find((c) => c.id === competitor);
        if (!comp) return new Response(JSON.stringify({ success: false, error: "Unknown competitor" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const adCopies = [
          `${comp.name}に月¥${comp.monthlyPrice.toLocaleString()}払ってる？\n自分株式会社なら${comp.features.join("+")}が全部無料。\nhttps://my-web-app-b67f4.web.app/\n#buildinpublic`,
          `${comp.name}からの乗り換え、5分で完了。\nデータインポート機能でかんたん移行。\nしかも${comp.features.length}機能+AIが全部無料。\nhttps://my-web-app-b67f4.web.app/`,
          `⚡ ${comp.name}ユーザーに朗報\n${comp.features.join("・")}の全機能を無料で提供中。\nさらにAIが12部署を自動運営。\nhttps://my-web-app-b67f4.web.app/ #SaaS`,
        ];
        return new Response(JSON.stringify({ success: true, competitor: comp, adCopies }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "auto_schedule") {
        // Show what the auto-scheduler would post this week
        const schedule = [];
        const now = new Date();
        for (let i = 0; i < 7; i++) {
          const date = new Date(now.getTime() + i * 86400000);
          const dayOfWeek = date.getDay();
          const comp = COMPETITORS[i % COMPETITORS.length];
          schedule.push({
            date: date.toISOString().split("T")[0],
            dayOfWeek: ["日", "月", "火", "水", "木", "金", "土"][dayOfWeek],
            posts: [
              { time: "08:00", type: "comparison", target: comp.name, channel: "x_twitter" },
              { time: "12:00", type: "feature_highlight", channel: "x_twitter" },
              { time: "19:00", type: "viral_meme", channel: "x_twitter" },
            ],
          });
        }
        return new Response(JSON.stringify({ success: true, schedule }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: true, competitors: COMPETITORS, strategies: GROWTH_STRATEGIES }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      const { action } = body;

      if (action === "generate_daily_posts") {
        // Generate a full day's worth of X posts targeting different competitors
        const posts = [];
        const shuffled = [...COMPETITORS].sort(() => Math.random() - 0.5);
        const targets = shuffled.slice(0, 3);
        for (const comp of targets) {
          const templates = [
            `💡 ${comp.name}の${comp.features[0]}機能、自分株式会社なら無料で使えます。\nさらにAIが自動で仕事を進めてくれる。\nhttps://my-web-app-b67f4.web.app/\n#buildinpublic #SaaS`,
            `🔥 月¥${comp.monthlyPrice.toLocaleString()}の${comp.name}やめて自分株式会社に移行した結果:\n✅ ${comp.features.join("\n✅ ")}\n全部無料で使えてる。\nhttps://my-web-app-b67f4.web.app/`,
          ];
          const postId = crypto.randomUUID();
          const text = templates[Math.floor(Math.random() * templates.length)];
          posts.push({ postId, text, competitor: comp.name, charCount: text.length });
          await adminClient.from("app_analytics").insert({
            user_id: user.id, source: "x_post_draft",
            metadata: { post_id: postId, text, competitor: comp.id, type: "comparison", status: "draft", auto_generated: true },
            created_at: new Date().toISOString(),
          });
        }
        return new Response(JSON.stringify({ success: true, posts }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "run_ab_test") {
        const { variants } = body;
        if (!variants || !Array.isArray(variants) || variants.length < 2) return new Response(JSON.stringify({ success: false, error: "At least 2 variants required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const testId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "growth_ab_test",
          metadata: { test_id: testId, variants, status: "running", start_date: new Date().toISOString(), results: variants.map((v: unknown, i: number) => ({ variant: i, text: v, impressions: 0, clicks: 0, conversions: 0 })) },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, testId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }
    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) { return new Response(JSON.stringify({ success: false, error: err instanceof Error ? err.message : String(err) }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }); }
});
