// health-check
// Infra health check endpoint called by the automated scheduled task.
// Checks: DB connectivity, key table accessibility, EF runtime env.
// Returns: { status: "healthy"|"degraded"|"unhealthy", checks: {...}, timestamp }
// Auth: public endpoint (no sensitive data returned — only boolean connectivity status).

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
import { requestTraceId } from "../_shared/trace_context.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, traceparent, tracestate, baggage, sentry-trace",
  "Access-Control-Max-Age": "86400",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

type CheckResult = {
  ok: boolean;
  latencyMs?: number;
  detail?: string;
};

type HealthResponse = {
  status: "healthy" | "degraded" | "unhealthy";
  checks: Record<string, CheckResult>;
  trace_id: string;
  timestamp: string;
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const traceId = requestTraceId(req);
  const checks: Record<string, CheckResult> = {};
  let failCount = 0;

  // Check 1: env vars present
  checks["env"] = {
    ok: SUPABASE_URL !== "" && SERVICE_ROLE_KEY !== "",
    detail: SUPABASE_URL !== "" && SERVICE_ROLE_KEY !== ""
      ? "SUPABASE_URL + SERVICE_ROLE_KEY set"
      : "missing env vars",
  };
  if (!checks["env"].ok) failCount++;

  // Check 2: DB connectivity via profiles table count
  if (checks["env"].ok) {
    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    const t0 = Date.now();
    const { error: dbError } = await admin
      .from("profiles")
      .select("id", { count: "exact", head: true });
    const latencyMs = Date.now() - t0;

    checks["db_connectivity"] = {
      ok: !dbError,
      latencyMs,
      detail: dbError
        ? dbError.message
        : `profiles reachable in ${latencyMs}ms`,
    };
    if (!checks["db_connectivity"].ok) failCount++;

    // Check 3: wbs_tasks table (WBS sync depends on this)
    const { error: wbsError } = await admin
      .from("wbs_tasks")
      .select("id", { count: "exact", head: true });
    checks["wbs_tasks"] = {
      ok: !wbsError,
      detail: wbsError ? wbsError.message : "wbs_tasks reachable",
    };
    if (!checks["wbs_tasks"].ok) failCount++;

    // Check 4: ai_circuit_breaker table (PK is "provider", no "id" column)
    const { error: cbError } = await admin
      .from("ai_circuit_breaker")
      .select("provider", { count: "exact", head: true });
    checks["ai_circuit_breaker"] = {
      ok: !cbError,
      detail: cbError ? cbError.message : "ai_circuit_breaker reachable",
    };
    if (!checks["ai_circuit_breaker"].ok) failCount++;

    // Check 5: session hygiene cleanup visibility (#2910)
    const { data: hygieneData, error: hygieneError } = await admin.rpc(
      "get_session_hygiene_health",
    );
    const hygieneStatus = typeof hygieneData === "object" &&
        hygieneData !== null &&
        "status" in hygieneData
      ? String((hygieneData as { status?: unknown }).status)
      : "unknown";
    checks["session_hygiene"] = {
      ok: !hygieneError && hygieneStatus !== "unhealthy",
      detail: hygieneError
        ? hygieneError.message
        : `session hygiene ${hygieneStatus}`,
    };
    if (!checks["session_hygiene"].ok) failCount++;
  }

  const status: HealthResponse["status"] = failCount === 0
    ? "healthy"
    : failCount <= 1
    ? "degraded"
    : "unhealthy";

  const body: HealthResponse = {
    status,
    checks,
    trace_id: traceId,
    timestamp: new Date().toISOString(),
  };

  console.log(JSON.stringify({
    event: "health_check.completed",
    trace_id: traceId,
    status,
    failure_count: failCount,
  }));

  return new Response(JSON.stringify(body, null, 2), {
    status: 200,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
      "X-Trace-Id": traceId,
    },
  });
});
