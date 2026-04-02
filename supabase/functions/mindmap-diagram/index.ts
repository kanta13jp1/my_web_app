// Mind Map & Diagram Edge Function
// マインドマップ・ダイアグラム (Notion/Miro/Mermaid競合)
// - マインドマップ作成
// - ノード・エッジ管理
// - テンプレート
// - エクスポート (Mermaid/JSON)
// - コラボレーション
//
// GET  → マップ一覧 / ノード / テンプレート / エクスポート / 統計
// POST → マップ作成 / ノード追加 / エッジ追加 / テンプレートから作成

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const DIAGRAM_TYPES = ["mindmap", "flowchart", "org_chart", "concept_map", "tree", "network"];
const NODE_SHAPES = ["rectangle", "rounded", "circle", "diamond", "hexagon", "cloud"];
const TEMPLATES = [
  { key: "brainstorm", name: "ブレインストーミング", type: "mindmap", nodes: 7 },
  { key: "project_plan", name: "プロジェクト計画", type: "flowchart", nodes: 12 },
  { key: "swot", name: "SWOT分析", type: "concept_map", nodes: 5 },
  { key: "org_structure", name: "組織図", type: "org_chart", nodes: 10 },
  { key: "decision_tree", name: "意思決定ツリー", type: "tree", nodes: 9 },
  { key: "user_journey", name: "ユーザージャーニー", type: "flowchart", nodes: 8 },
];

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
      const mapId = url.searchParams.get("map_id");

      if (view === "options") {
        return new Response(JSON.stringify({ success: true, diagramTypes: DIAGRAM_TYPES, nodeShapes: NODE_SHAPES }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "templates") {
        return new Response(JSON.stringify({ success: true, templates: TEMPLATES }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "nodes" && mapId) {
        const { data: nodes } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "diagram_node").eq("metadata->>map_id", mapId)
          .order("created_at", { ascending: true });
        const { data: edges } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "diagram_edge").eq("metadata->>map_id", mapId);
        return new Response(JSON.stringify({
          success: true,
          nodes: (nodes ?? []).map((n) => ({ ...(n.metadata as Record<string, unknown>), createdAt: n.created_at })),
          edges: (edges ?? []).map((e) => (e.metadata as Record<string, unknown>)),
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "export" && mapId) {
        const format = url.searchParams.get("format") ?? "mermaid";
        const { data: map } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "diagram_map").eq("metadata->>map_id", mapId).maybeSingle();
        const { data: nodes } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "diagram_node").eq("metadata->>map_id", mapId);
        const { data: edges } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "diagram_edge").eq("metadata->>map_id", mapId);

        if (format === "mermaid") {
          const mapMeta = map?.metadata as Record<string, unknown> | undefined;
          const type = (mapMeta?.diagram_type as string) ?? "flowchart";
          let mermaid = type === "mindmap" ? "mindmap\n" : "flowchart TD\n";
          for (const n of nodes ?? []) {
            const nm = n.metadata as Record<string, unknown>;
            mermaid += `  ${nm.node_id}["${nm.label}"]\n`;
          }
          for (const e of edges ?? []) {
            const em = e.metadata as Record<string, unknown>;
            mermaid += `  ${em.from_node} --> ${em.to_node}\n`;
          }
          return new Response(JSON.stringify({ success: true, format: "mermaid", content: mermaid }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }

        return new Response(JSON.stringify({
          success: true, format: "json",
          content: { map: map?.metadata, nodes: (nodes ?? []).map((n) => n.metadata), edges: (edges ?? []).map((e) => e.metadata) },
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "stats") {
        const { data: maps } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "diagram_map");
        const { data: nodes } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "diagram_node");
        const typeCounts: Record<string, number> = {};
        for (const m of maps ?? []) {
          const t = ((m.metadata as Record<string, unknown>).diagram_type as string) ?? "mindmap";
          typeCounts[t] = (typeCounts[t] ?? 0) + 1;
        }
        return new Response(JSON.stringify({
          success: true,
          stats: { totalMaps: (maps ?? []).length, totalNodes: (nodes ?? []).length, typeCounts },
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      // Default: map list
      const { data: maps } = await adminClient.from("app_analytics").select("metadata, created_at")
        .eq("user_id", user.id).eq("source", "diagram_map")
        .order("created_at", { ascending: false });
      return new Response(JSON.stringify({
        success: true,
        maps: (maps ?? []).map((m) => ({ ...(m.metadata as Record<string, unknown>), createdAt: m.created_at })),
      }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      const { action } = body;

      if (action === "create_map") {
        const { title, diagram_type, description } = body;
        if (!title) {
          return new Response(JSON.stringify({ success: false, error: "title required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const mapId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "diagram_map",
          metadata: { map_id: mapId, title, diagram_type: diagram_type ?? "mindmap", description: description ?? null, node_count: 0, is_shared: false },
          created_at: new Date().toISOString(),
        });
        // Create root node
        const rootId = `node_${crypto.randomUUID().substring(0, 8)}`;
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "diagram_node",
          metadata: { map_id: mapId, node_id: rootId, label: title, shape: "rounded", color: "#4A90D9", x: 400, y: 300, is_root: true },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, mapId, rootNodeId: rootId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "add_node") {
        const { map_id, label, parent_node_id, shape, color, x, y } = body;
        if (!map_id || !label) {
          return new Response(JSON.stringify({ success: false, error: "map_id and label required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const nodeId = `node_${crypto.randomUUID().substring(0, 8)}`;
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "diagram_node",
          metadata: { map_id, node_id: nodeId, label, shape: shape ?? "rectangle", color: color ?? "#FFFFFF", x: x ?? Math.random() * 800, y: y ?? Math.random() * 600, is_root: false },
          created_at: new Date().toISOString(),
        });
        // Auto-create edge from parent
        if (parent_node_id) {
          await adminClient.from("app_analytics").insert({
            user_id: user.id, source: "diagram_edge",
            metadata: { map_id, from_node: parent_node_id, to_node: nodeId, label: null },
            created_at: new Date().toISOString(),
          });
        }
        return new Response(JSON.stringify({ success: true, nodeId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "add_edge") {
        const { map_id, from_node, to_node, label: edgeLabel } = body;
        if (!map_id || !from_node || !to_node) {
          return new Response(JSON.stringify({ success: false, error: "map_id, from_node, to_node required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "diagram_edge",
          metadata: { map_id, from_node, to_node, label: edgeLabel ?? null },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, added: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "from_template") {
        const { template_key, title } = body;
        if (!template_key) {
          return new Response(JSON.stringify({ success: false, error: "template_key required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const template = TEMPLATES.find((t) => t.key === template_key);
        if (!template) {
          return new Response(JSON.stringify({ success: false, error: "Template not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const mapId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "diagram_map",
          metadata: { map_id: mapId, title: title ?? template.name, diagram_type: template.type, description: `テンプレート: ${template.name}`, node_count: template.nodes, is_shared: false, template: template_key },
          created_at: new Date().toISOString(),
        });
        // Create root node for template
        const rootId = `node_${crypto.randomUUID().substring(0, 8)}`;
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "diagram_node",
          metadata: { map_id: mapId, node_id: rootId, label: title ?? template.name, shape: "rounded", color: "#4A90D9", x: 400, y: 300, is_root: true },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, mapId, template: template.name }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return new Response(JSON.stringify({ success: false, error: message }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
