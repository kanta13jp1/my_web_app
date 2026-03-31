// Performance Review Edge Function
// 人事評価・パフォーマンスレビュー (ジョブカン/Microsoft競合)
// - 目標設定 (OKR/KPI)
// - 自己評価・上司評価
// - 360度フィードバック
// - 評価履歴
//
// GET  → 評価一覧 / 詳細 / 統計
// POST → 評価作成 / フィードバック

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const RATING_LABELS = ["未評価", "改善が必要", "期待を下回る", "期待通り", "期待を超える", "卓越"];

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, { auth: { persistSession: false } });
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ success: false, error: "Authorization required" }), { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, { global: { headers: { Authorization: authHeader } } });
    const { data: { user } } = await userClient.auth.getUser();
    if (!user) {
      return new Response(JSON.stringify({ success: false, error: "Unauthorized" }), { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "GET") {
      const url = new URL(req.url);
      const view = url.searchParams.get("view"); // 'my_reviews' | 'pending' | 'detail' | 'stats'
      const reviewId = url.searchParams.get("review_id");

      if (view === "detail" && reviewId) {
        const { data: review } = await adminClient.from("app_analytics").select("metadata, created_at").eq("source", "performance_review").eq("metadata->>review_id", reviewId).maybeSingle();
        if (!review) {
          return new Response(JSON.stringify({ success: false, error: "Review not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }

        const { data: feedback } = await adminClient.from("app_analytics").select("metadata, created_at, user_id").eq("source", "review_feedback").eq("metadata->>review_id", reviewId).order("created_at", { ascending: true });

        return new Response(JSON.stringify({
          success: true,
          review: { ...(review.metadata as Record<string, unknown>), createdAt: review.created_at },
          feedback: (feedback ?? []).map((f) => ({ ...(f.metadata as Record<string, unknown>), userId: f.user_id, createdAt: f.created_at })),
          ratingLabels: RATING_LABELS,
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "stats") {
        const { data: reviews } = await adminClient.from("app_analytics").select("metadata").eq("user_id", user.id).eq("source", "performance_review");

        const ratings = (reviews ?? []).map((r) => (r.metadata as Record<string, unknown>)?.overall_rating as number).filter((r) => r > 0);
        const avgRating = ratings.length > 0 ? Math.round(ratings.reduce((s, r) => s + r, 0) / ratings.length * 10) / 10 : 0;

        return new Response(JSON.stringify({
          success: true,
          stats: { totalReviews: (reviews ?? []).length, avgRating, ratingLabels: RATING_LABELS },
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "pending") {
        const { data: pending } = await adminClient.from("app_analytics").select("metadata, created_at").eq("source", "performance_review").eq("metadata->>status", "pending").order("created_at", { ascending: false });

        return new Response(JSON.stringify({
          success: true,
          pending: (pending ?? []).map((p) => ({ ...(p.metadata as Record<string, unknown>), createdAt: p.created_at })),
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      // Default: my reviews
      const { data: reviews } = await adminClient.from("app_analytics").select("metadata, created_at").eq("user_id", user.id).eq("source", "performance_review").order("created_at", { ascending: false });

      return new Response(JSON.stringify({
        success: true,
        reviews: (reviews ?? []).map((r) => ({ ...(r.metadata as Record<string, unknown>), createdAt: r.created_at })),
        ratingLabels: RATING_LABELS,
      }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json();
      const { action } = body;

      if (action === "create_review") {
        const { period, goals, self_assessment, overall_rating } = body;
        if (!period) {
          return new Response(JSON.stringify({ success: false, error: "period required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }

        const reviewId = crypto.randomUUID();
        const { data, error } = await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "performance_review",
          metadata: {
            review_id: reviewId, period, goals: goals ?? [],
            self_assessment: self_assessment ?? "", overall_rating: overall_rating ?? 0,
            status: "pending",
          },
          created_at: new Date().toISOString(),
        }).select().single();

        if (error) throw error;
        return new Response(JSON.stringify({ success: true, reviewId, review: data }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "add_feedback") {
        const { review_id, rating, strengths, improvements, comments } = body;
        if (!review_id) {
          return new Response(JSON.stringify({ success: false, error: "review_id required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }

        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "review_feedback",
          metadata: {
            review_id, rating: rating ?? 0,
            strengths: strengths ?? "", improvements: improvements ?? "",
            comments: comments ?? "",
          },
          created_at: new Date().toISOString(),
        });

        return new Response(JSON.stringify({ success: true, feedbackAdded: true }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return new Response(JSON.stringify({ success: false, error: message }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
