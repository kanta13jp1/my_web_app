// Video Ad Generator Edge Function
// 動画広告生成 (Dark War風広告/TikTok/YouTube Shorts/Instagram Reels競合)
// - 広告スクリプト生成 (AI)
// - 動画テンプレート管理
// - シーン構成
// - テキストオーバーレイ
// - キャンペーン管理
// - パフォーマンス追跡

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type" };
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const AD_STYLES = ["dark_war", "tech_demo", "testimonial", "problem_solution", "countdown", "comparison", "story", "meme"];
const PLATFORMS = ["x_twitter", "youtube_shorts", "tiktok", "instagram_reels", "facebook"];
const AD_STATUSES = ["draft", "rendering", "ready", "published", "archived"];

// Dark War風の広告テンプレート
const AD_TEMPLATES = [
  {
    id: "dark_war_urgency",
    name: "Dark War風 — 緊急性訴求",
    style: "dark_war",
    scenes: [
      { duration_sec: 3, text: "⚠️ まだNotionとEvernoteを別々に使ってるの？", bg_color: "#0a0a0a", text_color: "#ff3333", animation: "shake" },
      { duration_sec: 3, text: "21のアプリを1つに統合", bg_color: "#0a0a0a", text_color: "#ffffff", animation: "fade_in" },
      { duration_sec: 4, text: "自分株式会社 — AI統合ライフマネジメント", bg_color: "#1a1a2e", text_color: "#00ff88", animation: "zoom_in" },
      { duration_sec: 2, text: "無料で今すぐ始める →", bg_color: "#ff3333", text_color: "#ffffff", animation: "pulse" },
    ],
    cta_url: "https://my-web-app-b67f4.web.app/",
    music: "epic_tension",
  },
  {
    id: "comparison_killer",
    name: "比較キラー — 競合殲滅",
    style: "comparison",
    scenes: [
      { duration_sec: 2, text: "Notion ¥1,650/月 → 自分株式会社 ¥0", bg_color: "#0a0a0a", text_color: "#ff6600", animation: "slide_left" },
      { duration_sec: 2, text: "Evernote ¥1,100/月 → 自分株式会社 ¥0", bg_color: "#0a0a0a", text_color: "#ff6600", animation: "slide_left" },
      { duration_sec: 2, text: "MoneyForward ¥500/月 → 自分株式会社 ¥0", bg_color: "#0a0a0a", text_color: "#ff6600", animation: "slide_left" },
      { duration_sec: 2, text: "21アプリ分の機能が全部無料", bg_color: "#1a1a2e", text_color: "#00ff88", animation: "explode" },
      { duration_sec: 2, text: "自分株式会社 → 今すぐ登録", bg_color: "#ff3333", text_color: "#ffffff", animation: "pulse" },
    ],
    cta_url: "https://my-web-app-b67f4.web.app/",
    music: "dramatic_reveal",
  },
  {
    id: "ai_secretary_demo",
    name: "AI秘書デモ — 機能訴求",
    style: "tech_demo",
    scenes: [
      { duration_sec: 3, text: "🤖 AIが12部署20人を自動運営", bg_color: "#0d1117", text_color: "#58a6ff", animation: "typewriter" },
      { duration_sec: 3, text: "タスク割り振り・進捗管理・自動修正", bg_color: "#0d1117", text_color: "#ffffff", animation: "fade_in" },
      { duration_sec: 3, text: "あなたがやるのは「ゴール設定」だけ", bg_color: "#1a1a2e", text_color: "#f0e68c", animation: "zoom_in" },
      { duration_sec: 3, text: "自分株式会社 — AIが導く新時代", bg_color: "#0a0a0a", text_color: "#00ff88", animation: "glow" },
    ],
    cta_url: "https://my-web-app-b67f4.web.app/",
    music: "futuristic",
  },
  {
    id: "fomo_countdown",
    name: "FOMO — カウントダウン",
    style: "countdown",
    scenes: [
      { duration_sec: 2, text: "🔥 先行登録者 限定特典", bg_color: "#0a0a0a", text_color: "#ff3333", animation: "flash" },
      { duration_sec: 2, text: "現在の登録者: たった4人", bg_color: "#0a0a0a", text_color: "#ffcc00", animation: "counter" },
      { duration_sec: 3, text: "初期ユーザーは永久プレミアム無料", bg_color: "#1a1a2e", text_color: "#00ff88", animation: "reveal" },
      { duration_sec: 3, text: "今すぐ登録 → my-web-app-b67f4.web.app", bg_color: "#ff3333", text_color: "#ffffff", animation: "bounce" },
    ],
    cta_url: "https://my-web-app-b67f4.web.app/",
    music: "urgency",
  },
  {
    id: "meme_viral",
    name: "ミーム — バイラル狙い",
    style: "meme",
    scenes: [
      { duration_sec: 3, text: "友人: 「Notion課金してる」\n俺: 「無料で全部できるけど？」", bg_color: "#0a0a0a", text_color: "#ffffff", animation: "meme_top_bottom" },
      { duration_sec: 3, text: "Notion + Evernote + MoneyForward + Slack\n= 月額¥5,000以上", bg_color: "#1a1a2e", text_color: "#ff6600", animation: "stack" },
      { duration_sec: 2, text: "自分株式会社 = ¥0\n(しかもAI付き)", bg_color: "#0a0a0a", text_color: "#00ff88", animation: "drop" },
      { duration_sec: 2, text: "リンクはプロフィールに👆", bg_color: "#ff3333", text_color: "#ffffff", animation: "point_up" },
    ],
    cta_url: "https://my-web-app-b67f4.web.app/",
    music: "meme_bass",
  },
];

// AI広告スクリプト生成テンプレート
const SCRIPT_GENERATORS = {
  pain_point: (competitor: string) => [
    { text: `まだ${competitor}に毎月お金を払ってるの？`, style: "shock" },
    { text: `${competitor}でできること、全部無料でできます`, style: "solution" },
    { text: "さらにAIが自動で仕事を進めてくれる", style: "bonus" },
    { text: "自分株式会社 — 今すぐ無料で始める", style: "cta" },
  ],
  social_proof: (userCount: number) => [
    { text: `現在${userCount}人が使用中`, style: "proof" },
    { text: "21の競合サービスの機能を1つに統合", style: "value" },
    { text: "AIが12部署を自動運営する未来のアプリ", style: "vision" },
    { text: "先行登録で永久特典 →", style: "cta" },
  ],
  feature_showcase: (features: string[]) => features.map((f, i) => ({
    text: `${i + 1}. ${f}`, style: i === features.length - 1 ? "cta" : "feature",
  })),
};

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

      if (view === "templates") return new Response(JSON.stringify({ success: true, templates: AD_TEMPLATES, styles: AD_STYLES, platforms: PLATFORMS }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });

      if (view === "campaigns") {
        const { data: campaigns } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "video_ad_campaign").order("created_at", { ascending: false });
        return new Response(JSON.stringify({ success: true, campaigns: (campaigns ?? []).map((c) => ({ ...(c.metadata as Record<string, unknown>), createdAt: c.created_at })) }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "ads") {
        const { data: ads } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "video_ad").order("created_at", { ascending: false });
        return new Response(JSON.stringify({ success: true, ads: (ads ?? []).map((a) => ({ ...(a.metadata as Record<string, unknown>), createdAt: a.created_at })) }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "performance") {
        const { data: metrics } = await adminClient.from("app_analytics").select("metadata")
          .eq("source", "ad_impression");
        let totalViews = 0;
        let totalClicks = 0;
        let totalSignups = 0;
        for (const m of metrics ?? []) {
          const meta = m.metadata as Record<string, unknown>;
          totalViews += (meta.views as number) ?? 0;
          totalClicks += (meta.clicks as number) ?? 0;
          totalSignups += (meta.signups as number) ?? 0;
        }
        const ctr = totalViews > 0 ? Math.round((totalClicks / totalViews) * 10000) / 100 : 0;
        const convRate = totalClicks > 0 ? Math.round((totalSignups / totalClicks) * 10000) / 100 : 0;
        return new Response(JSON.stringify({ success: true, performance: { totalViews, totalClicks, totalSignups, ctr, conversionRate: convRate } }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "generate_script") {
        const competitor = url.searchParams.get("competitor") ?? "Notion";
        const scriptType = url.searchParams.get("type") ?? "pain_point";
        let script;
        if (scriptType === "pain_point") script = SCRIPT_GENERATORS.pain_point(competitor);
        else if (scriptType === "social_proof") script = SCRIPT_GENERATORS.social_proof(4);
        else script = SCRIPT_GENERATORS.feature_showcase(["メモ・タスク管理", "AI秘書", "家計簿", "SNS投稿", "チーム管理", "今すぐ登録 →"]);
        return new Response(JSON.stringify({ success: true, script, competitor, type: scriptType }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: true, templates: AD_TEMPLATES, styles: AD_STYLES }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json();
      const { action } = body;

      if (action === "create_ad") {
        const { template_id, custom_scenes, title, target_platforms } = body;
        if (!title) return new Response(JSON.stringify({ success: false, error: "title required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const template = template_id ? AD_TEMPLATES.find((t) => t.id === template_id) : null;
        const adId = crypto.randomUUID();
        const scenes = custom_scenes ?? template?.scenes ?? [];
        // Generate HTML5 video spec (can be rendered client-side or by external service)
        const videoSpec = {
          width: 1080,
          height: 1920, // 9:16 for Shorts/Reels/TikTok
          fps: 30,
          scenes: scenes.map((s: Record<string, unknown>, i: number) => ({
            id: i,
            ...s,
            start_sec: scenes.slice(0, i).reduce((sum: number, prev: Record<string, unknown>) => sum + ((prev.duration_sec as number) ?? 3), 0),
          })),
          total_duration_sec: scenes.reduce((sum: number, s: Record<string, unknown>) => sum + ((s.duration_sec as number) ?? 3), 0),
          cta_url: template?.cta_url ?? "https://my-web-app-b67f4.web.app/",
          music: template?.music ?? "none",
        };
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "video_ad",
          metadata: {
            ad_id: adId, title, template_id: template_id ?? null, status: "ready",
            video_spec: videoSpec, target_platforms: target_platforms ?? ["x_twitter"],
            views: 0, clicks: 0, signups: 0,
          },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, adId, videoSpec }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "create_campaign") {
        const { name, ad_ids, platforms, budget_daily, start_date, end_date } = body;
        if (!name) return new Response(JSON.stringify({ success: false, error: "name required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const campaignId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "video_ad_campaign",
          metadata: {
            campaign_id: campaignId, name, ad_ids: ad_ids ?? [], platforms: platforms ?? ["x_twitter"],
            budget_daily: budget_daily ?? 0, start_date: start_date ?? new Date().toISOString().split("T")[0],
            end_date: end_date ?? null, status: "active", total_spent: 0,
          },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, campaignId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "record_impression") {
        const { ad_id, platform, views, clicks, signups } = body;
        if (!ad_id) return new Response(JSON.stringify({ success: false, error: "ad_id required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "ad_impression",
          metadata: { ad_id, platform: platform ?? "x_twitter", views: views ?? 0, clicks: clicks ?? 0, signups: signups ?? 0, recorded_at: new Date().toISOString() },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "generate_x_post") {
        // X投稿用のテキスト+動画リンクを自動生成
        const { template_id, custom_text } = body;
        const template = template_id ? AD_TEMPLATES.find((t) => t.id === template_id) : AD_TEMPLATES[0];
        const hashtags = "#buildinpublic #FlutterWeb #AI #SaaS #自分株式会社";
        const postTexts = [
          `⚡ 21のアプリを1つに統合。\nNotion、Evernote、MoneyForward…全部無料で使えます。\n\nAIが12部署を自動運営する次世代アプリ🚀\n\n${template?.cta_url}\n${hashtags}`,
          `🔥 まだバラバラのアプリに課金してるの？\n\nNotion ¥1,650 + Evernote ¥1,100 + MoneyForward ¥500 = 月¥3,250\n\n自分株式会社なら全部¥0\n\n${template?.cta_url}\n${hashtags}`,
          `🤖 AIが全自動で仕事を進める時代。\n\n12部署20人のAI組織が24時間稼働。\nあなたがやるのは「ゴール設定」だけ。\n\n${template?.cta_url}\n${hashtags}`,
          `📱 先行登録者 永久プレミアム無料！\n\n現在たった4人。この機会を逃すな。\n215+ Edge Functions搭載のAI統合アプリ。\n\n${template?.cta_url}\n${hashtags}`,
        ];
        const selectedText = custom_text ?? postTexts[Math.floor(Math.random() * postTexts.length)];
        // Record the generated post
        const postId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "x_post_draft",
          metadata: { post_id: postId, text: selectedText, template_id: template_id ?? null, has_video: true, video_template: template?.id ?? "dark_war_urgency", status: "draft" },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, postId, text: selectedText, charCount: selectedText.length }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }
    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) { return new Response(JSON.stringify({ success: false, error: err instanceof Error ? err.message : String(err) }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }); }
});
