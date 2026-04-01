// Live Streaming Edge Function
// ライブストリーミング (YouTube/Discord/Facebook Live競合)
// - 配信管理
// - チャット
// - 視聴者分析
// - アーカイブ
// - スケジュール配信

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type" };
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const STREAM_STATUSES = ["scheduled", "live", "ended", "archived"];
const STREAM_CATEGORIES = ["tech", "gaming", "education", "music", "talk", "coding", "news", "other"];
const CHAT_TYPES = ["message", "donation", "system", "mod_action"];

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
      const streamId = url.searchParams.get("stream_id");

      if (view === "categories") return new Response(JSON.stringify({ success: true, categories: STREAM_CATEGORIES, statuses: STREAM_STATUSES }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });

      if (view === "live_now") {
        const { data: streams } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("source", "live_stream").eq("metadata->>status", "live").order("created_at", { ascending: false });
        return new Response(JSON.stringify({ success: true, streams: (streams ?? []).map((s) => ({ ...(s.metadata as Record<string, unknown>), createdAt: s.created_at })) }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "stream" && streamId) {
        const { data: stream } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("source", "live_stream").eq("metadata->>stream_id", streamId).maybeSingle();
        if (!stream) return new Response(JSON.stringify({ success: false, error: "Stream not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        // Get chat messages
        const { data: chats } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("source", "stream_chat").eq("metadata->>stream_id", streamId).order("created_at", { ascending: true }).limit(100);
        // Get viewer count
        const { count: viewerCount } = await adminClient.from("app_analytics").select("*", { count: "exact", head: true })
          .eq("source", "stream_view").eq("metadata->>stream_id", streamId);
        return new Response(JSON.stringify({
          success: true,
          stream: { ...(stream.metadata as Record<string, unknown>), createdAt: stream.created_at },
          chat: (chats ?? []).map((c) => ({ ...(c.metadata as Record<string, unknown>), createdAt: c.created_at })),
          viewerCount: viewerCount ?? 0,
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "my_streams") {
        const { data: streams } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "live_stream").order("created_at", { ascending: false }).limit(20);
        return new Response(JSON.stringify({ success: true, streams: (streams ?? []).map((s) => ({ ...(s.metadata as Record<string, unknown>), createdAt: s.created_at })) }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "analytics" && streamId) {
        const { data: views } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("source", "stream_view").eq("metadata->>stream_id", streamId);
        const uniqueViewers = new Set((views ?? []).map((v) => (v.metadata as Record<string, unknown>).user_id as string)).size;
        const { count: chatCount } = await adminClient.from("app_analytics").select("*", { count: "exact", head: true })
          .eq("source", "stream_chat").eq("metadata->>stream_id", streamId);
        return new Response(JSON.stringify({ success: true, analytics: { totalViews: (views ?? []).length, uniqueViewers, chatMessages: chatCount ?? 0 } }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      // Default: all recent streams
      const { data: streams } = await adminClient.from("app_analytics").select("metadata, created_at")
        .eq("source", "live_stream").order("created_at", { ascending: false }).limit(20);
      return new Response(JSON.stringify({ success: true, streams: (streams ?? []).map((s) => ({ ...(s.metadata as Record<string, unknown>), createdAt: s.created_at })) }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json();
      const { action } = body;

      if (action === "create_stream") {
        const { title, category, description, scheduled_at } = body;
        if (!title) return new Response(JSON.stringify({ success: false, error: "title required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const streamId = crypto.randomUUID();
        const streamKey = crypto.randomUUID().replace(/-/g, "").slice(0, 16);
        const status = scheduled_at ? "scheduled" : "live";
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "live_stream",
          metadata: { stream_id: streamId, title, category: category ?? "other", description: description ?? "", status, stream_key: streamKey, scheduled_at: scheduled_at ?? null, started_at: status === "live" ? new Date().toISOString() : null, ended_at: null },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, streamId, streamKey, status }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "end_stream") {
        const { stream_id } = body;
        if (!stream_id) return new Response(JSON.stringify({ success: false, error: "stream_id required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const { data: existing } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "live_stream").eq("metadata->>stream_id", stream_id).maybeSingle();
        if (!existing) return new Response(JSON.stringify({ success: false, error: "Stream not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        await adminClient.from("app_analytics").update({ metadata: { ...(existing.metadata as Record<string, unknown>), status: "ended", ended_at: new Date().toISOString() } })
          .eq("user_id", user.id).eq("source", "live_stream").eq("metadata->>stream_id", stream_id);
        return new Response(JSON.stringify({ success: true, ended: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "send_chat") {
        const { stream_id, message, chat_type } = body;
        if (!stream_id || !message) return new Response(JSON.stringify({ success: false, error: "stream_id and message required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const chatId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "stream_chat",
          metadata: { chat_id: chatId, stream_id, message, chat_type: chat_type ?? "message", user_email: user.email },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, chatId }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "record_view") {
        const { stream_id } = body;
        if (!stream_id) return new Response(JSON.stringify({ success: false, error: "stream_id required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "stream_view",
          metadata: { stream_id, user_id: user.id, viewed_at: new Date().toISOString() },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }
    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) { return new Response(JSON.stringify({ success: false, error: err instanceof Error ? err.message : String(err) }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }); }
});
