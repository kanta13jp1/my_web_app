// Carbon Footprint Tracker Edge Function
// カーボンフットプリント管理 (ESG/SDGs対応)
// - CO2排出量記録 (交通/電気/食事)
// - 削減目標・進捗
// - オフセット記録
// - 月次レポート

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const EMISSION_CATEGORIES = ["transport", "electricity", "food", "shopping", "heating", "waste", "other"];
const CO2_FACTORS: Record<string, number> = { car_km: 0.171, train_km: 0.029, flight_km: 0.255, electricity_kwh: 0.457, gas_m3: 2.21, meat_meal: 3.3, veg_meal: 0.7 };

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
      if (view === "factors") {
        return new Response(JSON.stringify({ success: true, categories: EMISSION_CATEGORIES, co2Factors: CO2_FACTORS }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }
      if (view === "monthly") {
        const month = url.searchParams.get("month") ?? new Date().toISOString().substring(0, 7);
        const { data: emissions } = await adminClient.from("app_analytics").select("metadata").eq("user_id", user.id).eq("source", "carbon_emission").gte("created_at", `${month}-01`).lte("created_at", `${month}-31`);
        let totalKg = 0;
        const byCategory: Record<string, number> = {};
        for (const e of emissions ?? []) {
          const meta = e.metadata as Record<string, unknown>;
          const kg = (meta.co2_kg as number) ?? 0;
          totalKg += kg;
          const cat = (meta.category as string) ?? "other";
          byCategory[cat] = (byCategory[cat] ?? 0) + kg;
        }
        return new Response(JSON.stringify({ success: true, month, totalKg: Math.round(totalKg * 100) / 100, byCategory, entryCount: (emissions ?? []).length }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }
      if (view === "goals") {
        const { data: goals } = await adminClient.from("app_analytics").select("metadata, created_at").eq("user_id", user.id).eq("source", "carbon_goal").order("created_at", { ascending: false });
        return new Response(JSON.stringify({ success: true, goals: (goals ?? []).map((g) => ({ ...(g.metadata as Record<string, unknown>), createdAt: g.created_at })) }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }
      if (view === "stats") {
        const { data: allEmissions } = await adminClient.from("app_analytics").select("metadata").eq("user_id", user.id).eq("source", "carbon_emission");
        const { data: offsets } = await adminClient.from("app_analytics").select("metadata").eq("user_id", user.id).eq("source", "carbon_offset");
        let totalEmitted = 0, totalOffset = 0;
        for (const e of allEmissions ?? []) totalEmitted += ((e.metadata as Record<string, unknown>).co2_kg as number) ?? 0;
        for (const o of offsets ?? []) totalOffset += ((o.metadata as Record<string, unknown>).co2_kg as number) ?? 0;
        return new Response(JSON.stringify({ success: true, stats: { totalEmitted: Math.round(totalEmitted), totalOffset: Math.round(totalOffset), netEmission: Math.round(totalEmitted - totalOffset), entries: (allEmissions ?? []).length } }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }
      const { data: recent } = await adminClient.from("app_analytics").select("metadata, created_at").eq("user_id", user.id).eq("source", "carbon_emission").order("created_at", { ascending: false }).limit(30);
      return new Response(JSON.stringify({ success: true, emissions: (recent ?? []).map((r) => ({ ...(r.metadata as Record<string, unknown>), createdAt: r.created_at })) }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      const { action } = body;
      if (action === "log_emission") {
        const { category, activity, quantity, unit, co2_kg } = body;
        if (!category || !activity) return new Response(JSON.stringify({ success: false, error: "category and activity required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const factorKey = `${activity}_${unit}`;
        const calculated = co2_kg ?? ((quantity ?? 0) * (CO2_FACTORS[factorKey] ?? 1));
        await adminClient.from("app_analytics").insert({ user_id: user.id, source: "carbon_emission", metadata: { category, activity, quantity: quantity ?? 0, unit: unit ?? "unit", co2_kg: Math.round(calculated * 100) / 100 }, created_at: new Date().toISOString() });
        return new Response(JSON.stringify({ success: true, co2_kg: Math.round(calculated * 100) / 100 }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }
      if (action === "set_goal") {
        const { target_monthly_kg, description } = body;
        if (!target_monthly_kg) return new Response(JSON.stringify({ success: false, error: "target_monthly_kg required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        await adminClient.from("app_analytics").insert({ user_id: user.id, source: "carbon_goal", metadata: { target_monthly_kg, description: description ?? null, status: "active" }, created_at: new Date().toISOString() });
        return new Response(JSON.stringify({ success: true, set: true }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }
      if (action === "log_offset") {
        const { co2_kg, method, description } = body;
        if (!co2_kg) return new Response(JSON.stringify({ success: false, error: "co2_kg required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        await adminClient.from("app_analytics").insert({ user_id: user.id, source: "carbon_offset", metadata: { co2_kg, method: method ?? "tree_planting", description: description ?? null }, created_at: new Date().toISOString() });
        return new Response(JSON.stringify({ success: true, offset: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }
      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }
    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    return new Response(JSON.stringify({ success: false, error: err instanceof Error ? err.message : String(err) }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
