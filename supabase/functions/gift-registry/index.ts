// Gift Registry & Wishlist Edge Function
// ギフトレジストリ・ウィッシュリスト管理 (Amazon/楽天競合)
// - ウィッシュリスト作成
// - ギフト登録・管理
// - イベント紐付け (誕生日/結婚式等)
// - 購入済みマーク
// - 共有リンク

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const EVENT_TYPES = ["birthday", "wedding", "baby_shower", "christmas", "anniversary", "graduation", "housewarming", "other"];

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
      const listId = url.searchParams.get("list_id");
      if (view === "event_types") return new Response(JSON.stringify({ success: true, eventTypes: EVENT_TYPES }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      if (view === "items" && listId) {
        const { data: items } = await adminClient.from("app_analytics").select("metadata, created_at").eq("user_id", user.id).eq("source", "gift_item").eq("metadata->>list_id", listId).order("created_at", { ascending: false });
        return new Response(JSON.stringify({ success: true, items: (items ?? []).map((i) => ({ ...(i.metadata as Record<string, unknown>), createdAt: i.created_at })) }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }
      if (view === "stats") {
        const { data: lists } = await adminClient.from("app_analytics").select("metadata").eq("user_id", user.id).eq("source", "gift_list");
        const { data: items } = await adminClient.from("app_analytics").select("metadata").eq("user_id", user.id).eq("source", "gift_item");
        const purchased = (items ?? []).filter((i) => (i.metadata as Record<string, unknown>).purchased).length;
        let totalValue = 0;
        for (const i of items ?? []) totalValue += ((i.metadata as Record<string, unknown>).price as number) ?? 0;
        return new Response(JSON.stringify({ success: true, stats: { totalLists: (lists ?? []).length, totalItems: (items ?? []).length, purchased, totalValue } }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }
      const { data: lists } = await adminClient.from("app_analytics").select("metadata, created_at").eq("user_id", user.id).eq("source", "gift_list").order("created_at", { ascending: false });
      return new Response(JSON.stringify({ success: true, lists: (lists ?? []).map((l) => ({ ...(l.metadata as Record<string, unknown>), createdAt: l.created_at })) }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json();
      const { action } = body;
      if (action === "create_list") {
        const { title, event_type, event_date, is_public } = body;
        if (!title) return new Response(JSON.stringify({ success: false, error: "title required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const listId = crypto.randomUUID();
        const shareCode = listId.substring(0, 8).toUpperCase();
        await adminClient.from("app_analytics").insert({ user_id: user.id, source: "gift_list", metadata: { list_id: listId, title, event_type: event_type ?? "other", event_date: event_date ?? null, is_public: is_public ?? false, share_code: shareCode, item_count: 0 }, created_at: new Date().toISOString() });
        return new Response(JSON.stringify({ success: true, listId, shareCode }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }
      if (action === "add_item") {
        const { list_id, name, price, url: itemUrl, priority, notes } = body;
        if (!list_id || !name) return new Response(JSON.stringify({ success: false, error: "list_id and name required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const itemId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({ user_id: user.id, source: "gift_item", metadata: { item_id: itemId, list_id, name, price: price ?? 0, url: itemUrl ?? null, priority: priority ?? "medium", notes: notes ?? null, purchased: false, purchased_by: null }, created_at: new Date().toISOString() });
        return new Response(JSON.stringify({ success: true, itemId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }
      if (action === "mark_purchased") {
        const { item_id, purchased_by } = body;
        if (!item_id) return new Response(JSON.stringify({ success: false, error: "item_id required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const { data: existing } = await adminClient.from("app_analytics").select("metadata").eq("user_id", user.id).eq("source", "gift_item").eq("metadata->>item_id", item_id).maybeSingle();
        if (!existing) return new Response(JSON.stringify({ success: false, error: "Item not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        await adminClient.from("app_analytics").update({ metadata: { ...(existing.metadata as Record<string, unknown>), purchased: true, purchased_by: purchased_by ?? user.email } }).eq("user_id", user.id).eq("source", "gift_item").eq("metadata->>item_id", item_id);
        return new Response(JSON.stringify({ success: true, purchased: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }
      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }
    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    return new Response(JSON.stringify({ success: false, error: err instanceof Error ? err.message : String(err) }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
