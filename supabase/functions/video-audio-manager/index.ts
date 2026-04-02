// Video/Audio Manager Edge Function
// 動画・音声管理 (YouTube/Discord/X競合)
// - メディアメタデータ管理
// - プレイリスト
// - 文字起こし (AI)
// - メディア検索
//
// GET  → メディア一覧 / プレイリスト / 検索
// POST → メタデータ登録 / プレイリスト作成 / 文字起こし

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
      const view = url.searchParams.get("view"); // 'media' | 'playlists' | 'search'
      const type = url.searchParams.get("type"); // 'video' | 'audio'
      const query = url.searchParams.get("q");
      const playlistId = url.searchParams.get("playlist_id");

      if (view === "playlists") {
        const { data: playlists } = await adminClient.from("app_analytics").select("metadata, created_at").eq("user_id", user.id).eq("source", "media_playlist").order("created_at", { ascending: false });

        return new Response(JSON.stringify({
          success: true,
          playlists: (playlists ?? []).map((p) => ({ ...(p.metadata as Record<string, unknown>), createdAt: p.created_at })),
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      let mediaQuery = adminClient.from("app_analytics").select("metadata, created_at").eq("user_id", user.id).eq("source", "media_item").order("created_at", { ascending: false }).limit(50);

      if (type) {
        mediaQuery = mediaQuery.eq("metadata->>media_type", type);
      }

      if (playlistId) {
        mediaQuery = mediaQuery.eq("metadata->>playlist_id", playlistId);
      }

      const { data: media } = await mediaQuery;
      let mediaList = (media ?? []).map((m) => ({ ...(m.metadata as Record<string, unknown>), createdAt: m.created_at }));

      if (query) {
        const q = query.toLowerCase();
        mediaList = mediaList.filter((m) => {
          const title = ((m.title as string) ?? "").toLowerCase();
          const desc = ((m.description as string) ?? "").toLowerCase();
          return title.includes(q) || desc.includes(q);
        });
      }

      return new Response(JSON.stringify({ success: true, media: mediaList }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      const { action } = body;

      if (action === "register") {
        const { title, url: mediaUrl, media_type, duration, description, thumbnail, playlist_id } = body;
        if (!title || !mediaUrl) {
          return new Response(JSON.stringify({ success: false, error: "title and url required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }

        const mediaId = crypto.randomUUID();
        const { data, error } = await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "media_item",
          metadata: {
            media_id: mediaId, title, url: mediaUrl,
            media_type: media_type ?? "video", duration: duration ?? 0,
            description: description ?? "", thumbnail: thumbnail ?? null,
            playlist_id: playlist_id ?? null, transcript: null,
          },
          created_at: new Date().toISOString(),
        }).select().single();

        if (error) throw error;
        return new Response(JSON.stringify({ success: true, mediaId, media: data }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "create_playlist") {
        const { name, description } = body;
        if (!name) {
          return new Response(JSON.stringify({ success: false, error: "name required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }

        const playlistId = crypto.randomUUID();
        const { data, error } = await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "media_playlist",
          metadata: { playlist_id: playlistId, name, description: description ?? "" },
          created_at: new Date().toISOString(),
        }).select().single();

        if (error) throw error;
        return new Response(JSON.stringify({ success: true, playlistId, playlist: data }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "transcribe") {
        const { media_id } = body;
        if (!media_id) {
          return new Response(JSON.stringify({ success: false, error: "media_id required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }

        // Placeholder: in production, integrate with Whisper API or similar
        const transcript = "（文字起こしはAI APIとの統合後に利用可能になります。現在は手動入力をサポートしています。）";

        const { data: existing } = await adminClient.from("app_analytics").select("metadata").eq("user_id", user.id).eq("source", "media_item").eq("metadata->>media_id", media_id).maybeSingle();

        if (existing) {
          await adminClient.from("app_analytics").update({
            metadata: { ...(existing.metadata as Record<string, unknown>), transcript },
          }).eq("user_id", user.id).eq("source", "media_item").eq("metadata->>media_id", media_id);
        }

        return new Response(JSON.stringify({ success: true, transcript }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return new Response(JSON.stringify({ success: false, error: message }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
