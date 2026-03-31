// Competitor Feature Sync Edge Function
// 競合機能パリティの動的管理・進捗トラッキング
// - 機能ステータスの更新 (done/partial/notYet)
// - 競合別の進捗率算出
// - 未実装機能の優先度リスト
//
// GET  → 競合別進捗率 / 未実装一覧 / カテゴリ別分析
// POST → ステータス更新 / 一括同期

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

// 21 competitors
const COMPETITORS = [
  "notion", "evernote", "moneyforward", "slack", "chatwork",
  "x", "animaworks", "claude-code", "codex", "netkeiba",
  "openclaw", "claude-cowork", "jobcan", "amazon", "google",
  "microsoft", "discord", "line", "facebook", "liven", "github",
] as const;

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
      const view = url.searchParams.get("view"); // 'progress' | 'gaps' | 'category' | 'priority'
      const competitor = url.searchParams.get("competitor");

      // competitor_feature_status テーブルから動的データを取得
      // テーブルがない場合は get-competitor-features の静的データにフォールバック
      const { data: overrides, error: overrideErr } = await adminClient
        .from("competitor_feature_status")
        .select("*");

      // 静的データを get-competitor-features から間接取得
      // (ここでは app_analytics 経由でキャッシュされたデータを使用)
      const { data: cachedFeatures } = await adminClient
        .from("app_analytics")
        .select("metadata")
        .eq("source", "competitor_feature_cache")
        .order("created_at", { ascending: false })
        .limit(1)
        .maybeSingle();

      // オーバーライドマップを構築
      const overrideMap = new Map<string, string>();
      for (const o of overrides ?? []) {
        const key = `${o.competitor_id}:${o.feature_name}`;
        overrideMap.set(key, o.status as string);
      }

      // キャッシュからの静的データ (なければ空)
      const staticData = (cachedFeatures?.metadata as Record<string, unknown>)?.competitors ?? [];

      if (view === "progress") {
        // 競合別の実装進捗率
        const progress: Record<string, { total: number; done: number; partial: number; notYet: number; rate: number }> = {};

        for (const comp of staticData as Array<{ id: string; features: Array<{ feature: string; status: string }> }>) {
          let done = 0, partial = 0, notYet = 0;
          for (const f of comp.features ?? []) {
            const overrideKey = `${comp.id}:${f.feature}`;
            const status = overrideMap.get(overrideKey) ?? f.status;
            if (status === "done") done++;
            else if (status === "partial") partial++;
            else notYet++;
          }
          const total = done + partial + notYet;
          progress[comp.id] = {
            total,
            done,
            partial,
            notYet,
            rate: total > 0 ? Math.round(((done + partial * 0.5) / total) * 100) : 0,
          };
        }

        return new Response(
          JSON.stringify({ success: true, progress, competitorCount: Object.keys(progress).length }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (view === "gaps") {
        // 未実装機能の一覧 (全競合 or 特定競合)
        const gaps: Array<{ competitor: string; feature: string; category: string; competitorDetail: string }> = [];

        for (const comp of staticData as Array<{ id: string; features: Array<{ feature: string; category: string; status: string; competitorDetail: string }> }>) {
          if (competitor && comp.id !== competitor) continue;
          for (const f of comp.features ?? []) {
            const overrideKey = `${comp.id}:${f.feature}`;
            const status = overrideMap.get(overrideKey) ?? f.status;
            if (status === "notYet") {
              gaps.push({
                competitor: comp.id,
                feature: f.feature,
                category: f.category,
                competitorDetail: f.competitorDetail,
              });
            }
          }
        }

        return new Response(
          JSON.stringify({ success: true, gaps, totalGaps: gaps.length }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (view === "category") {
        // カテゴリ別の実装状況
        const categoryMap = new Map<string, { done: number; partial: number; notYet: number }>();

        for (const comp of staticData as Array<{ id: string; features: Array<{ feature: string; category: string; status: string }> }>) {
          for (const f of comp.features ?? []) {
            const overrideKey = `${comp.id}:${f.feature}`;
            const status = overrideMap.get(overrideKey) ?? f.status;
            if (!categoryMap.has(f.category)) {
              categoryMap.set(f.category, { done: 0, partial: 0, notYet: 0 });
            }
            const cat = categoryMap.get(f.category)!;
            if (status === "done") cat.done++;
            else if (status === "partial") cat.partial++;
            else cat.notYet++;
          }
        }

        const categories = [...categoryMap.entries()].map(([name, data]) => ({
          name,
          ...data,
          total: data.done + data.partial + data.notYet,
          rate: Math.round(((data.done + data.partial * 0.5) / Math.max(data.done + data.partial + data.notYet, 1)) * 100),
        })).sort((a, b) => a.rate - b.rate);

        return new Response(
          JSON.stringify({ success: true, categories }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (view === "priority") {
        // 優先実装リスト: 複数競合に共通する未実装機能
        const featureGapCount = new Map<string, { count: number; competitors: string[]; category: string }>();

        for (const comp of staticData as Array<{ id: string; features: Array<{ feature: string; category: string; status: string }> }>) {
          for (const f of comp.features ?? []) {
            const overrideKey = `${comp.id}:${f.feature}`;
            const status = overrideMap.get(overrideKey) ?? f.status;
            if (status === "notYet") {
              const existing = featureGapCount.get(f.feature);
              if (existing) {
                existing.count++;
                existing.competitors.push(comp.id);
              } else {
                featureGapCount.set(f.feature, { count: 1, competitors: [comp.id], category: f.category });
              }
            }
          }
        }

        const priorityList = [...featureGapCount.entries()]
          .map(([feature, data]) => ({ feature, ...data }))
          .sort((a, b) => b.count - a.count)
          .slice(0, 20);

        return new Response(
          JSON.stringify({ success: true, priorityList }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      // デフォルト: オーバーライド一覧 + サマリー
      return new Response(
        JSON.stringify({
          success: true,
          overrides: overrides ?? [],
          overrideCount: (overrides ?? []).length,
          competitorCount: COMPETITORS.length,
          note: "Use ?view=progress|gaps|category|priority for detailed views",
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    if (req.method === "POST") {
      const body = await req.json();
      const { action } = body;

      if (action === "update_status") {
        // 個別機能のステータス更新
        const { competitor_id, feature_name, status, notes } = body;

        if (!competitor_id || !feature_name || !status) {
          return new Response(
            JSON.stringify({ success: false, error: "competitor_id, feature_name, and status are required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        if (!["done", "partial", "notYet"].includes(status)) {
          return new Response(
            JSON.stringify({ success: false, error: "status must be done, partial, or notYet" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const { data, error } = await adminClient
          .from("competitor_feature_status")
          .upsert({
            competitor_id,
            feature_name,
            status,
            notes: notes ?? null,
            updated_at: new Date().toISOString(),
          }, { onConflict: "competitor_id,feature_name" })
          .select()
          .single();

        if (error) throw error;

        return new Response(
          JSON.stringify({ success: true, override: data }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (action === "cache_features") {
        // 静的データをキャッシュとして app_analytics に保存
        // (get-competitor-features のレスポンスを POST で送信)
        const { competitors } = body;

        if (!competitors || !Array.isArray(competitors)) {
          return new Response(
            JSON.stringify({ success: false, error: "competitors array is required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const { data, error } = await adminClient
          .from("app_analytics")
          .insert({
            source: "competitor_feature_cache",
            metadata: { competitors, cached_at: new Date().toISOString() },
            created_at: new Date().toISOString(),
          })
          .select()
          .single();

        if (error) throw error;

        return new Response(
          JSON.stringify({ success: true, cached: true, id: data.id }),
          { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      return new Response(
        JSON.stringify({ success: false, error: "Unknown action. Use update_status or cache_features" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    return new Response(
      JSON.stringify({ error: "Method not allowed" }),
      { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error("competitor-feature-sync error:", err);
    return new Response(
      JSON.stringify({ success: false, error: message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
