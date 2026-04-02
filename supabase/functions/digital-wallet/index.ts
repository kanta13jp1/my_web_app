// Digital Wallet Edge Function
// デジタルウォレット (Amazon Pay/LINE Pay/PayPay/Apple Pay競合)
// - 残高管理
// - 送金・受取
// - 取引履歴
// - QRコード決済
// - 支出分析

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type" };
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const TRANSACTION_TYPES = ["deposit", "withdrawal", "transfer_out", "transfer_in", "payment", "refund", "cashback"];
const PAYMENT_CATEGORIES = ["food", "transport", "shopping", "entertainment", "utilities", "health", "education", "other"];

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

      if (view === "config") return new Response(JSON.stringify({ success: true, transactionTypes: TRANSACTION_TYPES, paymentCategories: PAYMENT_CATEGORIES }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });

      if (view === "balance") {
        const { data: txns } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "wallet_txn");
        let balance = 0;
        let totalIn = 0;
        let totalOut = 0;
        for (const t of txns ?? []) {
          const m = t.metadata as Record<string, unknown>;
          const amount = (m.amount as number) ?? 0;
          balance += amount;
          if (amount > 0) totalIn += amount; else totalOut += Math.abs(amount);
        }
        return new Response(JSON.stringify({ success: true, balance, totalIn, totalOut, transactionCount: (txns ?? []).length }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "history") {
        const limit = parseInt(url.searchParams.get("limit") ?? "30");
        const { data: txns } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "wallet_txn").order("created_at", { ascending: false }).limit(limit);
        return new Response(JSON.stringify({ success: true, transactions: (txns ?? []).map((t) => ({ ...(t.metadata as Record<string, unknown>), createdAt: t.created_at })) }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "spending_analysis") {
        const days = parseInt(url.searchParams.get("days") ?? "30");
        const since = new Date(Date.now() - days * 86400000).toISOString();
        const { data: txns } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "wallet_txn").gte("created_at", since);
        const categoryTotals: Record<string, number> = {};
        let totalSpent = 0;
        for (const t of txns ?? []) {
          const m = t.metadata as Record<string, unknown>;
          const amount = (m.amount as number) ?? 0;
          if (amount < 0) {
            const cat = (m.category as string) ?? "other";
            categoryTotals[cat] = (categoryTotals[cat] ?? 0) + Math.abs(amount);
            totalSpent += Math.abs(amount);
          }
        }
        const dailyAvg = days > 0 ? Math.round(totalSpent / days) : 0;
        return new Response(JSON.stringify({ success: true, analysis: { period: days, totalSpent, dailyAverage: dailyAvg, categoryBreakdown: categoryTotals } }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: true, transactionTypes: TRANSACTION_TYPES }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      const { action } = body;

      if (action === "deposit") {
        const { amount, description } = body;
        if (!amount || amount <= 0) return new Response(JSON.stringify({ success: false, error: "positive amount required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const txnId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "wallet_txn",
          metadata: { txn_id: txnId, type: "deposit", amount, description: description ?? "チャージ", category: null },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, txnId }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "payment") {
        const { amount, merchant, category, description } = body;
        if (!amount || amount <= 0) return new Response(JSON.stringify({ success: false, error: "positive amount required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        // Check balance
        const { data: txns } = await adminClient.from("app_analytics").select("metadata").eq("user_id", user.id).eq("source", "wallet_txn");
        let balance = 0;
        for (const t of txns ?? []) balance += ((t.metadata as Record<string, unknown>).amount as number) ?? 0;
        if (balance < amount) return new Response(JSON.stringify({ success: false, error: "残高不足", balance, required: amount }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const txnId = crypto.randomUUID();
        const cashback = Math.floor(amount * 0.01); // 1% cashback
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "wallet_txn",
          metadata: { txn_id: txnId, type: "payment", amount: -amount, merchant: merchant ?? "unknown", category: category ?? "other", description: description ?? `${merchant ?? ""}での支払い` },
          created_at: new Date().toISOString(),
        });
        if (cashback > 0) {
          await adminClient.from("app_analytics").insert({
            user_id: user.id, source: "wallet_txn",
            metadata: { txn_id: crypto.randomUUID(), type: "cashback", amount: cashback, description: `キャッシュバック (${merchant ?? ""})`, related_txn: txnId },
            created_at: new Date().toISOString(),
          });
        }
        return new Response(JSON.stringify({ success: true, txnId, charged: amount, cashback }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "transfer") {
        const { to_user_id, amount, message } = body;
        if (!to_user_id || !amount || amount <= 0) return new Response(JSON.stringify({ success: false, error: "to_user_id and positive amount required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        // Check balance
        const { data: txns } = await adminClient.from("app_analytics").select("metadata").eq("user_id", user.id).eq("source", "wallet_txn");
        let balance = 0;
        for (const t of txns ?? []) balance += ((t.metadata as Record<string, unknown>).amount as number) ?? 0;
        if (balance < amount) return new Response(JSON.stringify({ success: false, error: "残高不足" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const transferId = crypto.randomUUID();
        // Debit sender
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "wallet_txn",
          metadata: { txn_id: crypto.randomUUID(), type: "transfer_out", amount: -amount, to_user: to_user_id, transfer_id: transferId, message: message ?? "" },
          created_at: new Date().toISOString(),
        });
        // Credit receiver
        await adminClient.from("app_analytics").insert({
          user_id: to_user_id, source: "wallet_txn",
          metadata: { txn_id: crypto.randomUUID(), type: "transfer_in", amount, from_user: user.id, transfer_id: transferId, message: message ?? "" },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, transferId }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "generate_qr") {
        const { amount, description } = body;
        const qrCode = `JKPAY-${crypto.randomUUID().slice(0, 12)}-${amount ?? 0}`;
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "wallet_qr",
          metadata: { qr_code: qrCode, user_id: user.id, amount: amount ?? null, description: description ?? "", expires_at: new Date(Date.now() + 600000).toISOString() },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, qrCode, expiresIn: 600 }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }
    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) { return new Response(JSON.stringify({ success: false, error: err instanceof Error ? err.message : String(err) }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }); }
});
