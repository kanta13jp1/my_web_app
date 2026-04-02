// Tag Manager Edge Function
// タグ管理 (Notion/Evernote競合)
// - タグ CRUD
// - タグ使用状況・統計
// - タグ自動提案 (頻度ベース)
// - タグマージ・一括変更
//
// GET  → タグ一覧 / 統計 / 提案
// POST → タグ作成 / マージ / 一括適用

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
      const view = url.searchParams.get("view"); // 'stats' | 'suggest' | 'list'

      // Get all notes with tags
      const { data: notes } = await adminClient
        .from("notes")
        .select("id, tags")
        .eq("user_id", user.id);

      // Aggregate tags
      const tagCounts = new Map<string, number>();
      for (const note of notes ?? []) {
        const tags = (note.tags as string[]) ?? [];
        for (const tag of tags) {
          tagCounts.set(tag, (tagCounts.get(tag) ?? 0) + 1);
        }
      }

      const allTags = [...tagCounts.entries()]
        .map(([name, count]) => ({ name, count }))
        .sort((a, b) => b.count - a.count);

      if (view === "stats") {
        return new Response(
          JSON.stringify({
            success: true,
            stats: {
              totalTags: allTags.length,
              totalNotes: (notes ?? []).length,
              avgTagsPerNote: (notes ?? []).length > 0
                ? Math.round(allTags.reduce((s, t) => s + t.count, 0) / (notes ?? []).length * 10) / 10
                : 0,
              topTags: allTags.slice(0, 10),
              unusedThreshold: allTags.filter((t) => t.count === 1).length,
            },
          }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (view === "suggest") {
        const text = url.searchParams.get("text") ?? "";
        if (!text) {
          return new Response(
            JSON.stringify({ success: true, suggestions: allTags.slice(0, 5).map((t) => t.name) }),
            { headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        // Simple keyword-based suggestion
        const words = text.toLowerCase().split(/\s+/);
        const scored = allTags.map((tag) => {
          let score = 0;
          const tagLower = tag.name.toLowerCase();
          for (const word of words) {
            if (tagLower.includes(word) || word.includes(tagLower)) score += 3;
          }
          score += Math.min(tag.count, 5); // Popularity bonus
          return { name: tag.name, score };
        });

        const suggestions = scored
          .filter((s) => s.score > 0)
          .sort((a, b) => b.score - a.score)
          .slice(0, 5)
          .map((s) => s.name);

        return new Response(
          JSON.stringify({ success: true, suggestions }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      // Default: tag list
      return new Response(
        JSON.stringify({ success: true, tags: allTags }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      const { action } = body;

      if (action === "merge") {
        const { from_tag, to_tag } = body;
        if (!from_tag || !to_tag) {
          return new Response(
            JSON.stringify({ success: false, error: "from_tag and to_tag required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        // Find notes with from_tag
        const { data: notes } = await adminClient
          .from("notes")
          .select("id, tags")
          .eq("user_id", user.id)
          .contains("tags", [from_tag]);

        let updatedCount = 0;
        for (const note of notes ?? []) {
          const tags = (note.tags as string[]) ?? [];
          const newTags = tags.map((t) => (t === from_tag ? to_tag : t));
          // Deduplicate
          const uniqueTags = [...new Set(newTags)];

          const { error } = await adminClient
            .from("notes")
            .update({ tags: uniqueTags })
            .eq("id", note.id)
            .eq("user_id", user.id);

          if (!error) updatedCount++;
        }

        return new Response(
          JSON.stringify({ success: true, merged: true, from: from_tag, to: to_tag, updatedNotes: updatedCount }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (action === "bulk_add") {
        const { tag, note_ids } = body;
        if (!tag || !note_ids || !Array.isArray(note_ids)) {
          return new Response(
            JSON.stringify({ success: false, error: "tag and note_ids[] required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        let updatedCount = 0;
        for (const noteId of note_ids) {
          const { data: note } = await adminClient
            .from("notes")
            .select("tags")
            .eq("id", noteId)
            .eq("user_id", user.id)
            .maybeSingle();

          if (!note) continue;

          const tags = (note.tags as string[]) ?? [];
          if (tags.includes(tag)) continue;

          const { error } = await adminClient
            .from("notes")
            .update({ tags: [...tags, tag] })
            .eq("id", noteId)
            .eq("user_id", user.id);

          if (!error) updatedCount++;
        }

        return new Response(
          JSON.stringify({ success: true, tag, updatedNotes: updatedCount }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (action === "bulk_remove") {
        const { tag } = body;
        if (!tag) {
          return new Response(
            JSON.stringify({ success: false, error: "tag required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const { data: notes } = await adminClient
          .from("notes")
          .select("id, tags")
          .eq("user_id", user.id)
          .contains("tags", [tag]);

        let updatedCount = 0;
        for (const note of notes ?? []) {
          const tags = (note.tags as string[]) ?? [];
          const newTags = tags.filter((t) => t !== tag);

          const { error } = await adminClient
            .from("notes")
            .update({ tags: newTags })
            .eq("id", note.id)
            .eq("user_id", user.id);

          if (!error) updatedCount++;
        }

        return new Response(
          JSON.stringify({ success: true, removed: tag, updatedNotes: updatedCount }),
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
    console.error("tag-manager error:", err);
    return new Response(
      JSON.stringify({ success: false, error: message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
