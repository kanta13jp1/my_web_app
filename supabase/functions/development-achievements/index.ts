import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

// -----------------------------------------------------------------------
// development-achievements
//
// GET/POST action:"get"       → achievement list (default)
// POST     action:"add"       → insert new achievement
// GET/POST action:"get_stats" → dev stats (absorbed from development-stats)
// -----------------------------------------------------------------------

const PLANS = [
  { key: "short_term", label: "短期計画", deadline: "2026-06-30", totalTasks: 50, description: "MVP 強化・ユーザー 100 人突破" },
  { key: "mid_term", label: "中期計画", deadline: "2027-03-31", totalTasks: 150, description: "機能充実・ユーザー 10,000 人突破" },
  { key: "long_term", label: "長期計画", deadline: "2028-12-31", totalTasks: 500, description: "エンタープライズ対応・グローバル展開" },
];

const COMPETITORS_STATS = [
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

/** 期間文字列から since (ISO 8601) を計算して返す。全期間は null */
function calcSince(period: string): string | null {
  const now = new Date();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());

  switch (period) {
    case "今日の実績": {
      return today.toISOString();
    }
    case "今週の実績": {
      const day = today.getDay(); // 0=Sun
      const diff = day === 0 ? 6 : day - 1; // Mon start
      const mon = new Date(today);
      mon.setDate(today.getDate() - diff);
      return mon.toISOString();
    }
    case "直近2週間の実績": {
      const d = new Date(today);
      d.setDate(d.getDate() - 14);
      return d.toISOString();
    }
    case "今月の実績": {
      return new Date(now.getFullYear(), now.getMonth(), 1).toISOString();
    }
    case "直近2ヶ月の実績": {
      const d = new Date(today);
      d.setDate(d.getDate() - 60);
      return d.toISOString();
    }
    case "直近3ヶ月の実績": {
      const d = new Date(today);
      d.setDate(d.getDate() - 90);
      return d.toISOString();
    }
    case "直近半年の実績": {
      const d = new Date(today);
      d.setDate(d.getDate() - 180);
      return d.toISOString();
    }
    case "直近1年の実績": {
      const d = new Date(today);
      d.setDate(d.getDate() - 365);
      return d.toISOString();
    }
    case "直近2年の実績": {
      const d = new Date(today);
      d.setDate(d.getDate() - 730);
      return d.toISOString();
    }
    case "直近3年の実績": {
      const d = new Date(today);
      d.setDate(d.getDate() - 1095);
      return d.toISOString();
    }
    case "直近5年の実績": {
      const d = new Date(today);
      d.setDate(d.getDate() - 1825);
      return d.toISOString();
    }
    case "直近10年の実績": {
      const d = new Date(today);
      d.setDate(d.getDate() - 3650);
      return d.toISOString();
    }
    default:
      return null; // すべての実績
  }
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    if (SUPABASE_URL === "" || SERVICE_ROLE_KEY === "") {
      throw new Error("Missing Supabase runtime environment variables.");
    }

    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    // Support both GET query params and POST JSON body
    const url = new URL(req.url);
    const isGet = req.method === "GET";
    const body = isGet
      ? ({} as Record<string, unknown>)
      : (await req.json().catch(() => ({}))) as Record<string, unknown>;

    const getParam = (key: string): string | undefined =>
      isGet ? (url.searchParams.get(key) ?? undefined) : undefined;

    const action = (body.action as string | undefined) ?? getParam("action") ?? "get";
    const periodParam = (body.period as string | undefined) ?? getParam("period");
    const limitParam = Number((body.limit as number | undefined) ?? getParam("limit") ?? 200);
    const offsetParam = Number((body.offset as number | undefined) ?? getParam("offset") ?? 0);

    // ---- GET_STATS (absorbed from development-stats) ----
    if (action === "get_stats") {
      const { data: achievements, error: achError } = await admin
        .from("development_achievements")
        .select("id, title, completed_at")
        .order("completed_at", { ascending: false });
      if (achError) throw new Error(achError.message);

      const achievementsList = achievements ?? [];
      const totalAchievements = achievementsList.length;

      const { data: growthPlans } = await admin
        .from("growth_plans")
        .select("competitor_key, completed_count, total_count");
      const growthMap = new Map<string, { completed: number; total: number }>();
      for (const plan of growthPlans ?? []) {
        growthMap.set(plan.competitor_key, { completed: plan.completed_count ?? 0, total: plan.total_count ?? 0 });
      }

      const planProgress = PLANS.map((plan) => {
        const completed = Math.min(totalAchievements, plan.totalTasks);
        return { ...plan, completed, percent: Math.round((completed / plan.totalTasks) * 100) };
      });

      const competitorProgress = COMPETITORS_STATS.map((comp) => {
        const growthData = growthMap.get(comp.key);
        const completed = growthData?.completed ?? Math.min(Math.round(totalAchievements * (comp.totalFeatures / 500)), comp.totalFeatures);
        const total = growthData?.total ?? comp.totalFeatures;
        return { ...comp, completed, total, percent: total > 0 ? Math.round((completed / total) * 100) : 0 };
      });

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

      const { count: userCount } = await admin.from("user_profiles").select("*", { count: "exact", head: true });

      return jsonResponse({
        success: true,
        plans: planProgress,
        competitors: competitorProgress,
        periodStats,
        overview: {
          totalAchievements,
          totalUsers: userCount ?? 0,
          totalEdgeFunctions: 89,
          totalCompetitors: COMPETITORS_STATS.length,
        },
      });
    }

    // ---- ADD ----
    if (action === "add") {
      const title = String(body.title ?? "").trim();
      if (!title) {
        return jsonResponse({ error: "title is required" }, 400);
      }
      // Allow caller to specify a custom completed_at date (e.g. seed scripts)
      const completedAt = body.completed_at
        ? new Date(body.completed_at as string).toISOString()
        : new Date().toISOString();
      const description = String(body.description ?? "").trim() || null;
      const { error } = await admin
        .from("development_achievements")
        .insert({ title, description, completed_at: completedAt });
      if (error) throw new Error(error.message);
      return jsonResponse({ success: true, title, description, completed_at: completedAt });
    }

    // ---- GET ----
    const period = periodParam ?? "すべての実績";
    const since = calcSince(period);
    const limitVal = Math.min(limitParam, 500);
    const offsetVal = offsetParam;

    let query = admin
      .from("development_achievements")
      .select("title, description, completed_at")
      .order("completed_at", { ascending: false })
      .range(offsetVal, offsetVal + limitVal - 1);

    if (since !== null) {
      query = query.gte("completed_at", since);
    }

    const { data, error } = await query;
    if (error) throw new Error(error.message);

    return jsonResponse({ achievements: data ?? [], period, offset: offsetVal, limit: limitVal });
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    return jsonResponse({ error: message, achievements: [] }, 500);
  }
});

function jsonResponse(payload: unknown, status = 200): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
