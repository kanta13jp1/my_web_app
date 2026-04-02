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

// -----------------------------------------------------------------------
// get-competitor-monitoring
//
// Returns the latest competitor monitoring results from the
// competitor_monitoring table.
//
// GET  ?limit=14  — latest results for each competitor (default limit 14)
// GET  ?days=7    — results from the past N days (default 7)
//
// Auth: anon key (read-only access via RLS) or service role key.
// No JWT verification required (--no-verify-jwt).
// -----------------------------------------------------------------------

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Flutter の functions.invoke() はデフォルトで POST を送るため、
    // GET と POST の両方を許可する
    if (req.method !== "GET" && req.method !== "POST") {
      return new Response(JSON.stringify({ error: "Method not allowed" }), {
        status: 405,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (SUPABASE_URL === "") {
      throw new Error("Missing SUPABASE_URL environment variable.");
    }

    const url = new URL(req.url);
    const limitParam = url.searchParams.get("limit");
    const daysParam = url.searchParams.get("days");
    const competitorParam = url.searchParams.get("competitor");

    const limit = limitParam ? Math.min(parseInt(limitParam, 10), 100) : 50;
    const days = daysParam ? parseInt(daysParam, 10) : 7;

    // Use service role if available, otherwise anon
    const key = SERVICE_ROLE_KEY !== "" ? SERVICE_ROLE_KEY : SUPABASE_ANON_KEY;
    const supabase = createClient(SUPABASE_URL, key);

    const since = new Date(Date.now() - days * 24 * 60 * 60 * 1000).toISOString();

    let query = supabase
      .from("competitor_monitoring")
      .select("*")
      .gte("checked_at", since)
      .order("checked_at", { ascending: false })
      .limit(limit);

    if (competitorParam) {
      query = query.eq("competitor_key", competitorParam);
    }

    const { data, error } = await query;

    if (error) {
      throw new Error(`DB error: ${error.message}`);
    }

    // Aggregate latest result per competitor
    const latestByCompetitor: Record<string, {
      key: string;
      name: string;
      available: boolean;
      latency_ms: number | null;
      status_code: number | null;
      checked_at: string;
      error?: string;
    }> = {};

    for (const row of data ?? []) {
      const key = row.competitor_key as string;
      if (!latestByCompetitor[key]) {
        latestByCompetitor[key] = {
          key,
          name: row.competitor_name ?? key,
          available: row.available ?? false,
          latency_ms: row.latency_ms ?? null,
          status_code: row.status_code ?? null,
          checked_at: row.checked_at,
          error: row.error_message ?? undefined,
        };
      }
    }

    const competitors = Object.values(latestByCompetitor);
    const availableCount = competitors.filter((c) => c.available).length;

    return new Response(
      JSON.stringify({
        success: true,
        since,
        competitors,
        summary: {
          total: competitors.length,
          available: availableCount,
          unavailable: competitors.length - availableCount,
          availabilityPct: competitors.length > 0
            ? Math.round((availableCount / competitors.length) * 100)
            : 0,
        },
        rawRows: data?.length ?? 0,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return new Response(JSON.stringify({ error: message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
