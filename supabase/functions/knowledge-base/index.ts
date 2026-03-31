// Knowledge Base Edge Function
// ナレッジベース/ヘルプセンター (Notion/GitHub競合)
// - カテゴリ別記事管理
// - 検索
// - 閲覧数・役立ち度
// - FAQ管理
//
// GET  → 記事一覧 / カテゴリ / 検索 / FAQ
// POST → 記事作成 / フィードバック

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

const DEFAULT_CATEGORIES = [
  { key: "getting_started", label: "はじめに", icon: "🚀" },
  { key: "features", label: "機能ガイド", icon: "⚙️" },
  { key: "ai", label: "AI機能", icon: "🤖" },
  { key: "account", label: "アカウント", icon: "👤" },
  { key: "billing", label: "料金・プラン", icon: "💳" },
  { key: "troubleshooting", label: "トラブルシューティング", icon: "🔧" },
  { key: "api", label: "API", icon: "📡" },
  { key: "faq", label: "よくある質問", icon: "❓" },
];

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
      const view = url.searchParams.get("view"); // 'categories' | 'search' | 'article' | 'faq' | 'popular'
      const category = url.searchParams.get("category");
      const articleId = url.searchParams.get("article_id");
      const query = url.searchParams.get("q");

      if (view === "categories") {
        return new Response(
          JSON.stringify({ success: true, categories: DEFAULT_CATEGORIES }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (view === "article" && articleId) {
        const { data: article } = await adminClient
          .from("app_analytics")
          .select("metadata, created_at")
          .eq("source", "kb_article")
          .eq("metadata->>article_id", articleId)
          .maybeSingle();

        if (!article) {
          return new Response(
            JSON.stringify({ success: false, error: "Article not found" }),
            { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        // Increment view count
        const meta = article.metadata as Record<string, unknown>;
        const views = ((meta?.views as number) ?? 0) + 1;
        await adminClient
          .from("app_analytics")
          .update({ metadata: { ...meta, views } })
          .eq("source", "kb_article")
          .eq("metadata->>article_id", articleId);

        return new Response(
          JSON.stringify({ success: true, article: { ...meta, views, createdAt: article.created_at } }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (view === "faq") {
        const { data: faqs } = await adminClient
          .from("app_analytics")
          .select("metadata, created_at")
          .eq("source", "kb_article")
          .eq("metadata->>category", "faq")
          .order("created_at", { ascending: true });

        return new Response(
          JSON.stringify({
            success: true,
            faq: (faqs ?? []).map((f) => ({
              ...(f.metadata as Record<string, unknown>),
              createdAt: f.created_at,
            })),
          }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (view === "popular") {
        const { data: articles } = await adminClient
          .from("app_analytics")
          .select("metadata, created_at")
          .eq("source", "kb_article")
          .order("created_at", { ascending: false })
          .limit(100);

        const sorted = (articles ?? [])
          .map((a) => ({ ...(a.metadata as Record<string, unknown>), createdAt: a.created_at }))
          .sort((a, b) => ((b.views as number) ?? 0) - ((a.views as number) ?? 0))
          .slice(0, 10);

        return new Response(
          JSON.stringify({ success: true, articles: sorted }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      // Article list (with optional category filter and search)
      const { data: articles } = await adminClient
        .from("app_analytics")
        .select("metadata, created_at")
        .eq("source", "kb_article")
        .order("created_at", { ascending: false })
        .limit(100);

      let list = (articles ?? []).map((a) => ({
        ...(a.metadata as Record<string, unknown>),
        createdAt: a.created_at,
      }));

      if (category) {
        list = list.filter((a) => a.category === category);
      }

      if (query) {
        const q = query.toLowerCase();
        list = list.filter((a) => {
          const title = ((a.title as string) ?? "").toLowerCase();
          const content = ((a.content as string) ?? "").toLowerCase();
          return title.includes(q) || content.includes(q);
        });
      }

      return new Response(
        JSON.stringify({ success: true, articles: list }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    if (req.method === "POST") {
      // Auth required for POST
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

      const body = await req.json();
      const { action } = body;

      if (action === "create_article") {
        const { title, content, category: cat, tags } = body;
        if (!title || !content) {
          return new Response(
            JSON.stringify({ success: false, error: "title and content required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const articleId = crypto.randomUUID();
        const { data, error } = await adminClient.from("app_analytics").insert({
          user_id: user.id,
          source: "kb_article",
          metadata: {
            article_id: articleId,
            title,
            content,
            category: cat ?? "features",
            tags: tags ?? [],
            views: 0,
            helpful_count: 0,
            not_helpful_count: 0,
          },
          created_at: new Date().toISOString(),
        }).select().single();

        if (error) throw error;

        return new Response(
          JSON.stringify({ success: true, articleId, article: data }),
          { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (action === "feedback") {
        const { article_id, helpful } = body;
        if (!article_id || helpful === undefined) {
          return new Response(
            JSON.stringify({ success: false, error: "article_id and helpful required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const { data: article } = await adminClient
          .from("app_analytics")
          .select("metadata")
          .eq("source", "kb_article")
          .eq("metadata->>article_id", article_id)
          .maybeSingle();

        if (!article) {
          return new Response(
            JSON.stringify({ success: false, error: "Article not found" }),
            { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const meta = article.metadata as Record<string, unknown>;
        const field = helpful ? "helpful_count" : "not_helpful_count";
        const count = ((meta[field] as number) ?? 0) + 1;

        await adminClient
          .from("app_analytics")
          .update({ metadata: { ...meta, [field]: count } })
          .eq("source", "kb_article")
          .eq("metadata->>article_id", article_id);

        return new Response(
          JSON.stringify({ success: true, helpful, count }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
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
    console.error("knowledge-base error:", err);
    return new Response(
      JSON.stringify({ success: false, error: message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
