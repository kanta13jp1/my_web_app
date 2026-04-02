// Document Collaboration Edge Function
// ドキュメント共同編集 (Notion/Google Docs競合)
// - ドキュメント共有・権限管理
// - バージョン履歴
// - コメント・注釈
// - 共同編集者管理
//
// GET  → ドキュメント一覧 / バージョン / コメント / 共有者
// POST → 共有 / コメント / バージョン保存

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
      const view = url.searchParams.get("view"); // 'shared_with_me' | 'versions' | 'comments' | 'collaborators'
      const noteId = url.searchParams.get("note_id");

      if (view === "shared_with_me") {
        const { data: shares } = await adminClient
          .from("app_analytics")
          .select("metadata, created_at")
          .eq("source", "doc_share")
          .eq("metadata->>shared_with_id", user.id);

        return new Response(
          JSON.stringify({
            success: true,
            documents: (shares ?? []).map((s) => ({
              ...(s.metadata as Record<string, unknown>),
              sharedAt: s.created_at,
            })),
          }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (view === "versions" && noteId) {
        const { data: versions } = await adminClient
          .from("app_analytics")
          .select("metadata, created_at")
          .eq("source", "doc_version")
          .eq("metadata->>note_id", noteId)
          .order("created_at", { ascending: false })
          .limit(20);

        return new Response(
          JSON.stringify({
            success: true,
            versions: (versions ?? []).map((v, i) => ({
              ...(v.metadata as Record<string, unknown>),
              version: (versions ?? []).length - i,
              savedAt: v.created_at,
            })),
          }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (view === "comments" && noteId) {
        const { data: comments } = await adminClient
          .from("app_analytics")
          .select("metadata, created_at, user_id")
          .eq("source", "doc_comment")
          .eq("metadata->>note_id", noteId)
          .order("created_at", { ascending: true });

        return new Response(
          JSON.stringify({
            success: true,
            comments: (comments ?? []).map((c) => ({
              ...(c.metadata as Record<string, unknown>),
              userId: c.user_id,
              createdAt: c.created_at,
            })),
          }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (view === "collaborators" && noteId) {
        const { data: shares } = await adminClient
          .from("app_analytics")
          .select("metadata, created_at")
          .eq("source", "doc_share")
          .eq("metadata->>note_id", noteId);

        return new Response(
          JSON.stringify({
            success: true,
            collaborators: (shares ?? []).map((s) => ({
              ...(s.metadata as Record<string, unknown>),
              sharedAt: s.created_at,
            })),
          }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      // Default: my shared documents
      const { data: myShares } = await adminClient
        .from("app_analytics")
        .select("metadata, created_at")
        .eq("user_id", user.id)
        .eq("source", "doc_share")
        .order("created_at", { ascending: false });

      return new Response(
        JSON.stringify({
          success: true,
          sharedDocuments: (myShares ?? []).map((s) => ({
            ...(s.metadata as Record<string, unknown>),
            sharedAt: s.created_at,
          })),
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      const { action } = body;

      if (action === "share") {
        const { note_id, shared_with_id, permission } = body;
        if (!note_id || !shared_with_id) {
          return new Response(
            JSON.stringify({ success: false, error: "note_id and shared_with_id required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        // Check if already shared
        const { data: existing } = await adminClient
          .from("app_analytics")
          .select("metadata")
          .eq("source", "doc_share")
          .eq("metadata->>note_id", note_id)
          .eq("metadata->>shared_with_id", shared_with_id)
          .maybeSingle();

        if (existing) {
          return new Response(
            JSON.stringify({ success: true, alreadyShared: true }),
            { headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const { data, error } = await adminClient.from("app_analytics").insert({
          user_id: user.id,
          source: "doc_share",
          metadata: {
            share_id: crypto.randomUUID(),
            note_id,
            owner_id: user.id,
            shared_with_id,
            permission: permission ?? "read", // 'read' | 'write' | 'admin'
          },
          created_at: new Date().toISOString(),
        }).select().single();

        if (error) throw error;

        return new Response(
          JSON.stringify({ success: true, share: data }),
          { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (action === "save_version") {
        const { note_id, content, title } = body;
        if (!note_id || !content) {
          return new Response(
            JSON.stringify({ success: false, error: "note_id and content required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const { data, error } = await adminClient.from("app_analytics").insert({
          user_id: user.id,
          source: "doc_version",
          metadata: {
            version_id: crypto.randomUUID(),
            note_id,
            title: title ?? "",
            content,
            saved_by: user.id,
          },
          created_at: new Date().toISOString(),
        }).select().single();

        if (error) throw error;

        return new Response(
          JSON.stringify({ success: true, version: data }),
          { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (action === "add_comment") {
        const { note_id, content, position } = body;
        if (!note_id || !content) {
          return new Response(
            JSON.stringify({ success: false, error: "note_id and content required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const { data, error } = await adminClient.from("app_analytics").insert({
          user_id: user.id,
          source: "doc_comment",
          metadata: {
            comment_id: crypto.randomUUID(),
            note_id,
            content,
            position: position ?? null, // {line, offset} for inline comments
            resolved: false,
          },
          created_at: new Date().toISOString(),
        }).select().single();

        if (error) throw error;

        return new Response(
          JSON.stringify({ success: true, comment: data }),
          { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } },
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
    console.error("document-collaboration error:", err);
    return new Response(
      JSON.stringify({ success: false, error: message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
