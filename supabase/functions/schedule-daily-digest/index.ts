import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { authorizeAutomationActor } from "../_shared/automation-auth.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

// deno-lint-ignore no-explicit-any
type AdminClient = any;

// -----------------------------------------------------------------------
// schedule-daily-digest
//
// Returns today's key metrics as a JSON payload for Claude Code Schedule
// to call via WebFetch. Claude processes the result and writes a daily
// progress report to docs/daily-reports/YYYY-MM-DD.md, then commits it.
//
// Auth: Bearer token with the SERVICE_ROLE_KEY (set in CLAUDE.md schedule
//       instructions as the SUPABASE_SERVICE_KEY secret).
// -----------------------------------------------------------------------

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    if (req.method !== "GET" && req.method !== "POST") {
      throw new Error("Method not allowed. Use GET or POST.");
    }
    if (SUPABASE_URL === "" || SERVICE_ROLE_KEY === "") {
      throw new Error("Missing Supabase runtime environment variables.");
    }

    const admin: AdminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: { autoRefreshToken: false, persistSession: false },
    });
    await authorizeAutomationActor(admin, req);

    const today = fmtDate(new Date());
    const yesterday = fmtDate(new Date(Date.now() - 86_400_000));

    // ---- Run queries in parallel ----------------------------------------
    const [
      userListResult,
      featureRequestsResult,
      openFRResult,
      achievementsResult,
      growthPlansResult,
      blogStatsResult,
      streakStatsResult,
    ] = await Promise.all([
      // Total + new users today
      admin.auth.admin.listUsers({ perPage: 1 }),
      // Feature requests submitted today
      admin
        .from("feature_requests")
        .select("id, title, status, created_at", { count: "exact" })
        .gte("created_at", `${today}T00:00:00.000Z`)
        .lte("created_at", `${today}T23:59:59.999Z`),
      // All open feature requests (pending)
      admin
        .from("feature_requests")
        .select("id, title, status, votes, created_at", { count: "exact" })
        .eq("status", "open")
        .order("votes", { ascending: false })
        .limit(10),
      // Recent achievements (last 7 days)
      admin
        .from("development_achievements")
        .select("title, description, completed_at")
        .gte("completed_at", yesterday)
        .order("completed_at", { ascending: false })
        .limit(20),
      // Top growth plan progress (competitors)
      admin
        .from("growth_plans")
        .select("name, current_value, target_value, plan_type")
        .eq("plan_type", "users")
        .order("sort_order", { ascending: true })
        .limit(5),
      // Blog posts published today
      admin
        .from("blog_posts")
        .select("title, status, target_platforms, created_at", { count: "exact" })
        .gte("created_at", `${today}T00:00:00.000Z`)
        .lte("created_at", `${today}T23:59:59.999Z`),
      // User streak summary (top streaks)
      admin
        .from("user_stats")
        .select("user_id, current_streak, last_output_at")
        .gt("current_streak", 0)
        .order("current_streak", { ascending: false })
        .limit(5),
    ]);

    const totalUsers: number =
      (userListResult.data?.total as number | undefined) ?? 0;

    const newRequestsToday: number = featureRequestsResult.count ?? 0;
    const newRequestsTodayList: Array<{
      title: string;
      status: string;
    }> = (featureRequestsResult.data ?? []).map(
      (r: Record<string, unknown>) => ({
        title: String(r["title"] ?? ""),
        status: String(r["status"] ?? ""),
      }),
    );

    const openFRCount: number = openFRResult.count ?? 0;
    const topOpenFR: Array<{ title: string; votes: number }> = (
      openFRResult.data ?? []
    ).map((r: Record<string, unknown>) => ({
      title: String(r["title"] ?? ""),
      votes: Number(r["votes"] ?? 0),
    }));

    const recentAchievements: Array<{
      title: string;
      description: string;
      completed_at: string;
    }> = (achievementsResult.data ?? []).map(
      (r: Record<string, unknown>) => ({
        title: String(r["title"] ?? ""),
        description: String(r["description"] ?? ""),
        completed_at: String(r["completed_at"] ?? ""),
      }),
    );

    const userGrowthPlans: Array<{
      name: string;
      current: number;
      target: number;
    }> = (growthPlansResult.data ?? []).map(
      (r: Record<string, unknown>) => ({
        name: String(r["name"] ?? ""),
        current: Number(r["current_value"] ?? 0),
        target: Number(r["target_value"] ?? 0),
      }),
    );

    const blogPostsToday: number = blogStatsResult.count ?? 0;
    const blogPostsTodayList: Array<{ title: string; status: string }> = (
      blogStatsResult.data ?? []
    ).map((r: Record<string, unknown>) => ({
      title: String(r["title"] ?? ""),
      status: String(r["status"] ?? ""),
    }));

    const topStreaks: Array<{ user_id: string; streak: number; lastOutputAt: string | null }> = (
      streakStatsResult.data ?? []
    ).map((r: Record<string, unknown>) => ({
      user_id: String(r["user_id"] ?? ""),
      streak: Number(r["current_streak"] ?? 0),
      lastOutputAt: r["last_output_at"] ? String(r["last_output_at"]) : null,
    }));

    const digest = {
      generatedAt: new Date().toISOString(),
      date: today,
      users: {
        total: totalUsers,
      },
      featureRequests: {
        newToday: newRequestsToday,
        newTodayList: newRequestsTodayList,
        openCount: openFRCount,
        topOpen: topOpenFR,
      },
      recentAchievements,
      userGrowthPlans,
      blog: {
        postsToday: blogPostsToday,
        postsTodayList: blogPostsTodayList,
      },
      streaks: {
        topStreaks,
      },
    };

    return new Response(JSON.stringify({ success: true, digest }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    return new Response(JSON.stringify({ success: false, error: message }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});

function fmtDate(d: Date): string {
  const y = String(d.getFullYear()).padStart(4, "0");
  const m = String(d.getMonth() + 1).padStart(2, "0");
  const day = String(d.getDate()).padStart(2, "0");
  return `${y}-${m}-${day}`;
}
