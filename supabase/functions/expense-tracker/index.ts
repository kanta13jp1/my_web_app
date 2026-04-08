// Expense Tracker Edge Function
// 家計簿・経費管理 (MoneyForward競合)
// - 収支記録 (収入/支出)
// - カテゴリ別集計
// - 月次/年次レポート
// - 予算管理・超過アラート
//
// GET  → 収支一覧 / カテゴリ集計 / 予算状況
// POST → 記録追加 / 予算設定

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

const DEFAULT_CATEGORIES = [
  { key: "food", label: "食費", icon: "🍽️" },
  { key: "transport", label: "交通費", icon: "🚃" },
  { key: "housing", label: "住居費", icon: "🏠" },
  { key: "utilities", label: "光熱費", icon: "💡" },
  { key: "entertainment", label: "娯楽", icon: "🎮" },
  { key: "health", label: "医療・健康", icon: "🏥" },
  { key: "education", label: "教育", icon: "📚" },
  { key: "clothing", label: "衣服", icon: "👕" },
  { key: "salary", label: "給与", icon: "💰", type: "income" },
  { key: "freelance", label: "副業", icon: "💻", type: "income" },
  { key: "investment", label: "投資収益", icon: "📈", type: "income" },
  { key: "other", label: "その他", icon: "📦" },
];

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: { persistSession: false },
    });

    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ success: false, error: "Authorization required" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: { user } } = await userClient.auth.getUser();
    if (!user) {
      return new Response(
        JSON.stringify({ success: false, error: "Unauthorized" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    if (req.method === "GET") {
      const url = new URL(req.url);
      const view = url.searchParams.get("view"); // 'month' | 'year' | 'categories' | 'budget'
      const yearParam = url.searchParams.get("year");
      const monthParam = url.searchParams.get("month");
      const now = new Date();
      const year = yearParam ? parseInt(yearParam) : now.getFullYear();
      const month = monthParam ? parseInt(monthParam) : now.getMonth() + 1;

      if (view === "categories") {
        const since = new Date(year, month - 1, 1).toISOString();
        const until = new Date(year, month, 1).toISOString();

        const { data: entries } = await adminClient
          .from("app_analytics")
          .select("metadata, created_at")
          .eq("user_id", user.id)
          .eq("source", "expense_entry")
          .gte("created_at", since)
          .lt("created_at", until);

        const categoryTotals = new Map<string, { income: number; expense: number }>();
        for (const e of entries ?? []) {
          const meta = e.metadata as Record<string, unknown>;
          const cat = (meta?.category as string) ?? "other";
          const amount = (meta?.amount as number) ?? 0;
          const type = (meta?.type as string) ?? "expense";
          const curr = categoryTotals.get(cat) ?? { income: 0, expense: 0 };
          if (type === "income") curr.income += amount;
          else curr.expense += amount;
          categoryTotals.set(cat, curr);
        }

        return new Response(
          JSON.stringify({
            success: true,
            categories: [...categoryTotals.entries()].map(([key, totals]) => ({
              key,
              label: DEFAULT_CATEGORIES.find((c) => c.key === key)?.label ?? key,
              ...totals,
            })).sort((a, b) => b.expense - a.expense),
            month: `${year}-${String(month).padStart(2, "0")}`,
          }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (view === "budget") {
        const since = new Date(year, month - 1, 1).toISOString();
        const until = new Date(year, month, 1).toISOString();

        // 予算行と支出エントリを並列取得
        const [{ data: budgetRow }, { data: entries }] = await Promise.all([
          adminClient
            .from("app_analytics")
            .select("metadata")
            .eq("user_id", user.id)
            .eq("source", "expense_budget")
            .eq("metadata->>month", `${year}-${String(month).padStart(2, "0")}`)
            .maybeSingle(),
          adminClient
            .from("app_analytics")
            .select("metadata")
            .eq("user_id", user.id)
            .eq("source", "expense_entry")
            .gte("created_at", since)
            .lt("created_at", until),
        ]);

        const budget = (budgetRow?.metadata as Record<string, unknown>) ?? {};
        const monthlyLimit = (budget?.monthly_limit as number) ?? 0;

        let totalExpense = 0;
        for (const e of entries ?? []) {
          const meta = e.metadata as Record<string, unknown>;
          if ((meta?.type as string) !== "income") {
            totalExpense += (meta?.amount as number) ?? 0;
          }
        }

        return new Response(
          JSON.stringify({
            success: true,
            budget: {
              monthlyLimit,
              spent: totalExpense,
              remaining: monthlyLimit - totalExpense,
              overBudget: monthlyLimit > 0 && totalExpense > monthlyLimit,
              usagePercent: monthlyLimit > 0 ? Math.round((totalExpense / monthlyLimit) * 100) : 0,
            },
            month: `${year}-${String(month).padStart(2, "0")}`,
          }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (view === "year") {
        const since = new Date(year, 0, 1).toISOString();
        const until = new Date(year + 1, 0, 1).toISOString();

        const { data: entries } = await adminClient
          .from("app_analytics")
          .select("metadata, created_at")
          .eq("user_id", user.id)
          .eq("source", "expense_entry")
          .gte("created_at", since)
          .lt("created_at", until);

        const monthlyTotals: Array<{ month: number; income: number; expense: number }> = [];
        for (let m = 1; m <= 12; m++) {
          monthlyTotals.push({ month: m, income: 0, expense: 0 });
        }

        for (const e of entries ?? []) {
          const meta = e.metadata as Record<string, unknown>;
          const d = new Date(e.created_at);
          const m = d.getMonth();
          const amount = (meta?.amount as number) ?? 0;
          if ((meta?.type as string) === "income") monthlyTotals[m].income += amount;
          else monthlyTotals[m].expense += amount;
        }

        const totalIncome = monthlyTotals.reduce((s, m) => s + m.income, 0);
        const totalExpense = monthlyTotals.reduce((s, m) => s + m.expense, 0);

        return new Response(
          JSON.stringify({
            success: true,
            year,
            monthlyTotals,
            totalIncome: Math.round(totalIncome),
            totalExpense: Math.round(totalExpense),
            netSavings: Math.round(totalIncome - totalExpense),
          }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      // デフォルト: 月次一覧
      const since = new Date(year, month - 1, 1).toISOString();
      const until = new Date(year, month, 1).toISOString();

      const { data: entries } = await adminClient
        .from("app_analytics")
        .select("metadata, created_at")
        .eq("user_id", user.id)
        .eq("source", "expense_entry")
        .gte("created_at", since)
        .lt("created_at", until)
        .order("created_at", { ascending: false });

      let totalIncome = 0;
      let totalExpense = 0;
      for (const e of entries ?? []) {
        const meta = e.metadata as Record<string, unknown>;
        const amount = (meta?.amount as number) ?? 0;
        if ((meta?.type as string) === "income") totalIncome += amount;
        else totalExpense += amount;
      }

      return new Response(
        JSON.stringify({
          success: true,
          entries: (entries ?? []).map((e) => ({
            ...(e.metadata as Record<string, unknown>),
            recordedAt: e.created_at,
          })),
          totalIncome: Math.round(totalIncome),
          totalExpense: Math.round(totalExpense),
          balance: Math.round(totalIncome - totalExpense),
          month: `${year}-${String(month).padStart(2, "0")}`,
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      const { action } = body;

      if (action === "record") {
        const { amount, category, type, description, date } = body;
        if (!amount || amount <= 0) {
          return new Response(
            JSON.stringify({ success: false, error: "valid amount required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const { data, error } = await adminClient.from("app_analytics").insert({
          user_id: user.id,
          source: "expense_entry",
          metadata: {
            entry_id: crypto.randomUUID(),
            amount,
            category: category ?? "other",
            type: type ?? "expense",
            description: description ?? "",
            date: date ?? new Date().toISOString().slice(0, 10),
          },
          created_at: new Date().toISOString(),
        }).select().single();

        if (error) throw error;

        return new Response(
          JSON.stringify({ success: true, entry: data }),
          { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (action === "set_budget") {
        const { monthly_limit, month: budgetMonth } = body;
        if (!monthly_limit || monthly_limit <= 0) {
          return new Response(
            JSON.stringify({ success: false, error: "valid monthly_limit required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const targetMonth = budgetMonth ?? `${new Date().getFullYear()}-${String(new Date().getMonth() + 1).padStart(2, "0")}`;

        // Check existing budget
        const { data: existing } = await adminClient
          .from("app_analytics")
          .select("metadata")
          .eq("user_id", user.id)
          .eq("source", "expense_budget")
          .eq("metadata->>month", targetMonth)
          .maybeSingle();

        if (existing) {
          const { error } = await adminClient
            .from("app_analytics")
            .update({ metadata: { ...(existing.metadata as Record<string, unknown>), monthly_limit } })
            .eq("user_id", user.id)
            .eq("source", "expense_budget")
            .eq("metadata->>month", targetMonth);
          if (error) throw error;
        } else {
          const { error } = await adminClient.from("app_analytics").insert({
            user_id: user.id,
            source: "expense_budget",
            metadata: { month: targetMonth, monthly_limit },
            created_at: new Date().toISOString(),
          });
          if (error) throw error;
        }

        return new Response(
          JSON.stringify({ success: true, monthlyLimit: monthly_limit, month: targetMonth }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      return new Response(
        JSON.stringify({ success: false, error: "Unknown action" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    return new Response(
      JSON.stringify({ error: "Method not allowed" }),
      { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error("expense-tracker error:", err);
    return new Response(
      JSON.stringify({ success: false, error: message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
