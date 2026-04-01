// Inventory Barcode Scanner Edge Function
// 在庫バーコード管理 (Amazon/ジョブカン競合)
// - バーコードスキャン記録
// - 在庫入出庫
// - 棚卸し
// - アラート (在庫少)
// - 在庫レポート

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const BARCODE_TYPES = ["ean13", "ean8", "upc", "code128", "code39", "qr", "datamatrix"];
const MOVEMENT_TYPES = ["in", "out", "transfer", "adjustment", "return", "damaged"];

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
      const barcode = url.searchParams.get("barcode");
      const productId = url.searchParams.get("product_id");

      if (view === "types") {
        return new Response(JSON.stringify({ success: true, barcodeTypes: BARCODE_TYPES, movementTypes: MOVEMENT_TYPES }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "lookup" && barcode) {
        const { data: product } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "inventory_product").eq("metadata->>barcode", barcode).maybeSingle();
        if (!product) return new Response(JSON.stringify({ success: true, found: false }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
        return new Response(JSON.stringify({ success: true, found: true, product: { ...(product.metadata as Record<string, unknown>), createdAt: product.created_at } }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "movements" && productId) {
        const { data: movements } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "inventory_movement").eq("metadata->>product_id", productId)
          .order("created_at", { ascending: false }).limit(50);
        return new Response(JSON.stringify({ success: true, movements: (movements ?? []).map((m) => ({ ...(m.metadata as Record<string, unknown>), createdAt: m.created_at })) }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "low_stock") {
        const { data: products } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "inventory_product");
        const lowStock = (products ?? []).filter((p) => {
          const m = p.metadata as Record<string, unknown>;
          return ((m.current_stock as number) ?? 0) <= ((m.min_stock as number) ?? 5);
        }).map((p) => p.metadata as Record<string, unknown>);
        return new Response(JSON.stringify({ success: true, lowStock, count: lowStock.length }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "stocktake") {
        const { data: products } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "inventory_product")
          .order("created_at", { ascending: false });
        let totalValue = 0;
        let totalItems = 0;
        for (const p of products ?? []) {
          const m = p.metadata as Record<string, unknown>;
          const stock = (m.current_stock as number) ?? 0;
          const price = (m.unit_price as number) ?? 0;
          totalItems += stock;
          totalValue += stock * price;
        }
        return new Response(JSON.stringify({
          success: true,
          products: (products ?? []).map((p) => ({ ...(p.metadata as Record<string, unknown>), createdAt: p.created_at })),
          summary: { totalProducts: (products ?? []).length, totalItems, totalValue: Math.round(totalValue) },
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "stats") {
        const { data: products } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "inventory_product");
        const { data: movements } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "inventory_movement");
        const inCount = (movements ?? []).filter((m) => (m.metadata as Record<string, unknown>).type === "in").length;
        const outCount = (movements ?? []).filter((m) => (m.metadata as Record<string, unknown>).type === "out").length;
        return new Response(JSON.stringify({
          success: true, stats: {
            totalProducts: (products ?? []).length, totalMovements: (movements ?? []).length,
            inboundCount: inCount, outboundCount: outCount,
          },
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      // Default: product list
      const { data: products } = await adminClient.from("app_analytics").select("metadata, created_at")
        .eq("user_id", user.id).eq("source", "inventory_product")
        .order("created_at", { ascending: false }).limit(50);
      return new Response(JSON.stringify({ success: true, products: (products ?? []).map((p) => ({ ...(p.metadata as Record<string, unknown>), createdAt: p.created_at })) }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json();
      const { action } = body;

      if (action === "register_product") {
        const { name, barcode: bc, barcode_type, sku, unit_price, current_stock, min_stock, location, category } = body;
        if (!name) return new Response(JSON.stringify({ success: false, error: "name required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const productId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "inventory_product",
          metadata: {
            product_id: productId, name, barcode: bc ?? "", barcode_type: barcode_type ?? "ean13",
            sku: sku ?? "", unit_price: unit_price ?? 0, current_stock: current_stock ?? 0,
            min_stock: min_stock ?? 5, location: location ?? "", category: category ?? "",
          },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, productId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "record_movement") {
        const { product_id, type, quantity, notes, location } = body;
        if (!product_id || !type || !quantity) return new Response(JSON.stringify({ success: false, error: "product_id, type, and quantity required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const movementId = crypto.randomUUID();
        // Update stock
        const { data: product } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "inventory_product").eq("metadata->>product_id", product_id).maybeSingle();
        if (!product) return new Response(JSON.stringify({ success: false, error: "Product not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const meta = product.metadata as Record<string, unknown>;
        const currentStock = (meta.current_stock as number) ?? 0;
        const newStock = (type === "in" || type === "return") ? currentStock + quantity : currentStock - quantity;
        await adminClient.from("app_analytics").update({
          metadata: { ...meta, current_stock: Math.max(0, newStock) },
        }).eq("user_id", user.id).eq("source", "inventory_product").eq("metadata->>product_id", product_id);
        // Record movement
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "inventory_movement",
          metadata: {
            movement_id: movementId, product_id, type, quantity,
            previous_stock: currentStock, new_stock: Math.max(0, newStock),
            notes: notes ?? "", location: location ?? "",
          },
          created_at: new Date().toISOString(),
        });
        // Check low stock alert
        const isLowStock = Math.max(0, newStock) <= ((meta.min_stock as number) ?? 5);
        return new Response(JSON.stringify({ success: true, movementId, newStock: Math.max(0, newStock), isLowStock }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    return new Response(JSON.stringify({ success: false, error: err instanceof Error ? err.message : String(err) }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
