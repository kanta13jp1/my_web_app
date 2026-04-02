// Quick Note Edge Function
// クイックメモ (Evernote/Google Keep競合)
// - 即座にメモ作成 (タイトル不要)
// - 色分け
// - チェックリスト
// - ピン留め
//
// GET  → メモ一覧 / ピン / 色別
// POST → 作成 / 更新 / ピン / アーカイブ

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

const COLORS = ["default", "red", "orange", "yellow", "green", "blue", "purple", "pink"];

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
      const view = url.searchParams.get("view"); // 'pinned' | 'archived' | 'color'
      const color = url.searchParams.get("color");
      const query = url.searchParams.get("q");

      const { data: notes } = await adminClient
        .from("app_analytics")
        .select("metadata, created_at")
        .eq("user_id", user.id)
        .eq("source", "quick_note")
        .order("created_at", { ascending: false })
        .limit(100);

      let noteList = (notes ?? []).map((n) => ({
        ...(n.metadata as Record<string, unknown>),
        createdAt: n.created_at,
      }));

      if (view === "pinned") {
        noteList = noteList.filter((n) => n.pinned === true);
      } else if (view === "archived") {
        noteList = noteList.filter((n) => n.archived === true);
      } else {
        // Default: exclude archived
        noteList = noteList.filter((n) => n.archived !== true);
      }

      if (color) {
        noteList = noteList.filter((n) => n.color === color);
      }

      if (query) {
        const q = query.toLowerCase();
        noteList = noteList.filter((n) => {
          const content = ((n.content as string) ?? "").toLowerCase();
          const title = ((n.title as string) ?? "").toLowerCase();
          return content.includes(q) || title.includes(q);
        });
      }

      // Pinned first
      noteList.sort((a, b) => {
        if (a.pinned && !b.pinned) return -1;
        if (!a.pinned && b.pinned) return 1;
        return 0;
      });

      return new Response(
        JSON.stringify({ success: true, notes: noteList, total: noteList.length, colors: COLORS }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      const { action } = body;

      if (action === "create") {
        const { content, title, color: noteColor, checklist } = body;
        if (!content && (!checklist || !Array.isArray(checklist))) {
          return new Response(
            JSON.stringify({ success: false, error: "content or checklist required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const noteId = crypto.randomUUID();
        const { data, error } = await adminClient.from("app_analytics").insert({
          user_id: user.id,
          source: "quick_note",
          metadata: {
            note_id: noteId,
            title: title ?? "",
            content: content ?? "",
            color: noteColor ?? "default",
            pinned: false,
            archived: false,
            checklist: checklist ?? null,
          },
          created_at: new Date().toISOString(),
        }).select().single();

        if (error) throw error;

        return new Response(
          JSON.stringify({ success: true, noteId, note: data }),
          { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (action === "update") {
        const { note_id, content, title, color: noteColor, checklist } = body;
        if (!note_id) {
          return new Response(
            JSON.stringify({ success: false, error: "note_id required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const { data: existing } = await adminClient
          .from("app_analytics")
          .select("metadata")
          .eq("user_id", user.id)
          .eq("source", "quick_note")
          .eq("metadata->>note_id", note_id)
          .maybeSingle();

        if (!existing) {
          return new Response(
            JSON.stringify({ success: false, error: "Note not found" }),
            { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const meta = existing.metadata as Record<string, unknown>;
        const updated: Record<string, unknown> = { ...meta };
        if (content !== undefined) updated.content = content;
        if (title !== undefined) updated.title = title;
        if (noteColor !== undefined) updated.color = noteColor;
        if (checklist !== undefined) updated.checklist = checklist;

        const { error } = await adminClient
          .from("app_analytics")
          .update({ metadata: updated })
          .eq("user_id", user.id)
          .eq("source", "quick_note")
          .eq("metadata->>note_id", note_id);

        if (error) throw error;

        return new Response(
          JSON.stringify({ success: true, updated: true }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (action === "pin" || action === "archive") {
        const { note_id } = body;
        const field = action === "pin" ? "pinned" : "archived";
        const value = body[field] ?? true;

        if (!note_id) {
          return new Response(
            JSON.stringify({ success: false, error: "note_id required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const { data: existing } = await adminClient
          .from("app_analytics")
          .select("metadata")
          .eq("user_id", user.id)
          .eq("source", "quick_note")
          .eq("metadata->>note_id", note_id)
          .maybeSingle();

        if (!existing) {
          return new Response(
            JSON.stringify({ success: false, error: "Note not found" }),
            { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const { error } = await adminClient
          .from("app_analytics")
          .update({ metadata: { ...(existing.metadata as Record<string, unknown>), [field]: value } })
          .eq("user_id", user.id)
          .eq("source", "quick_note")
          .eq("metadata->>note_id", note_id);

        if (error) throw error;

        return new Response(
          JSON.stringify({ success: true, [field]: value }),
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
    console.error("quick-note error:", err);
    return new Response(
      JSON.stringify({ success: false, error: message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
