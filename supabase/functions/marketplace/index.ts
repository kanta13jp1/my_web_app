// Marketplace Edge Function
// マーケットプレイス・プラグイン管理 (Notion/Slack/Discord競合)
// - プラグイン/拡張機能一覧
// - インストール/アンインストール
// - レビュー・評価
// - カテゴリ別閲覧
//
// GET  → プラグイン一覧 / インストール済み / カテゴリ
// POST → インストール / レビュー

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const BUILTIN_PLUGINS = [
  { id: "weather", name: "天気ウィジェット", category: "utilities", description: "ダッシュボードに天気を表示", author: "自分株式会社", rating: 4.5, installs: 120 },
  { id: "pomodoro", name: "ポモドーロタイマー", category: "productivity", description: "集中作業用タイマー", author: "自分株式会社", rating: 4.8, installs: 200 },
  { id: "expense", name: "家計簿", category: "finance", description: "収支管理・予算追跡", author: "自分株式会社", rating: 4.3, installs: 95 },
  { id: "kanban", name: "カンバンボード", category: "productivity", description: "プロジェクト管理ボード", author: "自分株式会社", rating: 4.6, installs: 180 },
  { id: "habit", name: "習慣トラッカー", category: "health", description: "毎日の習慣を追跡", author: "自分株式会社", rating: 4.4, installs: 150 },
  { id: "ai_summary", name: "AI要約", category: "ai", description: "テキストをAIで要約", author: "自分株式会社", rating: 4.7, installs: 250 },
  { id: "calendar", name: "カレンダー", category: "productivity", description: "イベント・スケジュール管理", author: "自分株式会社", rating: 4.5, installs: 175 },
  { id: "social", name: "ソーシャルフィード", category: "social", description: "投稿・いいね・フォロー", author: "自分株式会社", rating: 4.2, installs: 80 },
];

const CATEGORIES = [
  { key: "productivity", label: "生産性" },
  { key: "finance", label: "ファイナンス" },
  { key: "ai", label: "AI" },
  { key: "social", label: "ソーシャル" },
  { key: "utilities", label: "ユーティリティ" },
  { key: "health", label: "ヘルス" },
  { key: "developer", label: "開発者向け" },
];

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, { auth: { persistSession: false } });
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ success: false, error: "Authorization required" }), { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, { global: { headers: { Authorization: authHeader } } });
    const { data: { user } } = await userClient.auth.getUser();
    if (!user) {
      return new Response(JSON.stringify({ success: false, error: "Unauthorized" }), { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "GET") {
      const url = new URL(req.url);
      const view = url.searchParams.get("view");
      const category = url.searchParams.get("category");

      if (view === "categories") {
        return new Response(JSON.stringify({ success: true, categories: CATEGORIES }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "installed") {
        const { data: installed } = await adminClient.from("app_analytics").select("metadata, created_at").eq("user_id", user.id).eq("source", "plugin_install");

        return new Response(JSON.stringify({
          success: true,
          installed: (installed ?? []).map((i) => ({ ...(i.metadata as Record<string, unknown>), installedAt: i.created_at })),
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      let plugins = [...BUILTIN_PLUGINS];
      if (category) plugins = plugins.filter((p) => p.category === category);

      // Check which are installed by user
      const { data: installed } = await adminClient.from("app_analytics").select("metadata").eq("user_id", user.id).eq("source", "plugin_install");
      const installedIds = new Set((installed ?? []).map((i) => (i.metadata as Record<string, unknown>)?.plugin_id));

      return new Response(JSON.stringify({
        success: true,
        plugins: plugins.map((p) => ({ ...p, installed: installedIds.has(p.id) })),
      }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json();
      const { action } = body;

      if (action === "install") {
        const { plugin_id } = body;
        if (!plugin_id) {
          return new Response(JSON.stringify({ success: false, error: "plugin_id required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }

        const { data: existing } = await adminClient.from("app_analytics").select("metadata").eq("user_id", user.id).eq("source", "plugin_install").eq("metadata->>plugin_id", plugin_id).maybeSingle();
        if (existing) {
          return new Response(JSON.stringify({ success: true, alreadyInstalled: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }

        const plugin = BUILTIN_PLUGINS.find((p) => p.id === plugin_id);
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "plugin_install",
          metadata: { plugin_id, name: plugin?.name ?? plugin_id },
          created_at: new Date().toISOString(),
        });

        return new Response(JSON.stringify({ success: true, installed: true }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "uninstall") {
        const { plugin_id } = body;
        if (!plugin_id) {
          return new Response(JSON.stringify({ success: false, error: "plugin_id required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }

        await adminClient.from("app_analytics").delete().eq("user_id", user.id).eq("source", "plugin_install").eq("metadata->>plugin_id", plugin_id);
        return new Response(JSON.stringify({ success: true, uninstalled: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "review") {
        const { plugin_id, rating, comment } = body;
        if (!plugin_id || !rating) {
          return new Response(JSON.stringify({ success: false, error: "plugin_id and rating required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }

        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "plugin_review",
          metadata: { plugin_id, rating: Math.max(1, Math.min(5, rating)), comment: comment ?? "" },
          created_at: new Date().toISOString(),
        });

        return new Response(JSON.stringify({ success: true, reviewed: true }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return new Response(JSON.stringify({ success: false, error: message }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
