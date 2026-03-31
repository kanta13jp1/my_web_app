// Search Analytics Edge Function
// 検索クエリ分析・トレンド・サジェスト改善
// - ユーザーの検索行動を記録・分析
// - 人気検索ワード / ゼロヒット検索の追跡
// - 検索品質スコア算出
//
// GET  → 検索トレンド / 人気クエリ / ゼロヒット分析
// POST → 検索イベント記録

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
      const view = url.searchParams.get("view"); // 'trending' | 'zero_hits' | 'quality' | 'suggestions'
      const days = parseInt(url.searchParams.get("days") ?? "30", 10);
      const since = new Date(Date.now() - days * 86400000).toISOString();

      // 検索イベントを取得
      const { data: searchEvents } = await adminClient
        .from("app_analytics")
        .select("metadata, created_at, user_id")
        .eq("source", "search")
        .gte("created_at", since)
        .order("created_at", { ascending: false })
        .limit(1000);

      if (view === "trending") {
        // 人気検索ワード
        const queryCount = new Map<string, number>();
        for (const e of searchEvents ?? []) {
          const q = ((e.metadata as Record<string, unknown>)?.query as string)?.toLowerCase() ?? "";
          if (q) queryCount.set(q, (queryCount.get(q) ?? 0) + 1);
        }

        const trending = [...queryCount.entries()]
          .map(([query, count]) => ({ query, count }))
          .sort((a, b) => b.count - a.count)
          .slice(0, 50);

        return new Response(
          JSON.stringify({ success: true, trending, totalSearches: (searchEvents ?? []).length, period: { days, since } }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (view === "zero_hits") {
        // ゼロヒット検索 (結果0件だった検索)
        const zeroHits = new Map<string, number>();
        for (const e of searchEvents ?? []) {
          const meta = e.metadata as Record<string, unknown>;
          const q = (meta?.query as string)?.toLowerCase() ?? "";
          const resultCount = (meta?.result_count as number) ?? -1;
          if (q && resultCount === 0) {
            zeroHits.set(q, (zeroHits.get(q) ?? 0) + 1);
          }
        }

        const zeroHitList = [...zeroHits.entries()]
          .map(([query, count]) => ({ query, count }))
          .sort((a, b) => b.count - a.count)
          .slice(0, 30);

        return new Response(
          JSON.stringify({ success: true, zeroHits: zeroHitList, totalZeroHits: zeroHitList.length }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (view === "quality") {
        // 検索品質スコア
        let totalSearches = 0;
        let clickedResults = 0;
        let zeroHitCount = 0;

        for (const e of searchEvents ?? []) {
          const meta = e.metadata as Record<string, unknown>;
          totalSearches++;
          if ((meta?.result_count as number) === 0) zeroHitCount++;
          if (meta?.clicked) clickedResults++;
        }

        const clickRate = totalSearches > 0 ? Math.round((clickedResults / totalSearches) * 100) : 0;
        const zeroHitRate = totalSearches > 0 ? Math.round((zeroHitCount / totalSearches) * 100) : 0;

        // 品質スコア: click率高い + ゼロヒット率低い = 高スコア
        const qualityScore = Math.min(100, Math.max(0,
          Math.round(clickRate * 0.7 + (100 - zeroHitRate) * 0.3)
        ));

        return new Response(
          JSON.stringify({
            success: true,
            quality: {
              score: qualityScore,
              totalSearches,
              clickedResults,
              clickRate,
              zeroHitCount,
              zeroHitRate,
            },
            period: { days, since },
          }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      // デフォルト: サマリー
      const uniqueUsers = new Set((searchEvents ?? []).map((e) => e.user_id).filter(Boolean)).size;

      return new Response(
        JSON.stringify({
          success: true,
          summary: {
            totalSearches: (searchEvents ?? []).length,
            uniqueUsers,
          },
          period: { days, since },
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    if (req.method === "POST") {
      const body = await req.json();
      const { query, result_count, clicked, clicked_id } = body;

      if (!query) {
        return new Response(
          JSON.stringify({ success: false, error: "query is required" }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      // ユーザーID取得 (認証任意)
      let userId = null;
      const authHeader = req.headers.get("Authorization");
      if (authHeader) {
        const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
          global: { headers: { Authorization: authHeader } },
        });
        const { data: { user } } = await userClient.auth.getUser();
        if (user) userId = user.id;
      }

      const { data, error } = await adminClient
        .from("app_analytics")
        .insert({
          user_id: userId,
          source: "search",
          metadata: {
            query,
            result_count: result_count ?? null,
            clicked: clicked ?? false,
            clicked_id: clicked_id ?? null,
          },
          created_at: new Date().toISOString(),
        })
        .select()
        .single();

      if (error) throw error;

      return new Response(
        JSON.stringify({ success: true, event: data }),
        { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    return new Response(
      JSON.stringify({ error: "Method not allowed" }),
      { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error("search-analytics error:", err);
    return new Response(
      JSON.stringify({ success: false, error: message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
