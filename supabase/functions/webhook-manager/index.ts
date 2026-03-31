// Webhook Manager Edge Function
// 外部サービス連携用 Webhook 管理
// - Webhook エンドポイントの登録・管理
// - イベント配信ログ
// - リトライ・ステータス追跡
//
// GET  → Webhook 一覧 / 配信ログ / 統計
// POST → Webhook 登録 / テスト送信 / イベント受信

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

// サポートするイベントタイプ
const EVENT_TYPES = [
  "note.created",
  "note.updated",
  "note.deleted",
  "user.signup",
  "user.profile_updated",
  "feature_request.created",
  "feature_request.voted",
  "support_ticket.created",
  "support_ticket.replied",
  "achievement.completed",
  "export.completed",
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
      const view = url.searchParams.get("view"); // 'webhooks' | 'logs' | 'stats' | 'events'

      if (view === "events") {
        // サポートするイベントタイプ一覧
        return new Response(
          JSON.stringify({ success: true, eventTypes: EVENT_TYPES }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (view === "logs") {
        // 配信ログ
        const webhookId = url.searchParams.get("webhook_id");
        const limit = parseInt(url.searchParams.get("limit") ?? "50", 10);

        let query = adminClient
          .from("app_analytics")
          .select("metadata, created_at")
          .eq("source", "webhook_delivery")
          .order("created_at", { ascending: false })
          .limit(limit);

        if (webhookId) {
          query = query.eq("metadata->>webhook_id", webhookId);
        }

        const { data: logs } = await query;

        return new Response(
          JSON.stringify({
            success: true,
            logs: (logs ?? []).map((l) => ({
              ...(l.metadata as Record<string, unknown>),
              deliveredAt: l.created_at,
            })),
          }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (view === "stats") {
        // 配信統計
        const days = parseInt(url.searchParams.get("days") ?? "7", 10);
        const since = new Date(Date.now() - days * 86400000).toISOString();

        const { data: deliveries } = await adminClient
          .from("app_analytics")
          .select("metadata")
          .eq("source", "webhook_delivery")
          .gte("created_at", since);

        let success = 0, failed = 0;
        for (const d of deliveries ?? []) {
          const meta = d.metadata as Record<string, unknown>;
          if (meta?.status === "success") success++;
          else failed++;
        }

        return new Response(
          JSON.stringify({
            success: true,
            stats: {
              totalDeliveries: (deliveries ?? []).length,
              successful: success,
              failed,
              successRate: (deliveries ?? []).length > 0
                ? Math.round((success / (deliveries ?? []).length) * 100)
                : 0,
            },
            period: { days, since },
          }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      // デフォルト: Webhook 一覧
      const { data: webhooks } = await adminClient
        .from("app_analytics")
        .select("metadata, created_at")
        .eq("source", "webhook_registration")
        .order("created_at", { ascending: false });

      return new Response(
        JSON.stringify({
          success: true,
          webhooks: (webhooks ?? []).map((w) => ({
            ...(w.metadata as Record<string, unknown>),
            registeredAt: w.created_at,
          })),
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    if (req.method === "POST") {
      const body = await req.json();
      const { action } = body;

      if (action === "register") {
        // Webhook 登録
        const { url: webhookUrl, events, name } = body;

        if (!webhookUrl || !events || !Array.isArray(events)) {
          return new Response(
            JSON.stringify({ success: false, error: "url and events array are required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        // イベントタイプの検証
        const validEvents = events.filter((e: string) =>
          (EVENT_TYPES as readonly string[]).includes(e)
        );

        if (validEvents.length === 0) {
          return new Response(
            JSON.stringify({ success: false, error: "No valid event types provided", validTypes: EVENT_TYPES }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const webhookId = crypto.randomUUID();

        const { data, error } = await adminClient
          .from("app_analytics")
          .insert({
            source: "webhook_registration",
            metadata: {
              webhook_id: webhookId,
              name: name ?? "Unnamed Webhook",
              url: webhookUrl,
              events: validEvents,
              active: true,
            },
            created_at: new Date().toISOString(),
          })
          .select()
          .single();

        if (error) throw error;

        return new Response(
          JSON.stringify({ success: true, webhookId, registration: data }),
          { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (action === "test") {
        // テスト送信 (実際には送信せず、ログに記録)
        const { webhook_id } = body;

        if (!webhook_id) {
          return new Response(
            JSON.stringify({ success: false, error: "webhook_id is required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const { data, error } = await adminClient
          .from("app_analytics")
          .insert({
            source: "webhook_delivery",
            metadata: {
              webhook_id,
              event_type: "test.ping",
              status: "success",
              payload: { message: "Test webhook delivery", timestamp: new Date().toISOString() },
            },
            created_at: new Date().toISOString(),
          })
          .select()
          .single();

        if (error) throw error;

        return new Response(
          JSON.stringify({ success: true, delivery: data }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (action === "deliver") {
        // イベント配信 (内部から呼び出し用)
        const { event_type, payload } = body;

        if (!event_type || !payload) {
          return new Response(
            JSON.stringify({ success: false, error: "event_type and payload are required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        // 該当イベントを購読しているWebhookを検索
        const { data: registrations } = await adminClient
          .from("app_analytics")
          .select("metadata")
          .eq("source", "webhook_registration");

        const targets = (registrations ?? []).filter((r) => {
          const meta = r.metadata as Record<string, unknown>;
          return meta?.active && ((meta?.events as string[]) ?? []).includes(event_type);
        });

        // 配信ログを記録
        const deliveryLogs = [];
        for (const target of targets) {
          const meta = target.metadata as Record<string, unknown>;
          deliveryLogs.push({
            source: "webhook_delivery",
            metadata: {
              webhook_id: meta?.webhook_id,
              webhook_name: meta?.name,
              event_type,
              status: "queued",
              payload,
            },
            created_at: new Date().toISOString(),
          });
        }

        if (deliveryLogs.length > 0) {
          await adminClient.from("app_analytics").insert(deliveryLogs);
        }

        return new Response(
          JSON.stringify({ success: true, deliveredTo: targets.length }),
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
    console.error("webhook-manager error:", err);
    return new Response(
      JSON.stringify({ success: false, error: message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
