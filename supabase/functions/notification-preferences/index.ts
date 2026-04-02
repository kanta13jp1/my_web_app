// Notification Preferences Edge Function
// 通知設定管理
// - 通知タイプ別のオン/オフ設定
// - メール通知 / プッシュ通知の設定
// - 通知頻度設定 (即時 / 日次ダイジェスト / 週次)
//
// GET  → 通知設定取得
// POST → 通知設定更新

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

// デフォルト通知設定
const DEFAULT_PREFERENCES = {
  feature_update: { enabled: true, email: true, push: true, frequency: "immediate" },
  achievement: { enabled: true, email: false, push: true, frequency: "immediate" },
  cs_reply: { enabled: true, email: true, push: true, frequency: "immediate" },
  system: { enabled: true, email: false, push: true, frequency: "immediate" },
  marketing: { enabled: true, email: true, push: false, frequency: "weekly" },
  blog_published: { enabled: true, email: false, push: false, frequency: "daily" },
  agent_report: { enabled: true, email: false, push: true, frequency: "daily" },
  mention: { enabled: true, email: true, push: true, frequency: "immediate" },
  streak_reminder: { enabled: true, email: false, push: true, frequency: "daily" },
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ success: false, error: "Authorization required" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: { user } } = await userClient.auth.getUser();
    if (!user) {
      return new Response(
        JSON.stringify({ success: false, error: "Unauthorized" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: { persistSession: false },
    });

    if (req.method === "GET") {
      const { data: profile } = await adminClient
        .from("user_profiles")
        .select("metadata")
        .eq("user_id", user.id)
        .maybeSingle();

      const meta = (profile?.metadata as Record<string, unknown>) ?? {};
      const prefs = (meta.notification_preferences as Record<string, unknown>) ?? {};

      // デフォルトとマージ
      const merged = { ...DEFAULT_PREFERENCES };
      for (const [key, value] of Object.entries(prefs)) {
        if (key in merged) {
          (merged as Record<string, unknown>)[key] = { ...(merged as Record<string, Record<string, unknown>>)[key], ...(value as Record<string, unknown>) };
        }
      }

      return new Response(
        JSON.stringify({ success: true, preferences: merged }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      const { preferences } = body;

      if (!preferences || typeof preferences !== "object") {
        return new Response(
          JSON.stringify({ success: false, error: "preferences object required" }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      // 既存メタデータを取得してマージ
      const { data: profile } = await adminClient
        .from("user_profiles")
        .select("metadata")
        .eq("user_id", user.id)
        .maybeSingle();

      const meta = (profile?.metadata as Record<string, unknown>) ?? {};

      const { error } = await adminClient
        .from("user_profiles")
        .update({
          metadata: {
            ...meta,
            notification_preferences: preferences,
          },
        })
        .eq("user_id", user.id);

      if (error) throw error;

      return new Response(
        JSON.stringify({ success: true, updated: true }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    return new Response(
      JSON.stringify({ error: "Method not allowed" }),
      { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error("notification-preferences error:", err);
    return new Response(
      JSON.stringify({ success: false, error: message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
