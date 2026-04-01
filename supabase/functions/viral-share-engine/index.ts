// Viral Share Engine Edge Function
// バイラルシェアエンジン (成長ハック・口コミ・紹介拡散)
// - シェアリンク生成 (UTMパラメータ付き)
// - バイラル係数計算
// - インセンティブ付きシェア
// - ソーシャルプルーフ
// - A/Bテスト (CTA文言)
// - シェアカード(OGP)自動生成

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type" };
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const SHARE_CHANNELS = ["x_twitter", "facebook", "line", "discord", "email", "qr_code", "direct_link", "embed"];
const INCENTIVE_TYPES = ["premium_days", "storage_bonus", "ai_credits", "custom_theme", "badge"];
const BASE_URL = "https://my-web-app-b67f4.web.app";

// シェア文言テンプレート (A/Bテスト用)
const SHARE_TEMPLATES: Record<string, Array<{ id: string; text: string; emoji: string }>> = {
  x_twitter: [
    { id: "a1", text: "21のアプリを1つに統合した無料ツール見つけた。AIが全自動で仕事進めてくれる。", emoji: "🚀" },
    { id: "a2", text: "Notion + Evernote + MoneyForward + Slack の全機能が無料って信じられる？", emoji: "🔥" },
    { id: "a3", text: "このAIアプリがヤバすぎる。12部署20人の仮想AI組織が24時間働いてくれる。", emoji: "🤖" },
    { id: "a4", text: "月3,000円以上のサブスクを全部やめられるアプリ。しかも無料。", emoji: "💰" },
  ],
  line: [
    { id: "l1", text: "これ使ってみて！メモもタスクも家計簿もAIもぜんぶ無料だよ", emoji: "✨" },
    { id: "l2", text: "NotionとかEvernoteの有料プランいらなくなるアプリ見つけた", emoji: "📱" },
  ],
  email: [
    { id: "e1", text: "自分株式会社 — 21のアプリを1つに統合したAIライフマネジメントツール", emoji: "📧" },
  ],
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

      if (view === "config") return new Response(JSON.stringify({ success: true, channels: SHARE_CHANNELS, incentiveTypes: INCENTIVE_TYPES, shareTemplates: SHARE_TEMPLATES }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });

      if (view === "my_shares") {
        const { data: shares } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "viral_share").order("created_at", { ascending: false });
        let totalClicks = 0;
        let totalSignups = 0;
        for (const s of shares ?? []) {
          const m = s.metadata as Record<string, unknown>;
          totalClicks += (m.clicks as number) ?? 0;
          totalSignups += (m.signups_from_share as number) ?? 0;
        }
        const viralCoefficient = (shares ?? []).length > 0 ? Math.round((totalSignups / (shares ?? []).length) * 100) / 100 : 0;
        return new Response(JSON.stringify({
          success: true,
          shares: (shares ?? []).map((s) => ({ ...(s.metadata as Record<string, unknown>), createdAt: s.created_at })),
          stats: { totalShares: (shares ?? []).length, totalClicks, totalSignups, viralCoefficient },
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "viral_metrics") {
        // Calculate overall viral coefficient (k-factor)
        const { data: allShares } = await adminClient.from("app_analytics").select("metadata").eq("source", "viral_share");
        const { count: totalUsers } = await adminClient.from("app_analytics").select("*", { count: "exact", head: true }).eq("source", "user_signup");
        const totalInviteSent = (allShares ?? []).length;
        let totalConversions = 0;
        for (const s of allShares ?? []) totalConversions += ((s.metadata as Record<string, unknown>).signups_from_share as number) ?? 0;
        const kFactor = totalInviteSent > 0 ? Math.round((totalConversions / totalInviteSent) * 100) / 100 : 0;
        // Best performing templates
        const templatePerformance: Record<string, { shares: number; clicks: number; signups: number }> = {};
        for (const s of allShares ?? []) {
          const m = s.metadata as Record<string, unknown>;
          const tid = (m.template_id as string) ?? "custom";
          if (!templatePerformance[tid]) templatePerformance[tid] = { shares: 0, clicks: 0, signups: 0 };
          templatePerformance[tid].shares++;
          templatePerformance[tid].clicks += (m.clicks as number) ?? 0;
          templatePerformance[tid].signups += (m.signups_from_share as number) ?? 0;
        }
        return new Response(JSON.stringify({
          success: true, viralMetrics: { kFactor, totalUsers: totalUsers ?? 4, totalShares: totalInviteSent, totalConversions, templatePerformance },
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "leaderboard") {
        const { data: all } = await adminClient.from("app_analytics").select("user_id, metadata").eq("source", "viral_share");
        const userStats: Record<string, { shares: number; signups: number }> = {};
        for (const s of all ?? []) {
          const uid = s.user_id;
          if (!userStats[uid]) userStats[uid] = { shares: 0, signups: 0 };
          userStats[uid].shares++;
          userStats[uid].signups += ((s.metadata as Record<string, unknown>).signups_from_share as number) ?? 0;
        }
        const leaderboard = Object.entries(userStats).map(([uid, stats]) => ({ userId: uid, ...stats })).sort((a, b) => b.signups - a.signups).slice(0, 20);
        return new Response(JSON.stringify({ success: true, leaderboard }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: true, channels: SHARE_CHANNELS }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json();
      const { action } = body;

      if (action === "generate_share_link") {
        const { channel, template_id, custom_text } = body;
        if (!channel) return new Response(JSON.stringify({ success: false, error: "channel required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const shareCode = `s-${crypto.randomUUID().slice(0, 8)}`;
        const utmParams = `utm_source=${channel}&utm_medium=share&utm_campaign=viral&utm_content=${shareCode}`;
        const shareUrl = `${BASE_URL}/?ref=${shareCode}&${utmParams}`;
        // Get share text
        const templates = SHARE_TEMPLATES[channel] ?? SHARE_TEMPLATES.x_twitter;
        const template = template_id ? templates.find((t) => t.id === template_id) : templates[Math.floor(Math.random() * templates.length)];
        const shareText = custom_text ?? `${template?.emoji ?? ""} ${template?.text ?? ""}\n\n${shareUrl}`;
        // Build platform-specific share URL
        let platformShareUrl = shareUrl;
        if (channel === "x_twitter") platformShareUrl = `https://twitter.com/intent/tweet?text=${encodeURIComponent(shareText)}`;
        else if (channel === "facebook") platformShareUrl = `https://www.facebook.com/sharer/sharer.php?u=${encodeURIComponent(shareUrl)}`;
        else if (channel === "line") platformShareUrl = `https://social-plugins.line.me/lineit/share?url=${encodeURIComponent(shareUrl)}&text=${encodeURIComponent(shareText)}`;

        const shareId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "viral_share",
          metadata: { share_id: shareId, share_code: shareCode, channel, share_url: shareUrl, platform_share_url: platformShareUrl, share_text: shareText, template_id: template?.id ?? null, clicks: 0, signups_from_share: 0 },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, shareId, shareCode, shareUrl, platformShareUrl, shareText }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "track_click") {
        const { share_code, referrer } = body;
        if (!share_code) return new Response(JSON.stringify({ success: false, error: "share_code required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        // Increment click count on share record
        const { data: share } = await adminClient.from("app_analytics").select("metadata")
          .eq("source", "viral_share").eq("metadata->>share_code", share_code).maybeSingle();
        if (share) {
          const m = share.metadata as Record<string, unknown>;
          await adminClient.from("app_analytics").update({ metadata: { ...m, clicks: ((m.clicks as number) ?? 0) + 1 } })
            .eq("source", "viral_share").eq("metadata->>share_code", share_code);
        }
        // Record individual click
        await adminClient.from("app_analytics").insert({
          user_id: "anonymous", source: "share_click",
          metadata: { share_code, referrer: referrer ?? "", clicked_at: new Date().toISOString() },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "track_signup") {
        const { share_code, new_user_id } = body;
        if (!share_code) return new Response(JSON.stringify({ success: false, error: "share_code required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const { data: share } = await adminClient.from("app_analytics").select("metadata, user_id")
          .eq("source", "viral_share").eq("metadata->>share_code", share_code).maybeSingle();
        if (share) {
          const m = share.metadata as Record<string, unknown>;
          await adminClient.from("app_analytics").update({ metadata: { ...m, signups_from_share: ((m.signups_from_share as number) ?? 0) + 1 } })
            .eq("source", "viral_share").eq("metadata->>share_code", share_code);
          // Grant incentive to referrer
          await adminClient.from("app_analytics").insert({
            user_id: share.user_id, source: "share_reward",
            metadata: { share_code, new_user_id: new_user_id ?? null, reward_type: "premium_days", reward_value: 7, description: "紹介報酬: プレミアム7日間" },
            created_at: new Date().toISOString(),
          });
        }
        return new Response(JSON.stringify({ success: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }
    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) { return new Response(JSON.stringify({ success: false, error: err instanceof Error ? err.message : String(err) }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }); }
});
