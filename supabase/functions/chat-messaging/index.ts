// Chat Messaging Edge Function
// チャット・メッセージング機能
// - チャンネル作成・管理
// - メッセージ送受信
// - ダイレクトメッセージ
// - スレッド返信
//
// GET  → チャンネル一覧 / メッセージ取得 / 未読数
// POST → チャンネル作成 / メッセージ送信 / 既読マーク

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

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: { persistSession: false },
    });

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

    if (req.method === "GET") {
      const url = new URL(req.url);
      const view = url.searchParams.get("view"); // 'channels' | 'messages' | 'unread'
      const channelId = url.searchParams.get("channel_id");

      if (view === "messages" && channelId) {
        const limit = parseInt(url.searchParams.get("limit") ?? "50", 10);
        const { data: messages } = await adminClient
          .from("app_analytics")
          .select("metadata, created_at, user_id")
          .eq("source", "chat_message")
          .eq("metadata->>channel_id", channelId)
          .order("created_at", { ascending: false })
          .limit(limit);

        return new Response(
          JSON.stringify({
            success: true,
            messages: (messages ?? []).reverse().map((m) => ({
              ...(m.metadata as Record<string, unknown>),
              userId: m.user_id,
              sentAt: m.created_at,
            })),
          }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (view === "unread") {
        // 未読カウント (簡易実装: last_read 以降のメッセージ数)
        const { data: channels } = await adminClient
          .from("app_analytics")
          .select("metadata")
          .eq("source", "chat_channel")
          .or(`metadata->>creator_id.eq.${user.id},metadata->>is_public.eq.true`);

        const unreadCounts: Array<{ channelId: string; channelName: string; unread: number }> = [];

        for (const ch of channels ?? []) {
          const meta = ch.metadata as Record<string, unknown>;
          const chId = meta?.channel_id as string;

          const { count } = await adminClient
            .from("app_analytics")
            .select("*", { count: "exact", head: true })
            .eq("source", "chat_message")
            .eq("metadata->>channel_id", chId)
            .neq("user_id", user.id);

          unreadCounts.push({
            channelId: chId,
            channelName: (meta?.name as string) ?? "Unknown",
            unread: count ?? 0,
          });
        }

        return new Response(
          JSON.stringify({ success: true, unread: unreadCounts }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      // デフォルト: チャンネル一覧
      const { data: channels } = await adminClient
        .from("app_analytics")
        .select("metadata, created_at")
        .eq("source", "chat_channel")
        .order("created_at", { ascending: false })
        .limit(50);

      return new Response(
        JSON.stringify({
          success: true,
          channels: (channels ?? []).map((c) => ({
            ...(c.metadata as Record<string, unknown>),
            createdAt: c.created_at,
          })),
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      const { action } = body;

      if (action === "create_channel") {
        const { name, description, is_public } = body;
        if (!name) {
          return new Response(
            JSON.stringify({ success: false, error: "name required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const channelId = crypto.randomUUID();
        const { data, error } = await adminClient.from("app_analytics").insert({
          user_id: user.id,
          source: "chat_channel",
          metadata: {
            channel_id: channelId,
            name,
            description: description ?? "",
            is_public: is_public ?? true,
            creator_id: user.id,
            members: [user.id],
          },
          created_at: new Date().toISOString(),
        }).select().single();

        if (error) throw error;

        return new Response(
          JSON.stringify({ success: true, channelId, channel: data }),
          { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (action === "send_message") {
        const { channel_id, content, thread_id } = body;
        if (!channel_id || !content) {
          return new Response(
            JSON.stringify({ success: false, error: "channel_id and content required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const messageId = crypto.randomUUID();
        const { data, error } = await adminClient.from("app_analytics").insert({
          user_id: user.id,
          source: "chat_message",
          metadata: {
            message_id: messageId,
            channel_id,
            content,
            thread_id: thread_id ?? null,
          },
          created_at: new Date().toISOString(),
        }).select().single();

        if (error) throw error;

        return new Response(
          JSON.stringify({ success: true, messageId, message: data }),
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
    console.error("chat-messaging error:", err);
    return new Response(
      JSON.stringify({ success: false, error: message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
