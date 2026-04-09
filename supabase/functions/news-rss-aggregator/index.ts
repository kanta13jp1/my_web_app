// News RSS Aggregator Edge Function
// ニュースRSSアグリゲーター (Google News/Feedly競合)
// - RSSフィード登録
// - 記事取得・表示
// - カテゴリ管理
// - ブックマーク・既読管理
// - 読書統計
//
// GET  → フィード一覧 / 記事 / ブックマーク / カテゴリ / 統計
// POST → フィード追加 / 記事ブックマーク / 既読マーク / カテゴリ設定

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const NEWS_CATEGORIES = ["tech", "business", "science", "sports", "entertainment", "politics", "health", "world", "local"];

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
      const view = url.searchParams.get("view");

      if (view === "categories") {
        return new Response(JSON.stringify({ success: true, categories: NEWS_CATEGORIES }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "articles") {
        const feedId = url.searchParams.get("feed_id");
        const category = url.searchParams.get("category");
        let query = adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "news_article")
          .order("created_at", { ascending: false });
        if (feedId) query = query.eq("metadata->>feed_id", feedId);
        if (category) query = query.eq("metadata->>category", category);
        const { data: articles } = await query.limit(50);
        return new Response(JSON.stringify({
          success: true,
          articles: (articles ?? []).map((a) => ({ ...(a.metadata as Record<string, unknown>), createdAt: a.created_at })),
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "bookmarks") {
        const { data: bookmarks } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "news_article").eq("metadata->>is_bookmarked", "true")
          .order("created_at", { ascending: false });
        return new Response(JSON.stringify({
          success: true,
          bookmarks: (bookmarks ?? []).map((b) => ({ ...(b.metadata as Record<string, unknown>), createdAt: b.created_at })),
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "stats") {
        // フィード・記事を並列取得
        const [{ data: feeds }, { data: articles }] = await Promise.all([
          adminClient.from("app_analytics").select("metadata")
            .eq("user_id", user.id).eq("source", "news_feed"),
          adminClient.from("app_analytics").select("metadata")
            .eq("user_id", user.id).eq("source", "news_article"),
        ]);
        const readCount = (articles ?? []).filter((a) => (a.metadata as Record<string, unknown>).is_read).length;
        const bookmarked = (articles ?? []).filter((a) => (a.metadata as Record<string, unknown>).is_bookmarked).length;
        const catCounts: Record<string, number> = {};
        for (const a of articles ?? []) {
          const cat = ((a.metadata as Record<string, unknown>).category as string) ?? "other";
          catCounts[cat] = (catCounts[cat] ?? 0) + 1;
        }
        return new Response(JSON.stringify({
          success: true,
          stats: { totalFeeds: (feeds ?? []).length, totalArticles: (articles ?? []).length, readCount, bookmarked, categoryCounts: catCounts },
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      // Default: feed list
      const { data: feeds } = await adminClient.from("app_analytics").select("metadata, created_at")
        .eq("user_id", user.id).eq("source", "news_feed")
        .order("created_at", { ascending: false });
      return new Response(JSON.stringify({
        success: true,
        feeds: (feeds ?? []).map((f) => ({ ...(f.metadata as Record<string, unknown>), createdAt: f.created_at })),
      }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      const { action } = body;

      if (action === "add_feed") {
        const { title, url: feedUrl, category } = body;
        if (!title || !feedUrl) {
          return new Response(JSON.stringify({ success: false, error: "title and url required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const feedId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "news_feed",
          metadata: { feed_id: feedId, title, url: feedUrl, category: category ?? "tech", is_active: true },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, feedId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "save_article") {
        const { feed_id, title, url: articleUrl, summary, category, author } = body;
        if (!title) {
          return new Response(JSON.stringify({ success: false, error: "title required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const articleId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "news_article",
          metadata: { article_id: articleId, feed_id: feed_id ?? null, title, url: articleUrl ?? null, summary: summary ?? null, category: category ?? "tech", author: author ?? null, is_read: false, is_bookmarked: false },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, articleId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "mark_read") {
        const { article_id } = body;
        if (!article_id) {
          return new Response(JSON.stringify({ success: false, error: "article_id required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const { data: existing } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "news_article").eq("metadata->>article_id", article_id).maybeSingle();
        if (!existing) {
          return new Response(JSON.stringify({ success: false, error: "Article not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        await adminClient.from("app_analytics").update({ metadata: { ...(existing.metadata as Record<string, unknown>), is_read: true } })
          .eq("user_id", user.id).eq("source", "news_article").eq("metadata->>article_id", article_id);
        return new Response(JSON.stringify({ success: true, marked: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "toggle_bookmark") {
        const { article_id } = body;
        if (!article_id) {
          return new Response(JSON.stringify({ success: false, error: "article_id required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const { data: existing } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "news_article").eq("metadata->>article_id", article_id).maybeSingle();
        if (!existing) {
          return new Response(JSON.stringify({ success: false, error: "Article not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const meta = existing.metadata as Record<string, unknown>;
        const newVal = !(meta.is_bookmarked as boolean);
        await adminClient.from("app_analytics").update({ metadata: { ...meta, is_bookmarked: newVal } })
          .eq("user_id", user.id).eq("source", "news_article").eq("metadata->>article_id", article_id);
        return new Response(JSON.stringify({ success: true, isBookmarked: newVal }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return new Response(JSON.stringify({ success: false, error: message }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
