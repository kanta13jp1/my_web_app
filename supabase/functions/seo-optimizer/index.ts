// SEO Optimizer Edge Function
// SEO分析・メタタグ管理・パフォーマンススコア
// - ページ別SEOスコア算出
// - メタタグ / OGP の最適化提案
// - サイトマップ整合性チェック
//
// GET  → SEOスコア / ページ分析 / 改善提案
// POST → ページ分析結果の記録

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

// SEO チェック項目
const SEO_CHECKS = [
  { key: "title", label: "タイトルタグ", weight: 15, maxLength: 60 },
  { key: "description", label: "メタディスクリプション", weight: 12, maxLength: 160 },
  { key: "ogp_title", label: "OGP タイトル", weight: 8 },
  { key: "ogp_description", label: "OGP ディスクリプション", weight: 8 },
  { key: "ogp_image", label: "OGP 画像", weight: 10 },
  { key: "canonical", label: "canonical URL", weight: 8 },
  { key: "h1", label: "H1 タグ", weight: 10 },
  { key: "structured_data", label: "構造化データ", weight: 10 },
  { key: "mobile_friendly", label: "モバイルフレンドリー", weight: 10 },
  { key: "load_speed", label: "読み込み速度", weight: 9 },
] as const;

// 主要ページ定義
const SITE_PAGES = [
  { path: "/", label: "ランディングページ", priority: 1.0 },
  { path: "/home", label: "ホーム画面", priority: 0.9 },
  { path: "/comparison", label: "競合比較ページ", priority: 0.8 },
  { path: "/user-manual", label: "ユーザーマニュアル", priority: 0.7 },
  { path: "/agents", label: "AI組織OS", priority: 0.7 },
  { path: "/feature-requests", label: "機能リクエスト", priority: 0.6 },
  { path: "/ai-secretary", label: "AI秘書", priority: 0.6 },
  { path: "/profile", label: "プロフィール", priority: 0.5 },
  { path: "/admin", label: "管理者ダッシュボード", priority: 0.3 },
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
      const view = url.searchParams.get("view"); // 'scores' | 'suggestions' | 'sitemap'

      if (view === "sitemap") {
        // サイトマップ整合性チェック
        const { data: publicMemos } = await adminClient
          .from("public_memos")
          .select("slug, updated_at")
          .limit(100);

        const sitemapPages = [
          ...SITE_PAGES.map((p) => ({ path: p.path, label: p.label, priority: p.priority, type: "static" })),
          ...(publicMemos ?? []).map((m) => ({
            path: `/memo/${m.slug}`,
            label: `公開メモ: ${m.slug}`,
            priority: 0.6,
            type: "dynamic",
          })),
        ];

        return new Response(
          JSON.stringify({
            success: true,
            sitemap: {
              totalPages: sitemapPages.length,
              staticPages: SITE_PAGES.length,
              dynamicPages: (publicMemos ?? []).length,
              pages: sitemapPages,
            },
          }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (view === "suggestions") {
        // 改善提案一覧
        const { data: analyses } = await adminClient
          .from("app_analytics")
          .select("metadata, created_at")
          .eq("source", "seo_analysis")
          .order("created_at", { ascending: false })
          .limit(20);

        const suggestions: Array<{ page: string; issue: string; priority: string; suggestion: string }> = [];

        for (const a of analyses ?? []) {
          const meta = a.metadata as Record<string, unknown>;
          const issues = (meta?.issues as Array<{ key: string; message: string; priority: string }>) ?? [];
          for (const issue of issues) {
            suggestions.push({
              page: (meta?.path as string) ?? "unknown",
              issue: issue.message,
              priority: issue.priority,
              suggestion: issue.key,
            });
          }
        }

        return new Response(
          JSON.stringify({ success: true, suggestions, total: suggestions.length }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      // デフォルト: ページ別SEOスコア
      const { data: analyses } = await adminClient
        .from("app_analytics")
        .select("metadata, created_at")
        .eq("source", "seo_analysis")
        .order("created_at", { ascending: false })
        .limit(50);

      // 最新のページ別スコアを抽出
      const pageScores = new Map<string, { score: number; analyzedAt: string; checks: Record<string, boolean> }>();

      for (const a of analyses ?? []) {
        const meta = a.metadata as Record<string, unknown>;
        const path = meta?.path as string;
        if (path && !pageScores.has(path)) {
          pageScores.set(path, {
            score: (meta?.score as number) ?? 0,
            analyzedAt: a.created_at as string,
            checks: (meta?.checks as Record<string, boolean>) ?? {},
          });
        }
      }

      const scores = [...pageScores.entries()].map(([path, data]) => ({
        path,
        ...data,
      }));

      // 全体スコアの平均
      const avgScore = scores.length > 0
        ? Math.round(scores.reduce((sum, s) => sum + s.score, 0) / scores.length)
        : 0;

      return new Response(
        JSON.stringify({
          success: true,
          overallScore: avgScore,
          pages: scores,
          totalChecks: SEO_CHECKS.length,
          sitePages: SITE_PAGES.length,
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      const { action } = body;

      if (action === "analyze") {
        // ページのSEO分析結果を記録
        const { path, checks, issues } = body;

        if (!path || !checks) {
          return new Response(
            JSON.stringify({ success: false, error: "path and checks are required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        // スコア計算
        let totalWeight = 0;
        let earnedWeight = 0;
        for (const check of SEO_CHECKS) {
          totalWeight += check.weight;
          if (checks[check.key]) earnedWeight += check.weight;
        }
        const score = totalWeight > 0 ? Math.round((earnedWeight / totalWeight) * 100) : 0;

        const { data, error } = await adminClient
          .from("app_analytics")
          .insert({
            source: "seo_analysis",
            metadata: {
              path,
              checks,
              issues: issues ?? [],
              score,
              analyzedAt: new Date().toISOString(),
            },
            created_at: new Date().toISOString(),
          })
          .select()
          .single();

        if (error) throw error;

        return new Response(
          JSON.stringify({ success: true, score, analysis: data }),
          { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } },
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
    console.error("seo-optimizer error:", err);
    return new Response(
      JSON.stringify({ success: false, error: message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
