// Budget & Financial Planner Edge Function
// 予算・家計プランナー (MoneyForward競合強化)
// - 月次予算設定
// - カテゴリ別支出管理
// - 貯蓄目標
// - キャッシュフロー予測
// - 家計診断

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const BUDGET_CATEGORIES = [
  "housing", "food", "transportation", "utilities", "insurance",
  "healthcare", "entertainment", "education", "clothing", "savings",
  "investments", "debt_repayment", "subscriptions", "gifts", "other",
];

const INCOME_TYPES = ["salary", "bonus", "freelance", "investment", "rental", "other"];

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
      const month = url.searchParams.get("month"); // YYYY-MM

      if (view === "categories") {
        return new Response(JSON.stringify({ success: true, budgetCategories: BUDGET_CATEGORIES, incomeTypes: INCOME_TYPES }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "budget" && month) {
        const { data: budgets } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "budget_plan").eq("metadata->>month", month);
        return new Response(JSON.stringify({
          success: true,
          budgets: (budgets ?? []).map((b) => ({ ...(b.metadata as Record<string, unknown>), createdAt: b.created_at })),
          month,
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "expenses" && month) {
        const { data: expenses } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "budget_expense")
          .gte("created_at", `${month}-01`).lt("created_at", `${month}-32`)
          .order("created_at", { ascending: false });
        return new Response(JSON.stringify({
          success: true,
          expenses: (expenses ?? []).map((e) => ({ ...(e.metadata as Record<string, unknown>), createdAt: e.created_at })),
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "income" && month) {
        const { data: incomes } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "budget_income")
          .gte("created_at", `${month}-01`).lt("created_at", `${month}-32`)
          .order("created_at", { ascending: false });
        return new Response(JSON.stringify({
          success: true,
          incomes: (incomes ?? []).map((i) => ({ ...(i.metadata as Record<string, unknown>), createdAt: i.created_at })),
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "savings_goals") {
        const { data: goals } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "savings_goal")
          .order("created_at", { ascending: false });
        return new Response(JSON.stringify({
          success: true,
          goals: (goals ?? []).map((g) => ({ ...(g.metadata as Record<string, unknown>), createdAt: g.created_at })),
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "analysis") {
        const targetMonth = month ?? new Date().toISOString().slice(0, 7);
        // 予算・支出・収入を並列取得
        const [{ data: budgets }, { data: expenses }, { data: incomes }] = await Promise.all([
          adminClient.from("app_analytics").select("metadata")
            .eq("user_id", user.id).eq("source", "budget_plan").eq("metadata->>month", targetMonth),
          adminClient.from("app_analytics").select("metadata")
            .eq("user_id", user.id).eq("source", "budget_expense")
            .gte("created_at", `${targetMonth}-01`).lt("created_at", `${targetMonth}-32`),
          adminClient.from("app_analytics").select("metadata")
            .eq("user_id", user.id).eq("source", "budget_income")
            .gte("created_at", `${targetMonth}-01`).lt("created_at", `${targetMonth}-32`),
        ]);

        // Category breakdown
        const categorySpending: Record<string, number> = {};
        const categoryBudget: Record<string, number> = {};
        for (const b of budgets ?? []) {
          const m = b.metadata as Record<string, unknown>;
          categoryBudget[m.category as string] = (m.amount as number) ?? 0;
        }
        for (const e of expenses ?? []) {
          const m = e.metadata as Record<string, unknown>;
          const cat = (m.category as string) ?? "other";
          categorySpending[cat] = (categorySpending[cat] ?? 0) + ((m.amount as number) ?? 0);
        }

        const totalIncome = (incomes ?? []).reduce((sum, i) => sum + (((i.metadata as Record<string, unknown>).amount as number) ?? 0), 0);
        const totalExpense = Object.values(categorySpending).reduce((a, b) => a + b, 0);
        const totalBudget = Object.values(categoryBudget).reduce((a, b) => a + b, 0);
        const savingsRate = totalIncome > 0 ? Math.round(((totalIncome - totalExpense) / totalIncome) * 100) : 0;

        // Health diagnosis
        let diagnosis = "良好";
        if (totalExpense > totalBudget * 1.1) diagnosis = "予算超過・要注意";
        else if (totalExpense > totalBudget) diagnosis = "やや超過";
        else if (savingsRate >= 20) diagnosis = "優秀";

        return new Response(JSON.stringify({
          success: true, analysis: {
            month: targetMonth, totalIncome, totalExpense, totalBudget,
            balance: totalIncome - totalExpense, savingsRate, diagnosis,
            categoryBreakdown: BUDGET_CATEGORIES.map((cat) => ({
              category: cat, budget: categoryBudget[cat] ?? 0, spent: categorySpending[cat] ?? 0,
              remaining: (categoryBudget[cat] ?? 0) - (categorySpending[cat] ?? 0),
            })).filter((c) => c.budget > 0 || c.spent > 0),
          },
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: true, categories: BUDGET_CATEGORIES }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      const { action } = body;

      if (action === "set_budget") {
        const { month, category, amount } = body;
        if (!month || !category || amount === undefined) return new Response(JSON.stringify({ success: false, error: "month, category, and amount required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const budgetId = crypto.randomUUID();
        // Upsert by deleting old + inserting new
        await adminClient.from("app_analytics").delete()
          .eq("user_id", user.id).eq("source", "budget_plan").eq("metadata->>month", month).eq("metadata->>category", category);
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "budget_plan",
          metadata: { budget_id: budgetId, month, category, amount },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, budgetId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "add_expense") {
        const { amount, category, description, date } = body;
        if (!amount || !category) return new Response(JSON.stringify({ success: false, error: "amount and category required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const expenseId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "budget_expense",
          metadata: { expense_id: expenseId, amount, category, description: description ?? "", date: date ?? new Date().toISOString().slice(0, 10) },
          created_at: date ? new Date(date).toISOString() : new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, expenseId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "add_income") {
        const { amount, type, description, date } = body;
        if (!amount) return new Response(JSON.stringify({ success: false, error: "amount required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const incomeId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "budget_income",
          metadata: { income_id: incomeId, amount, type: type ?? "salary", description: description ?? "" },
          created_at: date ? new Date(date).toISOString() : new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, incomeId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "create_savings_goal") {
        const { name, target_amount, target_date, current_amount } = body;
        if (!name || !target_amount) return new Response(JSON.stringify({ success: false, error: "name and target_amount required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const goalId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "savings_goal",
          metadata: {
            goal_id: goalId, name, target_amount, current_amount: current_amount ?? 0,
            target_date: target_date ?? null,
            percent: Math.round(((current_amount ?? 0) / target_amount) * 100),
          },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, goalId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    return new Response(JSON.stringify({ success: false, error: err instanceof Error ? err.message : String(err) }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
