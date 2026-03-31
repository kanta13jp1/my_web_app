// API Rate Limiter Edge Function
// API利用制限・レートリミット管理
// - ユーザー別 / IP別のレート制限
// - プラン別制限値設定
// - 制限超過時の通知
//
// GET  → 利用状況 / 制限設定
// POST → リクエスト記録 / 制限チェック

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

// プラン別レート制限
const RATE_LIMITS: Record<string, { requests_per_minute: number; requests_per_hour: number; requests_per_day: number }> = {
  free: { requests_per_minute: 10, requests_per_hour: 100, requests_per_day: 500 },
  pro: { requests_per_minute: 30, requests_per_hour: 500, requests_per_day: 5000 },
  premium: { requests_per_minute: 60, requests_per_hour: 2000, requests_per_day: 20000 },
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: { persistSession: false },
    });

    if (req.method === "GET") {
      const url = new URL(req.url);
      const view = url.searchParams.get("view"); // 'limits' | 'usage' | 'top_users'

      if (view === "limits") {
        return new Response(
          JSON.stringify({ success: true, rateLimits: RATE_LIMITS }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (view === "usage") {
        const authHeader = req.headers.get("Authorization");
        if (!authHeader) {
          return new Response(
            JSON.stringify({ success: false, error: "Authorization required" }),
            { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
          global: { headers: { Authorization: authHeader } },
        });
        const { data: { user } } = await userClient.auth.getUser();
        if (!user) {
          return new Response(
            JSON.stringify({ success: false, error: "Unauthorized" }),
            { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const now = new Date();
        const minuteAgo = new Date(now.getTime() - 60000).toISOString();
        const hourAgo = new Date(now.getTime() - 3600000).toISOString();
        const dayAgo = new Date(now.getTime() - 86400000).toISOString();

        const [minRes, hourRes, dayRes, profileRes] = await Promise.all([
          adminClient.from("app_analytics").select("*", { count: "exact", head: true })
            .eq("user_id", user.id).eq("source", "api_request").gte("created_at", minuteAgo),
          adminClient.from("app_analytics").select("*", { count: "exact", head: true })
            .eq("user_id", user.id).eq("source", "api_request").gte("created_at", hourAgo),
          adminClient.from("app_analytics").select("*", { count: "exact", head: true })
            .eq("user_id", user.id).eq("source", "api_request").gte("created_at", dayAgo),
          adminClient.from("user_profiles").select("subscription_plan").eq("user_id", user.id).maybeSingle(),
        ]);

        const plan = (profileRes.data?.subscription_plan as string) ?? "free";
        const limits = RATE_LIMITS[plan] ?? RATE_LIMITS.free;

        return new Response(
          JSON.stringify({
            success: true,
            usage: {
              plan,
              perMinute: { used: minRes.count ?? 0, limit: limits.requests_per_minute },
              perHour: { used: hourRes.count ?? 0, limit: limits.requests_per_hour },
              perDay: { used: dayRes.count ?? 0, limit: limits.requests_per_day },
            },
          }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      // デフォルト: 全体統計
      const dayAgo = new Date(Date.now() - 86400000).toISOString();
      const { count: totalRequests } = await adminClient
        .from("app_analytics")
        .select("*", { count: "exact", head: true })
        .eq("source", "api_request")
        .gte("created_at", dayAgo);

      return new Response(
        JSON.stringify({
          success: true,
          stats: { totalRequestsLast24h: totalRequests ?? 0 },
          rateLimits: RATE_LIMITS,
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    if (req.method === "POST") {
      const body = await req.json();
      const { action } = body;

      if (action === "check") {
        // レートリミットチェック
        const { user_id, endpoint } = body;
        if (!user_id) {
          return new Response(
            JSON.stringify({ success: false, error: "user_id required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const now = new Date();
        const minuteAgo = new Date(now.getTime() - 60000).toISOString();

        const [countRes, profileRes] = await Promise.all([
          adminClient.from("app_analytics").select("*", { count: "exact", head: true })
            .eq("user_id", user_id).eq("source", "api_request").gte("created_at", minuteAgo),
          adminClient.from("user_profiles").select("subscription_plan").eq("user_id", user_id).maybeSingle(),
        ]);

        const plan = (profileRes.data?.subscription_plan as string) ?? "free";
        const limits = RATE_LIMITS[plan] ?? RATE_LIMITS.free;
        const currentCount = countRes.count ?? 0;
        const allowed = currentCount < limits.requests_per_minute;

        // リクエスト記録
        if (allowed) {
          await adminClient.from("app_analytics").insert({
            user_id,
            source: "api_request",
            metadata: { endpoint: endpoint ?? "unknown" },
            created_at: now.toISOString(),
          });
        }

        return new Response(
          JSON.stringify({
            success: true,
            allowed,
            remaining: Math.max(0, limits.requests_per_minute - currentCount - (allowed ? 1 : 0)),
            limit: limits.requests_per_minute,
            plan,
          }),
          {
            status: allowed ? 200 : 429,
            headers: {
              ...corsHeaders,
              "Content-Type": "application/json",
              "X-RateLimit-Limit": String(limits.requests_per_minute),
              "X-RateLimit-Remaining": String(Math.max(0, limits.requests_per_minute - currentCount - (allowed ? 1 : 0))),
            },
          },
        );
      }

      return new Response(
        JSON.stringify({ success: false, error: "Unknown action" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    return new Response(
      JSON.stringify({ error: "Method not allowed" }),
      { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error("api-rate-limiter error:", err);
    return new Response(
      JSON.stringify({ success: false, error: message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
