// Sitemap & Web Analytics Edge Function
// サイトマップ・Web分析 (Google Analytics/Search Console競合)
// - ページビュー記録
// - リファラー分析
// - デバイス・ブラウザ分析
// - ページ別パフォーマンス
// - コンバージョントラッキング

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const CONVERSION_EVENTS = ["signup", "login", "feature_use", "upgrade", "share", "invite", "purchase"];

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  try {
    const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, { auth: { persistSession: false } });

    if (req.method === "GET") {
      const url = new URL(req.url);
      const view = url.searchParams.get("view");
      const days = parseInt(url.searchParams.get("days") ?? "30", 10);
      const since = new Date(Date.now() - days * 86400000).toISOString();

      if (view === "pageviews") {
        const { data: views } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("source", "pageview").gte("created_at", since)
          .order("created_at", { ascending: true });
        const dailyMap = new Map<string, number>();
        const pageMap = new Map<string, number>();
        for (const v of views ?? []) {
          const date = (v.created_at as string)?.slice(0, 10) ?? "unknown";
          dailyMap.set(date, (dailyMap.get(date) ?? 0) + 1);
          const page = ((v.metadata as Record<string, unknown>).path as string) ?? "/";
          pageMap.set(page, (pageMap.get(page) ?? 0) + 1);
        }
        return new Response(JSON.stringify({
          success: true,
          daily: [...dailyMap.entries()].sort(([a], [b]) => a.localeCompare(b)).map(([date, count]) => ({ date, count })),
          topPages: [...pageMap.entries()].sort(([, a], [, b]) => b - a).slice(0, 20).map(([path, count]) => ({ path, count })),
          totalViews: (views ?? []).length,
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "referrers") {
        const { data: views } = await adminClient.from("app_analytics").select("metadata")
          .eq("source", "pageview").gte("created_at", since);
        const refMap = new Map<string, number>();
        for (const v of views ?? []) {
          const ref = ((v.metadata as Record<string, unknown>).referrer as string) ?? "direct";
          refMap.set(ref, (refMap.get(ref) ?? 0) + 1);
        }
        return new Response(JSON.stringify({
          success: true,
          referrers: [...refMap.entries()].sort(([, a], [, b]) => b - a).map(([referrer, count]) => ({ referrer, count })),
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "devices") {
        const { data: views } = await adminClient.from("app_analytics").select("metadata")
          .eq("source", "pageview").gte("created_at", since);
        const deviceMap = new Map<string, number>();
        const browserMap = new Map<string, number>();
        for (const v of views ?? []) {
          const m = v.metadata as Record<string, unknown>;
          const device = (m.device as string) ?? "unknown";
          const browser = (m.browser as string) ?? "unknown";
          deviceMap.set(device, (deviceMap.get(device) ?? 0) + 1);
          browserMap.set(browser, (browserMap.get(browser) ?? 0) + 1);
        }
        return new Response(JSON.stringify({
          success: true,
          devices: [...deviceMap.entries()].sort(([, a], [, b]) => b - a).map(([device, count]) => ({ device, count })),
          browsers: [...browserMap.entries()].sort(([, a], [, b]) => b - a).map(([browser, count]) => ({ browser, count })),
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "conversions") {
        const { data: events } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("source", "conversion_event").gte("created_at", since);
        const eventMap = new Map<string, number>();
        for (const e of events ?? []) {
          const type = ((e.metadata as Record<string, unknown>).event as string) ?? "unknown";
          eventMap.set(type, (eventMap.get(type) ?? 0) + 1);
        }
        return new Response(JSON.stringify({
          success: true,
          conversions: CONVERSION_EVENTS.map((e) => ({ event: e, count: eventMap.get(e) ?? 0 })),
          totalConversions: (events ?? []).length,
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      // Default overview
      const { data: views } = await adminClient.from("app_analytics").select("metadata")
        .eq("source", "pageview").gte("created_at", since);
      const { data: conversions } = await adminClient.from("app_analytics").select("metadata")
        .eq("source", "conversion_event").gte("created_at", since);
      const uniqueUsers = new Set((views ?? []).map((v) => (v.metadata as Record<string, unknown>).user_id ?? (v.metadata as Record<string, unknown>).session_id)).size;
      return new Response(JSON.stringify({
        success: true, overview: {
          totalPageviews: (views ?? []).length, uniqueVisitors: uniqueUsers,
          totalConversions: (conversions ?? []).length, days,
          conversionRate: (views ?? []).length > 0 ? Math.round(((conversions ?? []).length / (views ?? []).length) * 10000) / 100 : 0,
        },
      }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      const { action } = body;

      if (action === "track_pageview") {
        const { path, referrer, device, browser, session_id, user_id: viewUserId } = body;
        await adminClient.from("app_analytics").insert({
          user_id: viewUserId ?? null, source: "pageview",
          metadata: { path: path ?? "/", referrer: referrer ?? "direct", device: device ?? "unknown", browser: browser ?? "unknown", session_id: session_id ?? crypto.randomUUID() },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "track_conversion") {
        const { event, user_id: convUserId, metadata } = body;
        if (!event) return new Response(JSON.stringify({ success: false, error: "event required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        await adminClient.from("app_analytics").insert({
          user_id: convUserId ?? null, source: "conversion_event",
          metadata: { event, ...(metadata ?? {}) },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    return new Response(JSON.stringify({ success: false, error: err instanceof Error ? err.message : String(err) }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
