// Revenue Forecaster Edge Function
// 収益予測・事業計画シミュレーション
// - 月次/四半期/年次の収益予測
// - ユーザー成長率ベースのMRR予測
// - プラン別の転換率分析
// - ブレークイーブンポイント算出
//
// GET  → 収益予測 / 成長シミュレーション / KPI目標

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

// コスト構造
const MONTHLY_COSTS = {
  supabase: 2500,        // Pro plan
  firebase: 0,           // Spark plan
  domain: 100,           // 月割り
  aiApi: 5000,           // Claude API
  misc: 2000,            // その他
};

const PLAN_PRICES = { free: 0, pro: 480, premium: 980 };

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: { persistSession: false },
    });

    const url = new URL(req.url);
    const view = url.searchParams.get("view"); // 'forecast' | 'simulation' | 'kpi' | 'breakeven'
    const months = parseInt(url.searchParams.get("months") ?? "12", 10);

    // 現在のユーザー数・プラン分布を取得
    const { data: profiles } = await adminClient
      .from("user_profiles")
      .select("subscription_plan, created_at");

    const totalUsers = (profiles ?? []).length;
    const planCounts: Record<string, number> = { free: 0, pro: 0, premium: 0 };
    for (const p of profiles ?? []) {
      const plan = (p.subscription_plan as string) ?? "free";
      planCounts[plan] = (planCounts[plan] ?? 0) + 1;
    }

    const currentMRR = planCounts.pro * PLAN_PRICES.pro + planCounts.premium * PLAN_PRICES.premium;
    const totalMonthlyCost = Object.values(MONTHLY_COSTS).reduce((sum, c) => sum + c, 0);

    if (view === "forecast") {
      // 月次収益予測
      const growthRate = 0.15; // 月15%成長想定
      const proConversionRate = 0.05; // Free→Pro転換率
      const premiumConversionRate = 0.02; // Free→Premium転換率

      const forecast = [];
      let users = totalUsers;
      for (let i = 1; i <= months; i++) {
        users = Math.ceil(users * (1 + growthRate));
        const proUsers = Math.ceil(users * proConversionRate);
        const premiumUsers = Math.ceil(users * premiumConversionRate);
        const mrr = proUsers * PLAN_PRICES.pro + premiumUsers * PLAN_PRICES.premium;
        const profit = mrr - totalMonthlyCost;

        forecast.push({
          month: i,
          users,
          proUsers,
          premiumUsers,
          mrr,
          costs: totalMonthlyCost,
          profit,
          cumProfit: forecast.reduce((sum, f) => sum + f.profit, 0) + profit,
        });
      }

      return new Response(
        JSON.stringify({
          success: true,
          current: { users: totalUsers, mrr: currentMRR, costs: totalMonthlyCost },
          forecast,
          assumptions: { growthRate, proConversionRate, premiumConversionRate },
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    if (view === "simulation") {
      // カスタムシミュレーション
      const growthRate = parseFloat(url.searchParams.get("growth") ?? "0.15");
      const proRate = parseFloat(url.searchParams.get("pro_rate") ?? "0.05");
      const premRate = parseFloat(url.searchParams.get("prem_rate") ?? "0.02");

      const sim = [];
      let users = totalUsers;
      for (let i = 1; i <= months; i++) {
        users = Math.ceil(users * (1 + growthRate));
        const mrr = Math.ceil(users * proRate) * PLAN_PRICES.pro +
                     Math.ceil(users * premRate) * PLAN_PRICES.premium;
        sim.push({ month: i, users, mrr, profit: mrr - totalMonthlyCost });
      }

      return new Response(
        JSON.stringify({ success: true, simulation: sim, params: { growthRate, proRate, premRate } }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    if (view === "breakeven") {
      // ブレークイーブンポイント算出
      const growthRate = 0.15;
      const proRate = 0.05;
      const premRate = 0.02;

      let users = totalUsers;
      let monthToBreakeven = -1;

      for (let i = 1; i <= 60; i++) { // 最大5年
        users = Math.ceil(users * (1 + growthRate));
        const mrr = Math.ceil(users * proRate) * PLAN_PRICES.pro +
                     Math.ceil(users * premRate) * PLAN_PRICES.premium;
        if (mrr >= totalMonthlyCost && monthToBreakeven === -1) {
          monthToBreakeven = i;
        }
      }

      return new Response(
        JSON.stringify({
          success: true,
          breakeven: {
            monthsToBreakeven: monthToBreakeven,
            monthlyCosts: totalMonthlyCost,
            costBreakdown: MONTHLY_COSTS,
            currentMRR,
            requiredMRR: totalMonthlyCost,
          },
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // デフォルト: KPIサマリー
    return new Response(
      JSON.stringify({
        success: true,
        kpi: {
          totalUsers,
          planCounts,
          currentMRR,
          arr: currentMRR * 12,
          monthlyCosts: totalMonthlyCost,
          monthlyProfit: currentMRR - totalMonthlyCost,
          arpu: totalUsers > 0 ? Math.round(currentMRR / totalUsers) : 0,
          paidUserRate: totalUsers > 0
            ? Math.round(((planCounts.pro + planCounts.premium) / totalUsers) * 100)
            : 0,
        },
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error("revenue-forecaster error:", err);
    return new Response(
      JSON.stringify({ success: false, error: message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
