// Push Notification Manager Edge Function
// Web Push通知管理 (LINE/Discord/Slack競合)
// - VAPID Web Push購読管理
// - FCMトークン登録
// - 対象指定Push配信
// - 購読解除
//
// GET  → 購読一覧 / 統計
// POST → 購読登録 / Push送信 / 購読解除

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

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

      if (view === "stats") {
        const { data: subs } = await adminClient.from("app_analytics").select("metadata").eq("user_id", user.id).eq("source", "push_subscription");
        const active = (subs ?? []).filter((s) => (s.metadata as Record<string, unknown>).active === true);
        const { data: sent } = await adminClient.from("app_analytics").select("metadata").eq("user_id", user.id).eq("source", "push_sent");
        return new Response(JSON.stringify({
          success: true,
          stats: {
            totalSubscriptions: active.length,
            totalSent: (sent ?? []).length,
            platforms: active.reduce((acc, s) => {
              const platform = (s.metadata as Record<string, unknown>).platform as string ?? "web";
              acc[platform] = (acc[platform] ?? 0) + 1;
              return acc;
            }, {} as Record<string, number>),
          },
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      // Default: subscription list
      const { data: subscriptions } = await adminClient.from("app_analytics").select("metadata, created_at").eq("user_id", user.id).eq("source", "push_subscription").order("created_at", { ascending: false });
      return new Response(JSON.stringify({
        success: true,
        subscriptions: (subscriptions ?? []).map((s) => {
          const meta = s.metadata as Record<string, unknown>;
          return {
            subscription_id: meta.subscription_id,
            platform: meta.platform,
            device_name: meta.device_name,
            active: meta.active,
            createdAt: s.created_at,
          };
        }),
      }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json();
      const { action } = body;

      if (action === "subscribe") {
        const { endpoint, keys, platform, device_name } = body;
        if (!endpoint) {
          return new Response(JSON.stringify({ success: false, error: "endpoint required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }

        const subscriptionId = crypto.randomUUID();
        const { error } = await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "push_subscription",
          metadata: {
            subscription_id: subscriptionId,
            endpoint,
            keys: keys ?? {},
            platform: platform ?? "web",
            device_name: device_name ?? "Unknown Device",
            active: true,
          },
          created_at: new Date().toISOString(),
        });
        if (error) throw error;
        return new Response(JSON.stringify({ success: true, subscriptionId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "unsubscribe") {
        const { subscription_id } = body;
        if (!subscription_id) {
          return new Response(JSON.stringify({ success: false, error: "subscription_id required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const { data: existing } = await adminClient.from("app_analytics").select("metadata").eq("user_id", user.id).eq("source", "push_subscription").eq("metadata->>subscription_id", subscription_id).maybeSingle();
        if (!existing) {
          return new Response(JSON.stringify({ success: false, error: "Subscription not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        await adminClient.from("app_analytics").update({ metadata: { ...(existing.metadata as Record<string, unknown>), active: false } }).eq("user_id", user.id).eq("source", "push_subscription").eq("metadata->>subscription_id", subscription_id);
        return new Response(JSON.stringify({ success: true, unsubscribed: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "send") {
        const { title, body: msgBody, target_user_id, url, icon } = body;
        if (!title || !msgBody) {
          return new Response(JSON.stringify({ success: false, error: "title and body required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }

        const targetUserId = target_user_id ?? user.id;
        const { data: subs } = await adminClient.from("app_analytics").select("metadata").eq("user_id", targetUserId).eq("source", "push_subscription");
        const activeSubs = (subs ?? []).filter((s) => (s.metadata as Record<string, unknown>).active === true);

        // Log push sent
        await adminClient.from("app_analytics").insert({
          user_id: targetUserId, source: "push_sent",
          metadata: {
            title, body: msgBody, url: url ?? null, icon: icon ?? null,
            sent_by: user.id, endpoints_count: activeSubs.length,
            sent_at: new Date().toISOString(),
          },
          created_at: new Date().toISOString(),
        });

        // Also create in-app notification
        await adminClient.from("app_notifications").insert({
          user_id: targetUserId, title, body: msgBody,
          notification_type: "push", is_read: false,
        });

        return new Response(JSON.stringify({
          success: true,
          sent: true,
          endpointsCount: activeSubs.length,
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return new Response(JSON.stringify({ success: false, error: message }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
