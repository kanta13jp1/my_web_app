// Team Collaboration Sync Edge Function
// チーム協業・通知ブリッジ
// - エージェント間のタスク更新通知
// - 共有メモアクティビティフィード
// - メンション・リアクション通知
// - 外部サービス (Slack/Discord) 通知ブリッジ
//
// GET  → アクティビティフィード / 通知設定
// POST → 通知送信 / メンション / 設定更新

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

// アクティビティタイプ
const ACTIVITY_TYPES = [
  "task_assigned", "task_completed", "task_comment",
  "memo_shared", "memo_reaction", "memo_comment",
  "agent_message", "department_update",
  "mention", "achievement_unlocked",
] as const;

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: { persistSession: false },
    });

    if (req.method === "GET") {
      const url = new URL(req.url);
      const view = url.searchParams.get("view"); // 'feed' | 'mentions' | 'settings'
      const limit = parseInt(url.searchParams.get("limit") ?? "30", 10);

      if (view === "feed") {
        // アクティビティフィード
        const { data: activities } = await adminClient
          .from("app_analytics")
          .select("metadata, created_at, user_id")
          .in("source", ACTIVITY_TYPES as unknown as string[])
          .order("created_at", { ascending: false })
          .limit(limit);

        return new Response(
          JSON.stringify({
            success: true,
            feed: (activities ?? []).map((a) => ({
              type: (a.metadata as Record<string, unknown>)?.type ?? "unknown",
              ...(a.metadata as Record<string, unknown>),
              userId: a.user_id,
              createdAt: a.created_at,
            })),
          }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (view === "mentions") {
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

        const { data: mentions } = await adminClient
          .from("app_analytics")
          .select("metadata, created_at")
          .eq("source", "mention")
          .eq("metadata->>mentioned_user_id", user.id)
          .order("created_at", { ascending: false })
          .limit(20);

        return new Response(
          JSON.stringify({ success: true, mentions: mentions ?? [] }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      // デフォルト: サマリー
      const now = new Date();
      const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate()).toISOString();

      const { data: todayActivities } = await adminClient
        .from("app_analytics")
        .select("source", { count: "exact" })
        .in("source", ACTIVITY_TYPES as unknown as string[])
        .gte("created_at", todayStart);

      return new Response(
        JSON.stringify({
          success: true,
          summary: {
            todayActivities: (todayActivities ?? []).length,
            activityTypes: ACTIVITY_TYPES,
          },
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      const { action } = body;

      if (action === "post_activity") {
        const { type, message, target_user_id, agent_id, metadata: extraMeta } = body;

        if (!type || !message) {
          return new Response(
            JSON.stringify({ success: false, error: "type and message are required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        let userId = null;
        const authHeader = req.headers.get("Authorization");
        if (authHeader) {
          const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
            global: { headers: { Authorization: authHeader } },
          });
          const { data: { user } } = await userClient.auth.getUser();
          if (user) userId = user.id;
        }

        const { data, error } = await adminClient
          .from("app_analytics")
          .insert({
            user_id: userId,
            source: type,
            metadata: {
              type,
              message,
              target_user_id: target_user_id ?? null,
              agent_id: agent_id ?? null,
              ...(extraMeta ?? {}),
            },
            created_at: new Date().toISOString(),
          })
          .select()
          .single();

        if (error) throw error;

        // メンションの場合、通知を作成
        if (type === "mention" && target_user_id) {
          await adminClient.from("app_notifications").insert({
            user_id: target_user_id,
            type: "system",
            title: "メンションされました",
            body: message,
            is_read: false,
            created_at: new Date().toISOString(),
          });
        }

        return new Response(
          JSON.stringify({ success: true, activity: data }),
          { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      return new Response(
        JSON.stringify({ success: false, error: "Unknown action" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    return new Response(
      JSON.stringify({ error: "Method not allowed" }),
      { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error("team-collaboration-sync error:", err);
    return new Response(
      JSON.stringify({ success: false, error: message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
