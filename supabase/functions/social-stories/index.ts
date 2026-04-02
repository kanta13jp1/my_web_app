// Social Stories Edge Function
// ソーシャルストーリーズ (X/Facebook/LINE/Instagram競合)
// - ストーリー投稿 (24時間表示)
// - メディア管理
// - リアクション
// - 閲覧者追跡
// - ハイライト

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type" };
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const STORY_TYPES = ["text", "image", "video", "poll", "question", "countdown", "link"];
const REACTION_TYPES = ["like", "love", "laugh", "wow", "sad", "fire", "clap"];
const STORY_DURATION_MS = 24 * 60 * 60 * 1000; // 24 hours

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
      const storyId = url.searchParams.get("story_id");

      if (view === "types") return new Response(JSON.stringify({ success: true, storyTypes: STORY_TYPES, reactionTypes: REACTION_TYPES }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });

      if (view === "feed") {
        const cutoff = new Date(Date.now() - STORY_DURATION_MS).toISOString();
        const { data: stories } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("source", "social_story").gte("created_at", cutoff).order("created_at", { ascending: false });
        // Group by user
        const grouped: Record<string, Array<Record<string, unknown>>> = {};
        for (const s of stories ?? []) {
          const m = s.metadata as Record<string, unknown>;
          const uid = m.user_id as string;
          if (!grouped[uid]) grouped[uid] = [];
          grouped[uid].push({ ...m, createdAt: s.created_at });
        }
        return new Response(JSON.stringify({ success: true, feed: Object.entries(grouped).map(([uid, items]) => ({ userId: uid, stories: items, count: items.length })) }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "my_stories") {
        const { data: stories } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "social_story").order("created_at", { ascending: false }).limit(30);
        return new Response(JSON.stringify({
          success: true,
          stories: (stories ?? []).map((s) => {
            const m = s.metadata as Record<string, unknown>;
            const createdTime = new Date(s.created_at).getTime();
            const isActive = Date.now() - createdTime < STORY_DURATION_MS;
            return { ...m, createdAt: s.created_at, isActive, expiresAt: new Date(createdTime + STORY_DURATION_MS).toISOString() };
          }),
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "story" && storyId) {
        const { data: story } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("source", "social_story").eq("metadata->>story_id", storyId).maybeSingle();
        if (!story) return new Response(JSON.stringify({ success: false, error: "Story not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        // Record view
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "story_view",
          metadata: { story_id: storyId, viewer_id: user.id },
          created_at: new Date().toISOString(),
        });
        // Get viewers and reactions
        const { count: viewCount } = await adminClient.from("app_analytics").select("*", { count: "exact", head: true })
          .eq("source", "story_view").eq("metadata->>story_id", storyId);
        const { data: reactions } = await adminClient.from("app_analytics").select("metadata")
          .eq("source", "story_reaction").eq("metadata->>story_id", storyId);
        const reactionCounts: Record<string, number> = {};
        for (const r of reactions ?? []) {
          const type = (r.metadata as Record<string, unknown>).reaction_type as string;
          reactionCounts[type] = (reactionCounts[type] ?? 0) + 1;
        }
        return new Response(JSON.stringify({
          success: true,
          story: { ...(story.metadata as Record<string, unknown>), createdAt: story.created_at },
          viewCount: viewCount ?? 0, reactions: reactionCounts,
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "highlights") {
        const { data: highlights } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "story_highlight").order("created_at", { ascending: false });
        return new Response(JSON.stringify({ success: true, highlights: (highlights ?? []).map((h) => ({ ...(h.metadata as Record<string, unknown>), createdAt: h.created_at })) }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: true, storyTypes: STORY_TYPES, reactionTypes: REACTION_TYPES }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      const { action } = body;

      if (action === "post_story") {
        const { type, content, media_url, background_color, poll_options } = body;
        if (!type || !content) return new Response(JSON.stringify({ success: false, error: "type and content required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const storyId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "social_story",
          metadata: {
            story_id: storyId, user_id: user.id, user_email: user.email, type, content,
            media_url: media_url ?? null, background_color: background_color ?? "#1a1a2e",
            poll_options: poll_options ?? null, poll_votes: null,
          },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, storyId, expiresAt: new Date(Date.now() + STORY_DURATION_MS).toISOString() }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "react") {
        const { story_id, reaction_type } = body;
        if (!story_id || !reaction_type) return new Response(JSON.stringify({ success: false, error: "story_id and reaction_type required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "story_reaction",
          metadata: { story_id, reaction_type, user_id: user.id },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "add_highlight") {
        const { story_id, highlight_name } = body;
        if (!story_id || !highlight_name) return new Response(JSON.stringify({ success: false, error: "story_id and highlight_name required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const highlightId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "story_highlight",
          metadata: { highlight_id: highlightId, story_id, highlight_name },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, highlightId }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "vote_poll") {
        const { story_id, option_index } = body;
        if (!story_id || option_index === undefined) return new Response(JSON.stringify({ success: false, error: "story_id and option_index required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "story_poll_vote",
          metadata: { story_id, option_index, user_id: user.id },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }
    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) { return new Response(JSON.stringify({ success: false, error: err instanceof Error ? err.message : String(err) }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }); }
});
