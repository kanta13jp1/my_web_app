// Social Feed Edge Function
// ソーシャルフィード (X/Facebook/LINE競合)
// - 投稿 (テキスト/リンク)
// - いいね/リアクション
// - フォロー/フォロワー
// - タイムライン表示
// - ハッシュタグ
//
// GET  → タイムライン / プロフィール / フォロー
// POST → 投稿 / いいね / フォロー

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
      const view = url.searchParams.get("view"); // 'timeline' | 'profile' | 'followers' | 'following' | 'hashtag'
      const userId = url.searchParams.get("user_id");
      const tag = url.searchParams.get("tag");

      if (view === "followers" || view === "following") {
        const targetId = userId ?? user.id;
        const field = view === "followers" ? "following_id" : "follower_id";
        const { data: follows } = await adminClient
          .from("app_analytics")
          .select("metadata, created_at")
          .eq("source", "social_follow")
          .eq(`metadata->>${field}`, targetId);

        return new Response(
          JSON.stringify({
            success: true,
            [view]: (follows ?? []).map((f) => ({
              ...(f.metadata as Record<string, unknown>),
              followedAt: f.created_at,
            })),
            count: (follows ?? []).length,
          }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (view === "profile") {
        const targetId = userId ?? user.id;
        // 投稿・フォロワー数・フォロー数を並列取得
        const [{ data: posts }, { data: followerCount }, { data: followingCount }] = await Promise.all([
          adminClient.from("app_analytics").select("metadata, created_at")
            .eq("user_id", targetId).eq("source", "social_post")
            .order("created_at", { ascending: false }).limit(20),
          adminClient.from("app_analytics").select("metadata", { count: "exact" })
            .eq("source", "social_follow").eq("metadata->>following_id", targetId),
          adminClient.from("app_analytics").select("metadata", { count: "exact" })
            .eq("source", "social_follow").eq("metadata->>follower_id", targetId),
        ]);

        return new Response(
          JSON.stringify({
            success: true,
            userId: targetId,
            posts: (posts ?? []).map((p) => ({ ...(p.metadata as Record<string, unknown>), createdAt: p.created_at })),
            followers: (followerCount ?? []).length,
            following: (followingCount ?? []).length,
          }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (view === "hashtag" && tag) {
        const { data: posts } = await adminClient
          .from("app_analytics")
          .select("metadata, created_at, user_id")
          .eq("source", "social_post")
          .order("created_at", { ascending: false })
          .limit(50);

        const filtered = (posts ?? []).filter((p) => {
          const hashtags = ((p.metadata as Record<string, unknown>)?.hashtags as string[]) ?? [];
          return hashtags.includes(tag);
        });

        return new Response(
          JSON.stringify({
            success: true,
            tag,
            posts: filtered.map((p) => ({ ...(p.metadata as Record<string, unknown>), userId: p.user_id, createdAt: p.created_at })),
          }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      // Default timeline: own posts + followed users' posts
      const { data: following } = await adminClient
        .from("app_analytics")
        .select("metadata")
        .eq("source", "social_follow")
        .eq("metadata->>follower_id", user.id);

      const followingIds = [user.id, ...(following ?? []).map((f) => (f.metadata as Record<string, unknown>)?.following_id as string)];

      const { data: posts } = await adminClient
        .from("app_analytics")
        .select("metadata, created_at, user_id")
        .eq("source", "social_post")
        .in("user_id", followingIds)
        .order("created_at", { ascending: false })
        .limit(30);

      // Get like counts
      const postIds = (posts ?? []).map((p) => (p.metadata as Record<string, unknown>)?.post_id as string).filter(Boolean);
      const { data: likes } = await adminClient
        .from("app_analytics")
        .select("metadata")
        .eq("source", "social_like")
        .in("metadata->>post_id", postIds);

      const likeCounts = new Map<string, number>();
      for (const l of likes ?? []) {
        const pid = (l.metadata as Record<string, unknown>)?.post_id as string;
        likeCounts.set(pid, (likeCounts.get(pid) ?? 0) + 1);
      }

      return new Response(
        JSON.stringify({
          success: true,
          posts: (posts ?? []).map((p) => {
            const meta = p.metadata as Record<string, unknown>;
            const postId = meta?.post_id as string;
            return { ...meta, userId: p.user_id, createdAt: p.created_at, likeCount: likeCounts.get(postId) ?? 0 };
          }),
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      const { action } = body;

      if (action === "post") {
        const { content, link, hashtags } = body;
        if (!content) {
          return new Response(
            JSON.stringify({ success: false, error: "content required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        // Auto-extract hashtags from content
        const extractedTags = (content.match(/#[\w\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FFF]+/g) ?? []).map((t: string) => t.slice(1));
        const allTags = [...new Set([...(hashtags ?? []), ...extractedTags])];

        const postId = crypto.randomUUID();
        const { data, error } = await adminClient.from("app_analytics").insert({
          user_id: user.id,
          source: "social_post",
          metadata: { post_id: postId, content, link: link ?? null, hashtags: allTags },
          created_at: new Date().toISOString(),
        }).select().single();

        if (error) throw error;

        return new Response(
          JSON.stringify({ success: true, postId, post: data }),
          { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (action === "like") {
        const { post_id } = body;
        if (!post_id) {
          return new Response(
            JSON.stringify({ success: false, error: "post_id required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        // Toggle like
        const { data: existing } = await adminClient
          .from("app_analytics")
          .select("metadata")
          .eq("user_id", user.id)
          .eq("source", "social_like")
          .eq("metadata->>post_id", post_id)
          .maybeSingle();

        if (existing) {
          await adminClient.from("app_analytics")
            .delete()
            .eq("user_id", user.id)
            .eq("source", "social_like")
            .eq("metadata->>post_id", post_id);
          return new Response(
            JSON.stringify({ success: true, liked: false }),
            { headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        await adminClient.from("app_analytics").insert({
          user_id: user.id,
          source: "social_like",
          metadata: { post_id },
          created_at: new Date().toISOString(),
        });

        return new Response(
          JSON.stringify({ success: true, liked: true }),
          { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (action === "follow") {
        const { target_user_id } = body;
        if (!target_user_id || target_user_id === user.id) {
          return new Response(
            JSON.stringify({ success: false, error: "valid target_user_id required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        // Toggle follow
        const { data: existing } = await adminClient
          .from("app_analytics")
          .select("metadata")
          .eq("source", "social_follow")
          .eq("metadata->>follower_id", user.id)
          .eq("metadata->>following_id", target_user_id)
          .maybeSingle();

        if (existing) {
          await adminClient.from("app_analytics")
            .delete()
            .eq("source", "social_follow")
            .eq("metadata->>follower_id", user.id)
            .eq("metadata->>following_id", target_user_id);
          return new Response(
            JSON.stringify({ success: true, following: false }),
            { headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        await adminClient.from("app_analytics").insert({
          user_id: user.id,
          source: "social_follow",
          metadata: { follower_id: user.id, following_id: target_user_id },
          created_at: new Date().toISOString(),
        });

        return new Response(
          JSON.stringify({ success: true, following: true }),
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
    console.error("social-feed error:", err);
    return new Response(
      JSON.stringify({ success: false, error: message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
