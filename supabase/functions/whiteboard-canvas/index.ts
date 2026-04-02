// Whiteboard Canvas Edge Function
// ホワイトボード・キャンバス (Microsoft Whiteboard/Notion/Miro/FigJam競合)
// - 無限キャンバス状態管理
// - 図形・テキスト・コネクター保存
// - テンプレート提供
// - リアルタイム共有 (realtime-presenceと連携)
//
// GET  → ボード一覧 / 要素取得 / テンプレート
// POST → ボード作成 / 要素追加・更新・削除 / 共有

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const TEMPLATES = [
  { key: "blank", name: "ブランク", icon: "⬜", description: "白紙キャンバス" },
  { key: "brainstorm", name: "ブレインストーミング", icon: "🧠", description: "中央トピック + 放射状配置" },
  { key: "flowchart", name: "フローチャート", icon: "📊", description: "開始→処理→判断→終了" },
  { key: "kanban", name: "カンバン", icon: "📋", description: "Todo / In Progress / Done" },
  { key: "mindmap", name: "マインドマップ", icon: "🗺️", description: "階層型思考整理" },
  { key: "wireframe", name: "ワイヤーフレーム", icon: "📱", description: "画面設計テンプレート" },
  { key: "retrospective", name: "振り返り", icon: "🔄", description: "KPT (Keep/Problem/Try)" },
  { key: "org_chart", name: "組織図", icon: "👥", description: "階層型組織チャート" },
];

const ELEMENT_TYPES = ["rect", "circle", "text", "sticky_note", "arrow", "line", "image", "group", "freehand"];

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
      const boardId = url.searchParams.get("board_id");

      if (view === "templates") {
        return new Response(JSON.stringify({ success: true, templates: TEMPLATES, elementTypes: ELEMENT_TYPES }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "elements" && boardId) {
        const { data: elements } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "whiteboard_element")
          .eq("metadata->>board_id", boardId)
          .order("created_at", { ascending: true });
        return new Response(JSON.stringify({
          success: true, boardId,
          elements: (elements ?? []).map((e) => ({ ...(e.metadata as Record<string, unknown>), createdAt: e.created_at })),
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      // Default: board list
      const { data: boards } = await adminClient.from("app_analytics").select("metadata, created_at")
        .eq("user_id", user.id).eq("source", "whiteboard")
        .order("created_at", { ascending: false });
      return new Response(JSON.stringify({
        success: true,
        boards: (boards ?? []).map((b) => ({ ...(b.metadata as Record<string, unknown>), createdAt: b.created_at })),
      }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      const { action } = body;

      if (action === "create_board") {
        const { name, template } = body;
        if (!name) {
          return new Response(JSON.stringify({ success: false, error: "name required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const boardId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "whiteboard",
          metadata: {
            board_id: boardId, name,
            template: template ?? "blank",
            viewport: { x: 0, y: 0, zoom: 1 },
            shared_with: [],
          },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, boardId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "add_element") {
        const { board_id, type, x, y, width, height, content, style } = body;
        if (!board_id || !type) {
          return new Response(JSON.stringify({ success: false, error: "board_id and type required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        if (!ELEMENT_TYPES.includes(type)) {
          return new Response(JSON.stringify({ success: false, error: "Invalid element type" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const elementId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "whiteboard_element",
          metadata: {
            element_id: elementId, board_id, type,
            x: x ?? 0, y: y ?? 0,
            width: width ?? 100, height: height ?? 100,
            content: content ?? "", style: style ?? {},
            locked: false, z_index: Date.now(),
          },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, elementId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "update_element") {
        const { element_id, x, y, width, height, content, style } = body;
        if (!element_id) {
          return new Response(JSON.stringify({ success: false, error: "element_id required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const { data: existing } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "whiteboard_element").eq("metadata->>element_id", element_id).maybeSingle();
        if (!existing) {
          return new Response(JSON.stringify({ success: false, error: "Element not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const meta = existing.metadata as Record<string, unknown>;
        const updates: Record<string, unknown> = {};
        if (x !== undefined) updates.x = x;
        if (y !== undefined) updates.y = y;
        if (width !== undefined) updates.width = width;
        if (height !== undefined) updates.height = height;
        if (content !== undefined) updates.content = content;
        if (style !== undefined) updates.style = style;
        await adminClient.from("app_analytics").update({ metadata: { ...meta, ...updates } })
          .eq("user_id", user.id).eq("source", "whiteboard_element").eq("metadata->>element_id", element_id);
        return new Response(JSON.stringify({ success: true, updated: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "delete_element") {
        const { element_id } = body;
        if (!element_id) {
          return new Response(JSON.stringify({ success: false, error: "element_id required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        await adminClient.from("app_analytics").delete()
          .eq("user_id", user.id).eq("source", "whiteboard_element").eq("metadata->>element_id", element_id);
        return new Response(JSON.stringify({ success: true, deleted: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "share") {
        const { board_id, share_with_user_id, permission } = body;
        if (!board_id || !share_with_user_id) {
          return new Response(JSON.stringify({ success: false, error: "board_id and share_with_user_id required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const { data: existing } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "whiteboard").eq("metadata->>board_id", board_id).maybeSingle();
        if (!existing) {
          return new Response(JSON.stringify({ success: false, error: "Board not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const meta = existing.metadata as Record<string, unknown>;
        const shared = (meta.shared_with as Array<Record<string, unknown>>) ?? [];
        shared.push({ user_id: share_with_user_id, permission: permission ?? "view" });
        await adminClient.from("app_analytics").update({ metadata: { ...meta, shared_with: shared } })
          .eq("user_id", user.id).eq("source", "whiteboard").eq("metadata->>board_id", board_id);
        return new Response(JSON.stringify({ success: true, shared: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return new Response(JSON.stringify({ success: false, error: message }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
