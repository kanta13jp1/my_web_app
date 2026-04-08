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
// All checks run in parallel via Promise.all for minimal latency.
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
    if (req.method !== "GET" && req.method !== "POST") {
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

    const FIREBASE_URL = "https://my-web-app-b67f4.web.app/";

    // --- Run all checks in parallel for minimal response latency ---
    const dbStart = Date.now();
    const [
      dbResult,
      tableCheckResults,
      achievementsResult,
      firebaseResult,
    ] = await Promise.all([
      // Check 1: DB connectivity (user_profiles count + latency)
      supabase
        .from("user_profiles")
        .select("*", { count: "exact", head: true }),
      // Check 2: All required tables accessibility in parallel
      Promise.all(
        (REQUIRED_TABLES as readonly string[]).map(async (table: string) => {
          const { error } = await supabase
            .from(table)
            .select("*", { count: "exact", head: true });
          return { table, ok: !error };
        }),
      ),
      // Check 3: Achievements count
      supabase
        .from("development_achievements")
        .select("*", { count: "exact", head: true }),
      // Check 4: Firebase Hosting availability
      (async () => {
        const start = Date.now();
        try {
          const res = await fetch(FIREBASE_URL, {
            method: "HEAD",
            signal: AbortSignal.timeout(10_000),
          });
          return { ok: res.ok, status: res.status, latencyMs: Date.now() - start };
        } catch (e) {
          return { ok: false, status: 0, latencyMs: Date.now() - start, error: String(e) };
        }
      })(),
    ]);
    const dbLatency = Date.now() - dbStart;

    // --- Aggregate DB check ---
    const dbCheck = dbResult.error
      ? { status: "error" as const, error: String(dbResult.error.message), latencyMs: dbLatency }
      : { status: "ok" as const, latencyMs: dbLatency };

    // --- Aggregate table checks ---
    const accessibleTables: string[] = tableCheckResults
      .filter((r: { table: string; ok: boolean }) => r.ok)
      .map((r: { table: string; ok: boolean }) => r.table);
    const inaccessibleTables: string[] = tableCheckResults
      .filter((r: { table: string; ok: boolean }) => !r.ok)
      .map((r: { table: string; ok: boolean }) => r.table);

    const tablesCheck = inaccessibleTables.length === 0
      ? { status: "ok" as const, accessible: accessibleTables }
      : {
        status: "degraded" as const,
        accessible: accessibleTables,
        inaccessible: inaccessibleTables,
      };

    // --- Overall status ---
    let overallStatus: "healthy" | "degraded" | "unhealthy" = "healthy";
    if (dbResult.error) {
      overallStatus = "unhealthy";
    } else if (inaccessibleTables.length > 0 || !firebaseResult.ok) {
      overallStatus = "degraded";
    }

    // --- Build response ---
    const result = {
      status: overallStatus,
      timestamp: new Date().toISOString(),
      checks: {
        database: dbCheck,
        tables: tablesCheck,
        userCount: (dbResult.count as number | null) ?? 0,
        achievementsCount: (achievementsResult.count as number | null) ?? 0,
        hosting: firebaseResult.ok
          ? { status: "ok" as const, latencyMs: firebaseResult.latencyMs }
          : {
            status: "error" as const,
            httpStatus: firebaseResult.status,
            latencyMs: firebaseResult.latencyMs,
            error: (firebaseResult as { error?: string }).error,
          },
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
