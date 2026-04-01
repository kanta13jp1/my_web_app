// Real Estate Tracker Edge Function
// 不動産管理 (MoneyForward/Suumo競合)
// - 物件登録・管理
// - 賃貸収支管理
// - メンテナンス記録
// - テナント管理
// - 物件統計
//
// GET  → 物件一覧 / 収支 / メンテナンス / テナント / 統計
// POST → 物件登録 / 収支記録 / メンテナンス記録 / テナント登録

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const PROPERTY_TYPES = ["apartment", "house", "condo", "land", "commercial", "parking", "other"];
const TRANSACTION_TYPES = ["rent_income", "maintenance_cost", "tax", "insurance", "mortgage", "utility", "other_expense", "other_income"];

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
      const propertyId = url.searchParams.get("property_id");

      if (view === "options") {
        return new Response(JSON.stringify({ success: true, propertyTypes: PROPERTY_TYPES, transactionTypes: TRANSACTION_TYPES }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "finances" && propertyId) {
        const { data: txns } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "realestate_txn").eq("metadata->>property_id", propertyId)
          .order("created_at", { ascending: false }).limit(100);
        let totalIncome = 0, totalExpense = 0;
        for (const t of txns ?? []) {
          const meta = t.metadata as Record<string, unknown>;
          const type = (meta.type as string) ?? "";
          const amount = (meta.amount as number) ?? 0;
          if (type.includes("income")) totalIncome += amount;
          else totalExpense += amount;
        }
        return new Response(JSON.stringify({
          success: true, totalIncome, totalExpense, netIncome: totalIncome - totalExpense,
          transactions: (txns ?? []).map((t) => ({ ...(t.metadata as Record<string, unknown>), recordedAt: t.created_at })),
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "maintenance" && propertyId) {
        const { data: records } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "realestate_maintenance").eq("metadata->>property_id", propertyId)
          .order("created_at", { ascending: false }).limit(50);
        return new Response(JSON.stringify({
          success: true,
          records: (records ?? []).map((r) => ({ ...(r.metadata as Record<string, unknown>), recordedAt: r.created_at })),
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "tenants" && propertyId) {
        const { data: tenants } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "realestate_tenant").eq("metadata->>property_id", propertyId)
          .order("created_at", { ascending: false });
        return new Response(JSON.stringify({
          success: true,
          tenants: (tenants ?? []).map((t) => ({ ...(t.metadata as Record<string, unknown>), createdAt: t.created_at })),
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "stats") {
        const { data: properties } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "realestate_property");
        const { data: txns } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "realestate_txn");
        let totalValue = 0, totalIncome = 0, totalExpense = 0;
        for (const p of properties ?? []) totalValue += ((p.metadata as Record<string, unknown>).purchase_price as number) ?? 0;
        for (const t of txns ?? []) {
          const meta = t.metadata as Record<string, unknown>;
          const amount = (meta.amount as number) ?? 0;
          if (((meta.type as string) ?? "").includes("income")) totalIncome += amount;
          else totalExpense += amount;
        }
        return new Response(JSON.stringify({
          success: true,
          stats: { totalProperties: (properties ?? []).length, totalValue, totalIncome, totalExpense, netIncome: totalIncome - totalExpense, roi: totalValue > 0 ? Math.round((totalIncome - totalExpense) / totalValue * 10000) / 100 : 0 },
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      // Default: property list
      const { data: properties } = await adminClient.from("app_analytics").select("metadata, created_at")
        .eq("user_id", user.id).eq("source", "realestate_property")
        .order("created_at", { ascending: false });
      return new Response(JSON.stringify({
        success: true,
        properties: (properties ?? []).map((p) => ({ ...(p.metadata as Record<string, unknown>), createdAt: p.created_at })),
      }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json();
      const { action } = body;

      if (action === "register_property") {
        const { name, property_type, address, purchase_price, purchase_date, area_sqm, rooms } = body;
        if (!name || !property_type) {
          return new Response(JSON.stringify({ success: false, error: "name and property_type required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const propertyId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "realestate_property",
          metadata: { property_id: propertyId, name, property_type, address: address ?? null, purchase_price: purchase_price ?? 0, purchase_date: purchase_date ?? null, area_sqm: area_sqm ?? null, rooms: rooms ?? null, status: "active" },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, propertyId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "record_transaction") {
        const { property_id, type, amount, description, date } = body;
        if (!property_id || !type || !amount) {
          return new Response(JSON.stringify({ success: false, error: "property_id, type, amount required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const txnId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "realestate_txn",
          metadata: { txn_id: txnId, property_id, type, amount, description: description ?? null, date: date ?? new Date().toISOString().substring(0, 10) },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, txnId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "log_maintenance") {
        const { property_id, title, description, cost, contractor, scheduled_date, completed } = body;
        if (!property_id || !title) {
          return new Response(JSON.stringify({ success: false, error: "property_id and title required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const recordId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "realestate_maintenance",
          metadata: { record_id: recordId, property_id, title, description: description ?? null, cost: cost ?? 0, contractor: contractor ?? null, scheduled_date: scheduled_date ?? null, completed: completed ?? false },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, recordId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "add_tenant") {
        const { property_id, name, email, phone, rent_amount, lease_start, lease_end } = body;
        if (!property_id || !name) {
          return new Response(JSON.stringify({ success: false, error: "property_id and name required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const tenantId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "realestate_tenant",
          metadata: { tenant_id: tenantId, property_id, name, email: email ?? null, phone: phone ?? null, rent_amount: rent_amount ?? 0, lease_start: lease_start ?? null, lease_end: lease_end ?? null, status: "active" },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, tenantId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return new Response(JSON.stringify({ success: false, error: message }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
