// Marketplace Reviews Edge Function
// マーケットプレイスレビュー (Amazon/Google/食べログ競合)
// - 商品レビュー
// - 星評価
// - 画像付きレビュー
// - 役立った投票
// - レビュー分析

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type" };
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const REVIEW_CATEGORIES = ["product", "service", "restaurant", "hotel", "app", "book", "course", "other"];
const SORT_OPTIONS = ["newest", "highest_rated", "lowest_rated", "most_helpful"];

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
      const itemId = url.searchParams.get("item_id");

      if (view === "config") return new Response(JSON.stringify({ success: true, categories: REVIEW_CATEGORIES, sortOptions: SORT_OPTIONS }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });

      if (view === "item_reviews" && itemId) {
        const sort = url.searchParams.get("sort") ?? "newest";
        const { data: reviews } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("source", "marketplace_review").eq("metadata->>item_id", itemId).order("created_at", { ascending: false }).limit(50);
        let sorted = (reviews ?? []).map((r) => ({ ...(r.metadata as Record<string, unknown>), createdAt: r.created_at }));
        if (sort === "highest_rated") sorted.sort((a, b) => ((b.rating as number) ?? 0) - ((a.rating as number) ?? 0));
        else if (sort === "lowest_rated") sorted.sort((a, b) => ((a.rating as number) ?? 0) - ((b.rating as number) ?? 0));
        else if (sort === "most_helpful") sorted.sort((a, b) => ((b.helpful_count as number) ?? 0) - ((a.helpful_count as number) ?? 0));
        // Calculate stats
        const ratings = sorted.map((r) => (r.rating as number) ?? 0);
        const avg = ratings.length > 0 ? Math.round((ratings.reduce((a, b) => a + b, 0) / ratings.length) * 10) / 10 : 0;
        const distribution: Record<number, number> = { 1: 0, 2: 0, 3: 0, 4: 0, 5: 0 };
        for (const r of ratings) distribution[r] = (distribution[r] ?? 0) + 1;
        return new Response(JSON.stringify({ success: true, reviews: sorted, stats: { totalReviews: sorted.length, averageRating: avg, distribution } }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "my_reviews") {
        const { data: reviews } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "marketplace_review").order("created_at", { ascending: false });
        return new Response(JSON.stringify({ success: true, reviews: (reviews ?? []).map((r) => ({ ...(r.metadata as Record<string, unknown>), createdAt: r.created_at })) }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "top_reviewers") {
        const { data: all } = await adminClient.from("app_analytics").select("user_id").eq("source", "marketplace_review");
        const counts: Record<string, number> = {};
        for (const r of all ?? []) counts[r.user_id] = (counts[r.user_id] ?? 0) + 1;
        const top = Object.entries(counts).map(([uid, cnt]) => ({ userId: uid, reviewCount: cnt })).sort((a, b) => b.reviewCount - a.reviewCount).slice(0, 10);
        return new Response(JSON.stringify({ success: true, topReviewers: top }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: true, categories: REVIEW_CATEGORIES }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json();
      const { action } = body;

      if (action === "post_review") {
        const { item_id, item_name, rating, title, content, category, images } = body;
        if (!item_id || !rating || !content) return new Response(JSON.stringify({ success: false, error: "item_id, rating, content required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const reviewId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "marketplace_review",
          metadata: {
            review_id: reviewId, item_id, item_name: item_name ?? "", rating: Math.min(5, Math.max(1, rating)),
            title: title ?? "", content, category: category ?? "other", images: images ?? [],
            helpful_count: 0, user_email: user.email, verified_purchase: false,
          },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, reviewId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "mark_helpful") {
        const { review_id } = body;
        if (!review_id) return new Response(JSON.stringify({ success: false, error: "review_id required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const { data: review } = await adminClient.from("app_analytics").select("metadata")
          .eq("source", "marketplace_review").eq("metadata->>review_id", review_id).maybeSingle();
        if (!review) return new Response(JSON.stringify({ success: false, error: "Review not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const m = review.metadata as Record<string, unknown>;
        await adminClient.from("app_analytics").update({ metadata: { ...m, helpful_count: ((m.helpful_count as number) ?? 0) + 1 } })
          .eq("source", "marketplace_review").eq("metadata->>review_id", review_id);
        return new Response(JSON.stringify({ success: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "report_review") {
        const { review_id, reason } = body;
        if (!review_id) return new Response(JSON.stringify({ success: false, error: "review_id required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "review_report",
          metadata: { review_id, reported_by: user.id, reason: reason ?? "inappropriate" },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, reported: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }
    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) { return new Response(JSON.stringify({ success: false, error: err instanceof Error ? err.message : String(err) }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }); }
});
