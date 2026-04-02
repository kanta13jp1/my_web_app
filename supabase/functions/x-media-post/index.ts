// x-media-post — X API v1.1 media upload + v2 tweet with media
//
// POST body:
//   { "text": "tweet text", "mediaBase64": "base64string", "mediaType": "image/png" }
//   or
//   { "text": "tweet text", "mediaUrl": "https://..." }  ← fetch image from URL
//
// Media pipeline:
//   1. X API v1.1 POST media/upload (INIT → APPEND → FINALIZE)
//   2. X API v2 POST tweets with media.media_ids
//
// Supports: image/png, image/jpeg, image/gif, video/mp4 (≤ 15 MB chunked)

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const X_API_KEY = Deno.env.get("X_API_KEY") ?? "";
const X_API_SECRET = Deno.env.get("X_API_SECRET") ?? "";
const X_ACCESS_TOKEN = Deno.env.get("X_ACCESS_TOKEN") ?? "";
const X_ACCESS_TOKEN_SECRET = Deno.env.get("X_ACCESS_TOKEN_SECRET") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const CHUNK_SIZE = 1024 * 1024; // 1 MB per chunk

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return jsonResp({ success: false, error: "POST only" }, 405);
  }

  // Simple auth: Bearer SERVICE_ROLE_KEY
  const auth = req.headers.get("authorization") ?? "";
  if (!auth.includes(SERVICE_ROLE_KEY) || SERVICE_ROLE_KEY === "") {
    return jsonResp({ success: false, error: "Unauthorized" }, 401);
  }
  if (!X_API_KEY || !X_API_SECRET || !X_ACCESS_TOKEN || !X_ACCESS_TOKEN_SECRET) {
    return jsonResp({ success: false, error: "X API credentials not configured" }, 500);
  }

  try {
    const body = await req.json().catch(() => ({})) as {
      text?: string;
      mediaBase64?: string;
      mediaType?: string;
      mediaUrl?: string;
      dryRun?: boolean;
    };

    const { text, mediaBase64, mediaType, mediaUrl, dryRun = false } = body;
    if (!text) return jsonResp({ success: false, error: "text is required" }, 400);
    if (text.length > 280) return jsonResp({ success: false, error: "text exceeds 280 chars" }, 400);

    // --- Resolve media bytes ---
    let mediaBytes: Uint8Array | null = null;
    let mimeType = mediaType ?? "image/png";

    if (mediaBase64) {
      // Strip data URI prefix if present
      const b64 = mediaBase64.replace(/^data:[^;]+;base64,/, "");
      mediaBytes = Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
    } else if (mediaUrl) {
      const r = await fetch(mediaUrl);
      if (!r.ok) throw new Error(`Failed to fetch mediaUrl: ${r.status}`);
      mimeType = r.headers.get("content-type") ?? mimeType;
      mediaBytes = new Uint8Array(await r.arrayBuffer());
    }

    if (dryRun) {
      return jsonResp({
        success: true,
        dryRun: true,
        text,
        mediaBytes: mediaBytes?.length ?? 0,
        mimeType,
      });
    }

    // --- Upload media if provided ---
    let mediaId: string | null = null;
    if (mediaBytes) {
      mediaId = await uploadMedia(mediaBytes, mimeType);
    }

    // --- Post tweet ---
    const tweetUrl = "https://api.twitter.com/2/tweets";
    const tweetBody: Record<string, unknown> = { text };
    if (mediaId) tweetBody.media = { media_ids: [mediaId] };

    const oauthHeader = await buildOAuthHeader("POST", tweetUrl);
    const resp = await fetch(tweetUrl, {
      method: "POST",
      headers: { Authorization: oauthHeader, "Content-Type": "application/json" },
      body: JSON.stringify(tweetBody),
    });

    if (!resp.ok) {
      const errText = await resp.text();
      throw new Error(`X API v2 error ${resp.status}: ${errText}`);
    }

    const result = await resp.json() as { data?: { id?: string } };
    return jsonResp({
      success: true,
      tweetId: result?.data?.id ?? null,
      mediaId,
      account: "@kanta13jp1",
    });
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    console.error("x-media-post error:", err);
    return jsonResp({ success: false, error: msg }, 500);
  }
});

// ---------------------------------------------------------------------------
// X API v1.1 chunked media upload (INIT → APPEND → FINALIZE → STATUS)
// ---------------------------------------------------------------------------
async function uploadMedia(bytes: Uint8Array, mimeType: string): Promise<string> {
  const uploadUrl = "https://upload.twitter.com/1.1/media/upload.json";

  // INIT
  const initParams = new URLSearchParams({
    command: "INIT",
    total_bytes: String(bytes.length),
    media_type: mimeType,
    media_category: mimeType.startsWith("video") ? "tweet_video" : "tweet_image",
  });
  const initOauth = await buildOAuthHeader("POST", uploadUrl, Object.fromEntries(initParams));
  const initResp = await fetch(uploadUrl, {
    method: "POST",
    headers: { Authorization: initOauth, "Content-Type": "application/x-www-form-urlencoded" },
    body: initParams.toString(),
  });
  if (!initResp.ok) throw new Error(`Media INIT failed: ${await initResp.text()}`);
  const initData = await initResp.json() as { media_id_string: string };
  const mediaId = initData.media_id_string;

  // APPEND in chunks
  let segmentIndex = 0;
  for (let offset = 0; offset < bytes.length; offset += CHUNK_SIZE) {
    const chunk = bytes.slice(offset, offset + CHUNK_SIZE);
    const b64 = btoa(String.fromCharCode(...chunk));

    const appendParams = new URLSearchParams({
      command: "APPEND",
      media_id: mediaId,
      segment_index: String(segmentIndex),
    });
    const appendOauth = await buildOAuthHeader("POST", uploadUrl, Object.fromEntries(appendParams));

    // Send as multipart form
    const form = new FormData();
    form.append("command", "APPEND");
    form.append("media_id", mediaId);
    form.append("segment_index", String(segmentIndex));
    form.append("media_data", b64);

    const appendResp = await fetch(uploadUrl, {
      method: "POST",
      headers: { Authorization: appendOauth },
      body: form,
    });
    if (!appendResp.ok && appendResp.status !== 204) {
      throw new Error(`Media APPEND seg ${segmentIndex} failed: ${await appendResp.text()}`);
    }
    segmentIndex++;
  }

  // FINALIZE
  const finalizeParams = new URLSearchParams({ command: "FINALIZE", media_id: mediaId });
  const finalizeOauth = await buildOAuthHeader("POST", uploadUrl, Object.fromEntries(finalizeParams));
  const finalizeResp = await fetch(uploadUrl, {
    method: "POST",
    headers: { Authorization: finalizeOauth, "Content-Type": "application/x-www-form-urlencoded" },
    body: finalizeParams.toString(),
  });
  if (!finalizeResp.ok) throw new Error(`Media FINALIZE failed: ${await finalizeResp.text()}`);
  const finalizeData = await finalizeResp.json() as {
    media_id_string: string;
    processing_info?: { state: string; check_after_secs?: number };
  };

  // Poll STATUS if video processing
  if (finalizeData.processing_info) {
    await pollMediaStatus(mediaId, finalizeData.processing_info.check_after_secs ?? 5);
  }

  return mediaId;
}

async function pollMediaStatus(mediaId: string, waitSecs: number): Promise<void> {
  const statusUrl = `https://upload.twitter.com/1.1/media/upload.json?command=STATUS&media_id=${mediaId}`;
  for (let attempt = 0; attempt < 10; attempt++) {
    await new Promise((r) => setTimeout(r, waitSecs * 1000));
    const oauthHeader = await buildOAuthHeader("GET", statusUrl);
    const r = await fetch(statusUrl, { headers: { Authorization: oauthHeader } });
    if (!r.ok) throw new Error(`Media STATUS failed: ${await r.text()}`);
    const data = await r.json() as { processing_info?: { state: string; check_after_secs?: number } };
    const state = data.processing_info?.state;
    if (state === "succeeded") return;
    if (state === "failed") throw new Error("X media processing failed");
    waitSecs = data.processing_info?.check_after_secs ?? 5;
  }
  throw new Error("X media processing timed out");
}

// ---------------------------------------------------------------------------
// OAuth 1.0a helpers (same as post-x-update but accepts extra params)
// ---------------------------------------------------------------------------
async function buildOAuthHeader(
  method: string,
  url: string,
  extraParams: Record<string, string> = {},
): Promise<string> {
  const oauthParams: Record<string, string> = {
    oauth_consumer_key: X_API_KEY,
    oauth_nonce: crypto.randomUUID().replace(/-/g, ""),
    oauth_signature_method: "HMAC-SHA1",
    oauth_timestamp: String(Math.floor(Date.now() / 1000)),
    oauth_token: X_ACCESS_TOKEN,
    oauth_version: "1.0",
  };

  const signature = await computeOAuthSignature(method, url, { ...oauthParams, ...extraParams });
  oauthParams["oauth_signature"] = signature;

  return "OAuth " +
    Object.entries(oauthParams)
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([k, v]) => `${pctEncode(k)}="${pctEncode(v)}"`)
      .join(", ");
}

async function computeOAuthSignature(
  method: string,
  url: string,
  allParams: Record<string, string>,
): Promise<string> {
  const urlObj = new URL(url);
  const queryParams: Record<string, string> = {};
  urlObj.searchParams.forEach((v, k) => { queryParams[k] = v; });

  const merged = { ...allParams, ...queryParams };
  const paramStr = Object.entries(merged)
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([k, v]) => `${pctEncode(k)}=${pctEncode(v)}`)
    .join("&");

  const baseUrl = `${urlObj.protocol}//${urlObj.host}${urlObj.pathname}`;
  const baseString = [method.toUpperCase(), pctEncode(baseUrl), pctEncode(paramStr)].join("&");
  const signingKey = `${pctEncode(X_API_SECRET)}&${pctEncode(X_ACCESS_TOKEN_SECRET)}`;

  const cryptoKey = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(signingKey),
    { name: "HMAC", hash: "SHA-1" },
    false,
    ["sign"],
  );
  const sigBuf = await crypto.subtle.sign("HMAC", cryptoKey, new TextEncoder().encode(baseString));
  return btoa(String.fromCharCode(...new Uint8Array(sigBuf)));
}

function pctEncode(s: string): string {
  return encodeURIComponent(s).replace(/[!'()*]/g, (c) =>
    `%${c.charCodeAt(0).toString(16).toUpperCase()}`);
}

function jsonResp(payload: unknown, status = 200): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
