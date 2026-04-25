// Semantic Search Edge Function
// セマンティック検索 (Google/Notion競合)
// - 全文検索 (ノート/タスク/ファイル横断)
// - 検索フィルタ (タイプ/日付/タグ)
// - 検索履歴・保存検索
// - 検索サジェスト
//
// GET  → 検索 / 検索履歴 / サジェスト
// POST → 保存検索

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

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
      const view = url.searchParams.get("view"); // 'search' | 'history' | 'suggest' | 'saved'
      const query = url.searchParams.get("q") ?? "";
      const type = url.searchParams.get("type"); // 'notes' | 'tasks' | 'files' | 'all'
      const since = url.searchParams.get("since");

      if (view === "history") {
        const { data: history } = await adminClient.from("app_analytics").select("metadata, created_at").eq("user_id", user.id).eq("source", "search_history").order("created_at", { ascending: false }).limit(20);
        return new Response(JSON.stringify({
          success: true,
          history: (history ?? []).map((h) => ({ ...(h.metadata as Record<string, unknown>), searchedAt: h.created_at })),
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "saved") {
        const { data: saved } = await adminClient.from("app_analytics").select("metadata, created_at").eq("user_id", user.id).eq("source", "saved_search").order("created_at", { ascending: false });
        return new Response(JSON.stringify({
          success: true,
          savedSearches: (saved ?? []).map((s) => ({ ...(s.metadata as Record<string, unknown>), savedAt: s.created_at })),
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "suggest") {
        // Return popular recent searches
        const { data: recent } = await adminClient.from("app_analytics").select("metadata").eq("user_id", user.id).eq("source", "search_history").order("created_at", { ascending: false }).limit(10);
        const suggestions = [...new Set((recent ?? []).map((r) => (r.metadata as Record<string, unknown>)?.query as string).filter(Boolean))].slice(0, 5);
        return new Response(JSON.stringify({ success: true, suggestions }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (!query) {
        return new Response(JSON.stringify({ success: true, results: [], message: "Enter a search query" }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      const q = query.toLowerCase();
      const results: Array<{ type: string; title: string; snippet: string; id: string; score: number; date: string }> = [];

      const searchNotes = !type || type === "notes" || type === "all";
      const searchTasks = !type || type === "tasks" || type === "all";

      // Build notes query
      const buildNotesQuery = () => {
        let notesQuery = adminClient
          .from("notes")
          .select("id, title, content, tags, created_at")
          .eq("user_id", user.id);
        if (since) notesQuery = notesQuery.gte("created_at", since);
        return notesQuery.limit(100);
      };

      // Run all applicable searches in parallel
      const [notesResult, tasksResult] = await Promise.all([
        searchNotes ? buildNotesQuery() : Promise.resolve({ data: null }),
        searchTasks
          ? adminClient.from("agent_tasks").select("id, title, description, created_at").limit(100)
          : Promise.resolve({ data: null }),
      ]);

      // Process notes results
      for (const note of notesResult.data ?? []) {
        const title = ((note as Record<string, unknown>).title as string ?? "").toLowerCase();
        const content = ((note as Record<string, unknown>).content as string ?? "").toLowerCase();
        let score = 0;
        if (title.includes(q)) score += 10;
        if (content.includes(q)) score += 5;
        const tags = ((note as Record<string, unknown>).tags as string[]) ?? [];
        if (tags.some((t) => t.toLowerCase().includes(q))) score += 3;
        if (score > 0) {
          const idx = content.indexOf(q);
          const snippetStart = Math.max(0, idx - 30);
          const snippet = content.substring(snippetStart, snippetStart + 100) + "...";
          results.push({ type: "note", title: (note as Record<string, unknown>).title as string ?? "無題", snippet, id: (note as Record<string, unknown>).id as string, score, date: (note as Record<string, unknown>).created_at as string });
        }
      }

      // Process tasks results
      for (const task of tasksResult.data ?? []) {
        const title = ((task as Record<string, unknown>).title as string ?? "").toLowerCase();
        const desc = ((task as Record<string, unknown>).description as string ?? "").toLowerCase();
        let score = 0;
        if (title.includes(q)) score += 8;
        if (desc.includes(q)) score += 4;
        if (score > 0) {
          results.push({ type: "task", title: (task as Record<string, unknown>).title as string ?? "無題タスク", snippet: ((task as Record<string, unknown>).description as string ?? "").substring(0, 100), id: (task as Record<string, unknown>).id as string, score, date: (task as Record<string, unknown>).created_at as string });
        }
      }

      // Sort by score
      results.sort((a, b) => b.score - a.score);

      // Log search
      await adminClient.from("app_analytics").insert({
        user_id: user.id, source: "search_history",
        metadata: { query, type: type ?? "all", resultCount: results.length },
        created_at: new Date().toISOString(),
      });

      return new Response(JSON.stringify({ success: true, query, results: results.slice(0, 20), totalResults: results.length }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      const { action } = body;

      if (action === "save_search") {
        const { query: savedQuery, filters } = body;
        if (!savedQuery) {
          return new Response(JSON.stringify({ success: false, error: "query required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }

        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "saved_search",
          metadata: { query: savedQuery, filters: filters ?? {} },
          created_at: new Date().toISOString(),
        });

        return new Response(JSON.stringify({ success: true, saved: true }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return new Response(JSON.stringify({ success: false, error: message }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
