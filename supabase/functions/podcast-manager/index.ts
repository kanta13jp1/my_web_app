// Podcast Manager Edge Function
// ポッドキャスト管理 (Spotify/Apple Podcasts/Amazon Music競合)
// - ポッドキャスト/番組管理
// - エピソード管理
// - 再生統計
// - サブスクリプション管理
// - ランキング
//
// GET  → 番組一覧 / エピソード / 購読 / 統計 / ランキング
// POST → 番組作成 / エピソード追加 / 購読 / 再生記録

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const PODCAST_CATEGORIES = ["technology", "business", "comedy", "education", "news", "sports", "music", "science", "society", "health", "arts", "fiction"];

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
      const showId = url.searchParams.get("show_id");

      if (view === "categories") {
        return new Response(JSON.stringify({ success: true, categories: PODCAST_CATEGORIES }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "episodes" && showId) {
        const { data: episodes } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "podcast_episode").eq("metadata->>show_id", showId)
          .order("created_at", { ascending: false });
        return new Response(JSON.stringify({
          success: true,
          episodes: (episodes ?? []).map((e) => ({ ...(e.metadata as Record<string, unknown>), createdAt: e.created_at })),
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "subscriptions") {
        const { data: subs } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "podcast_subscription")
          .order("created_at", { ascending: false });
        return new Response(JSON.stringify({
          success: true,
          subscriptions: (subs ?? []).map((s) => ({ ...(s.metadata as Record<string, unknown>), subscribedAt: s.created_at })),
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "stats") {
        const { data: shows } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "podcast_show");
        const { data: episodes } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "podcast_episode");
        const { data: plays } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "podcast_play");
        let totalDuration = 0;
        for (const p of plays ?? []) totalDuration += ((p.metadata as Record<string, unknown>).duration_sec as number) ?? 0;
        return new Response(JSON.stringify({
          success: true,
          stats: { totalShows: (shows ?? []).length, totalEpisodes: (episodes ?? []).length, totalPlays: (plays ?? []).length, totalListeningHours: Math.round(totalDuration / 3600 * 10) / 10 },
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "ranking") {
        const { data: plays } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "podcast_play");
        const showPlays: Record<string, { title: string; count: number }> = {};
        for (const p of plays ?? []) {
          const meta = p.metadata as Record<string, unknown>;
          const sid = (meta.show_id as string) ?? "unknown";
          if (!showPlays[sid]) showPlays[sid] = { title: (meta.show_title as string) ?? sid, count: 0 };
          showPlays[sid].count++;
        }
        const ranking = Object.entries(showPlays).map(([id, info]) => ({ showId: id, ...info })).sort((a, b) => b.count - a.count).slice(0, 10);
        return new Response(JSON.stringify({ success: true, ranking }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      // Default: show list
      const { data: shows } = await adminClient.from("app_analytics").select("metadata, created_at")
        .eq("user_id", user.id).eq("source", "podcast_show")
        .order("created_at", { ascending: false });
      return new Response(JSON.stringify({
        success: true,
        shows: (shows ?? []).map((s) => ({ ...(s.metadata as Record<string, unknown>), createdAt: s.created_at })),
      }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json();
      const { action } = body;

      if (action === "create_show") {
        const { title, description, category, cover_url, language } = body;
        if (!title) {
          return new Response(JSON.stringify({ success: false, error: "title required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const showId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "podcast_show",
          metadata: { show_id: showId, title, description: description ?? null, category: category ?? "technology", cover_url: cover_url ?? null, language: language ?? "ja", episode_count: 0, subscriber_count: 0 },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, showId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "add_episode") {
        const { show_id, title, description, audio_url, duration_sec, season, episode_number } = body;
        if (!show_id || !title) {
          return new Response(JSON.stringify({ success: false, error: "show_id and title required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const episodeId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "podcast_episode",
          metadata: { episode_id: episodeId, show_id, title, description: description ?? null, audio_url: audio_url ?? null, duration_sec: duration_sec ?? 1800, season: season ?? 1, episode_number: episode_number ?? 1, play_count: 0 },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, episodeId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "subscribe") {
        const { show_id, show_title } = body;
        if (!show_id) {
          return new Response(JSON.stringify({ success: false, error: "show_id required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "podcast_subscription",
          metadata: { show_id, show_title: show_title ?? null, is_active: true },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, subscribed: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "record_play") {
        const { episode_id, show_id, show_title, episode_title, duration_sec, completed } = body;
        if (!episode_id) {
          return new Response(JSON.stringify({ success: false, error: "episode_id required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "podcast_play",
          metadata: { episode_id, show_id: show_id ?? null, show_title: show_title ?? null, episode_title: episode_title ?? null, duration_sec: duration_sec ?? 0, completed: completed ?? false },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, recorded: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return new Response(JSON.stringify({ success: false, error: message }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
