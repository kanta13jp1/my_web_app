// Development Stats Edge Function
// 開発進捗データ API — ホーム画面のグラフ表示用
// 短期・中期・長期計画 + 競合21社 vs 進捗を返す
//
// GET → 開発進捗データ (計画別・競合別・期間別実績)

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

// 短期・中期・長期計画の定義
const PLANS = [
  {
    key: "short_term",
    label: "短期計画",
    deadline: "2026-06-30",
    totalTasks: 50,
    description: "MVP 強化・ユーザー 100 人突破",
  },
  {
    key: "mid_term",
    label: "中期計画",
    deadline: "2027-03-31",
    totalTasks: 150,
    description: "機能充実・ユーザー 10,000 人突破",
  },
  {
    key: "long_term",
    label: "長期計画",
    deadline: "2028-12-31",
    totalTasks: 500,
    description: "エンタープライズ対応・グローバル展開",
  },
];

// 競合21社の定義と必要機能数
const COMPETITORS = [
  { key: "notion", label: "Notion", deadline: "2028-12-31", totalFeatures: 80, category: "ナレッジ・生産性" },
  { key: "evernote", label: "EverNote", deadline: "2028-06-30", totalFeatures: 60, category: "ノート・記録" },
  { key: "moneyforward", label: "MoneyForward", deadline: "2028-12-31", totalFeatures: 50, category: "家計・資産管理" },
  { key: "x", label: "X", deadline: "2029-06-30", totalFeatures: 70, category: "SNS・コンテンツ配信" },
  { key: "animaworks", label: "Animaworks", deadline: "2027-12-31", totalFeatures: 40, category: "パーソナル生産性" },
  { key: "claude_code", label: "Claude Code", deadline: "2028-06-30", totalFeatures: 45, category: "AI コーディング" },
  { key: "codex", label: "Codex", deadline: "2028-06-30", totalFeatures: 40, category: "AI コーディング" },
  { key: "netkeiba", label: "netkeiba", deadline: "2028-12-31", totalFeatures: 35, category: "競馬・データ分析" },
  { key: "openclaw", label: "OpenClaw", deadline: "2028-06-30", totalFeatures: 35, category: "AI エージェント" },
  { key: "claude_cowork", label: "Claude Cowork", deadline: "2028-12-31", totalFeatures: 45, category: "法人 AI ワークスペース" },
  { key: "chatwork", label: "Chatwork", deadline: "2028-06-30", totalFeatures: 50, category: "ビジネスチャット" },
  { key: "slack", label: "Slack", deadline: "2029-06-30", totalFeatures: 65, category: "ビジネスチャット" },
  { key: "jobcan", label: "ジョブカン", deadline: "2028-12-31", totalFeatures: 45, category: "バックオフィス SaaS" },
  { key: "amazon", label: "Amazon", deadline: "2030-12-31", totalFeatures: 100, category: "EC・AI・コンテンツ" },
  { key: "google", label: "Google", deadline: "2030-12-31", totalFeatures: 120, category: "Workspace・Search・Cloud" },
  { key: "microsoft", label: "Microsoft", deadline: "2030-12-31", totalFeatures: 110, category: "365・Azure・LinkedIn" },
  { key: "discord", label: "Discord", deadline: "2029-06-30", totalFeatures: 55, category: "コミュニティ・ボイスチャット" },
  { key: "line", label: "LINE", deadline: "2029-06-30", totalFeatures: 60, category: "メッセージング・決済" },
  { key: "facebook", label: "Facebook", deadline: "2030-12-31", totalFeatures: 90, category: "SNS・広告プラットフォーム" },
  { key: "liven", label: "Liven", deadline: "2028-06-30", totalFeatures: 30, category: "ライフスタイル" },
  { key: "github", label: "GitHub", deadline: "2029-06-30", totalFeatures: 70, category: "ソースコード・DevOps" },
];

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: { persistSession: false },
    });

    if (req.method === "GET") {
      // 開発実績の総数を取得
      const { data: achievements, error: achError } = await supabase
        .from("development_achievements")
        .select("id, title, completed_at")
        .order("completed_at", { ascending: false });

      if (achError) throw achError;

      const achievementsList = achievements ?? [];
      const totalAchievements = achievementsList.length;

      // 競合進捗データ (growth_plans テーブルから取得を試みる)
      const { data: growthPlans } = await supabase
        .from("growth_plans")
        .select("competitor_key, completed_count, total_count");

      const growthMap = new Map<string, { completed: number; total: number }>();
      for (const plan of growthPlans ?? []) {
        growthMap.set(plan.competitor_key, {
          completed: plan.completed_count ?? 0,
          total: plan.total_count ?? 0,
        });
      }

      // 短期・中期・長期の進捗を計算
      const planProgress = PLANS.map((plan) => {
        // 実績ベースの進捗計算
        const completed = Math.min(totalAchievements, plan.totalTasks);
        const percent = Math.round((completed / plan.totalTasks) * 100);

        return {
          ...plan,
          completed,
          percent,
        };
      });

      // 競合別の進捗を計算
      const competitorProgress = COMPETITORS.map((comp) => {
        const growthData = growthMap.get(comp.key);
        const completed = growthData?.completed ?? Math.min(
          Math.round(totalAchievements * (comp.totalFeatures / 500)),
          comp.totalFeatures
        );
        const total = growthData?.total ?? comp.totalFeatures;
        const percent = total > 0 ? Math.round((completed / total) * 100) : 0;

        return {
          ...comp,
          completed,
          total,
          percent,
        };
      });

      // 期間別実績集計
      const now = new Date();
      const todayStr = now.toISOString().slice(0, 10);
      const weekAgo = new Date(now.getTime() - 7 * 86400000).toISOString().slice(0, 10);
      const twoWeeksAgo = new Date(now.getTime() - 14 * 86400000).toISOString().slice(0, 10);
      const monthAgo = new Date(now.getFullYear(), now.getMonth() - 1, now.getDate()).toISOString().slice(0, 10);

      const periodStats = {
        today: achievementsList.filter((a) => a.completed_at?.slice(0, 10) === todayStr).length,
        thisWeek: achievementsList.filter((a) => a.completed_at >= weekAgo).length,
        twoWeeks: achievementsList.filter((a) => a.completed_at >= twoWeeksAgo).length,
        thisMonth: achievementsList.filter((a) => a.completed_at >= monthAgo).length,
        total: totalAchievements,
      };

      // ユーザー数
      const { count: userCount } = await supabase
        .from("user_profiles")
        .select("*", { count: "exact", head: true });

      // Edge Function 数
      const edgeFunctionCount = 135; // 130 + 5 (session432e: schedule-result-tracker, blog-auto-publisher, virtual-organization, edge-function-ui-checker, issue-auto-resolver)

      return new Response(
        JSON.stringify({
          success: true,
          plans: planProgress,
          competitors: competitorProgress,
          periodStats,
          overview: {
            totalAchievements,
            totalUsers: userCount ?? 0,
            totalEdgeFunctions: edgeFunctionCount,
            totalCompetitors: COMPETITORS.length,
          },
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    return new Response(
      JSON.stringify({ error: "Method not allowed" }),
      { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error("development-stats error:", err);
    return new Response(
      JSON.stringify({ success: false, error: message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
