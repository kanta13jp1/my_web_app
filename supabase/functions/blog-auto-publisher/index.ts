// Blog Auto Publisher Edge Function
// 技術ブログ自動投稿管理 (11プラットフォーム対応)
// - 投稿先: Zenn, Qiita, はてなブログ, note, Medium, dev.to, Hashnode, Substack, GitHub Pages, Notion, X Article
// - 投稿状態管理
// - 投稿スケジュール
// - クロスポスト管理
//
// GET  → プラットフォーム一覧 / 投稿履歴 / 未投稿リスト / 統計
// POST → 投稿記録 / 投稿スケジュール / ステータス更新

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const PLATFORMS = [
  { key: "zenn", name: "Zenn", icon: "📘", url_pattern: "https://zenn.dev/{username}/articles/{slug}" },
  { key: "qiita", name: "Qiita", icon: "📗", url_pattern: "https://qiita.com/{username}/items/{slug}" },
  { key: "hatena", name: "はてなブログ", icon: "📙", url_pattern: "https://{username}.hatenablog.com/entry/{slug}" },
  { key: "note", name: "note", icon: "📝", url_pattern: "https://note.com/{username}/n/{slug}" },
  { key: "medium", name: "Medium", icon: "📰", url_pattern: "https://medium.com/@{username}/{slug}" },
  { key: "devto", name: "dev.to", icon: "🖥️", url_pattern: "https://dev.to/{username}/{slug}" },
  { key: "hashnode", name: "Hashnode", icon: "📓", url_pattern: "https://{username}.hashnode.dev/{slug}" },
  { key: "substack", name: "Substack", icon: "📮", url_pattern: "https://{username}.substack.com/p/{slug}" },
  { key: "github_pages", name: "GitHub Pages", icon: "🐙", url_pattern: "https://{username}.github.io/{slug}" },
  { key: "notion", name: "Notion", icon: "📋", url_pattern: "https://www.notion.so/{slug}" },
  { key: "x_article", name: "X Article", icon: "🐦", url_pattern: "https://x.com/i/articles/{slug}" },
];

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

      if (view === "platforms") {
        return new Response(JSON.stringify({ success: true, platforms: PLATFORMS }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "unpublished") {
        // Blog drafts not yet posted to all platforms
        const { data: drafts } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "blog_draft_track")
          .order("created_at", { ascending: false });
        const unpublished = (drafts ?? []).filter((d) => {
          const meta = d.metadata as Record<string, unknown>;
          const posted = (meta.posted_to as string[]) ?? [];
          return posted.length < PLATFORMS.length;
        }).map((d) => {
          const meta = d.metadata as Record<string, unknown>;
          const posted = (meta.posted_to as string[]) ?? [];
          const remaining = PLATFORMS.filter((p) => !posted.includes(p.key));
          return { ...(d.metadata as Record<string, unknown>), remainingPlatforms: remaining.map((r) => r.name), createdAt: d.created_at };
        });
        return new Response(JSON.stringify({ success: true, unpublished }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "stats") {
        const { data: posts } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "blog_publication");
        const platformCounts: Record<string, number> = {};
        for (const p of posts ?? []) {
          const platform = ((p.metadata as Record<string, unknown>).platform as string) ?? "unknown";
          platformCounts[platform] = (platformCounts[platform] ?? 0) + 1;
        }
        return new Response(JSON.stringify({
          success: true,
          stats: { totalPublications: (posts ?? []).length, platformCounts },
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      // Default: publication history
      const platform = url.searchParams.get("platform");
      let query = adminClient.from("app_analytics").select("metadata, created_at")
        .eq("user_id", user.id).eq("source", "blog_publication")
        .order("created_at", { ascending: false });
      if (platform) {
        query = query.eq("metadata->>platform", platform);
      }
      const { data: posts } = await query.limit(100);
      return new Response(JSON.stringify({
        success: true,
        publications: (posts ?? []).map((p) => ({ ...(p.metadata as Record<string, unknown>), createdAt: p.created_at })),
      }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json();
      const { action } = body;

      if (action === "register_draft") {
        const { title, draft_path, tags } = body;
        if (!title) {
          return new Response(JSON.stringify({ success: false, error: "title required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const draftId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "blog_draft_track",
          metadata: { draft_id: draftId, title, draft_path: draft_path ?? null, tags: tags ?? [], posted_to: [], status: "draft" },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, draftId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "record_publication") {
        const { draft_id, platform, url: postUrl, title } = body;
        if (!platform || !title) {
          return new Response(JSON.stringify({ success: false, error: "platform and title required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const valid = PLATFORMS.find((p) => p.key === platform);
        if (!valid) {
          return new Response(JSON.stringify({ success: false, error: "Invalid platform" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }

        const pubId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "blog_publication",
          metadata: { pub_id: pubId, draft_id: draft_id ?? null, platform, platform_name: valid.name, title, url: postUrl ?? null, published_at: new Date().toISOString() },
          created_at: new Date().toISOString(),
        });

        // Update draft tracking if draft_id provided
        if (draft_id) {
          const { data: draft } = await adminClient.from("app_analytics").select("metadata")
            .eq("user_id", user.id).eq("source", "blog_draft_track").eq("metadata->>draft_id", draft_id).maybeSingle();
          if (draft) {
            const meta = draft.metadata as Record<string, unknown>;
            const posted = (meta.posted_to as string[]) ?? [];
            if (!posted.includes(platform)) posted.push(platform);
            await adminClient.from("app_analytics").update({ metadata: { ...meta, posted_to: posted } })
              .eq("user_id", user.id).eq("source", "blog_draft_track").eq("metadata->>draft_id", draft_id);
          }
        }

        return new Response(JSON.stringify({ success: true, pubId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return new Response(JSON.stringify({ success: false, error: message }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
