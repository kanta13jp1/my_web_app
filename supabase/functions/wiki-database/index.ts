// Wiki Database Edge Function
// Wiki・データベース (Notion競合)
// - ページ階層管理 (親子関係)
// - テーブルビュー (構造化データ)
// - リンク参照
// - テンプレートからのページ生成
//
// GET  → ページ一覧 / ページ詳細 / 子ページ / テーブル
// POST → ページ作成 / 更新 / テーブル行追加

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
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
      const view = url.searchParams.get("view");
      const pageId = url.searchParams.get("page_id");
      const parentId = url.searchParams.get("parent_id");

      if (view === "page" && pageId) {
        // ページ本体と子ページを並列取得
        const [{ data: page }, { data: children }] = await Promise.all([
          adminClient.from("app_analytics").select("metadata, created_at").eq("user_id", user.id).eq("source", "wiki_page").eq("metadata->>page_id", pageId).maybeSingle(),
          adminClient.from("app_analytics").select("metadata, created_at").eq("user_id", user.id).eq("source", "wiki_page").eq("metadata->>parent_id", pageId).order("created_at", { ascending: true }),
        ]);
        if (!page) {
          return new Response(JSON.stringify({ success: false, error: "Page not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        return new Response(JSON.stringify({
          success: true,
          page: { ...(page.metadata as Record<string, unknown>), createdAt: page.created_at },
          children: (children ?? []).map((c) => ({ ...(c.metadata as Record<string, unknown>), createdAt: c.created_at })),
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "table" && pageId) {
        const { data: rows } = await adminClient.from("app_analytics").select("metadata, created_at").eq("user_id", user.id).eq("source", "wiki_table_row").eq("metadata->>table_id", pageId).order("created_at", { ascending: true });
        return new Response(JSON.stringify({
          success: true,
          rows: (rows ?? []).map((r) => ({ ...(r.metadata as Record<string, unknown>), createdAt: r.created_at })),
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      // Page list (root or children of parent)
      let query = adminClient.from("app_analytics").select("metadata, created_at").eq("user_id", user.id).eq("source", "wiki_page").order("created_at", { ascending: false });
      if (parentId) {
        query = query.eq("metadata->>parent_id", parentId);
      } else {
        // Root pages only (no parent)
        query = query.is("metadata->>parent_id", null);
      }
      const { data: pages } = await query.limit(50);
      return new Response(JSON.stringify({
        success: true,
        pages: (pages ?? []).map((p) => ({ ...(p.metadata as Record<string, unknown>), createdAt: p.created_at })),
      }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      const { action } = body;

      if (action === "create_page") {
        const { title, content, parent_id, icon, page_type } = body;
        if (!title) {
          return new Response(JSON.stringify({ success: false, error: "title required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const pageId = crypto.randomUUID();
        const { data, error } = await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "wiki_page",
          metadata: { page_id: pageId, title, content: content ?? "", parent_id: parent_id ?? null, icon: icon ?? "📄", page_type: page_type ?? "page" },
          created_at: new Date().toISOString(),
        }).select().single();
        if (error) throw error;
        return new Response(JSON.stringify({ success: true, pageId, page: data }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "update_page") {
        const { page_id, title, content, icon } = body;
        if (!page_id) {
          return new Response(JSON.stringify({ success: false, error: "page_id required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const { data: existing } = await adminClient.from("app_analytics").select("metadata").eq("user_id", user.id).eq("source", "wiki_page").eq("metadata->>page_id", page_id).maybeSingle();
        if (!existing) {
          return new Response(JSON.stringify({ success: false, error: "Page not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const meta = existing.metadata as Record<string, unknown>;
        const updated: Record<string, unknown> = { ...meta };
        if (title !== undefined) updated.title = title;
        if (content !== undefined) updated.content = content;
        if (icon !== undefined) updated.icon = icon;
        const { error } = await adminClient.from("app_analytics").update({ metadata: updated }).eq("user_id", user.id).eq("source", "wiki_page").eq("metadata->>page_id", page_id);
        if (error) throw error;
        return new Response(JSON.stringify({ success: true, updated: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "add_table_row") {
        const { table_id, columns } = body;
        if (!table_id || !columns) {
          return new Response(JSON.stringify({ success: false, error: "table_id and columns required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const rowId = crypto.randomUUID();
        const { error } = await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "wiki_table_row",
          metadata: { row_id: rowId, table_id, columns },
          created_at: new Date().toISOString(),
        });
        if (error) throw error;
        return new Response(JSON.stringify({ success: true, rowId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return new Response(JSON.stringify({ success: false, error: message }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
