// Payment Processor Edge Function
// 決済処理 (Amazon/Liven競合)
// - 支払い記録・管理
// - 決済ステータス追跡
// - 支払い履歴
// - 売上レポート
//
// GET  → 支払い一覧 / レポート
// POST → 支払い記録 / ステータス更新

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const PAYMENT_METHODS = ["credit_card", "bank_transfer", "convenience_store", "paypal", "apple_pay", "google_pay"];

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
      const view = url.searchParams.get("view"); // 'history' | 'report' | 'methods'

      if (view === "methods") {
        return new Response(JSON.stringify({ success: true, methods: PAYMENT_METHODS }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "report") {
        const year = parseInt(url.searchParams.get("year") ?? String(new Date().getFullYear()));
        const since = new Date(year, 0, 1).toISOString();
        const until = new Date(year + 1, 0, 1).toISOString();

        const { data: payments } = await adminClient.from("app_analytics").select("metadata, created_at").eq("user_id", user.id).eq("source", "payment").gte("created_at", since).lt("created_at", until);

        const monthly = new Array(12).fill(0);
        let totalAmount = 0;
        for (const p of payments ?? []) {
          const meta = p.metadata as Record<string, unknown>;
          const amount = (meta?.amount as number) ?? 0;
          if ((meta?.status as string) === "completed") {
            monthly[new Date(p.created_at).getMonth()] += amount;
            totalAmount += amount;
          }
        }

        return new Response(JSON.stringify({ success: true, year, monthly, totalAmount, totalTransactions: (payments ?? []).length }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      // history
      const { data: payments } = await adminClient.from("app_analytics").select("metadata, created_at").eq("user_id", user.id).eq("source", "payment").order("created_at", { ascending: false }).limit(50);

      return new Response(JSON.stringify({
        success: true,
        payments: (payments ?? []).map((p) => ({ ...(p.metadata as Record<string, unknown>), createdAt: p.created_at })),
      }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      const { action } = body;

      if (action === "record") {
        const { amount, method, description, currency } = body;
        if (!amount || amount <= 0) {
          return new Response(JSON.stringify({ success: false, error: "valid amount required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }

        const paymentId = crypto.randomUUID();
        const { data, error } = await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "payment",
          metadata: { payment_id: paymentId, amount, currency: currency ?? "JPY", method: method ?? "credit_card", description: description ?? "", status: "completed" },
          created_at: new Date().toISOString(),
        }).select().single();

        if (error) throw error;
        return new Response(JSON.stringify({ success: true, paymentId, payment: data }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return new Response(JSON.stringify({ success: false, error: message }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
