// Music Playlist Manager Edge Function
// 音楽プレイリスト管理 (Amazon Music/Liven競合)
// - プレイリスト作成・管理
// - 楽曲登録 (メタデータ)
// - 再生履歴
// - お気に入り・レコメンド
// - ジャンル別統計
//
// GET  → プレイリスト一覧 / 楽曲 / 履歴 / レコメンド / 統計
// POST → プレイリスト作成 / 楽曲追加 / 再生記録 / お気に入り

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const GENRES = ["pop", "rock", "jazz", "classical", "hip_hop", "electronic", "r_and_b", "country", "anime", "jpop", "kpop", "soundtrack"];

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

      if (view === "genres") {
        return new Response(JSON.stringify({ success: true, genres: GENRES }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "tracks") {
        const playlistId = url.searchParams.get("playlist_id");
        let query = adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "music_track")
          .order("created_at", { ascending: false });
        if (playlistId) query = query.eq("metadata->>playlist_id", playlistId);
        const { data: tracks } = await query.limit(100);
        return new Response(JSON.stringify({
          success: true,
          tracks: (tracks ?? []).map((t) => ({ ...(t.metadata as Record<string, unknown>), createdAt: t.created_at })),
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "history") {
        const { data: history } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "music_play")
          .order("created_at", { ascending: false }).limit(50);
        return new Response(JSON.stringify({
          success: true,
          history: (history ?? []).map((h) => ({ ...(h.metadata as Record<string, unknown>), playedAt: h.created_at })),
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "favorites") {
        const { data: favs } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "music_track").eq("metadata->>is_favorite", "true")
          .order("created_at", { ascending: false });
        return new Response(JSON.stringify({
          success: true,
          favorites: (favs ?? []).map((f) => ({ ...(f.metadata as Record<string, unknown>), createdAt: f.created_at })),
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "recommend") {
        // Simple recommendation: most played genres → suggest tracks from those genres
        const { data: plays } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "music_play");
        const genreCounts: Record<string, number> = {};
        for (const p of plays ?? []) {
          const genre = ((p.metadata as Record<string, unknown>).genre as string) ?? "pop";
          genreCounts[genre] = (genreCounts[genre] ?? 0) + 1;
        }
        const topGenres = Object.entries(genreCounts).sort(([, a], [, b]) => b - a).slice(0, 3).map(([g]) => g);
        return new Response(JSON.stringify({
          success: true,
          recommendedGenres: topGenres.length > 0 ? topGenres : ["jpop", "pop", "rock"],
          basedOn: (plays ?? []).length,
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "stats") {
        // プレイリスト・トラック・再生履歴を並列取得
        const [{ data: playlists }, { data: tracks }, { data: plays }] = await Promise.all([
          adminClient.from("app_analytics").select("metadata").eq("user_id", user.id).eq("source", "music_playlist"),
          adminClient.from("app_analytics").select("metadata").eq("user_id", user.id).eq("source", "music_track"),
          adminClient.from("app_analytics").select("metadata").eq("user_id", user.id).eq("source", "music_play"),
        ]);
        let totalDuration = 0;
        for (const p of plays ?? []) totalDuration += ((p.metadata as Record<string, unknown>).duration_sec as number) ?? 0;
        return new Response(JSON.stringify({
          success: true,
          stats: { totalPlaylists: (playlists ?? []).length, totalTracks: (tracks ?? []).length, totalPlays: (plays ?? []).length, totalListeningMinutes: Math.round(totalDuration / 60) },
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      // Default: playlists
      const { data: playlists } = await adminClient.from("app_analytics").select("metadata, created_at")
        .eq("user_id", user.id).eq("source", "music_playlist")
        .order("created_at", { ascending: false });
      return new Response(JSON.stringify({
        success: true,
        playlists: (playlists ?? []).map((p) => ({ ...(p.metadata as Record<string, unknown>), createdAt: p.created_at })),
      }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      const { action } = body;

      if (action === "create_playlist") {
        const { title, description, is_public } = body;
        if (!title) {
          return new Response(JSON.stringify({ success: false, error: "title required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const playlistId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "music_playlist",
          metadata: { playlist_id: playlistId, title, description: description ?? null, is_public: is_public ?? false, track_count: 0 },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, playlistId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "add_track") {
        const { playlist_id, title, artist, album, genre, duration_sec, url } = body;
        if (!title || !artist) {
          return new Response(JSON.stringify({ success: false, error: "title and artist required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const trackId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "music_track",
          metadata: { track_id: trackId, playlist_id: playlist_id ?? null, title, artist, album: album ?? null, genre: genre ?? "pop", duration_sec: duration_sec ?? 240, url: url ?? null, is_favorite: false },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, trackId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "record_play") {
        const { track_id, title, artist, genre, duration_sec } = body;
        if (!track_id) {
          return new Response(JSON.stringify({ success: false, error: "track_id required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "music_play",
          metadata: { track_id, title: title ?? null, artist: artist ?? null, genre: genre ?? "pop", duration_sec: duration_sec ?? 240 },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, recorded: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "toggle_favorite") {
        const { track_id } = body;
        if (!track_id) {
          return new Response(JSON.stringify({ success: false, error: "track_id required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const { data: existing } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "music_track").eq("metadata->>track_id", track_id).maybeSingle();
        if (!existing) {
          return new Response(JSON.stringify({ success: false, error: "Track not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const meta = existing.metadata as Record<string, unknown>;
        const newFav = !(meta.is_favorite as boolean);
        await adminClient.from("app_analytics").update({ metadata: { ...meta, is_favorite: newFav } })
          .eq("user_id", user.id).eq("source", "music_track").eq("metadata->>track_id", track_id);
        return new Response(JSON.stringify({ success: true, isFavorite: newFav }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return new Response(JSON.stringify({ success: false, error: message }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
