// Blog Auto Publisher Edge Function
// 技術ブログ自動投稿 — Qiita API / dev.to API / はてなブログ XML-RPC 対応
//
// GET  ?view=drafts|history|platforms   → 未投稿一覧 / 投稿履歴 / プラットフォーム一覧
// POST { action, id, content, tags? }
//   action="publish_qiita"   → Qiita API で投稿 → blog_posts.status="posted"
//   action="publish_devto"   → dev.to API で投稿 → blog_posts.status="posted"
//   action="auto_publish"    → target_platforms に応じて全プラットフォームに一括投稿
//   action="mark_posted"     → 手動投稿済みとして status 更新
//
// 必要な Supabase シークレット:
//   QIITA_ACCESS_TOKEN   — Qiita アクセストークン
//   DEVTO_API_KEY        — dev.to API キー

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";
const QIITA_ACCESS_TOKEN = Deno.env.get("QIITA_ACCESS_TOKEN") ?? "";
const DEVTO_API_KEY = Deno.env.get("DEVTO_API_KEY") ?? "";

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

// ── Qiita 投稿 ──────────────────────────────────────────────────────────────
async function publishToQiita(
  title: string,
  body: string,
  tags: string[],
): Promise<{ url: string }> {
  if (!QIITA_ACCESS_TOKEN) {
    throw new Error("QIITA_ACCESS_TOKEN が設定されていません");
  }
  const tagObjects = tags.slice(0, 5).map((t) => ({ name: t.slice(0, 20) }));
  const res = await fetch("https://qiita.com/api/v2/items", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${QIITA_ACCESS_TOKEN}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      title,
      body,
      tags: tagObjects.length > 0 ? tagObjects : [{ name: "Flutter" }],
      private: false,
      tweet: false,
    }),
  });
  if (!res.ok) {
    const errText = await res.text();
    throw new Error(`Qiita API error ${res.status}: ${errText}`);
  }
  const data = await res.json() as { url: string; id: string };
  return { url: data.url };
}

// ── dev.to 投稿 ─────────────────────────────────────────────────────────────
async function publishToDevTo(
  title: string,
  body: string,
  tags: string[],
): Promise<{ url: string }> {
  if (!DEVTO_API_KEY) {
    throw new Error("DEVTO_API_KEY が設定されていません");
  }
  const cleanTags = tags.slice(0, 4).map((t) =>
    t.toLowerCase().replace(/[^a-z0-9]/g, "").slice(0, 30)
  ).filter((t) => t.length > 0);

  const res = await fetch("https://dev.to/api/articles", {
    method: "POST",
    headers: {
      "api-key": DEVTO_API_KEY,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      article: {
        title,
        body_markdown: body,
        tags: cleanTags.length > 0 ? cleanTags : ["flutter"],
        published: true,
      },
    }),
  });
  if (!res.ok) {
    const errText = await res.text();
    throw new Error(`dev.to API error ${res.status}: ${errText}`);
  }
  const data = await res.json() as { url: string; id: number };
  return { url: data.url };
}

// ── blog_posts テーブル更新 ──────────────────────────────────────────────────
async function updateBlogPostStatus(
  supabase: ReturnType<typeof createClient>,
  id: string,
  platform: string,
  url: string,
): Promise<void> {
  // PATCH: 最初の投稿成功でステータスを posted に更新
  const { error } = await supabase
    .from("blog_posts")
    .update({
      status: "posted",
      url,
      posted_at: new Date().toISOString(),
    })
    .eq("id", id)
    .eq("status", "draft"); // draft のみ更新 (冪等性)

  if (error) {
    console.error(`blog_posts update error (${platform}):`, error.message);
  }
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (SUPABASE_URL === "" || SERVICE_ROLE_KEY === "") {
    return json({ success: false, error: "misconfigured" }, 500);
  }

  const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: { persistSession: false },
  });

  try {
    // ── GET ──────────────────────────────────────────────────────────────────
    if (req.method === "GET") {
      const url = new URL(req.url);
      const view = url.searchParams.get("view") ?? "drafts";

      if (view === "platforms") {
        return json({
          success: true,
          platforms: [
            { key: "qiita", name: "Qiita", available: !!QIITA_ACCESS_TOKEN },
            { key: "devto", name: "dev.to", available: !!DEVTO_API_KEY },
            {
              key: "zenn",
              name: "Zenn",
              available: false,
              note: "GitHub リポジトリ連携が必要 (Zenn CLI)",
            },
          ],
        });
      }

      if (view === "history") {
        const { data, error } = await supabase
          .from("blog_posts")
          .select("id, title, status, url, posted_at, target_platforms")
          .eq("status", "posted")
          .order("posted_at", { ascending: false })
          .limit(50);
        if (error) throw error;
        return json({ success: true, posts: data ?? [] });
      }

      // Default: drafts
      const { data, error } = await supabase
        .from("blog_posts")
        .select("id, title, status, draft_path, target_platforms, created_at")
        .eq("status", "draft")
        .order("created_at", { ascending: false })
        .limit(20);
      if (error) throw error;
      return json({ success: true, drafts: data ?? [] });
    }

    // ── POST ─────────────────────────────────────────────────────────────────
    if (req.method === "POST") {
      // deno-lint-ignore no-explicit-any
      const body: any = await req.json().catch(() => ({}));
      const { action, id, content, tags } = body;

      if (!action) {
        return json({ success: false, error: "action is required" }, 400);
      }

      // ── mark_posted: 手動投稿済み記録 ─────────────────────────────────────
      if (action === "mark_posted") {
        if (!id) return json({ success: false, error: "id is required" }, 400);
        const { data, error } = await supabase
          .from("blog_posts")
          .update({
            status: "posted",
            url: body.url ?? null,
            posted_at: new Date().toISOString(),
          })
          .eq("id", id)
          .select("id, title, status")
          .single();
        if (error) throw error;
        return json({ success: true, post: data });
      }

      // 以下は content が必須
      if (!id || !content) {
        return json(
          { success: false, error: "id and content are required" },
          400,
        );
      }

      // blog_posts レコードを取得
      const { data: post, error: fetchErr } = await supabase
        .from("blog_posts")
        .select("id, title, status, target_platforms")
        .eq("id", id)
        .single();
      if (fetchErr || !post) {
        return json({ success: false, error: "blog post not found" }, 404);
      }
      if (post.status === "posted") {
        return json({
          success: false,
          error: "already posted",
          post,
        }, 409);
      }

      const articleTags: string[] = Array.isArray(tags) ? tags : ["Flutter", "Supabase", "buildinpublic"];
      const results: Record<string, unknown> = {};

      // ── publish_qiita ──────────────────────────────────────────────────────
      if (action === "publish_qiita" || action === "auto_publish") {
        const shouldPost = action === "publish_qiita" ||
          (post.target_platforms ?? []).includes("qiita");
        if (shouldPost) {
          try {
            const { url: postedUrl } = await publishToQiita(
              post.title,
              content,
              articleTags,
            );
            await updateBlogPostStatus(supabase, id, "qiita", postedUrl);
            results["qiita"] = { success: true, url: postedUrl };
          } catch (e) {
            results["qiita"] = {
              success: false,
              error: e instanceof Error ? e.message : String(e),
            };
          }
        }
      }

      // ── publish_devto ──────────────────────────────────────────────────────
      if (action === "publish_devto" || action === "auto_publish") {
        const shouldPost = action === "publish_devto" ||
          (post.target_platforms ?? []).includes("devto");
        if (shouldPost) {
          try {
            const { url: postedUrl } = await publishToDevTo(
              post.title,
              content,
              articleTags,
            );
            await updateBlogPostStatus(supabase, id, "devto", postedUrl);
            results["devto"] = { success: true, url: postedUrl };
          } catch (e) {
            results["devto"] = {
              success: false,
              error: e instanceof Error ? e.message : String(e),
            };
          }
        }
      }

      if (Object.keys(results).length === 0) {
        return json({
          success: false,
          error: `Unknown action: ${action}`,
        }, 400);
      }

      const anySuccess = Object.values(results).some(
        (r) => (r as Record<string, unknown>).success === true,
      );

      return json({
        success: anySuccess,
        results,
        post_id: id,
        title: post.title,
      }, anySuccess ? 200 : 500);
    }

    return json({ error: "Method not allowed" }, 405);
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error("blog-auto-publisher error:", err);
    return json({ success: false, error: message }, 500);
  }
});
