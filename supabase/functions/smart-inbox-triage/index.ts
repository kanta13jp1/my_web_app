// Smart Inbox Triage Edge Function
// スマート受信トレイ (Gmail/Slack/LINE/Chatwork統合)
// - マルチチャネル統合受信箱
// - AI優先度分類
// - 自動ラベル付け
// - スヌーズ・リマインダー
// - レスポンス統計
//
// GET  → 受信箱 / 優先度別 / ラベル / スヌーズ / 統計
// POST → メッセージ追加 / 優先度変更 / ラベル付け / スヌーズ / アーカイブ

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const CHANNELS = ["email", "slack", "line", "chatwork", "discord", "x", "facebook", "internal"];
const PRIORITIES = ["urgent", "high", "normal", "low"];
const DEFAULT_LABELS = ["仕事", "個人", "請求", "サポート", "ニュースレター", "重要", "後で読む"];

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

      if (view === "options") {
        return new Response(JSON.stringify({ success: true, channels: CHANNELS, priorities: PRIORITIES, defaultLabels: DEFAULT_LABELS }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "priority") {
        const priority = url.searchParams.get("priority") ?? "urgent";
        const { data: msgs } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "inbox_message").eq("metadata->>priority", priority).eq("metadata->>is_archived", "false")
          .order("created_at", { ascending: false }).limit(50);
        return new Response(JSON.stringify({
          success: true,
          messages: (msgs ?? []).map((m) => ({ ...(m.metadata as Record<string, unknown>), receivedAt: m.created_at })),
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "label") {
        const label = url.searchParams.get("label");
        if (!label) {
          return new Response(JSON.stringify({ success: false, error: "label required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const { data: msgs } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "inbox_message")
          .order("created_at", { ascending: false }).limit(50);
        const filtered = (msgs ?? []).filter((m) => {
          const labels = ((m.metadata as Record<string, unknown>).labels as string[]) ?? [];
          return labels.includes(label);
        });
        return new Response(JSON.stringify({
          success: true,
          messages: filtered.map((m) => ({ ...(m.metadata as Record<string, unknown>), receivedAt: m.created_at })),
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "snoozed") {
        const _now = new Date().toISOString();
        const { data: msgs } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "inbox_message").eq("metadata->>is_snoozed", "true")
          .order("metadata->>snooze_until", { ascending: true });
        return new Response(JSON.stringify({
          success: true,
          snoozed: (msgs ?? []).map((m) => ({ ...(m.metadata as Record<string, unknown>), receivedAt: m.created_at })),
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "stats") {
        const { data: msgs } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "inbox_message");
        const channelCounts: Record<string, number> = {};
        const priorityCounts: Record<string, number> = {};
        let unread = 0;
        for (const m of msgs ?? []) {
          const meta = m.metadata as Record<string, unknown>;
          const ch = (meta.channel as string) ?? "internal";
          const pr = (meta.priority as string) ?? "normal";
          channelCounts[ch] = (channelCounts[ch] ?? 0) + 1;
          priorityCounts[pr] = (priorityCounts[pr] ?? 0) + 1;
          if (!meta.is_read) unread++;
        }
        return new Response(JSON.stringify({
          success: true,
          stats: { total: (msgs ?? []).length, unread, channelCounts, priorityCounts },
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      // Default: inbox (unarchived)
      const channel = url.searchParams.get("channel");
      let query = adminClient.from("app_analytics").select("metadata, created_at")
        .eq("user_id", user.id).eq("source", "inbox_message").eq("metadata->>is_archived", "false")
        .order("created_at", { ascending: false });
      if (channel) query = query.eq("metadata->>channel", channel);
      const { data: msgs } = await query.limit(50);
      return new Response(JSON.stringify({
        success: true,
        messages: (msgs ?? []).map((m) => ({ ...(m.metadata as Record<string, unknown>), receivedAt: m.created_at })),
      }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      const { action } = body;

      if (action === "add_message") {
        const { channel, from_name, from_address, subject, preview, priority, labels } = body;
        if (!channel || !subject) {
          return new Response(JSON.stringify({ success: false, error: "channel and subject required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const msgId = crypto.randomUUID();
        // AI priority classification
        let aiPriority = priority ?? "normal";
        if (!priority) {
          const subjectLower = subject.toLowerCase();
          if (subjectLower.includes("緊急") || subjectLower.includes("urgent")) aiPriority = "urgent";
          else if (subjectLower.includes("重要") || subjectLower.includes("important")) aiPriority = "high";
          else if (subjectLower.includes("ニュースレター") || subjectLower.includes("newsletter")) aiPriority = "low";
        }
        // AI auto-labeling
        const autoLabels = labels ?? [];
        if (channel === "email" && !autoLabels.length) {
          if (subject.includes("請求") || subject.includes("invoice")) autoLabels.push("請求");
          else if (subject.includes("サポート") || subject.includes("support")) autoLabels.push("サポート");
        }
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "inbox_message",
          metadata: { message_id: msgId, channel, from_name: from_name ?? null, from_address: from_address ?? null, subject, preview: preview ?? null, priority: aiPriority, labels: autoLabels, is_read: false, is_archived: false, is_snoozed: false, snooze_until: null },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, messageId: msgId, priority: aiPriority, labels: autoLabels }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "update_priority") {
        const { message_id, priority } = body;
        if (!message_id || !priority) {
          return new Response(JSON.stringify({ success: false, error: "message_id and priority required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const { data: existing } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "inbox_message").eq("metadata->>message_id", message_id).maybeSingle();
        if (!existing) {
          return new Response(JSON.stringify({ success: false, error: "Message not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        await adminClient.from("app_analytics").update({ metadata: { ...(existing.metadata as Record<string, unknown>), priority } })
          .eq("user_id", user.id).eq("source", "inbox_message").eq("metadata->>message_id", message_id);
        return new Response(JSON.stringify({ success: true, updated: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "snooze") {
        const { message_id, snooze_until } = body;
        if (!message_id || !snooze_until) {
          return new Response(JSON.stringify({ success: false, error: "message_id and snooze_until required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const { data: existing } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "inbox_message").eq("metadata->>message_id", message_id).maybeSingle();
        if (!existing) {
          return new Response(JSON.stringify({ success: false, error: "Message not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        await adminClient.from("app_analytics").update({ metadata: { ...(existing.metadata as Record<string, unknown>), is_snoozed: true, snooze_until } })
          .eq("user_id", user.id).eq("source", "inbox_message").eq("metadata->>message_id", message_id);
        return new Response(JSON.stringify({ success: true, snoozed: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "archive") {
        const { message_id } = body;
        if (!message_id) {
          return new Response(JSON.stringify({ success: false, error: "message_id required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const { data: existing } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "inbox_message").eq("metadata->>message_id", message_id).maybeSingle();
        if (!existing) {
          return new Response(JSON.stringify({ success: false, error: "Message not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        await adminClient.from("app_analytics").update({ metadata: { ...(existing.metadata as Record<string, unknown>), is_archived: true, is_read: true } })
          .eq("user_id", user.id).eq("source", "inbox_message").eq("metadata->>message_id", message_id);
        return new Response(JSON.stringify({ success: true, archived: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return new Response(JSON.stringify({ success: false, error: message }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
