// Bookmark Manager Edge Function
// ブックマーク管理 (Google/Evernote競合)
// - URL保存・分類
// - タグ・フォルダ管理
// - 検索・フィルタ
// - インポート/エクスポート
//
// GET  → ブックマーク一覧 / フォルダ / 検索
// POST → 追加 / フォルダ作成 / 削除

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

    if (req.method === "GET") {
      const url = new URL(req.url);
      const view = url.searchParams.get("view"); // 'search' | 'folders' | 'recent'
      const folder = url.searchParams.get("folder");
      const query = url.searchParams.get("q");
      const tag = url.searchParams.get("tag");

      const { data: bookmarks } = await adminClient
        .from("app_analytics")
        .select("metadata, created_at")
        .eq("user_id", user.id)
        .eq("source", "bookmark")
        .order("created_at", { ascending: false })
        .limit(100);

      const allBookmarks = (bookmarks ?? []).map((b) => ({
        ...(b.metadata as Record<string, unknown>),
        savedAt: b.created_at,
      }));

      if (view === "folders") {
        const folders = new Map<string, number>();
        for (const b of allBookmarks) {
          const f = (b.folder as string) ?? "未分類";
          folders.set(f, (folders.get(f) ?? 0) + 1);
        }
        return new Response(
          JSON.stringify({
            success: true,
            folders: [...folders.entries()].map(([name, count]) => ({ name, count })).sort((a, b) => b.count - a.count),
          }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      let filtered = allBookmarks;

      if (folder) {
        filtered = filtered.filter((b) => (b.folder as string ?? "未分類") === folder);
      }

      if (tag) {
        filtered = filtered.filter((b) => {
          const tags = (b.tags as string[]) ?? [];
          return tags.includes(tag);
        });
      }

      if (query) {
        const q = query.toLowerCase();
        filtered = filtered.filter((b) => {
          const title = ((b.title as string) ?? "").toLowerCase();
          const urlStr = ((b.url as string) ?? "").toLowerCase();
          const desc = ((b.description as string) ?? "").toLowerCase();
          return title.includes(q) || urlStr.includes(q) || desc.includes(q);
        });
      }

      if (view === "recent") {
        filtered = filtered.slice(0, 10);
      }

      return new Response(
        JSON.stringify({ success: true, bookmarks: filtered, total: filtered.length }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      const { action } = body;

      if (action === "add") {
        const { url: bookmarkUrl, title, description, folder: folderName, tags } = body;
        if (!bookmarkUrl) {
          return new Response(
            JSON.stringify({ success: false, error: "url required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const bookmarkId = crypto.randomUUID();
        const { data, error } = await adminClient.from("app_analytics").insert({
          user_id: user.id,
          source: "bookmark",
          metadata: {
            bookmark_id: bookmarkId,
            url: bookmarkUrl,
            title: title ?? bookmarkUrl,
            description: description ?? "",
            folder: folderName ?? "未分類",
            tags: tags ?? [],
            favicon: `https://www.google.com/s2/favicons?domain=${new URL(bookmarkUrl).hostname}`,
          },
          created_at: new Date().toISOString(),
        }).select().single();

        if (error) throw error;

        return new Response(
          JSON.stringify({ success: true, bookmarkId, bookmark: data }),
          { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (action === "delete") {
        const { bookmark_id } = body;
        if (!bookmark_id) {
          return new Response(
            JSON.stringify({ success: false, error: "bookmark_id required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const { error } = await adminClient
          .from("app_analytics")
          .delete()
          .eq("user_id", user.id)
          .eq("source", "bookmark")
          .eq("metadata->>bookmark_id", bookmark_id);

        if (error) throw error;

        return new Response(
          JSON.stringify({ success: true, deleted: true }),
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
    console.error("bookmark-manager error:", err);
    return new Response(
      JSON.stringify({ success: false, error: message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
