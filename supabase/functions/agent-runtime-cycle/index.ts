import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-cron-token",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";
const CRON_SECRET = Deno.env.get("AGENT_RUNTIME_CRON_SECRET") ?? "";

type RuntimeMode = "cycle" | "heartbeat" | "nightly" | "forgetting";

interface RuntimeRequest {
  mode?: RuntimeMode;
  userId?: string | null;
  runNightly?: boolean;
  runForgetting?: boolean;
  retentionDays?: number;
}

function asBoolean(value: unknown, fallback: boolean): boolean {
  if (typeof value === "boolean") return value;
  if (typeof value === "string") {
    if (value.toLowerCase() == "true") return true;
    if (value.toLowerCase() == "false") return false;
  }
  return fallback;
}

function asNumber(value: unknown, fallback: number): number {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string") {
    const parsed = Number.parseInt(value, 10);
    if (Number.isFinite(parsed)) return parsed;
  }
  return fallback;
}

function extractCronToken(req: Request): string {
  const tokenFromHeader = req.headers.get("x-cron-token");
  if (tokenFromHeader != null && tokenFromHeader.trim() != "") {
    return tokenFromHeader.trim();
  }
  const auth = req.headers.get("authorization") ?? "";
  if (auth.toLowerCase().startsWith("bearer ")) {
    return auth.slice(7).trim();
  }
  return "";
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ success: false, error: "Method not allowed" }), {
      status: 405,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  if (SUPABASE_URL === "" || SERVICE_ROLE_KEY === "") {
    return new Response(
      JSON.stringify({ success: false, error: "Missing Supabase runtime env vars" }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }

  const token = extractCronToken(req);
  if (CRON_SECRET === "" || token !== CRON_SECRET) {
    return new Response(JSON.stringify({ success: false, error: "Unauthorized" }), {
      status: 401,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  try {
    const body = (await req.json().catch(() => ({}))) as RuntimeRequest;
    const mode: RuntimeMode = body.mode ?? "cycle";
    const userId = body.userId ?? null;
    const runNightly = asBoolean(body.runNightly, false);
    const runForgetting = asBoolean(body.runForgetting, false);
    const retentionDays = Math.max(1, asNumber(body.retentionDays, 30));

    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    let result: unknown;
    if (mode === "heartbeat") {
      const { data, error } = await admin.rpc("run_agent_heartbeat", {
        p_user_id: userId,
      });
      if (error) throw error;
      result = data;
    } else if (mode === "nightly") {
      const { data, error } = await admin.rpc("run_agent_nightly_consolidation", {
        p_user_id: userId,
      });
      if (error) throw error;
      result = data;
    } else if (mode === "forgetting") {
      const { data, error } = await admin.rpc("run_agent_memory_forgetting", {
        p_user_id: userId,
        p_retention_days: retentionDays,
      });
      if (error) throw error;
      result = data;
    } else {
      const { data, error } = await admin.rpc("run_agent_runtime_cycle", {
        p_user_id: userId,
        p_run_nightly: runNightly,
        p_run_forgetting: runForgetting,
      });
      if (error) throw error;
      result = data;
    }

    return new Response(
      JSON.stringify({
        success: true,
        mode,
        user_id: userId,
        result,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    return new Response(JSON.stringify({ success: false, error: message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
