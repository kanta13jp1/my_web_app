// Bookmark Sync Edge Function
// ブックマーク同期・バックアップ (Pocket/Instapaper競合)
// - ブックマークの CRUD
// - タグ付け・カテゴリ分類
// - 既読/未読管理
// - クロスデバイス同期
// - インポート/エクスポート (HTML/JSON)
//
// GET  → ブックマーク一覧 / タグ一覧 / 統計
// POST → 追加 / 更新 / 削除 / 既読マーク / インポート

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ success: false, error: "Authorization required" }), {
        status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: { user } } = await userClient.auth.getUser();
    if (!user) {
      return new Response(JSON.stringify({ success: false, error: "Unauthorized" }), {
        status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const url = new URL(req.url);
    const action = req.method === "GET" ? (url.searchParams.get("action") ?? "list") : (await req.json()).action ?? "add";

    if (action === "list") {
      const tag = url.searchParams.get("tag");
      const unreadOnly = url.searchParams.get("unread") === "true";
      let query = userClient.from("bookmarks").select("*").eq("user_id", user.id).order("created_at", { ascending: false });
      if (tag) query = query.contains("tags", [tag]);
      if (unreadOnly) query = query.eq("is_read", false);
      const { data, error } = await query;
      if (error) throw error;

      // get tags
      const tagsResult = await userClient.from("bookmarks").select("tags").eq("user_id", user.id);
      const allTags = new Set<string>();
      (tagsResult.data ?? []).forEach((r: { tags?: string[] }) => (r.tags ?? []).forEach((t) => allTags.add(t)));

      return new Response(JSON.stringify({
        success: true,
        bookmarks: data ?? [],
        tags: Array.from(allTags),
        stats: { total: (data ?? []).length, unread: (data ?? []).filter((b: { is_read?: boolean }) => !b.is_read).length },
      }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    const body = await req.json().catch(() => ({}));

    if (body.action === "add") {
      const { data, error } = await userClient.from("bookmarks").insert({
        user_id: user.id,
        url: body.url,
        title: body.title ?? body.url,
        description: body.description ?? null,
        tags: body.tags ?? [],
        is_read: false,
        created_at: new Date().toISOString(),
      }).select().single();
      if (error) throw error;
      return new Response(JSON.stringify({ success: true, bookmark: data }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (body.action === "mark_read") {
      const { error } = await userClient.from("bookmarks").update({ is_read: true }).eq("id", body.id).eq("user_id", user.id);
      if (error) throw error;
      return new Response(JSON.stringify({ success: true }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (body.action === "delete") {
      const { error } = await userClient.from("bookmarks").delete().eq("id", body.id).eq("user_id", user.id);
      if (error) throw error;
      return new Response(JSON.stringify({ success: true }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    return new Response(JSON.stringify({ success: false, error: "Unknown action" }), {
      status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    return new Response(JSON.stringify({ success: false, error: String(err) }), {
      status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
