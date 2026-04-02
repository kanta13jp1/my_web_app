// Inventory Manager Edge Function
// 在庫・資産管理 (Amazon/MoneyForward競合)
// - 物品・デジタル資産の登録管理
// - カテゴリ別在庫
// - 在庫アラート (最低数量)
// - 入出庫履歴
//
// GET  → 在庫一覧 / カテゴリ / アラート / 履歴
// POST → 登録 / 入庫 / 出庫 / 更新

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const CATEGORIES = ["electronics", "office", "books", "digital", "subscription", "furniture", "food", "other"];

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

      if (view === "categories") {
        return new Response(JSON.stringify({ success: true, categories: CATEGORIES }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "alerts") {
        const { data: items } = await adminClient.from("app_analytics").select("metadata, created_at").eq("user_id", user.id).eq("source", "inventory_item");
        const alerts = (items ?? []).filter((i) => {
          const meta = i.metadata as Record<string, unknown>;
          const qty = (meta.quantity as number) ?? 0;
          const minQty = (meta.min_quantity as number) ?? 0;
          return minQty > 0 && qty <= minQty;
        }).map((i) => ({ ...(i.metadata as Record<string, unknown>), createdAt: i.created_at }));
        return new Response(JSON.stringify({ success: true, alerts }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "history") {
        const itemId = url.searchParams.get("item_id");
        let query = adminClient.from("app_analytics").select("metadata, created_at").eq("user_id", user.id).eq("source", "inventory_movement").order("created_at", { ascending: false }).limit(100);
        if (itemId) {
          query = query.eq("metadata->>item_id", itemId);
        }
        const { data: movements } = await query;
        return new Response(JSON.stringify({
          success: true,
          movements: (movements ?? []).map((m) => ({ ...(m.metadata as Record<string, unknown>), createdAt: m.created_at })),
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      // Default: item list
      const category = url.searchParams.get("category");
      let query = adminClient.from("app_analytics").select("metadata, created_at").eq("user_id", user.id).eq("source", "inventory_item").order("created_at", { ascending: false });
      if (category) {
        query = query.eq("metadata->>category", category);
      }
      const { data: items } = await query.limit(100);
      return new Response(JSON.stringify({
        success: true,
        items: (items ?? []).map((i) => ({ ...(i.metadata as Record<string, unknown>), createdAt: i.created_at })),
      }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      const { action } = body;

      if (action === "register") {
        const { name, category, quantity, min_quantity, unit_price, location, notes } = body;
        if (!name) {
          return new Response(JSON.stringify({ success: false, error: "name required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const itemId = crypto.randomUUID();
        const { error } = await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "inventory_item",
          metadata: {
            item_id: itemId, name, category: category ?? "other",
            quantity: quantity ?? 0, min_quantity: min_quantity ?? 0,
            unit_price: unit_price ?? 0, location: location ?? null,
            notes: notes ?? null,
          },
          created_at: new Date().toISOString(),
        });
        if (error) throw error;
        return new Response(JSON.stringify({ success: true, itemId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "stock_in" || action === "stock_out") {
        const { item_id, quantity, reason } = body;
        if (!item_id || !quantity) {
          return new Response(JSON.stringify({ success: false, error: "item_id and quantity required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }

        const { data: existing } = await adminClient.from("app_analytics").select("metadata").eq("user_id", user.id).eq("source", "inventory_item").eq("metadata->>item_id", item_id).maybeSingle();
        if (!existing) {
          return new Response(JSON.stringify({ success: false, error: "Item not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }

        const meta = existing.metadata as Record<string, unknown>;
        const currentQty = (meta.quantity as number) ?? 0;
        const delta = action === "stock_in" ? quantity : -quantity;
        const newQty = Math.max(0, currentQty + delta);

        await adminClient.from("app_analytics").update({
          metadata: { ...meta, quantity: newQty },
        }).eq("user_id", user.id).eq("source", "inventory_item").eq("metadata->>item_id", item_id);

        // Log movement
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "inventory_movement",
          metadata: { item_id, type: action, quantity, reason: reason ?? null, before: currentQty, after: newQty },
          created_at: new Date().toISOString(),
        });

        return new Response(JSON.stringify({ success: true, newQuantity: newQty }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return new Response(JSON.stringify({ success: false, error: message }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
