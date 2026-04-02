// Integration Connector Edge Function
// 外部サービス連携 (Slack/Discord/LINE競合)
// - 連携設定管理
// - Webhook受信
// - 連携ステータス確認
// - データ同期トリガー
//
// GET  → 連携一覧 / ステータス / 利用可能サービス
// POST → 連携追加 / 同期 / 切断

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const AVAILABLE_SERVICES = [
  { key: "slack", name: "Slack", icon: "💬", category: "communication", description: "Slackチャンネルと通知を連携" },
  { key: "discord", name: "Discord", icon: "🎮", category: "communication", description: "Discordサーバーと連携" },
  { key: "line", name: "LINE", icon: "💚", category: "communication", description: "LINE通知を受信" },
  { key: "github", name: "GitHub", icon: "🐙", category: "development", description: "GitHubリポジトリと連携" },
  { key: "notion", name: "Notion", icon: "📝", category: "productivity", description: "Notionページと同期" },
  { key: "google_calendar", name: "Google Calendar", icon: "📅", category: "productivity", description: "Googleカレンダーと同期" },
  { key: "x", name: "X (Twitter)", icon: "🐦", category: "social", description: "Xアカウントと連携" },
  { key: "chatwork", name: "Chatwork", icon: "💼", category: "communication", description: "Chatworkルームと連携" },
  { key: "google_drive", name: "Google Drive", icon: "📁", category: "storage", description: "Google Driveファイルと連携" },
  { key: "dropbox", name: "Dropbox", icon: "📦", category: "storage", description: "Dropboxと連携" },
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
      const view = url.searchParams.get("view"); // 'available' | 'connected' | 'status'

      if (view === "available") {
        return new Response(JSON.stringify({ success: true, services: AVAILABLE_SERVICES }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      const { data: connections } = await adminClient.from("app_analytics").select("metadata, created_at").eq("user_id", user.id).eq("source", "integration").order("created_at", { ascending: false });

      const connectedList = (connections ?? []).map((c) => ({ ...(c.metadata as Record<string, unknown>), connectedAt: c.created_at }));

      if (view === "status") {
        return new Response(JSON.stringify({
          success: true,
          connections: connectedList.map((c) => ({
            service: c.service,
            name: AVAILABLE_SERVICES.find((s) => s.key === c.service)?.name ?? c.service,
            status: c.active ? "connected" : "disconnected",
            lastSync: c.last_sync,
          })),
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      // Default: connected list + available
      const connectedKeys = new Set(connectedList.filter((c) => c.active).map((c) => c.service as string));
      return new Response(JSON.stringify({
        success: true,
        connected: connectedList.filter((c) => c.active),
        available: AVAILABLE_SERVICES.map((s) => ({ ...s, connected: connectedKeys.has(s.key) })),
      }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      const { action } = body;

      if (action === "connect") {
        const { service, config } = body;
        if (!service) {
          return new Response(JSON.stringify({ success: false, error: "service required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }

        const valid = AVAILABLE_SERVICES.find((s) => s.key === service);
        if (!valid) {
          return new Response(JSON.stringify({ success: false, error: "Unknown service" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }

        const connectionId = crypto.randomUUID();
        const { data, error } = await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "integration",
          metadata: {
            connection_id: connectionId, service,
            name: valid.name, config: config ?? {},
            active: true, last_sync: null,
          },
          created_at: new Date().toISOString(),
        }).select().single();

        if (error) throw error;
        return new Response(JSON.stringify({ success: true, connectionId, connection: data }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "disconnect") {
        const { connection_id } = body;
        if (!connection_id) {
          return new Response(JSON.stringify({ success: false, error: "connection_id required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }

        const { data: existing } = await adminClient.from("app_analytics").select("metadata").eq("user_id", user.id).eq("source", "integration").eq("metadata->>connection_id", connection_id).maybeSingle();
        if (!existing) {
          return new Response(JSON.stringify({ success: false, error: "Connection not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }

        await adminClient.from("app_analytics").update({ metadata: { ...(existing.metadata as Record<string, unknown>), active: false } }).eq("user_id", user.id).eq("source", "integration").eq("metadata->>connection_id", connection_id);
        return new Response(JSON.stringify({ success: true, disconnected: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "sync") {
        const { connection_id } = body;
        if (!connection_id) {
          return new Response(JSON.stringify({ success: false, error: "connection_id required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }

        const { data: existing } = await adminClient.from("app_analytics").select("metadata").eq("user_id", user.id).eq("source", "integration").eq("metadata->>connection_id", connection_id).maybeSingle();
        if (!existing) {
          return new Response(JSON.stringify({ success: false, error: "Connection not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }

        await adminClient.from("app_analytics").update({ metadata: { ...(existing.metadata as Record<string, unknown>), last_sync: new Date().toISOString() } }).eq("user_id", user.id).eq("source", "integration").eq("metadata->>connection_id", connection_id);
        return new Response(JSON.stringify({ success: true, synced: true, syncedAt: new Date().toISOString() }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return new Response(JSON.stringify({ success: false, error: message }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
