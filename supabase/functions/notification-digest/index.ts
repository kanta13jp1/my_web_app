// Notification Digest Edge Function
// 通知ダイジェスト (Slack/Discord競合)
// - 通知集約
// - ダイジェスト配信スケジュール
// - 優先度フィルタ
// - チャネル別設定
// - 既読管理

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const NOTIFICATION_CATEGORIES = ["system", "social", "task", "calendar", "finance", "security", "marketing", "support"];
const DELIVERY_CHANNELS = ["in_app", "email", "push", "sms", "slack", "discord"];
const DIGEST_FREQUENCIES = ["realtime", "hourly", "daily", "weekly"];

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

      if (view === "categories") return new Response(JSON.stringify({ success: true, categories: NOTIFICATION_CATEGORIES, channels: DELIVERY_CHANNELS, frequencies: DIGEST_FREQUENCIES }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });

      if (view === "unread") {
        const { data: notifications } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "notification_item").eq("metadata->>read", "false")
          .order("created_at", { ascending: false }).limit(50);
        return new Response(JSON.stringify({
          success: true, count: (notifications ?? []).length,
          notifications: (notifications ?? []).map((n) => ({ ...(n.metadata as Record<string, unknown>), createdAt: n.created_at })),
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "digest") {
        const since = url.searchParams.get("since") ?? new Date(Date.now() - 86400000).toISOString();
        const { data: notifications } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "notification_item").gte("created_at", since)
          .order("created_at", { ascending: false });
        // Group by category
        const grouped: Record<string, Array<Record<string, unknown>>> = {};
        for (const n of notifications ?? []) {
          const m = n.metadata as Record<string, unknown>;
          const cat = (m.category as string) ?? "system";
          if (!grouped[cat]) grouped[cat] = [];
          grouped[cat].push({ ...m, createdAt: n.created_at });
        }
        return new Response(JSON.stringify({ success: true, digest: grouped, totalCount: (notifications ?? []).length }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "preferences") {
        const { data: prefs } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "notification_digest_prefs").maybeSingle();
        return new Response(JSON.stringify({
          success: true,
          preferences: prefs ? prefs.metadata as Record<string, unknown> : {
            frequency: "daily", channels: ["in_app", "email"],
            muted_categories: [], quiet_hours: { start: "22:00", end: "08:00" },
          },
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "stats") {
        const { data: all } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "notification_item");
        const unread = (all ?? []).filter((n) => !(n.metadata as Record<string, unknown>).read).length;
        const catCount: Record<string, number> = {};
        for (const n of all ?? []) {
          const c = ((n.metadata as Record<string, unknown>).category as string) ?? "system";
          catCount[c] = (catCount[c] ?? 0) + 1;
        }
        return new Response(JSON.stringify({
          success: true, stats: { total: (all ?? []).length, unread, categoryBreakdown: catCount },
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      // Default: recent notifications
      const { data: notifications } = await adminClient.from("app_analytics").select("metadata, created_at")
        .eq("user_id", user.id).eq("source", "notification_item")
        .order("created_at", { ascending: false }).limit(30);
      return new Response(JSON.stringify({ success: true, notifications: (notifications ?? []).map((n) => ({ ...(n.metadata as Record<string, unknown>), createdAt: n.created_at })) }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      const { action } = body;

      if (action === "send") {
        const { title, message, category, priority, target_user_id } = body;
        if (!title || !message) return new Response(JSON.stringify({ success: false, error: "title and message required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const nId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: target_user_id ?? user.id, source: "notification_item",
          metadata: {
            notification_id: nId, title, message, category: category ?? "system",
            priority: priority ?? "normal", read: false, sender_id: user.id,
          },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, notificationId: nId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "mark_read") {
        const { notification_ids } = body;
        if (!notification_ids || !Array.isArray(notification_ids)) return new Response(JSON.stringify({ success: false, error: "notification_ids array required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        for (const nId of notification_ids) {
          const { data: existing } = await adminClient.from("app_analytics").select("metadata")
            .eq("user_id", user.id).eq("source", "notification_item").eq("metadata->>notification_id", nId).maybeSingle();
          if (existing) {
            await adminClient.from("app_analytics").update({
              metadata: { ...(existing.metadata as Record<string, unknown>), read: true, read_at: new Date().toISOString() },
            }).eq("user_id", user.id).eq("source", "notification_item").eq("metadata->>notification_id", nId);
          }
        }
        return new Response(JSON.stringify({ success: true, marked: notification_ids.length }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "mark_all_read") {
        const { data: unread } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "notification_item").eq("metadata->>read", "false");
        let count = 0;
        for (const n of unread ?? []) {
          const m = n.metadata as Record<string, unknown>;
          await adminClient.from("app_analytics").update({
            metadata: { ...m, read: true, read_at: new Date().toISOString() },
          }).eq("user_id", user.id).eq("source", "notification_item").eq("metadata->>notification_id", m.notification_id);
          count++;
        }
        return new Response(JSON.stringify({ success: true, marked: count }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "update_preferences") {
        const { frequency, channels, muted_categories, quiet_hours } = body;
        await adminClient.from("app_analytics").delete()
          .eq("user_id", user.id).eq("source", "notification_digest_prefs");
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "notification_digest_prefs",
          metadata: {
            frequency: frequency ?? "daily", channels: channels ?? ["in_app"],
            muted_categories: muted_categories ?? [],
            quiet_hours: quiet_hours ?? { start: "22:00", end: "08:00" },
          },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, updated: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    return new Response(JSON.stringify({ success: false, error: err instanceof Error ? err.message : String(err) }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
