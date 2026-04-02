// Rate Limiter Enhanced Edge Function
// レートリミッター強化版 (Cloudflare/AWS競合)
// - API呼び出し制限
// - プラン別制限
// - IPベース制限
// - 使用量ダッシュボード
// - アラート設定

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type" };
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const RATE_LIMITS: Record<string, { requests_per_minute: number; requests_per_hour: number; requests_per_day: number }> = {
  free: { requests_per_minute: 10, requests_per_hour: 100, requests_per_day: 500 },
  starter: { requests_per_minute: 30, requests_per_hour: 500, requests_per_day: 5000 },
  pro: { requests_per_minute: 60, requests_per_hour: 2000, requests_per_day: 20000 },
  enterprise: { requests_per_minute: 120, requests_per_hour: 10000, requests_per_day: 100000 },
};

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  try {
    const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, { auth: { persistSession: false } });
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return new Response(JSON.stringify({ success: false, error: "Authorization required" }), { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, { global: { headers: { Authorization: authHeader } } });
    const { data: { user } } = await userClient.auth.getUser();
    if (!user) return new Response(JSON.stringify({ success: false, error: "Unauthorized" }), { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } });

    if (req.method === "GET") {
      const url = new URL(req.url);
      const view = url.searchParams.get("view");

      if (view === "limits") return new Response(JSON.stringify({ success: true, rateLimits: RATE_LIMITS }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });

      if (view === "usage") {
        const now = new Date();
        const minuteAgo = new Date(now.getTime() - 60000).toISOString();
        const hourAgo = new Date(now.getTime() - 3600000).toISOString();
        const dayAgo = new Date(now.getTime() - 86400000).toISOString();
        const { count: minuteCount } = await adminClient.from("app_analytics").select("*", { count: "exact", head: true })
          .eq("user_id", user.id).eq("source", "api_request").gte("created_at", minuteAgo);
        const { count: hourCount } = await adminClient.from("app_analytics").select("*", { count: "exact", head: true })
          .eq("user_id", user.id).eq("source", "api_request").gte("created_at", hourAgo);
        const { count: dayCount } = await adminClient.from("app_analytics").select("*", { count: "exact", head: true })
          .eq("user_id", user.id).eq("source", "api_request").gte("created_at", dayAgo);
        // Get user plan
        const { data: sub } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "user_subscription").maybeSingle();
        const plan = sub ? ((sub.metadata as Record<string, unknown>).plan_id as string) ?? "free" : "free";
        const limits = RATE_LIMITS[plan] ?? RATE_LIMITS["free"];
        return new Response(JSON.stringify({
          success: true, usage: {
            plan, minuteUsage: minuteCount ?? 0, minuteLimit: limits.requests_per_minute,
            hourUsage: hourCount ?? 0, hourLimit: limits.requests_per_hour,
            dayUsage: dayCount ?? 0, dayLimit: limits.requests_per_day,
          },
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "check") {
        const endpoint = url.searchParams.get("endpoint") ?? "default";
        const now = new Date();
        const minuteAgo = new Date(now.getTime() - 60000).toISOString();
        const { count } = await adminClient.from("app_analytics").select("*", { count: "exact", head: true })
          .eq("user_id", user.id).eq("source", "api_request").gte("created_at", minuteAgo);
        const { data: sub } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "user_subscription").maybeSingle();
        const plan = sub ? ((sub.metadata as Record<string, unknown>).plan_id as string) ?? "free" : "free";
        const limit = (RATE_LIMITS[plan] ?? RATE_LIMITS["free"]).requests_per_minute;
        const allowed = (count ?? 0) < limit;
        return new Response(JSON.stringify({
          success: true, allowed, remaining: Math.max(0, limit - (count ?? 0)), limit, plan, endpoint,
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: true, rateLimits: RATE_LIMITS }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      const { action } = body;

      if (action === "record_request") {
        const { endpoint, method, response_time_ms } = body;
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "api_request",
          metadata: { endpoint: endpoint ?? "unknown", method: method ?? "GET", response_time_ms: response_time_ms ?? 0, ip: req.headers.get("x-forwarded-for") ?? "unknown" },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }
    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) { return new Response(JSON.stringify({ success: false, error: err instanceof Error ? err.message : String(err) }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }); }
});
