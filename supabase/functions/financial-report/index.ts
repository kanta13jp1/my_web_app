// Financial Report Edge Function
// 財務レポート (MoneyForward/Microsoft競合)
// - 損益計算書 (P/L)
// - キャッシュフロー分析
// - カテゴリ別支出分析
// - 月次・年次比較
//
// GET  → P/L / キャッシュフロー / カテゴリ分析 / 比較

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

    if (req.method !== "GET") {
      return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    const url = new URL(req.url);
    const view = url.searchParams.get("view");
    const year = parseInt(url.searchParams.get("year") ?? new Date().getFullYear().toString());
    const month = url.searchParams.get("month"); // optional

    // Fetch all expense data for the period
    const startDate = month
      ? `${year}-${month.padStart(2, "0")}-01`
      : `${year}-01-01`;
    const endDate = month
      ? `${year}-${month.padStart(2, "0")}-31`
      : `${year}-12-31`;

    const { data: expenses } = await adminClient.from("app_analytics").select("metadata, created_at").eq("user_id", user.id).eq("source", "expense").gte("created_at", startDate).lte("created_at", endDate + "T23:59:59Z");

    const allExpenses = (expenses ?? []).map((e) => ({ ...(e.metadata as Record<string, unknown>), date: e.created_at }));

    if (view === "pl") {
      // Profit & Loss
      let totalIncome = 0, totalExpense = 0;
      for (const e of allExpenses) {
        const amount = (e.amount as number) ?? 0;
        if (e.type === "income") totalIncome += amount;
        else totalExpense += amount;
      }
      return new Response(JSON.stringify({
        success: true,
        report: "pl",
        period: { year, month: month ?? "all" },
        pl: { totalIncome, totalExpense, netProfit: totalIncome - totalExpense, profitMargin: totalIncome > 0 ? Math.round((totalIncome - totalExpense) / totalIncome * 100) : 0 },
      }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (view === "cashflow") {
      // Monthly cashflow
      const monthly = new Map<string, { income: number; expense: number }>();
      for (const e of allExpenses) {
        const m = (e.date as string).slice(0, 7);
        if (!monthly.has(m)) monthly.set(m, { income: 0, expense: 0 });
        const entry = monthly.get(m)!;
        const amount = (e.amount as number) ?? 0;
        if (e.type === "income") entry.income += amount;
        else entry.expense += amount;
      }
      const cashflow = [...monthly.entries()]
        .map(([month, data]) => ({ month, ...data, net: data.income - data.expense }))
        .sort((a, b) => a.month.localeCompare(b.month));

      return new Response(JSON.stringify({
        success: true,
        report: "cashflow",
        period: { year },
        cashflow,
      }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (view === "category") {
      // Category breakdown
      const categories = new Map<string, number>();
      for (const e of allExpenses) {
        if (e.type === "expense") {
          const cat = (e.category as string) ?? "その他";
          categories.set(cat, (categories.get(cat) ?? 0) + ((e.amount as number) ?? 0));
        }
      }
      const breakdown = [...categories.entries()]
        .map(([category, amount]) => ({ category, amount }))
        .sort((a, b) => b.amount - a.amount);
      const total = breakdown.reduce((s, b) => s + b.amount, 0);

      return new Response(JSON.stringify({
        success: true,
        report: "category",
        period: { year, month: month ?? "all" },
        breakdown: breakdown.map((b) => ({ ...b, percentage: total > 0 ? Math.round(b.amount / total * 100) : 0 })),
        total,
      }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (view === "comparison") {
      // Year-over-year comparison
      const prevStartDate = `${year - 1}-01-01`;
      const prevEndDate = `${year - 1}-12-31`;
      const { data: prevExpenses } = await adminClient.from("app_analytics").select("metadata, created_at").eq("user_id", user.id).eq("source", "expense").gte("created_at", prevStartDate).lte("created_at", prevEndDate + "T23:59:59Z");

      let currIncome = 0, currExpense = 0, prevIncome = 0, prevExpense = 0;
      for (const e of allExpenses) {
        const amount = (e.amount as number) ?? 0;
        if (e.type === "income") currIncome += amount;
        else currExpense += amount;
      }
      for (const e of prevExpenses ?? []) {
        const meta = e.metadata as Record<string, unknown>;
        const amount = (meta.amount as number) ?? 0;
        if (meta.type === "income") prevIncome += amount;
        else prevExpense += amount;
      }

      return new Response(JSON.stringify({
        success: true,
        report: "comparison",
        current: { year, income: currIncome, expense: currExpense, net: currIncome - currExpense },
        previous: { year: year - 1, income: prevIncome, expense: prevExpense, net: prevIncome - prevExpense },
        change: {
          incomeChange: prevIncome > 0 ? Math.round((currIncome - prevIncome) / prevIncome * 100) : 0,
          expenseChange: prevExpense > 0 ? Math.round((currExpense - prevExpense) / prevExpense * 100) : 0,
        },
      }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    // Default: summary
    return new Response(JSON.stringify({
      success: true,
      views: ["pl", "cashflow", "category", "comparison"],
      period: { year },
      transactionCount: allExpenses.length,
    }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });

  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return new Response(JSON.stringify({ success: false, error: message }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
