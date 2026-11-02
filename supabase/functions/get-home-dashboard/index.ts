// get-home-dashboard
// Authenticated endpoint that returns home screen KPI snapshot:
//   - totalUsers, todaySignups (admin-level counts)
//   - todayViews, todayShares, topShareChannel (from app_analytics)
//   - lpStats 7-day series (from get_lp_view_stats RPC)
// Consolidates 3 separate client-side DB calls into a single round-trip.

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, traceparent, tracestate, baggage, sentry-trace",
  "Access-Control-Max-Age": "86400",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

// -----------------------------------------------------------------------
// Serve
// -----------------------------------------------------------------------

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    if (req.method !== "POST" && req.method !== "GET") {
      throw new Error("Method not allowed.");
    }
    if (SUPABASE_URL === "" || SERVICE_ROLE_KEY === "") {
      throw new Error("Missing Supabase runtime environment variables.");
    }

    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    const today = startOfDayUtc(new Date());
    const todayKey = fmt(today);
    const tomorrow = new Date(today);
    tomorrow.setDate(today.getDate() + 1);

    // ---- Parallel fetches ---------------------------------------------
    // Use auth.admin.listUsers for accurate counts from auth.users,
    // not user_profiles (which may be missing entries for users who
    // registered but never completed profile setup).
    const [
      authUsersResult,
      analyticsResult,
      lpStatsResult,
      recentAchievementsResult,
    ] = await Promise.all([
      admin.auth.admin.listUsers({ page: 1, perPage: 1 }),
      admin
        .from("app_analytics")
        .select("date,landing_views,share_count,source_details")
        .eq("date", todayKey)
        .maybeSingle(),
      admin.rpc("get_lp_view_stats"),
      admin
        .from("development_achievements")
        .select("title, description, completed_at")
        .order("completed_at", { ascending: false })
        .limit(5),
    ]);

    // ---- Total users (from auth.users) --------------------------------
    const totalUsers = authUsersResult.data?.total ?? 0;

    // ---- Today signups (filter from auth users by created_at) ---------
    // Fetch a page with higher perPage to count today's signups.
    // For small user bases this is fine; at scale, move to a DB trigger.
    const todayIso = today.toISOString();
    const tomorrowIso = tomorrow.toISOString();
    let todaySignups = 0;
    try {
      // Fetch all users page by page to find today's signups.
      // This is acceptable at current scale (21 users).
      let page = 1;
      while (true) { // infinite loop with explicit break
        const { data: pageData } = await admin.auth.admin.listUsers({
          page,
          perPage: 100,
        });
        const pageUsers = pageData?.users ?? [];
        if (pageUsers.length === 0) break;
        for (const u of pageUsers) {
          if (u.created_at >= todayIso && u.created_at < tomorrowIso) {
            todaySignups += 1;
          }
        }
        // If returned fewer than 100, we've exhausted all users
        if (pageUsers.length < 100) break;
        page += 1;
      }
    } catch (_) {
      // fall back to 0
    }

    // ---- Analytics row -----------------------------------------------
    const analyticsRow = toMap(analyticsResult.data);
    let todayViews = toNumber(analyticsRow["landing_views"]);
    let lpSeries: Array<{ date: string; count: number }> = [];

    const lpStats = toMap(lpStatsResult.data);
    if (Object.keys(lpStats).length > 0) {
      const fromStats = toNumber(lpStats["today"]);
      if (fromStats > 0) todayViews = fromStats;
      const rawSeries = lpStats["series"];
      if (Array.isArray(rawSeries)) {
        lpSeries = rawSeries
          .filter((r): r is Record<string, unknown> =>
            !!r && typeof r === "object"
          )
          .map((r) => ({
            date: String(r["date"] ?? "").slice(0, 10),
            count: toNumber(r["count"]),
          }))
          .filter((r) => r.date.length >= 10);
        // Fall back to series entry for today if todayViews is still 0
        if (todayViews === 0) {
          const todayEntry = lpSeries.find((r) => r.date === todayKey);
          if (todayEntry) todayViews = todayEntry.count;
        }
      }
    }

    // ---- Top share channel -------------------------------------------
    let topShareChannelKey: string | null = null;
    let topShareChannelCount = 0;
    const sourceDetails = toMap(analyticsRow["source_details"]);
    for (const [key, rawValue] of Object.entries(sourceDetails)) {
      if (!key.startsWith("share_") && key !== "x_share") continue;
      const count = toNumber(rawValue);
      if (count > topShareChannelCount) {
        topShareChannelCount = count;
        topShareChannelKey = key;
      }
    }

    const recentAchievements = (recentAchievementsResult.data ?? []) as Array<{
      title: string;
      description: string | null;
      completed_at: string;
    }>;

    return jsonResponse({
      success: true,
      totalUsers,
      todaySignups,
      todayViews,
      todayShares: toNumber(analyticsRow["share_count"]),
      topShareChannelKey,
      topShareChannelCount,
      lpSeries,
      recentAchievements,
    });
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    return jsonResponse({ success: false, error: message }, 400);
  }
});

// -----------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------

function startOfDayUtc(date: Date): Date {
  const d = new Date(date);
  d.setUTCHours(0, 0, 0, 0);
  return d;
}

function fmt(date: Date): string {
  const y = String(date.getUTCFullYear()).padStart(4, "0");
  const m = String(date.getUTCMonth() + 1).padStart(2, "0");
  const d = String(date.getUTCDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
}

function toMap(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)) return {};
  return value as Record<string, unknown>;
}

function toNumber(value: unknown): number {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string") {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : 0;
  }
  return 0;
}

function jsonResponse(payload: unknown, status = 200): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
