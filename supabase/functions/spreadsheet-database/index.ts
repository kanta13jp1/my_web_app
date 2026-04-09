// Spreadsheet Database Edge Function
// スプレッドシート・データベース (Google Sheets/Notion Databases/Airtable競合)
// - 列定義 (型: text/number/date/select/checkbox/relation)
// - 行データ CRUD
// - フィルタ・ソート
// - ビュー切替 (table/gallery/board/list)
//
// GET  → データベース一覧 / 行取得 / フィルタ / ビュー
// POST → データベース作成 / 列追加 / 行追加・更新 / ビュー保存

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const COLUMN_TYPES = ["text", "number", "date", "select", "multi_select", "checkbox", "url", "email", "relation", "formula", "rollup"];
const VIEW_TYPES = ["table", "gallery", "board", "list", "calendar"];

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
      const dbId = url.searchParams.get("db_id");

      if (view === "types") {
        return new Response(JSON.stringify({ success: true, columnTypes: COLUMN_TYPES, viewTypes: VIEW_TYPES }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "rows" && dbId) {
        const sortBy = url.searchParams.get("sort_by");
        const sortDir = url.searchParams.get("sort_dir") ?? "asc";
        const filterCol = url.searchParams.get("filter_col");
        const filterVal = url.searchParams.get("filter_val");

        const { data: rows } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "spreadsheet_row")
          .eq("metadata->>db_id", dbId)
          .order("created_at", { ascending: sortDir === "asc" })
          .limit(500);

        let result = (rows ?? []).map((r) => ({ ...(r.metadata as Record<string, unknown>), createdAt: r.created_at }));

        // Apply filter
        if (filterCol && filterVal) {
          result = result.filter((r) => {
            const cells = (r.cells as Record<string, unknown>) ?? {};
            const val = String(cells[filterCol] ?? "").toLowerCase();
            return val.includes(filterVal.toLowerCase());
          });
        }

        // Apply sort
        if (sortBy) {
          result.sort((a, b) => {
            const cellsA = (a.cells as Record<string, unknown>) ?? {};
            const cellsB = (b.cells as Record<string, unknown>) ?? {};
            const va = String(cellsA[sortBy] ?? "");
            const vb = String(cellsB[sortBy] ?? "");
            return sortDir === "asc" ? va.localeCompare(vb) : vb.localeCompare(va);
          });
        }

        return new Response(JSON.stringify({ success: true, dbId, rows: result }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "detail" && dbId) {
        // DB定義と行数を並列取得
        const [{ data: db }, { data: rowCount }] = await Promise.all([
          adminClient.from("app_analytics").select("metadata, created_at")
            .eq("user_id", user.id).eq("source", "spreadsheet_db")
            .eq("metadata->>db_id", dbId).maybeSingle(),
          adminClient.from("app_analytics").select("metadata", { count: "exact", head: true })
            .eq("user_id", user.id).eq("source", "spreadsheet_row").eq("metadata->>db_id", dbId),
        ]);
        if (!db) {
          return new Response(JSON.stringify({ success: false, error: "Database not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        return new Response(JSON.stringify({
          success: true,
          database: { ...(db.metadata as Record<string, unknown>), rowCount: rowCount ?? 0, createdAt: db.created_at },
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      // Default: list databases
      const { data: dbs } = await adminClient.from("app_analytics").select("metadata, created_at")
        .eq("user_id", user.id).eq("source", "spreadsheet_db")
        .order("created_at", { ascending: false });
      return new Response(JSON.stringify({
        success: true,
        databases: (dbs ?? []).map((d) => ({ ...(d.metadata as Record<string, unknown>), createdAt: d.created_at })),
      }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      const { action } = body;

      if (action === "create_database") {
        const { name, columns, icon } = body;
        if (!name) {
          return new Response(JSON.stringify({ success: false, error: "name required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const dbId = crypto.randomUUID();
        const defaultColumns = columns ?? [
          { key: "title", name: "タイトル", type: "text" },
          { key: "status", name: "ステータス", type: "select", options: ["未着手", "進行中", "完了"] },
        ];
        const { error } = await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "spreadsheet_db",
          metadata: { db_id: dbId, name, icon: icon ?? "📊", columns: defaultColumns, views: [{ name: "テーブル", type: "table" }] },
          created_at: new Date().toISOString(),
        });
        if (error) throw error;
        return new Response(JSON.stringify({ success: true, dbId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "add_column") {
        const { db_id, key, name, type, options } = body;
        if (!db_id || !key || !name || !type) {
          return new Response(JSON.stringify({ success: false, error: "db_id, key, name, type required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        if (!COLUMN_TYPES.includes(type)) {
          return new Response(JSON.stringify({ success: false, error: "Invalid column type" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }

        const { data: existing } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "spreadsheet_db").eq("metadata->>db_id", db_id).maybeSingle();
        if (!existing) {
          return new Response(JSON.stringify({ success: false, error: "Database not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }

        const meta = existing.metadata as Record<string, unknown>;
        const columns = (meta.columns as Array<Record<string, unknown>>) ?? [];
        columns.push({ key, name, type, options: options ?? null });
        await adminClient.from("app_analytics").update({ metadata: { ...meta, columns } })
          .eq("user_id", user.id).eq("source", "spreadsheet_db").eq("metadata->>db_id", db_id);
        return new Response(JSON.stringify({ success: true, added: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "add_row") {
        const { db_id, cells } = body;
        if (!db_id || !cells) {
          return new Response(JSON.stringify({ success: false, error: "db_id and cells required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const rowId = crypto.randomUUID();
        const { error } = await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "spreadsheet_row",
          metadata: { row_id: rowId, db_id, cells },
          created_at: new Date().toISOString(),
        });
        if (error) throw error;
        return new Response(JSON.stringify({ success: true, rowId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "update_row") {
        const { row_id, db_id, cells } = body;
        if (!row_id || !db_id || !cells) {
          return new Response(JSON.stringify({ success: false, error: "row_id, db_id, cells required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const { data: existing } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "spreadsheet_row").eq("metadata->>row_id", row_id).maybeSingle();
        if (!existing) {
          return new Response(JSON.stringify({ success: false, error: "Row not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const meta = existing.metadata as Record<string, unknown>;
        const oldCells = (meta.cells as Record<string, unknown>) ?? {};
        await adminClient.from("app_analytics").update({ metadata: { ...meta, cells: { ...oldCells, ...cells } } })
          .eq("user_id", user.id).eq("source", "spreadsheet_row").eq("metadata->>row_id", row_id);
        return new Response(JSON.stringify({ success: true, updated: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "save_view") {
        const { db_id, view_name, view_type, filters, sorts } = body;
        if (!db_id || !view_name || !view_type) {
          return new Response(JSON.stringify({ success: false, error: "db_id, view_name, view_type required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const { data: existing } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "spreadsheet_db").eq("metadata->>db_id", db_id).maybeSingle();
        if (!existing) {
          return new Response(JSON.stringify({ success: false, error: "Database not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const meta = existing.metadata as Record<string, unknown>;
        const views = (meta.views as Array<Record<string, unknown>>) ?? [];
        views.push({ name: view_name, type: view_type, filters: filters ?? [], sorts: sorts ?? [] });
        await adminClient.from("app_analytics").update({ metadata: { ...meta, views } })
          .eq("user_id", user.id).eq("source", "spreadsheet_db").eq("metadata->>db_id", db_id);
        return new Response(JSON.stringify({ success: true, saved: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return new Response(JSON.stringify({ success: false, error: message }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
