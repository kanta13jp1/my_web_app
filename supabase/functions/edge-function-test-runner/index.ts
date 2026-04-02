import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};

// All 100 Tier 1 deployed functions to test
const DEPLOYED_FUNCTIONS = [
  "get-public-memo-preview", "public-memo-share", "memo-reactions", "get-ogp",
  "get-public-memo-ogp", "get-home-dashboard", "note-comments", "notification-center",
  "user-profile-manager", "onboarding-flow", "feature-request-manager",
  "app-analytics-dashboard", "development-achievements", "development-stats", "system-status",
  "growth-weekly-digest", "growth-acquisition-signal", "growth-acquisition-report",
  "growth-command-center", "growth-referral", "growth-share-signal",
  "growth-achievement-summary", "growth-import-preview", "growth-import-commit",
  "get-growth-roadmap-progress", "video-ad-generator", "viral-share-engine",
  "x-media-post", "growth-automation-controller", "landing-ab-test",
  "referral-program", "share-quote", "generate-quote-image", "seo-optimizer",
  "send-waitlist-notification", "viral-ad-generator", "viral-growth-pipeline",
  "viral-video-ad-generator",
  "daily-judgment", "ai-assistant", "ai-search", "ai-suggest-tags", "ai-secretary",
  "ai-summarizer", "agent-runtime-cycle", "agent-personality",
  "agent-department-manager", "agent-task-router", "agent-performance-monitor",
  "virtual-organization",
  "schedule-daily-digest", "schedule-task-monitor", "schedule-health-check",
  "post-x-update", "blog-post-manager", "blog-auto-publisher", "health-check",
  "check-competitor-updates", "get-competitor-monitoring", "edge-function-coverage",
  "get-admin-users", "notify-feature-request", "get-support-tickets",
  "reply-support-request", "get-competitor-features", "competitor-feature-sync",
  "import-from-competitors", "code-review-issues",
  "subscription-management", "subscription-billing", "email-service",
  "gamification-engine", "calendar-events", "kanban-board", "chat-messaging",
  "team-task-manager", "team-collaboration-sync", "file-storage-manager",
  "expense-tracker", "time-tracker", "automation-workflows", "content-moderation",
  "user-activity-tracker", "data-export-manager", "user-feedback-collector",
  "department-reporting", "analyze-reality", "trigger-analysis",
  "ab-testing-manager", "search-analytics", "webhook-manager", "api-rate-limiter",
  "notification-preferences", "revenue-forecaster", "generate-daily-challenges",
  "tag-manager", "template-library", "habit-tracker", "bookmark-manager",
  "invoice-generator",
];

// Functions known to need UI connectivity (no frontend page exists)
// deno-lint-ignore no-unused-vars
const UI_STATUS_CACHE: Record<string, boolean> = {};

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseKey = Deno.env.get("SERVICE_ROLE_KEY") ?? "";
    const supabase = createClient(supabaseUrl, supabaseKey);

    const url = new URL(req.url);
    const action = url.searchParams.get("action") ?? "run_tests";

    if (action === "run_tests") {
      const testSubset = url.searchParams.get("subset"); // "all" or comma-separated names
      const functionsToTest = testSubset && testSubset !== "all"
        ? testSubset.split(",").map(f => f.trim())
        : DEPLOYED_FUNCTIONS;

      const results: Array<{
        name: string;
        status: "pass" | "fail" | "timeout" | "error";
        statusCode: number | null;
        responseTimeMs: number;
        error: string | null;
      }> = [];

      // Test each function with GET request (batch of 10 concurrent)
      const batchSize = 10;
      for (let i = 0; i < functionsToTest.length; i += batchSize) {
        const batch = functionsToTest.slice(i, i + batchSize);
        const batchResults = await Promise.allSettled(
          batch.map(async (fnName) => {
            const start = Date.now();
            try {
              const controller = new AbortController();
              const timeoutId = setTimeout(() => controller.abort(), 8000);

              const resp = await fetch(`${supabaseUrl}/functions/v1/${fnName}`, {
                method: "GET",
                headers: {
                  "Authorization": `Bearer ${supabaseKey}`,
                  "Content-Type": "application/json",
                },
                signal: controller.signal,
              });

              clearTimeout(timeoutId);
              const elapsed = Date.now() - start;

              return {
                name: fnName,
                status: (resp.status >= 200 && resp.status < 500 ? "pass" : "fail") as "pass" | "fail",
                statusCode: resp.status,
                responseTimeMs: elapsed,
                error: resp.status >= 500 ? `HTTP ${resp.status}` : null,
              };
            } catch (err) {
              const elapsed = Date.now() - start;
              const isTimeout = (err as Error).name === "AbortError";
              return {
                name: fnName,
                status: (isTimeout ? "timeout" : "error") as "timeout" | "error",
                statusCode: null,
                responseTimeMs: elapsed,
                error: (err as Error).message,
              };
            }
          })
        );

        for (const result of batchResults) {
          if (result.status === "fulfilled") {
            results.push(result.value);
          }
        }
      }

      const passed = results.filter(r => r.status === "pass").length;
      const failed = results.filter(r => r.status === "fail").length;
      const timeouts = results.filter(r => r.status === "timeout").length;
      const errors = results.filter(r => r.status === "error").length;
      const avgResponseTime = results.length > 0
        ? Math.round(results.reduce((sum, r) => sum + r.responseTimeMs, 0) / results.length)
        : 0;

      // Log results to app_analytics
      await supabase.from("app_analytics").insert({
        source: "edge-function-test-runner",
        metadata: {
          event_type: "test_run",
          totalTested: results.length,
          passed,
          failed,
          timeouts,
          errors,
          avgResponseTimeMs: avgResponseTime,
          failedFunctions: results.filter(r => r.status !== "pass").map(r => r.name),
          executedAt: new Date().toISOString(),
        },
      });

      return new Response(
        JSON.stringify({
          summary: {
            totalTested: results.length,
            passed,
            failed,
            timeouts,
            errors,
            avgResponseTimeMs: avgResponseTime,
            healthScore: results.length > 0 ? Math.round((passed / results.length) * 100) : 0,
          },
          failedFunctions: results.filter(r => r.status !== "pass"),
          allResults: results,
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // action=ui_connectivity — Check which functions have UI pages
    if (action === "ui_connectivity") {
      // Read from app_analytics for UI call records
      const { data: uiCalls } = await supabase
        .from("app_analytics")
        .select("metadata")
        .eq("source", "edge-function-ui-checker")
        .order("created_at", { ascending: false })
        .limit(1);

      const _lastCheck = uiCalls?.[0]?.metadata ?? null;

      // Also check user-activity-tracker for actual function calls from UI
      const { data: activityLogs } = await supabase
        .from("app_analytics")
        .select("source, event_type")
        .gte("created_at", new Date(Date.now() - 7 * 86400000).toISOString())
        .limit(1000);

      const calledSources = new Set(
        (activityLogs ?? []).map((l: Record<string, unknown>) => l.source as string)
      );

      const connectivity = DEPLOYED_FUNCTIONS.map(fn => ({
        name: fn,
        hasUiCalls: calledSources.has(fn),
        lastCalledFromUi: calledSources.has(fn),
      }));

      const withUi = connectivity.filter(c => c.hasUiCalls).length;
      const withoutUi = connectivity.filter(c => !c.hasUiCalls).length;

      return new Response(
        JSON.stringify({
          summary: {
            totalDeployed: DEPLOYED_FUNCTIONS.length,
            withUiConnectivity: withUi,
            withoutUiConnectivity: withoutUi,
            coveragePercent: Math.round((withUi / DEPLOYED_FUNCTIONS.length) * 100),
          },
          needsUiImplementation: connectivity.filter(c => !c.hasUiCalls).map(c => c.name),
          hasUiImplementation: connectivity.filter(c => c.hasUiCalls).map(c => c.name),
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // action=history — past test runs
    if (action === "history") {
      const { data: history } = await supabase
        .from("app_analytics")
        .select("*")
        .eq("source", "edge-function-test-runner")
        .eq("metadata->>event_type", "test_run")
        .order("created_at", { ascending: false })
        .limit(20);

      return new Response(
        JSON.stringify({
          runs: (history ?? []).map((h: Record<string, unknown>) => ({
            ...(h.metadata as Record<string, unknown>),
            createdAt: h.created_at,
          })),
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    return new Response(
      JSON.stringify({
        error: "Unknown action",
        validActions: ["run_tests", "ui_connectivity", "history"],
        deployedFunctionCount: DEPLOYED_FUNCTIONS.length,
      }),
      { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err) {
    return new Response(
      JSON.stringify({ error: (err as Error).message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
