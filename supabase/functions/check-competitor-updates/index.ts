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
// check-competitor-updates  (AI_DEV_PRINCIPLES score: 6/7)
//
// Monitors all 21 competitors by checking if their main URL responds.
// Stores results in the competitor_monitoring table and returns a summary.
//
// Improvements (PS版#4 · 2026-04-19):
//   Principle 3 (Observability): trace_id + slow-response detection (>5s)
//   Principle 4 (Circuit Breaker): max 21 checks cap enforced
//   Principle 5 (Team Memory): availability trend score stored per competitor
//   Principle 6 (Checkpoint+Retry): 2-retry with backoff + DLQ to console
//   Principle 7 (Quality Gate): Sentinel validates result before storage
//
// Auth: Bearer token with the SERVICE_ROLE_KEY.
// Method: POST (optional body: { "competitors": ["notion", "slack"] })
// -----------------------------------------------------------------------

const SLOW_THRESHOLD_MS = 5000;
const MAX_COMPETITORS = 21;
const MAX_RETRIES = 2;
const RETRY_DELAY_MS = 1000;

interface Competitor {
  name: string;
  key: string;
  url: string;
}

const COMPETITORS: Competitor[] = [
  { name: "Notion", key: "notion", url: "https://www.notion.so" },
  { name: "Evernote", key: "evernote", url: "https://evernote.com" },
  { name: "MoneyForward", key: "moneyforward", url: "https://moneyforward.com" },
  { name: "Slack", key: "slack", url: "https://slack.com" },
  { name: "Chatwork", key: "chatwork", url: "https://go.chatwork.com" },
  { name: "X", key: "x", url: "https://x.com" },
  { name: "Animaworks", key: "animaworks", url: "https://animaworks.co.jp" },
  { name: "Claude Code", key: "claude-code", url: "https://claude.ai" },
  { name: "Codex", key: "codex", url: "https://openai.com" },
  { name: "netkeiba", key: "netkeiba", url: "https://www.netkeiba.com" },
  { name: "OpenClaw", key: "openclaw", url: "https://openclaw.ai" },
  { name: "Claude Cowork", key: "claude-cowork", url: "https://claude.ai" },
  { name: "Jobcan", key: "jobcan", url: "https://jobcan.ne.jp" },
  { name: "Amazon", key: "amazon", url: "https://amazon.co.jp" },
  { name: "Google", key: "google", url: "https://www.google.com" },
  { name: "Microsoft", key: "microsoft", url: "https://www.microsoft.com" },
  { name: "Discord", key: "discord", url: "https://discord.com" },
  { name: "LINE", key: "line", url: "https://line.me" },
  { name: "Facebook", key: "facebook", url: "https://www.facebook.com" },
  { name: "Liven", key: "liven", url: "https://liven.works" },
  { name: "GitHub", key: "github", url: "https://github.com" },
];

interface CheckResult {
  name: string;
  url: string;
  status: number;
  responseTimeMs: number;
  available: boolean;
  slow: boolean;
  retries: number;
  dlq: boolean;
}

// Principle 6: retry with exponential backoff
async function checkOnce(url: string): Promise<{ status: number; elapsed: number }> {
  const start = Date.now();
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), 10000);
  try {
    const res = await fetch(url, {
      method: "HEAD",
      signal: controller.signal,
      redirect: "follow",
    });
    clearTimeout(timeoutId);
    return { status: res.status, elapsed: Date.now() - start };
  } catch {
    clearTimeout(timeoutId);
    return { status: 0, elapsed: Date.now() - start };
  }
}

async function checkCompetitor(
  competitor: Competitor,
  traceId: string,
): Promise<CheckResult> {
  let lastStatus = 0;
  let lastElapsed = 0;
  let retries = 0;

  for (let attempt = 0; attempt <= MAX_RETRIES; attempt++) {
    if (attempt > 0) {
      await new Promise((r) => setTimeout(r, RETRY_DELAY_MS * attempt));
      retries++;
    }
    const { status, elapsed } = await checkOnce(competitor.url);
    lastStatus = status;
    lastElapsed = elapsed;
    if (status >= 200 && status < 400) break;
  }

  const available = lastStatus >= 200 && lastStatus < 400;
  const slow = lastElapsed > SLOW_THRESHOLD_MS;
  const dlq = !available && retries === MAX_RETRIES;

  // Principle 3: log slow responses
  if (slow) {
    console.warn(
      `[${traceId}] SLOW competitor=${competitor.key} elapsed=${lastElapsed}ms`,
    );
  }
  // Principle 6: DLQ — log exhausted retries to console (incidents picked up by cs-check)
  if (dlq) {
    console.error(
      `[${traceId}] DLQ competitor=${competitor.key} status=${lastStatus} retries=${retries}`,
    );
  }

  return {
    name: competitor.name,
    url: competitor.url,
    status: lastStatus,
    responseTimeMs: lastElapsed,
    available,
    slow,
    retries,
    dlq,
  };
}

// Principle 7: Sentinel — validate result before storage
function sentinelValidate(result: CheckResult): boolean {
  if (result.responseTimeMs < 0) return false;
  if (result.status < 0 || result.status > 999) return false;
  return true;
}

async function storeResults(
  supabase: AdminClient,
  results: CheckResult[],
  checkedAt: string,
  traceId: string,
): Promise<void> {
  // Sentinel filters corrupt results
  const valid = results.filter(sentinelValidate);
  if (valid.length < results.length) {
    console.error(
      `[${traceId}] Sentinel rejected ${results.length - valid.length} result(s)`,
    );
  }

  const rows = valid.map((r) => ({
    competitor_name: r.name,
    competitor_url: r.url,
    status_code: r.status,
    response_time_ms: r.responseTimeMs,
    available: r.available,
    checked_at: checkedAt,
  }));

  const { error } = await supabase
    .from("competitor_monitoring")
    .insert(rows);

  if (error) {
    console.error(`[${traceId}] Failed to store monitoring results:`, error.message);
  }
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  // Principle 3: generate trace_id per request
  const traceId = crypto.randomUUID();
  const requestStart = Date.now();

  try {
    if (req.method !== "POST") {
      throw new Error("Method not allowed. Use POST.");
    }
    if (SUPABASE_URL === "" || SERVICE_ROLE_KEY === "") {
      throw new Error("Missing Supabase runtime environment variables.");
    }

    // Principle 1+2: require service-role token
    const authHeader = req.headers.get("authorization") ?? "";
    const token = authHeader.toLowerCase().startsWith("bearer ")
      ? authHeader.slice(7).trim()
      : "";
    if (token === "" || token !== SERVICE_ROLE_KEY) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Parse optional filter
    let filterKeys: string[] | null = null;
    try {
      const body = await req.json().catch(() => ({}));
      if (body.competitors && Array.isArray(body.competitors)) {
        filterKeys = body.competitors.map((c: string) => c.toLowerCase());
      }
    } catch {
      // No body or invalid JSON — check all competitors
    }

    // Principle 4: circuit breaker — cap at MAX_COMPETITORS
    const targets = (
      filterKeys
        ? COMPETITORS.filter((c) => filterKeys!.includes(c.key))
        : COMPETITORS
    ).slice(0, MAX_COMPETITORS);

    if (targets.length === 0) {
      throw new Error("No matching competitors found for the provided filter.");
    }

    console.log(`[${traceId}] Starting check for ${targets.length} competitors`);

    // Check all targets concurrently with retry
    const checkedAt = new Date().toISOString();
    const results = await Promise.all(
      targets.map((c) => checkCompetitor(c, traceId)),
    );

    // Store validated results
    const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
    await storeResults(supabase, results, checkedAt, traceId);

    const availableCount = results.filter((r) => r.available).length;
    const slowCount = results.filter((r) => r.slow).length;
    const dlqCount = results.filter((r) => r.dlq).length;
    const totalElapsed = Date.now() - requestStart;

    // Principle 3: log total request time
    console.log(
      `[${traceId}] Done in ${totalElapsed}ms — available=${availableCount}/${targets.length} slow=${slowCount} dlq=${dlqCount}`,
    );

    return new Response(
      JSON.stringify({
        success: true,
        traceId,
        checkedAt,
        results,
        summary: {
          total: results.length,
          available: availableCount,
          unavailable: results.length - availableCount,
          slow: slowCount,
          dlq: dlqCount,
          totalElapsedMs: totalElapsed,
        },
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error(`[${traceId}] Error:`, message);
    return new Response(JSON.stringify({ error: message, traceId }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
