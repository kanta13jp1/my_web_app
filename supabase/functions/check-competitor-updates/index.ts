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
// check-competitor-updates
//
// Monitors all 21 competitors by checking if their main URL responds.
// Stores results in the competitor_monitoring table and returns a summary.
//
// Auth: Bearer token with the SERVICE_ROLE_KEY.
// Method: POST (optional body: { "competitors": ["notion", "slack"] })
// -----------------------------------------------------------------------

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
}

async function checkCompetitor(competitor: Competitor): Promise<CheckResult> {
  const start = Date.now();
  try {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 10000);
    const res = await fetch(competitor.url, {
      method: "HEAD",
      signal: controller.signal,
      redirect: "follow",
    });
    clearTimeout(timeoutId);
    const elapsed = Date.now() - start;
    return {
      name: competitor.name,
      url: competitor.url,
      status: res.status,
      responseTimeMs: elapsed,
      available: res.status >= 200 && res.status < 400,
    };
  } catch (_err) {
    const elapsed = Date.now() - start;
    return {
      name: competitor.name,
      url: competitor.url,
      status: 0,
      responseTimeMs: elapsed,
      available: false,
    };
  }
}

async function storeResults(
  supabase: AdminClient,
  results: CheckResult[],
  checkedAt: string,
): Promise<void> {
  const rows = results.map((r) => ({
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
    console.error("Failed to store monitoring results:", error.message);
  }
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    if (req.method !== "POST") {
      throw new Error("Method not allowed. Use POST.");
    }
    if (SUPABASE_URL === "" || SERVICE_ROLE_KEY === "") {
      throw new Error("Missing Supabase runtime environment variables.");
    }

    // Require service-role token
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

    // Determine which competitors to check
    const targets = filterKeys
      ? COMPETITORS.filter((c) => filterKeys!.includes(c.key))
      : COMPETITORS;

    if (targets.length === 0) {
      throw new Error(
        "No matching competitors found for the provided filter.",
      );
    }

    // Check all targets concurrently
    const checkedAt = new Date().toISOString();
    const results = await Promise.all(targets.map(checkCompetitor));

    // Store in database
    const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
    await storeResults(supabase, results, checkedAt);

    const availableCount = results.filter((r) => r.available).length;

    return new Response(
      JSON.stringify({
        success: true,
        checkedAt,
        results,
        summary: {
          total: results.length,
          available: availableCount,
          unavailable: results.length - availableCount,
        },
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return new Response(JSON.stringify({ error: message }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
