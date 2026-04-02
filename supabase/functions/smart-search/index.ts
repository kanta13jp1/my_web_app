// Smart Search with Filters Edge Function
// スマート検索・フィルタ (Google/Notion/Evernote競合)
// - 全文検索
// - フィルタ条件
// - 検索履歴
// - 保存済み検索
// - 検索サジェスト

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const SEARCHABLE_SOURCES = [
  "note", "task", "calendar_event", "contact", "expense", "bookmark",
  "code_snippet", "vault_entry", "feedback", "document", "memo",
];

const SORT_OPTIONS = ["relevance", "newest", "oldest", "alphabetical"];

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

      if (view === "options") return new Response(JSON.stringify({ success: true, searchableSources: SEARCHABLE_SOURCES, sortOptions: SORT_OPTIONS }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });

      if (view === "history") {
        const { data: history } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "search_history")
          .order("created_at", { ascending: false }).limit(20);
        return new Response(JSON.stringify({ success: true, history: (history ?? []).map((h) => ({ ...(h.metadata as Record<string, unknown>), createdAt: h.created_at })) }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "saved") {
        const { data: saved } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "saved_search")
          .order("created_at", { ascending: false });
        return new Response(JSON.stringify({ success: true, savedSearches: (saved ?? []).map((s) => ({ ...(s.metadata as Record<string, unknown>), createdAt: s.created_at })) }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "suggest") {
        const q = url.searchParams.get("q") ?? "";
        if (!q) return new Response(JSON.stringify({ success: true, suggestions: [] }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
        // Get recent search terms that match
        const { data: history } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "search_history")
          .order("created_at", { ascending: false }).limit(100);
        const terms = [...new Set((history ?? []).map((h) => (h.metadata as Record<string, unknown>).query as string).filter((t) => t && t.toLowerCase().includes(q.toLowerCase())))].slice(0, 5);
        return new Response(JSON.stringify({ success: true, suggestions: terms }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: true, sources: SEARCHABLE_SOURCES, sorts: SORT_OPTIONS }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      const { action } = body;

      if (action === "search") {
        const { query, sources, sort, date_from, date_to, limit: maxResults } = body;
        if (!query) return new Response(JSON.stringify({ success: false, error: "query required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const searchSources = sources ?? SEARCHABLE_SOURCES;
        const lim = maxResults ?? 50;

        // Search across all source types
        const results: Array<Record<string, unknown>> = [];
        for (const src of searchSources) {
          let q = adminClient.from("app_analytics").select("source, metadata, created_at")
            .eq("user_id", user.id).eq("source", src);
          if (date_from) q = q.gte("created_at", date_from);
          if (date_to) q = q.lte("created_at", date_to);
          const { data } = await q.order("created_at", { ascending: false }).limit(lim);
          for (const item of data ?? []) {
            const meta = item.metadata as Record<string, unknown>;
            const metaStr = JSON.stringify(meta).toLowerCase();
            if (metaStr.includes(query.toLowerCase())) {
              results.push({ source: item.source, ...meta, createdAt: item.created_at });
            }
          }
        }

        // Sort
        if (sort === "newest") results.sort((a, b) => String(b.createdAt ?? "").localeCompare(String(a.createdAt ?? "")));
        else if (sort === "oldest") results.sort((a, b) => String(a.createdAt ?? "").localeCompare(String(b.createdAt ?? "")));
        else if (sort === "alphabetical") results.sort((a, b) => String(a.title ?? a.name ?? "").localeCompare(String(b.title ?? b.name ?? "")));

        // Record search history
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "search_history",
          metadata: { query, sources: searchSources, result_count: results.length, sort: sort ?? "relevance" },
          created_at: new Date().toISOString(),
        });

        return new Response(JSON.stringify({ success: true, results: results.slice(0, lim), totalResults: results.length, query }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "save_search") {
        const { name, query, sources, filters } = body;
        if (!name || !query) return new Response(JSON.stringify({ success: false, error: "name and query required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const searchId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "saved_search",
          metadata: { search_id: searchId, name, query, sources: sources ?? SEARCHABLE_SOURCES, filters: filters ?? {} },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, searchId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "clear_history") {
        await adminClient.from("app_analytics").delete()
          .eq("user_id", user.id).eq("source", "search_history");
        return new Response(JSON.stringify({ success: true, cleared: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    return new Response(JSON.stringify({ success: false, error: err instanceof Error ? err.message : String(err) }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
