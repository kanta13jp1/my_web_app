// get-home-dashboard
// Authenticated endpoint that returns home screen KPI snapshot:
//   - totalUsers, todaySignups (admin-level counts)
//   - todayViews, todayShares, topShareChannel (from app_analytics)
//   - lpStats 7-day series (from get_lp_view_stats RPC)
// Consolidates 3 separate client-side DB calls into a single round-trip.

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
// Serve
// -----------------------------------------------------------------------

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    if (req.method !== "POST") {
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
    const [
      totalUsersResult,
      todaySignupsResult,
      analyticsResult,
      lpStatsResult,
    ] = await Promise.all([
      admin
        .from("user_profiles")
        .select("*", { count: "exact", head: true }),
      admin
        .from("user_profiles")
        .select("*", { count: "exact", head: true })
        .gte("created_at", today.toISOString())
        .lt("created_at", tomorrow.toISOString()),
      admin
        .from("app_analytics")
        .select("date,landing_views,share_count,source_details")
        .eq("date", todayKey)
        .maybeSingle(),
      admin.rpc("get_lp_view_stats"),
    ]);

    // ---- Total users --------------------------------------------------
    const totalUsers = totalUsersResult.count ?? 0;

    // ---- Today signups -----------------------------------------------
    const todaySignups = todaySignupsResult.count ?? 0;

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
          .filter((r): r is Record<string, unknown> => !!r && typeof r === "object")
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

    return jsonResponse({
      success: true,
      totalUsers,
      todaySignups,
      todayViews,
      todayShares: toNumber(analyticsRow["share_count"]),
      topShareChannelKey,
      lpSeries,
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
