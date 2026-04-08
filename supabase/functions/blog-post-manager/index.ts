// Blog Post Manager Edge Function
// 技術ブログの投稿管理 (Zenn, Qiita, はてな, note, Medium, dev.to, Hashnode, Substack, GitHub Pages, Notion, X Article)
//
// GET  → 投稿一覧・ステータス取得
// POST → 投稿記録の作成・更新
// PATCH → 投稿ステータス更新 (draft → posted / skipped)

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const PLATFORMS = [
  "zenn", "qiita", "hatena", "note", "medium",
  "devto", "hashnode", "substack", "github-pages", "notion", "x-article",
] as const;

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: { persistSession: false },
    });

    if (req.method === "GET") {
      const url = new URL(req.url);
      const status = url.searchParams.get("status"); // draft | posted | skipped
      const platform = url.searchParams.get("platform");
      const limit = parseInt(url.searchParams.get("limit") ?? "30", 10);
      const today = new Date().toISOString().slice(0, 10);

      // Build main posts query
      let postsQuery = supabase
        .from("blog_posts")
        .select("*")
        .order("created_at", { ascending: false })
        .limit(limit);
      if (status) postsQuery = postsQuery.eq("status", status);
      if (platform) postsQuery = postsQuery.contains("target_platforms", [platform]);

      // Run main query, all platform counts, and today count in parallel
      const [postsResult, platformCountResults, todayResult] = await Promise.all([
        postsQuery,
        Promise.all(
          (PLATFORMS as readonly string[]).map((p) =>
            supabase
              .from("blog_posts")
              .select("*", { count: "exact", head: true })
              .eq("status", "posted")
              .contains("target_platforms", [p])
          ),
        ),
        supabase
          .from("blog_posts")
          .select("*", { count: "exact", head: true })
          .eq("status", "posted")
          .gte("posted_at", `${today}T00:00:00`),
      ]);

      if (postsResult.error) throw postsResult.error;

      // Aggregate platform counts
      const platformStats: Record<string, number> = {};
      (PLATFORMS as readonly string[]).forEach((p, i) => {
        platformStats[p] = (platformCountResults[i]?.count as number | null) ?? 0;
      });

      return new Response(
        JSON.stringify({
          success: true,
          posts: postsResult.data ?? [],
          platformStats,
          todayPostedCount: (todayResult.count as number | null) ?? 0,
          availablePlatforms: PLATFORMS,
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      const { title, draft_path, target_platforms, content_preview } = body;

      if (!title) {
        return new Response(
          JSON.stringify({ success: false, error: "title is required" }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      const { data, error } = await supabase
        .from("blog_posts")
        .insert({
          title,
          draft_path: draft_path ?? null,
          status: "draft",
          target_platforms: target_platforms ?? PLATFORMS,
          content_preview: content_preview ?? null,
          created_at: new Date().toISOString(),
        })
        .select()
        .single();

      if (error) throw error;

      return new Response(
        JSON.stringify({ success: true, post: data }),
        { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    if (req.method === "PATCH") {
      const body = await req.json().catch(() => ({}));
      const { id, status, url, posted_at } = body;

      if (!id || !status) {
        return new Response(
          JSON.stringify({ success: false, error: "id and status are required" }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      const updates: Record<string, unknown> = { status };
      if (url) updates.url = url;
      if (posted_at) updates.posted_at = posted_at;
      if (status === "posted" && !posted_at) updates.posted_at = new Date().toISOString();

      const { data, error } = await supabase
        .from("blog_posts")
        .update(updates)
        .eq("id", id)
        .select()
        .single();

      if (error) throw error;

      return new Response(
        JSON.stringify({ success: true, post: data }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    return new Response(
      JSON.stringify({ error: "Method not allowed" }),
      { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error("blog-post-manager error:", err);
    return new Response(
      JSON.stringify({ success: false, error: message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
