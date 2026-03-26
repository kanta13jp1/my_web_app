import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

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
// health-check
//
// Returns a health status JSON for the application.
// Checks database connectivity, key table accessibility, and counts.
//
// Auth: Bearer token with the SERVICE_ROLE_KEY.
// -----------------------------------------------------------------------

const REQUIRED_TABLES = [
  "user_profiles",
  "notes",
  "development_achievements",
  "feature_requests",
  "growth_plans",
  "tech_blog_posts",
] as const;

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    if (req.method !== "GET") {
      throw new Error("Method not allowed. Use GET.");
    }
    if (SUPABASE_URL === "" || SERVICE_ROLE_KEY === "") {
      throw new Error("Missing Supabase runtime environment variables.");
    }

    // Require service-role token
    const authHeader = req.headers.get("authorization") ?? "";
    if (authHeader !== `Bearer ${SERVICE_ROLE_KEY}`) {
      return new Response(
        JSON.stringify({ error: "Unauthorized" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const supabase: AdminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: { persistSession: false },
    });

    let overallStatus: "healthy" | "degraded" | "unhealthy" = "healthy";

    // --- Check 1: Database connectivity (user_profiles count) ---
    const dbStart = Date.now();
    const { count: userCount, error: dbError } = await supabase
      .from("user_profiles")
      .select("*", { count: "exact", head: true });
    const dbLatency = Date.now() - dbStart;

    const dbCheck = dbError
      ? { status: "error" as const, error: dbError.message, latencyMs: dbLatency }
      : { status: "ok" as const, latencyMs: dbLatency };

    if (dbError) {
      overallStatus = "unhealthy";
    }

    // --- Check 2: Key tables accessibility ---
    const accessibleTables: string[] = [];
    const inaccessibleTables: string[] = [];

    for (const table of REQUIRED_TABLES) {
      const { error: tableError } = await supabase
        .from(table)
        .select("*", { count: "exact", head: true });

      if (tableError) {
        inaccessibleTables.push(table);
      } else {
        accessibleTables.push(table);
      }
    }

    const tablesCheck = inaccessibleTables.length === 0
      ? { status: "ok" as const, accessible: accessibleTables }
      : {
          status: "degraded" as const,
          accessible: accessibleTables,
          inaccessible: inaccessibleTables,
        };

    if (inaccessibleTables.length > 0 && overallStatus === "healthy") {
      overallStatus = "degraded";
    }

    // --- Check 3: Counts ---
    const { count: achievementsCount } = await supabase
      .from("development_achievements")
      .select("*", { count: "exact", head: true });

    // --- Build response ---
    const result = {
      status: overallStatus,
      timestamp: new Date().toISOString(),
      checks: {
        database: dbCheck,
        tables: tablesCheck,
        userCount: userCount ?? 0,
        achievementsCount: achievementsCount ?? 0,
        edgeFunctions: { status: "ok" },
      },
    };

    return new Response(JSON.stringify(result, null, 2), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return new Response(
      JSON.stringify({
        status: "unhealthy",
        timestamp: new Date().toISOString(),
        error: message,
      }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }
});
