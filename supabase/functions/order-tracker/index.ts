// Order Tracker Edge Function
// 注文・配送追跡 (Amazon競合)
// - 注文登録・管理
// - 配送ステータス追跡
// - 注文履歴・統計
// - ウィッシュリスト
//
// GET  → 注文一覧 / 詳細 / ウィッシュリスト / 統計
// POST → 注文作成 / ステータス更新 / ウィッシュリスト追加

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const ORDER_STATUSES = ["pending", "confirmed", "processing", "shipped", "delivered", "cancelled", "returned"];

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
      const orderId = url.searchParams.get("order_id");

      if (view === "detail" && orderId) {
        const { data: order } = await adminClient.from("app_analytics").select("metadata, created_at").eq("user_id", user.id).eq("source", "order").eq("metadata->>order_id", orderId).maybeSingle();
        if (!order) {
          return new Response(JSON.stringify({ success: false, error: "Order not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        // Get status history
        const { data: history } = await adminClient.from("app_analytics").select("metadata, created_at").eq("user_id", user.id).eq("source", "order_status").eq("metadata->>order_id", orderId).order("created_at", { ascending: true });
        return new Response(JSON.stringify({
          success: true,
          order: { ...(order.metadata as Record<string, unknown>), createdAt: order.created_at },
          statusHistory: (history ?? []).map((h) => ({ ...(h.metadata as Record<string, unknown>), updatedAt: h.created_at })),
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "wishlist") {
        const { data: items } = await adminClient.from("app_analytics").select("metadata, created_at").eq("user_id", user.id).eq("source", "wishlist_item").order("created_at", { ascending: false });
        return new Response(JSON.stringify({
          success: true,
          wishlist: (items ?? []).map((i) => ({ ...(i.metadata as Record<string, unknown>), addedAt: i.created_at })),
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "stats") {
        const { data: orders } = await adminClient.from("app_analytics").select("metadata").eq("user_id", user.id).eq("source", "order");
        let totalSpent = 0;
        const statusCounts: Record<string, number> = {};
        for (const o of orders ?? []) {
          const meta = o.metadata as Record<string, unknown>;
          totalSpent += (meta.total as number) ?? 0;
          const status = (meta.status as string) ?? "pending";
          statusCounts[status] = (statusCounts[status] ?? 0) + 1;
        }
        return new Response(JSON.stringify({
          success: true,
          stats: { totalOrders: (orders ?? []).length, totalSpent, statusCounts },
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      // Default: order list
      const status = url.searchParams.get("status");
      let query = adminClient.from("app_analytics").select("metadata, created_at").eq("user_id", user.id).eq("source", "order").order("created_at", { ascending: false });
      if (status) {
        query = query.eq("metadata->>status", status);
      }
      const { data: orders } = await query.limit(50);
      return new Response(JSON.stringify({
        success: true,
        orders: (orders ?? []).map((o) => ({ ...(o.metadata as Record<string, unknown>), createdAt: o.created_at })),
      }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json();
      const { action } = body;

      if (action === "create_order") {
        const { items, total, currency, shipping_address, notes } = body;
        if (!items || !total) {
          return new Response(JSON.stringify({ success: false, error: "items and total required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const orderId = crypto.randomUUID();
        const { error } = await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "order",
          metadata: {
            order_id: orderId, items, total,
            currency: currency ?? "JPY", status: "pending",
            shipping_address: shipping_address ?? null,
            notes: notes ?? null,
          },
          created_at: new Date().toISOString(),
        });
        if (error) throw error;

        // Log initial status
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "order_status",
          metadata: { order_id: orderId, status: "pending", note: "注文作成" },
          created_at: new Date().toISOString(),
        });

        return new Response(JSON.stringify({ success: true, orderId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "update_status") {
        const { order_id, status, note } = body;
        if (!order_id || !status) {
          return new Response(JSON.stringify({ success: false, error: "order_id and status required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        if (!ORDER_STATUSES.includes(status)) {
          return new Response(JSON.stringify({ success: false, error: "Invalid status" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }

        const { data: existing } = await adminClient.from("app_analytics").select("metadata").eq("user_id", user.id).eq("source", "order").eq("metadata->>order_id", order_id).maybeSingle();
        if (!existing) {
          return new Response(JSON.stringify({ success: false, error: "Order not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }

        await adminClient.from("app_analytics").update({
          metadata: { ...(existing.metadata as Record<string, unknown>), status },
        }).eq("user_id", user.id).eq("source", "order").eq("metadata->>order_id", order_id);

        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "order_status",
          metadata: { order_id, status, note: note ?? null },
          created_at: new Date().toISOString(),
        });

        return new Response(JSON.stringify({ success: true, updated: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "add_to_wishlist") {
        const { name, url: itemUrl, price, notes } = body;
        if (!name) {
          return new Response(JSON.stringify({ success: false, error: "name required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const wishlistId = crypto.randomUUID();
        const { error } = await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "wishlist_item",
          metadata: { wishlist_id: wishlistId, name, url: itemUrl ?? null, price: price ?? null, notes: notes ?? null },
          created_at: new Date().toISOString(),
        });
        if (error) throw error;
        return new Response(JSON.stringify({ success: true, wishlistId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return new Response(JSON.stringify({ success: false, error: message }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
