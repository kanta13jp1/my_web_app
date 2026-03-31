// Compensation Manager Edge Function
// 給与・報酬管理 (ジョブカン/MoneyForward競合)
// - 給与計算・記録
// - 賞与管理
// - 経費精算ステータス
// - 給与明細履歴
//
// GET  → 給与履歴 / 明細 / 統計
// POST → 給与記録 / 賞与記録

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

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
      const year = url.searchParams.get("year") ?? new Date().getFullYear().toString();

      if (view === "detail") {
        const paymentId = url.searchParams.get("payment_id");
        if (!paymentId) {
          return new Response(JSON.stringify({ success: false, error: "payment_id required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const { data: payment } = await adminClient.from("app_analytics").select("metadata, created_at").eq("user_id", user.id).eq("source", "compensation").eq("metadata->>payment_id", paymentId).maybeSingle();
        if (!payment) {
          return new Response(JSON.stringify({ success: false, error: "Payment not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        return new Response(JSON.stringify({ success: true, payment: { ...(payment.metadata as Record<string, unknown>), createdAt: payment.created_at } }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "stats") {
        const { data: payments } = await adminClient.from("app_analytics").select("metadata").eq("user_id", user.id).eq("source", "compensation");
        const yearPayments = (payments ?? []).filter((p) => {
          const meta = p.metadata as Record<string, unknown>;
          return ((meta.period as string) ?? "").startsWith(year);
        });
        let totalGross = 0, totalNet = 0, totalBonus = 0;
        for (const p of yearPayments) {
          const meta = p.metadata as Record<string, unknown>;
          if (meta.type === "salary") {
            totalGross += (meta.gross_amount as number) ?? 0;
            totalNet += (meta.net_amount as number) ?? 0;
          } else if (meta.type === "bonus") {
            totalBonus += (meta.amount as number) ?? 0;
          }
        }
        return new Response(JSON.stringify({
          success: true,
          year,
          stats: { totalGross, totalNet, totalBonus, paymentCount: yearPayments.length },
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      // Default: payment history
      const { data: payments } = await adminClient.from("app_analytics").select("metadata, created_at").eq("user_id", user.id).eq("source", "compensation").order("created_at", { ascending: false }).limit(24);
      return new Response(JSON.stringify({
        success: true,
        payments: (payments ?? []).map((p) => ({ ...(p.metadata as Record<string, unknown>), createdAt: p.created_at })),
      }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json();
      const { action } = body;

      if (action === "record_salary") {
        const { period, gross_amount, deductions, net_amount, breakdown } = body;
        if (!period || !gross_amount) {
          return new Response(JSON.stringify({ success: false, error: "period and gross_amount required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const paymentId = crypto.randomUUID();
        const deductionTotal = deductions
          ? Object.values(deductions as Record<string, number>).reduce((s: number, v: number) => s + v, 0)
          : 0;
        const { error } = await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "compensation",
          metadata: {
            payment_id: paymentId, type: "salary", period,
            gross_amount, deductions: deductions ?? {},
            deduction_total: deductionTotal,
            net_amount: net_amount ?? (gross_amount - deductionTotal),
            breakdown: breakdown ?? null,
          },
          created_at: new Date().toISOString(),
        });
        if (error) throw error;
        return new Response(JSON.stringify({ success: true, paymentId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "record_bonus") {
        const { period, amount, reason } = body;
        if (!period || !amount) {
          return new Response(JSON.stringify({ success: false, error: "period and amount required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const paymentId = crypto.randomUUID();
        const { error } = await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "compensation",
          metadata: { payment_id: paymentId, type: "bonus", period, amount, reason: reason ?? null },
          created_at: new Date().toISOString(),
        });
        if (error) throw error;
        return new Response(JSON.stringify({ success: true, paymentId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return new Response(JSON.stringify({ success: false, error: message }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
