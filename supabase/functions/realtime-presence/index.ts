// Realtime Presence Edge Function
// リアルタイムコラボレーション (Notion/Google Docs/Microsoft競合)
// - ドキュメント閲覧者一覧
// - カーソル位置共有
// - 編集ロック管理
// - オンラインステータス
//
// GET  → プレゼンス情報 / オンラインユーザー
// POST → プレゼンス更新 / ロック取得・解放

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const LOCK_TIMEOUT_MS = 5 * 60 * 1000; // 5 minutes

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
      const documentId = url.searchParams.get("document_id");

      if (view === "online") {
        // Get recently active users (last 5 min)
        const since = new Date(Date.now() - 5 * 60 * 1000).toISOString();
        const { data: presences } = await adminClient.from("app_analytics").select("user_id, metadata, created_at").eq("source", "presence_heartbeat").gte("created_at", since).order("created_at", { ascending: false });

        const seen = new Set<string>();
        const onlineUsers = [];
        for (const p of presences ?? []) {
          if (!seen.has(p.user_id)) {
            seen.add(p.user_id);
            const meta = p.metadata as Record<string, unknown>;
            onlineUsers.push({ user_id: p.user_id, display_name: meta.display_name, status: meta.status, lastSeen: p.created_at });
          }
        }

        return new Response(JSON.stringify({ success: true, onlineUsers, count: onlineUsers.length }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "document" && documentId) {
        const since = new Date(Date.now() - 2 * 60 * 1000).toISOString();
        const { data: viewers } = await adminClient.from("app_analytics").select("user_id, metadata, created_at").eq("source", "presence_document").eq("metadata->>document_id", documentId).gte("created_at", since).order("created_at", { ascending: false });

        const seen = new Set<string>();
        const activeViewers = [];
        for (const v of viewers ?? []) {
          if (!seen.has(v.user_id)) {
            seen.add(v.user_id);
            const meta = v.metadata as Record<string, unknown>;
            activeViewers.push({
              user_id: v.user_id,
              display_name: meta.display_name,
              cursor_position: meta.cursor_position,
              color: meta.color,
              lastSeen: v.created_at,
            });
          }
        }

        // Check locks
        const { data: locks } = await adminClient.from("app_analytics").select("metadata, created_at").eq("source", "document_lock").eq("metadata->>document_id", documentId).eq("metadata->>active", "true").order("created_at", { ascending: false }).limit(1);
        const activeLock = locks?.[0];
        let lockInfo = null;
        if (activeLock) {
          const lockMeta = activeLock.metadata as Record<string, unknown>;
          const lockTime = new Date(activeLock.created_at).getTime();
          if (Date.now() - lockTime < LOCK_TIMEOUT_MS) {
            lockInfo = { locked_by: lockMeta.user_id, display_name: lockMeta.display_name, locked_at: activeLock.created_at };
          }
        }

        return new Response(JSON.stringify({ success: true, documentId, viewers: activeViewers, lock: lockInfo }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: true, views: ["online", "document"] }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      const { action } = body;

      if (action === "heartbeat") {
        const { display_name, status } = body;
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "presence_heartbeat",
          metadata: { display_name: display_name ?? user.email, status: status ?? "online" },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "join_document") {
        const { document_id, display_name, cursor_position, color } = body;
        if (!document_id) {
          return new Response(JSON.stringify({ success: false, error: "document_id required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        // Assign a random color if not provided
        const colors = ["#FF6B6B", "#4ECDC4", "#45B7D1", "#96CEB4", "#FFEAA7", "#DDA0DD", "#98D8C8", "#F7DC6F"];
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "presence_document",
          metadata: {
            document_id,
            display_name: display_name ?? user.email,
            cursor_position: cursor_position ?? null,
            color: color ?? colors[Math.floor(Math.random() * colors.length)],
          },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "acquire_lock") {
        const { document_id, display_name } = body;
        if (!document_id) {
          return new Response(JSON.stringify({ success: false, error: "document_id required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }

        // Check existing lock
        const { data: existing } = await adminClient.from("app_analytics").select("metadata, created_at").eq("source", "document_lock").eq("metadata->>document_id", document_id).eq("metadata->>active", "true").order("created_at", { ascending: false }).limit(1);
        if (existing?.[0]) {
          const lockMeta = existing[0].metadata as Record<string, unknown>;
          const lockTime = new Date(existing[0].created_at).getTime();
          if (Date.now() - lockTime < LOCK_TIMEOUT_MS && lockMeta.user_id !== user.id) {
            return new Response(JSON.stringify({ success: false, error: "Document locked by another user", locked_by: lockMeta.display_name }), { status: 409, headers: { ...corsHeaders, "Content-Type": "application/json" } });
          }
        }

        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "document_lock",
          metadata: { document_id, user_id: user.id, display_name: display_name ?? user.email, active: "true" },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, locked: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "release_lock") {
        const { document_id } = body;
        if (!document_id) {
          return new Response(JSON.stringify({ success: false, error: "document_id required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        // Insert a release record
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "document_lock",
          metadata: { document_id, user_id: user.id, active: "false" },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, released: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return new Response(JSON.stringify({ success: false, error: message }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
