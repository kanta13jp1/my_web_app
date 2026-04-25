// Virtual Whiteboard Edge Function
// バーチャルホワイトボード (Miro/Figma/Microsoft Whiteboard競合)
// - キャンバス管理
// - 図形・テキスト配置
// - 付箋
// - テンプレート
// - コラボレーション

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type" };
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const ELEMENT_TYPES = ["rectangle", "circle", "line", "arrow", "text", "sticky_note", "image", "freehand", "connector"];
const STICKY_COLORS = ["#FFEB3B", "#4CAF50", "#2196F3", "#FF5722", "#9C27B0", "#FF9800", "#E91E63", "#00BCD4"];
const BOARD_TEMPLATES = [
  { id: "brainstorm", name: "ブレインストーミング", description: "アイデア出しボード", defaultElements: [
    { type: "text", content: "テーマ", x: 400, y: 50, fontSize: 24 },
    { type: "sticky_note", content: "アイデア1", x: 100, y: 200, color: "#FFEB3B" },
    { type: "sticky_note", content: "アイデア2", x: 300, y: 200, color: "#4CAF50" },
    { type: "sticky_note", content: "アイデア3", x: 500, y: 200, color: "#2196F3" },
  ]},
  { id: "kanban", name: "カンバン", description: "タスク管理ボード", defaultElements: [
    { type: "text", content: "ToDo", x: 100, y: 50, fontSize: 20 },
    { type: "text", content: "In Progress", x: 350, y: 50, fontSize: 20 },
    { type: "text", content: "Done", x: 600, y: 50, fontSize: 20 },
  ]},
  { id: "retrospective", name: "振り返り", description: "KPTボード", defaultElements: [
    { type: "text", content: "Keep", x: 100, y: 50, fontSize: 20 },
    { type: "text", content: "Problem", x: 350, y: 50, fontSize: 20 },
    { type: "text", content: "Try", x: 600, y: 50, fontSize: 20 },
  ]},
  { id: "mindmap", name: "マインドマップ", description: "思考整理ボード", defaultElements: [
    { type: "circle", x: 400, y: 300, radius: 60, content: "中心テーマ" },
  ]},
];

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
      const boardId = url.searchParams.get("board_id");

      if (view === "config") return new Response(JSON.stringify({ success: true, elementTypes: ELEMENT_TYPES, stickyColors: STICKY_COLORS, templates: BOARD_TEMPLATES }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });

      if (view === "board" && boardId) {
        const { data: board } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("source", "whiteboard").eq("metadata->>board_id", boardId).maybeSingle();
        if (!board) return new Response(JSON.stringify({ success: false, error: "Board not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        return new Response(JSON.stringify({ success: true, board: { ...(board.metadata as Record<string, unknown>), createdAt: board.created_at } }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "my_boards") {
        const { data: boards } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "whiteboard").order("created_at", { ascending: false });
        return new Response(JSON.stringify({ success: true, boards: (boards ?? []).map((b) => ({ ...(b.metadata as Record<string, unknown>), createdAt: b.created_at })) }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: true, templates: BOARD_TEMPLATES }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      const { action } = body;

      if (action === "create_board") {
        const { name, template_id } = body;
        if (!name) return new Response(JSON.stringify({ success: false, error: "name required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const boardId = crypto.randomUUID();
        const template = template_id ? BOARD_TEMPLATES.find((t) => t.id === template_id) : null;
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "whiteboard",
          metadata: { board_id: boardId, name, elements: template?.defaultElements ?? [], collaborators: [user.id], template_id: template_id ?? null, background: "#ffffff" },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, boardId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "add_element") {
        const { board_id, element } = body;
        if (!board_id || !element) return new Response(JSON.stringify({ success: false, error: "board_id and element required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const { data: board } = await adminClient.from("app_analytics").select("metadata")
          .eq("source", "whiteboard").eq("metadata->>board_id", board_id).maybeSingle();
        if (!board) return new Response(JSON.stringify({ success: false, error: "Board not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const m = board.metadata as Record<string, unknown>;
        const elements = [...((m.elements as Array<unknown>) ?? []), { ...element, id: crypto.randomUUID(), created_by: user.id }];
        await adminClient.from("app_analytics").update({ metadata: { ...m, elements } })
          .eq("source", "whiteboard").eq("metadata->>board_id", board_id);
        return new Response(JSON.stringify({ success: true, elementCount: elements.length }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "update_elements") {
        const { board_id, elements } = body;
        if (!board_id || !elements) return new Response(JSON.stringify({ success: false, error: "board_id and elements required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const { data: board } = await adminClient.from("app_analytics").select("metadata")
          .eq("source", "whiteboard").eq("metadata->>board_id", board_id).maybeSingle();
        if (!board) return new Response(JSON.stringify({ success: false, error: "Board not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        await adminClient.from("app_analytics").update({ metadata: { ...(board.metadata as Record<string, unknown>), elements } })
          .eq("source", "whiteboard").eq("metadata->>board_id", board_id);
        return new Response(JSON.stringify({ success: true, updated: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "add_collaborator") {
        const { board_id, collaborator_id } = body;
        if (!board_id || !collaborator_id) return new Response(JSON.stringify({ success: false, error: "board_id and collaborator_id required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const { data: board } = await adminClient.from("app_analytics").select("metadata")
          .eq("source", "whiteboard").eq("metadata->>board_id", board_id).maybeSingle();
        if (!board) return new Response(JSON.stringify({ success: false, error: "Board not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const m = board.metadata as Record<string, unknown>;
        const collaborators = [...((m.collaborators as string[]) ?? [])];
        if (!collaborators.includes(collaborator_id)) collaborators.push(collaborator_id);
        await adminClient.from("app_analytics").update({ metadata: { ...m, collaborators } })
          .eq("source", "whiteboard").eq("metadata->>board_id", board_id);
        return new Response(JSON.stringify({ success: true, collaborators }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }
    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) { return new Response(JSON.stringify({ success: false, error: err instanceof Error ? err.message : String(err) }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }); }
});
