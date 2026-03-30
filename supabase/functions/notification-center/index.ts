// Notification Center Edge Function
// 通知センター — アプリ内通知の管理
// - 新機能通知 / CS チケット更新 / 開発実績 / システム通知
// - 既読管理 / 通知設定
//
// GET  → 通知一覧 (未読/既読/全件)
// POST → 通知作成 / 既読マーク / 設定更新

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

// 通知カテゴリ
const NOTIFICATION_TYPES = [
  "feature_update",   // 新機能
  "achievement",      // 開発実績
  "cs_reply",         // CS 返信
  "system",           // システム通知
  "marketing",        // マーケティング
  "blog_published",   // ブログ投稿
  "agent_report",     // エージェント報告
] as const;

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    if (req.method === "GET") {
      const url = new URL(req.url);
      const mode = url.searchParams.get("mode"); // 'user' | 'admin'
      const filter = url.searchParams.get("filter"); // 'unread' | 'read' | 'all'
      const limit = parseInt(url.searchParams.get("limit") ?? "30", 10);

      if (mode === "admin") {
        // 管理者: 全通知 (service_role)
        const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
          auth: { persistSession: false },
        });

        const { data, error, count } = await adminClient
          .from("app_notifications")
          .select("*", { count: "exact" })
          .order("created_at", { ascending: false })
          .limit(limit);

        if (error) throw error;

        return new Response(
          JSON.stringify({
            success: true,
            notifications: data ?? [],
            total: count ?? 0,
            types: NOTIFICATION_TYPES,
          }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      // ユーザー自身の通知
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

      let query = adminClient
        .from("app_notifications")
        .select("*")
        .or(`user_id.eq.${user.id},user_id.is.null`) // ユーザー向け or 全体通知
        .order("created_at", { ascending: false })
        .limit(limit);

      if (filter === "unread") query = query.eq("is_read", false);
      if (filter === "read") query = query.eq("is_read", true);

      const { data, error } = await query;
      if (error) throw error;

      // 未読数
      const { count: unreadCount } = await adminClient
        .from("app_notifications")
        .select("*", { count: "exact", head: true })
        .or(`user_id.eq.${user.id},user_id.is.null`)
        .eq("is_read", false);

      return new Response(
        JSON.stringify({
          success: true,
          notifications: data ?? [],
          unreadCount: unreadCount ?? 0,
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    if (req.method === "POST") {
      const body = await req.json();
      const { action } = body;

      if (action === "create") {
        // service_role のみ通知作成を許可
        const authHeader = req.headers.get("Authorization");
        const token = authHeader?.replace("Bearer ", "") ?? "";
        if (token !== SERVICE_ROLE_KEY) {
          return new Response(
            JSON.stringify({ success: false, error: "Service role required" }),
            { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        // 通知を作成 (service_role)
        const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
          auth: { persistSession: false },
        });

        const { title, message, type, user_id, link } = body;

        if (!title || !message) {
          return new Response(
            JSON.stringify({ success: false, error: "title and message are required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const { data, error } = await adminClient
          .from("app_notifications")
          .insert({
            title,
            message,
            type: type ?? "system",
            user_id: user_id ?? null, // null = 全員向け
            link: link ?? null,
            is_read: false,
            created_at: new Date().toISOString(),
          })
          .select()
          .single();

        if (error) throw error;

        return new Response(
          JSON.stringify({ success: true, notification: data }),
          { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (action === "mark_read") {
        // 既読マーク
        const authHeader = req.headers.get("Authorization");
        if (!authHeader) {
          return new Response(
            JSON.stringify({ success: false, error: "Authorization required" }),
            { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
          auth: { persistSession: false },
        });

        const { notification_id, mark_all } = body;

        if (mark_all) {
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

          const { error } = await adminClient
            .from("app_notifications")
            .update({ is_read: true })
            .or(`user_id.eq.${user.id},user_id.is.null`)
            .eq("is_read", false);

          if (error) throw error;

          return new Response(
            JSON.stringify({ success: true, message: "全通知を既読にしました" }),
            { headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        if (!notification_id) {
          return new Response(
            JSON.stringify({ success: false, error: "notification_id or mark_all is required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        // 所有者確認: 自分の通知のみ既読にできる
        const userClientSingle = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
          global: { headers: { Authorization: authHeader } },
        });
        const { data: { user: singleUser } } = await userClientSingle.auth.getUser();
        if (!singleUser) {
          return new Response(
            JSON.stringify({ success: false, error: "Unauthorized" }),
            { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const { error } = await adminClient
          .from("app_notifications")
          .update({ is_read: true })
          .eq("id", notification_id)
          .eq("user_id", singleUser.id);

        if (error) throw error;

        return new Response(
          JSON.stringify({ success: true }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
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
    console.error("notification-center error:", err);
    return new Response(
      JSON.stringify({ success: false, error: message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
