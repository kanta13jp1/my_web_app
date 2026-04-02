// Kanban Board Edge Function
// プロジェクト管理 — カンバンボード
// - ボード / カラム / カード CRUD
// - ドラッグ&ドロップ用のカード移動
// - ラベル・担当者・期日
//
// GET  → ボード一覧 / ボード詳細 / カード一覧
// POST → ボード作成 / カード作成 / カード移動 / カード更新

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

// デフォルトカラム
const DEFAULT_COLUMNS = [
  { key: "backlog", label: "バックログ", order: 0 },
  { key: "todo", label: "TODO", order: 1 },
  { key: "in_progress", label: "進行中", order: 2 },
  { key: "review", label: "レビュー", order: 3 },
  { key: "done", label: "完了", order: 4 },
];

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
      const boardId = url.searchParams.get("board_id");

      if (boardId) {
        // ボード詳細 + カード一覧
        const { data: board } = await adminClient
          .from("app_analytics")
          .select("metadata, created_at")
          .eq("user_id", user.id)
          .eq("source", "kanban_board")
          .eq("metadata->>board_id", boardId)
          .maybeSingle();

        const { data: cards } = await adminClient
          .from("app_analytics")
          .select("metadata, created_at")
          .eq("user_id", user.id)
          .eq("source", "kanban_card")
          .eq("metadata->>board_id", boardId)
          .order("created_at", { ascending: true });

        const columns = ((board?.metadata as Record<string, unknown>)?.columns as typeof DEFAULT_COLUMNS) ?? DEFAULT_COLUMNS;

        // カラムごとにカードをグループ化
        const columnCards: Record<string, Array<Record<string, unknown>>> = {};
        for (const col of columns) {
          columnCards[col.key] = [];
        }
        for (const card of cards ?? []) {
          const meta = card.metadata as Record<string, unknown>;
          const col = (meta?.column as string) ?? "backlog";
          if (!columnCards[col]) columnCards[col] = [];
          columnCards[col].push({ ...meta, createdAt: card.created_at });
        }

        return new Response(
          JSON.stringify({
            success: true,
            board: board?.metadata ?? null,
            columns,
            cards: columnCards,
            totalCards: (cards ?? []).length,
          }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      // ボード一覧
      const { data: boards } = await adminClient
        .from("app_analytics")
        .select("metadata, created_at")
        .eq("user_id", user.id)
        .eq("source", "kanban_board")
        .order("created_at", { ascending: false });

      return new Response(
        JSON.stringify({
          success: true,
          boards: (boards ?? []).map((b) => ({
            ...(b.metadata as Record<string, unknown>),
            createdAt: b.created_at,
          })),
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      const { action } = body;

      if (action === "create_board") {
        const { name, description } = body;
        if (!name) {
          return new Response(
            JSON.stringify({ success: false, error: "name required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const boardId = crypto.randomUUID();
        const { data, error } = await adminClient.from("app_analytics").insert({
          user_id: user.id,
          source: "kanban_board",
          metadata: {
            board_id: boardId,
            name,
            description: description ?? "",
            columns: DEFAULT_COLUMNS,
          },
          created_at: new Date().toISOString(),
        }).select().single();

        if (error) throw error;

        return new Response(
          JSON.stringify({ success: true, boardId, board: data }),
          { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (action === "create_card") {
        const { board_id, title, description, column, labels, due_date, assignee } = body;
        if (!board_id || !title) {
          return new Response(
            JSON.stringify({ success: false, error: "board_id and title required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const cardId = crypto.randomUUID();
        const { data, error } = await adminClient.from("app_analytics").insert({
          user_id: user.id,
          source: "kanban_card",
          metadata: {
            card_id: cardId,
            board_id,
            title,
            description: description ?? "",
            column: column ?? "backlog",
            labels: labels ?? [],
            due_date: due_date ?? null,
            assignee: assignee ?? null,
          },
          created_at: new Date().toISOString(),
        }).select().single();

        if (error) throw error;

        return new Response(
          JSON.stringify({ success: true, cardId, card: data }),
          { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (action === "move_card") {
        const { card_id, to_column } = body;
        if (!card_id || !to_column) {
          return new Response(
            JSON.stringify({ success: false, error: "card_id and to_column required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const { data: existing } = await adminClient
          .from("app_analytics")
          .select("metadata")
          .eq("user_id", user.id)
          .eq("source", "kanban_card")
          .eq("metadata->>card_id", card_id)
          .maybeSingle();

        if (!existing) {
          return new Response(
            JSON.stringify({ success: false, error: "Card not found" }),
            { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const { error } = await adminClient
          .from("app_analytics")
          .update({ metadata: { ...(existing.metadata as Record<string, unknown>), column: to_column } })
          .eq("user_id", user.id)
          .eq("source", "kanban_card")
          .eq("metadata->>card_id", card_id);

        if (error) throw error;

        return new Response(
          JSON.stringify({ success: true, moved: true, to_column }),
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
    console.error("kanban-board error:", err);
    return new Response(
      JSON.stringify({ success: false, error: message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
