// Clipboard History Edge Function
// クリップボード履歴 (生産性ツール)
// - テキストスニペット保存
// - ピン留め (お気に入り)
// - 検索・フィルタ
// - 有効期限付き自動削除
//
// GET  → 履歴一覧 / ピン / 検索
// POST → 保存 / ピン / 削除

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
      const view = url.searchParams.get("view"); // 'pinned' | 'search'
      const query = url.searchParams.get("q");

      const { data: clips } = await adminClient
        .from("app_analytics")
        .select("metadata, created_at")
        .eq("user_id", user.id)
        .eq("source", "clipboard")
        .order("created_at", { ascending: false })
        .limit(100);

      let clipList = (clips ?? []).map((c) => ({
        ...(c.metadata as Record<string, unknown>),
        savedAt: c.created_at,
      }));

      if (view === "pinned") {
        clipList = clipList.filter((c) => c.pinned === true);
      }

      if (query) {
        const q = query.toLowerCase();
        clipList = clipList.filter((c) => {
          const content = ((c.content as string) ?? "").toLowerCase();
          const label = ((c.label as string) ?? "").toLowerCase();
          return content.includes(q) || label.includes(q);
        });
      }

      return new Response(
        JSON.stringify({ success: true, clips: clipList, total: clipList.length }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      const { action } = body;

      if (action === "save") {
        const { content, label, category } = body;
        if (!content) {
          return new Response(
            JSON.stringify({ success: false, error: "content required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const clipId = crypto.randomUUID();
        const { data, error } = await adminClient.from("app_analytics").insert({
          user_id: user.id,
          source: "clipboard",
          metadata: {
            clip_id: clipId,
            content: content.slice(0, 10000), // 10KB limit
            label: label ?? "",
            category: category ?? "general",
            pinned: false,
            charCount: content.length,
          },
          created_at: new Date().toISOString(),
        }).select().single();

        if (error) throw error;

        return new Response(
          JSON.stringify({ success: true, clipId, clip: data }),
          { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (action === "pin") {
        const { clip_id, pinned } = body;
        if (!clip_id) {
          return new Response(
            JSON.stringify({ success: false, error: "clip_id required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const { data: existing } = await adminClient
          .from("app_analytics")
          .select("metadata")
          .eq("user_id", user.id)
          .eq("source", "clipboard")
          .eq("metadata->>clip_id", clip_id)
          .maybeSingle();

        if (!existing) {
          return new Response(
            JSON.stringify({ success: false, error: "Clip not found" }),
            { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const { error } = await adminClient
          .from("app_analytics")
          .update({ metadata: { ...(existing.metadata as Record<string, unknown>), pinned: pinned ?? true } })
          .eq("user_id", user.id)
          .eq("source", "clipboard")
          .eq("metadata->>clip_id", clip_id);

        if (error) throw error;

        return new Response(
          JSON.stringify({ success: true, pinned: pinned ?? true }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (action === "delete") {
        const { clip_id } = body;
        if (!clip_id) {
          return new Response(
            JSON.stringify({ success: false, error: "clip_id required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const { error } = await adminClient
          .from("app_analytics")
          .delete()
          .eq("user_id", user.id)
          .eq("source", "clipboard")
          .eq("metadata->>clip_id", clip_id);

        if (error) throw error;

        return new Response(
          JSON.stringify({ success: true, deleted: true }),
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
    console.error("clipboard-history error:", err);
    return new Response(
      JSON.stringify({ success: false, error: message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
