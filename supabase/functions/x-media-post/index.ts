// x-media-post Edge Function
// X (Twitter) への画像/動画付き投稿
//
// 機能:
// - 画像URLからメディアをX APIにアップロード (media/upload)
// - アップロードしたmedia_idをツイートに添付
// - 動画はチャンク分割アップロード対応
// - viral-video-ad-generatorと連携して広告投稿を自動化
//
// POST { "text": "...", "mediaUrl": "https://...", "mediaType": "image/jpeg" | "video/mp4" }
// POST { "text": "...", "mediaUrls": ["url1", "url2"] } // 最大4枚

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";
const X_API_KEY = Deno.env.get("X_API_KEY") ?? "";
const X_API_SECRET = Deno.env.get("X_API_SECRET") ?? "";
const X_ACCESS_TOKEN = Deno.env.get("X_ACCESS_TOKEN") ?? "";
const X_ACCESS_TOKEN_SECRET = Deno.env.get("X_ACCESS_TOKEN_SECRET") ?? "";

// OAuth 1.0a signature
async function buildOAuthHeader(method: string, url: string, extra: Record<string, string> = {}): Promise<string> {
  const ts = Math.floor(Date.now() / 1000).toString();
  const nonce = crypto.randomUUID().replace(/-/g, "");
  const oauthParams: Record<string, string> = {
    oauth_consumer_key: X_API_KEY,
    oauth_nonce: nonce,
    oauth_signature_method: "HMAC-SHA256",
    oauth_timestamp: ts,
    oauth_token: X_ACCESS_TOKEN,
    oauth_version: "1.0",
    ...extra,
  };

  const allParams = { ...oauthParams };
  const sortedParams = Object.keys(allParams).sort().map((k) =>
    `${encodeURIComponent(k)}=${encodeURIComponent(allParams[k])}`
  ).join("&");

  const baseString = [method.toUpperCase(), encodeURIComponent(url), encodeURIComponent(sortedParams)].join("&");
  const signingKey = `${encodeURIComponent(X_API_SECRET)}&${encodeURIComponent(X_ACCESS_TOKEN_SECRET)}`;

  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(signingKey),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(baseString));
  const sigB64 = btoa(String.fromCharCode(...new Uint8Array(sig)));

  const headerParts = { ...oauthParams, oauth_signature: sigB64 };
  const headerStr = Object.keys(headerParts).sort().map((k) =>
    `${encodeURIComponent(k)}="${encodeURIComponent(headerParts[k])}"`
  ).join(", ");
  return `OAuth ${headerStr}`;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    if (req.method !== "POST") {
      return jsonRes({ error: "POST only" }, 405);
    }

    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: { persistSession: false },
    });

    if (!X_API_KEY || !X_API_SECRET || !X_ACCESS_TOKEN || !X_ACCESS_TOKEN_SECRET) {
      return jsonRes({
        error: "X API credentials not configured",
        setup: "Set X_API_KEY, X_API_SECRET, X_ACCESS_TOKEN, X_ACCESS_TOKEN_SECRET in Supabase secrets",
      }, 503);
    }

    const body = await req.json() as {
      text?: string;
      mediaUrl?: string;
      mediaUrls?: string[];
      mediaType?: string;
      dryRun?: boolean;
      adGenerationId?: string;
    };

    const text = body.text?.trim() ?? "";
    const mediaUrls = body.mediaUrls ?? (body.mediaUrl ? [body.mediaUrl] : []);
    const dryRun = body.dryRun ?? false;

    if (!text) return jsonRes({ error: "text is required" }, 400);
    if (text.length > 280) return jsonRes({ error: "text exceeds 280 chars" }, 400);
    if (mediaUrls.length > 4) return jsonRes({ error: "Max 4 media files" }, 400);

    if (dryRun) {
      return jsonRes({ success: true, dryRun: true, text, mediaUrls });
    }

    // Step 1: Upload each media
    const mediaIds: string[] = [];
    for (const mUrl of mediaUrls) {
      try {
        const mediaResp = await fetch(mUrl);
        if (!mediaResp.ok) {
          continue;
        }
        const mimeType = body.mediaType ?? mediaResp.headers.get("content-type") ?? "image/jpeg";
        const mediaBytes = await mediaResp.arrayBuffer();
        const mediaSize = mediaBytes.byteLength;

        const uploadUrl = "https://upload.twitter.com/1.1/media/upload.json";
        const initOauth = await buildOAuthHeader("POST", uploadUrl);

        // INIT
        const initForm = new URLSearchParams();
        initForm.append("command", "INIT");
        initForm.append("total_bytes", mediaSize.toString());
        initForm.append("media_type", mimeType);

        const initResp = await fetch(uploadUrl, {
          method: "POST",
          headers: {
            Authorization: initOauth,
            "Content-Type": "application/x-www-form-urlencoded",
          },
          body: initForm.toString(),
        });

        if (!initResp.ok) {
          const errText = await initResp.text();
          console.error("INIT failed:", errText);
          continue;
        }

        const initData = await initResp.json() as { media_id_string: string };
        const mediaIdStr = initData.media_id_string;

        // APPEND (chunk size 5MB)
        const chunkSize = 5 * 1024 * 1024;
        let segmentIndex = 0;
        let offset = 0;
        while (offset < mediaSize) {
          const chunk = mediaBytes.slice(offset, offset + chunkSize);
          const appendOauth = await buildOAuthHeader("POST", uploadUrl);

          const appendForm = new FormData();
          appendForm.append("command", "APPEND");
          appendForm.append("media_id", mediaIdStr);
          appendForm.append("segment_index", segmentIndex.toString());
          appendForm.append("media", new Blob([chunk], { type: mimeType }));

          await fetch(uploadUrl, {
            method: "POST",
            headers: { Authorization: appendOauth },
            body: appendForm,
          });

          offset += chunkSize;
          segmentIndex++;
        }

        // FINALIZE
        const finalizeOauth = await buildOAuthHeader("POST", uploadUrl);
        const finalForm = new URLSearchParams();
        finalForm.append("command", "FINALIZE");
        finalForm.append("media_id", mediaIdStr);

        const finalResp = await fetch(uploadUrl, {
          method: "POST",
          headers: {
            Authorization: finalizeOauth,
            "Content-Type": "application/x-www-form-urlencoded",
          },
          body: finalForm.toString(),
        });

        if (finalResp.ok) {
          mediaIds.push(mediaIdStr);
        }
      } catch (_e) {
        // skip failed media
      }
    }

    // Step 2: Post tweet with media
    const tweetUrl = "https://api.twitter.com/2/tweets";
    const oauthHeader = await buildOAuthHeader("POST", tweetUrl);

    const tweetBody: Record<string, unknown> = { text };
    if (mediaIds.length > 0) {
      tweetBody.media = { media_ids: mediaIds };
    }

    const tweetResp = await fetch(tweetUrl, {
      method: "POST",
      headers: {
        Authorization: oauthHeader,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(tweetBody),
    });

    if (!tweetResp.ok) {
      const errText = await tweetResp.text();
      throw new Error(`X API error ${tweetResp.status}: ${errText}`);
    }

    const tweetData = await tweetResp.json() as { data: { id: string; text: string } };
    const tweetId = tweetData.data?.id;
    const tweetLink = tweetId ? `https://x.com/kanta13jp1/status/${tweetId}` : null;

    // 投稿履歴を記録
    try {
      await admin.from("viral_ad_generations").upsert({
        id: body.adGenerationId,
        posted_tweet_id: tweetId,
        posted_tweet_url: tweetLink,
        posted_at: new Date().toISOString(),
        status: "posted",
      }, { onConflict: "id" });
    } catch (_e) {
      // ignore
    }

    return jsonRes({
      success: true,
      tweetId,
      tweetLink,
      text,
      mediaIds,
    });
  } catch (e) {
    return jsonRes({ error: String(e) }, 500);
  }
});

function jsonRes(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
