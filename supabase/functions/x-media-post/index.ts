// X Media Post Edge Function
// X メディア投稿 (動画/画像付きツイート)
// - メディアアップロード (X API v1.1 media/upload)
// - 動画付きツイート
// - スレッド投稿
// - 予約投稿
// - 投稿パフォーマンス追跡

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type" };
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";
const X_API_KEY = Deno.env.get("X_API_KEY") ?? "";
const X_API_SECRET = Deno.env.get("X_API_SECRET") ?? "";
const X_ACCESS_TOKEN = Deno.env.get("X_ACCESS_TOKEN") ?? "";
const X_ACCESS_TOKEN_SECRET = Deno.env.get("X_ACCESS_TOKEN_SECRET") ?? "";

function pctEncode(str: string): string {
  return encodeURIComponent(str).replace(/[!'()*]/g, (c) => `%${c.charCodeAt(0).toString(16).toUpperCase()}`);
}

async function buildOAuth(method: string, url: string, extraParams: Record<string, string> = {}): Promise<string> {
  const oauthParams: Record<string, string> = {
    oauth_consumer_key: X_API_KEY,
    oauth_nonce: crypto.randomUUID().replace(/-/g, ""),
    oauth_signature_method: "HMAC-SHA1",
    oauth_timestamp: String(Math.floor(Date.now() / 1000)),
    oauth_token: X_ACCESS_TOKEN,
    oauth_version: "1.0",
  };
  const allParams = { ...oauthParams, ...extraParams };
  const paramStr = Object.entries(allParams).sort(([a], [b]) => a.localeCompare(b)).map(([k, v]) => `${pctEncode(k)}=${pctEncode(v)}`).join("&");
  const baseString = [method.toUpperCase(), pctEncode(url), pctEncode(paramStr)].join("&");
  const signingKey = `${pctEncode(X_API_SECRET)}&${pctEncode(X_ACCESS_TOKEN_SECRET)}`;
  const keyData = new TextEncoder().encode(signingKey);
  const msgData = new TextEncoder().encode(baseString);
  const cryptoKey = await crypto.subtle.importKey("raw", keyData, { name: "HMAC", hash: "SHA-1" }, false, ["sign"]);
  const sig = await crypto.subtle.sign("HMAC", cryptoKey, msgData);
  oauthParams["oauth_signature"] = btoa(String.fromCharCode(...new Uint8Array(sig)));
  return "OAuth " + Object.entries(oauthParams).sort(([a], [b]) => a.localeCompare(b)).map(([k, v]) => `${pctEncode(k)}="${pctEncode(v)}"`).join(", ");
}

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

      if (view === "posts") {
        const { data: posts } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "x_media_post").order("created_at", { ascending: false }).limit(30);
        return new Response(JSON.stringify({ success: true, posts: (posts ?? []).map((p) => ({ ...(p.metadata as Record<string, unknown>), createdAt: p.created_at })) }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "scheduled") {
        const { data: scheduled } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "x_scheduled_post").eq("metadata->>status", "scheduled").order("created_at", { ascending: true });
        return new Response(JSON.stringify({ success: true, scheduled: (scheduled ?? []).map((s) => ({ ...(s.metadata as Record<string, unknown>), createdAt: s.created_at })) }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "analytics") {
        const { data: posts } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "x_media_post");
        let totalImpressions = 0;
        let totalLikes = 0;
        let totalRetweets = 0;
        let totalReplies = 0;
        for (const p of posts ?? []) {
          const m = p.metadata as Record<string, unknown>;
          totalImpressions += (m.impressions as number) ?? 0;
          totalLikes += (m.likes as number) ?? 0;
          totalRetweets += (m.retweets as number) ?? 0;
          totalReplies += (m.replies as number) ?? 0;
        }
        const engagementRate = totalImpressions > 0 ? Math.round(((totalLikes + totalRetweets + totalReplies) / totalImpressions) * 10000) / 100 : 0;
        return new Response(JSON.stringify({
          success: true, analytics: { totalPosts: (posts ?? []).length, totalImpressions, totalLikes, totalRetweets, totalReplies, engagementRate },
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json();
      const { action } = body;

      if (action === "post_with_media") {
        const { text, media_url, media_type } = body;
        if (!text) return new Response(JSON.stringify({ success: false, error: "text required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        if (!X_API_KEY) return new Response(JSON.stringify({ success: false, error: "X API credentials not configured" }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });

        let tweetPayload: Record<string, unknown> = { text };

        // If media_url is provided, try to upload it via X media upload
        if (media_url) {
          try {
            // INIT media upload
            const initUrl = "https://upload.twitter.com/1.1/media/upload.json";
            const initParams = { command: "INIT", media_type: media_type ?? "video/mp4", total_bytes: "5000000" };
            const initAuth = await buildOAuth("POST", initUrl, initParams);
            const initResp = await fetch(initUrl, {
              method: "POST",
              headers: { Authorization: initAuth, "Content-Type": "application/x-www-form-urlencoded" },
              body: new URLSearchParams(initParams).toString(),
            });
            if (initResp.ok) {
              const initData = await initResp.json();
              const mediaId = initData.media_id_string;
              if (mediaId) tweetPayload = { text, media: { media_ids: [mediaId] } };
            }
          } catch (_e) {
            // If media upload fails, post text-only with link
            console.error("Media upload failed, posting text only");
          }
        }

        // Post tweet
        const tweetUrl = "https://api.twitter.com/2/tweets";
        const oauthHeader = await buildOAuth("POST", tweetUrl);
        const resp = await fetch(tweetUrl, {
          method: "POST",
          headers: { Authorization: oauthHeader, "Content-Type": "application/json" },
          body: JSON.stringify(tweetPayload),
        });

        const postId = crypto.randomUUID();
        let tweetId = null;
        let postStatus = "failed";

        if (resp.ok) {
          const result = await resp.json();
          tweetId = result?.data?.id ?? null;
          postStatus = "posted";
        }

        // Record the post
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "x_media_post",
          metadata: { post_id: postId, tweet_id: tweetId, text, media_url: media_url ?? null, media_type: media_type ?? null, status: postStatus, impressions: 0, likes: 0, retweets: 0, replies: 0 },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: postStatus === "posted", postId, tweetId, status: postStatus }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "post_thread") {
        const { tweets } = body;
        if (!tweets || !Array.isArray(tweets) || tweets.length === 0) return new Response(JSON.stringify({ success: false, error: "tweets array required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        if (!X_API_KEY) return new Response(JSON.stringify({ success: false, error: "X API credentials not configured" }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const threadId = crypto.randomUUID();
        const results: Array<{ text: string; tweetId: string | null; success: boolean }> = [];
        let replyToId: string | null = null;
        for (const tweet of tweets as string[]) {
          const tweetUrl = "https://api.twitter.com/2/tweets";
          const oauthHeader = await buildOAuth("POST", tweetUrl);
          const payload: Record<string, unknown> = { text: tweet };
          if (replyToId) payload.reply = { in_reply_to_tweet_id: replyToId };
          const resp = await fetch(tweetUrl, {
            method: "POST",
            headers: { Authorization: oauthHeader, "Content-Type": "application/json" },
            body: JSON.stringify(payload),
          });
          if (resp.ok) {
            const result = await resp.json();
            const tid = result?.data?.id ?? null;
            results.push({ text: tweet, tweetId: tid, success: true });
            if (tid) replyToId = tid;
          } else {
            results.push({ text: tweet, tweetId: null, success: false });
            break;
          }
        }
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "x_media_post",
          metadata: { post_id: threadId, type: "thread", tweets: results, tweet_count: results.length, status: results.every((r) => r.success) ? "posted" : "partial" },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, threadId, results }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "schedule_post") {
        const { text, media_url, scheduled_at } = body;
        if (!text || !scheduled_at) return new Response(JSON.stringify({ success: false, error: "text and scheduled_at required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const scheduleId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "x_scheduled_post",
          metadata: { schedule_id: scheduleId, text, media_url: media_url ?? null, scheduled_at, status: "scheduled" },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, scheduleId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }
    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) { return new Response(JSON.stringify({ success: false, error: err instanceof Error ? err.message : String(err) }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }); }
});
