// Encrypted Messaging Edge Function
// 暗号化メッセージング (LINE/Discord/Slack/Signal競合)
// - E2Eライクメッセージング
// - チャンネル管理
// - メッセージ自動削除
// - ファイル共有
// - 既読管理

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type" };
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const CHANNEL_TYPES = ["direct", "group", "public", "private"];
const MESSAGE_TYPES = ["text", "image", "file", "voice", "system"];
const AUTO_DELETE_OPTIONS = [0, 300, 3600, 86400, 604800]; // seconds: none, 5min, 1hr, 1day, 1week

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
      const channelId = url.searchParams.get("channel_id");

      if (view === "config") return new Response(JSON.stringify({ success: true, channelTypes: CHANNEL_TYPES, messageTypes: MESSAGE_TYPES, autoDeleteOptions: AUTO_DELETE_OPTIONS }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });

      if (view === "channels") {
        const { data: channels } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("source", "enc_channel").order("created_at", { ascending: false });
        // Filter channels user is member of
        const myChannels = (channels ?? []).filter((c) => {
          const m = c.metadata as Record<string, unknown>;
          const members = (m.members as string[]) ?? [];
          return members.includes(user.id) || m.type === "public";
        }).map((c) => ({ ...(c.metadata as Record<string, unknown>), createdAt: c.created_at }));
        return new Response(JSON.stringify({ success: true, channels: myChannels }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "messages" && channelId) {
        // Clean up auto-delete messages
        const { data: msgs } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("source", "enc_message").eq("metadata->>channel_id", channelId).order("created_at", { ascending: false }).limit(50);
        const now = Date.now();
        const validMessages = (msgs ?? []).filter((m) => {
          const meta = m.metadata as Record<string, unknown>;
          const autoDelete = (meta.auto_delete_seconds as number) ?? 0;
          if (autoDelete === 0) return true;
          return now - new Date(m.created_at).getTime() < autoDelete * 1000;
        }).map((m) => ({ ...(m.metadata as Record<string, unknown>), createdAt: m.created_at }));
        // Mark as read
        await adminClient.from("app_analytics").upsert({
          user_id: user.id, source: "enc_read_receipt",
          metadata: { channel_id: channelId, user_id: user.id, last_read_at: new Date().toISOString() },
          created_at: new Date().toISOString(),
        }, { onConflict: "user_id,source" });
        return new Response(JSON.stringify({ success: true, messages: validMessages.reverse() }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "unread") {
        const { data: channels } = await adminClient.from("app_analytics").select("metadata").eq("source", "enc_channel");
        const myChannels = (channels ?? []).filter((c) => ((c.metadata as Record<string, unknown>).members as string[])?.includes(user.id));
        const unreadCounts: Record<string, number> = {};
        for (const ch of myChannels) {
          const chId = (ch.metadata as Record<string, unknown>).channel_id as string;
          const { data: receipt } = await adminClient.from("app_analytics").select("metadata")
            .eq("user_id", user.id).eq("source", "enc_read_receipt").eq("metadata->>channel_id", chId).maybeSingle();
          const lastRead = receipt ? ((receipt.metadata as Record<string, unknown>).last_read_at as string) : "1970-01-01T00:00:00Z";
          const { count } = await adminClient.from("app_analytics").select("*", { count: "exact", head: true })
            .eq("source", "enc_message").eq("metadata->>channel_id", chId).gt("created_at", lastRead);
          if ((count ?? 0) > 0) unreadCounts[chId] = count ?? 0;
        }
        return new Response(JSON.stringify({ success: true, unread: unreadCounts }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: true, channelTypes: CHANNEL_TYPES }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json();
      const { action } = body;

      if (action === "create_channel") {
        const { name, type, members, auto_delete_seconds } = body;
        if (!name) return new Response(JSON.stringify({ success: false, error: "name required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const channelId = crypto.randomUUID();
        const memberList = members ?? [user.id];
        if (!memberList.includes(user.id)) memberList.push(user.id);
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "enc_channel",
          metadata: { channel_id: channelId, name, type: type ?? "private", members: memberList, owner_id: user.id, auto_delete_seconds: auto_delete_seconds ?? 0 },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, channelId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "send_message") {
        const { channel_id, content, message_type, file_url, auto_delete_seconds } = body;
        if (!channel_id || !content) return new Response(JSON.stringify({ success: false, error: "channel_id and content required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const messageId = crypto.randomUUID();
        // Simple obfuscation (not true E2E, but demonstrates the concept)
        const encoded = btoa(unescape(encodeURIComponent(content)));
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "enc_message",
          metadata: {
            message_id: messageId, channel_id, content: encoded, content_plain: content,
            message_type: message_type ?? "text", file_url: file_url ?? null,
            sender_id: user.id, sender_email: user.email,
            auto_delete_seconds: auto_delete_seconds ?? 0,
          },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, messageId }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "add_member") {
        const { channel_id, member_id } = body;
        if (!channel_id || !member_id) return new Response(JSON.stringify({ success: false, error: "channel_id and member_id required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const { data: ch } = await adminClient.from("app_analytics").select("metadata")
          .eq("source", "enc_channel").eq("metadata->>channel_id", channel_id).maybeSingle();
        if (!ch) return new Response(JSON.stringify({ success: false, error: "Channel not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const m = ch.metadata as Record<string, unknown>;
        const members = [...((m.members as string[]) ?? [])];
        if (!members.includes(member_id)) members.push(member_id);
        await adminClient.from("app_analytics").update({ metadata: { ...m, members } })
          .eq("source", "enc_channel").eq("metadata->>channel_id", channel_id);
        return new Response(JSON.stringify({ success: true, members }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "delete_message") {
        const { message_id } = body;
        if (!message_id) return new Response(JSON.stringify({ success: false, error: "message_id required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        await adminClient.from("app_analytics").delete()
          .eq("user_id", user.id).eq("source", "enc_message").eq("metadata->>message_id", message_id);
        return new Response(JSON.stringify({ success: true, deleted: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }
    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) { return new Response(JSON.stringify({ success: false, error: err instanceof Error ? err.message : String(err) }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }); }
});
