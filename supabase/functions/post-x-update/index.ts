import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { authorizeAutomationActor } from "../_shared/automation-auth.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";
const X_API_KEY = Deno.env.get("X_API_KEY") ?? "";
const X_API_SECRET = Deno.env.get("X_API_SECRET") ?? "";
const X_ACCESS_TOKEN = Deno.env.get("X_ACCESS_TOKEN") ?? "";
const X_ACCESS_TOKEN_SECRET = Deno.env.get("X_ACCESS_TOKEN_SECRET") ?? "";

// -----------------------------------------------------------------------
// post-x-update
//
// Posts to @kanta13jp1 via X API v2 using OAuth 1.0a.
// Called by Claude Code Schedule (daily-report task) after generating
// the daily progress report.
//
// Single tweet:
//   Body: { "text": "tweet text (max 280 chars)" }
//
// Thread (sequential replies):
//   Body: { "texts": ["tweet1", "tweet2", ...] }
//         Max 25 tweets per thread.
//
// Reply to existing tweet:
//   Body: { "text": "...", "replyToTweetId": "<tweet_id>" }
//
// Dry run (no actual post):
//   Body: { "text": "...", "dryRun": true }
//        or { "texts": [...], "dryRun": true }
//
// Auth: Bearer SERVICE_ROLE_KEY
// -----------------------------------------------------------------------

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    if (req.method !== "POST") {
      throw new Error("Method not allowed. Use POST.");
    }
    if (SUPABASE_URL === "" || SERVICE_ROLE_KEY === "") {
      throw new Error("Missing Supabase runtime environment variables.");
    }

    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: { autoRefreshToken: false, persistSession: false },
    });
    await authorizeAutomationActor(admin, req);

    if (!X_API_KEY || !X_API_SECRET || !X_ACCESS_TOKEN || !X_ACCESS_TOKEN_SECRET) {
      throw new Error(
        "X API credentials not configured. Set X_API_KEY, X_API_SECRET, X_ACCESS_TOKEN, X_ACCESS_TOKEN_SECRET in Supabase secrets.",
      );
    }

    const body = (await req.json().catch(() => ({}))) as {
      text?: string;
      texts?: string[]; // Thread mode: array of tweet texts
      replyToTweetId?: string; // Reply to an existing tweet
      dryRun?: boolean;
    };
    const { text, texts, replyToTweetId, dryRun = false } = body;

    // ── Thread mode ──────────────────────────────────────────────────────
    if (texts !== undefined && texts.length > 0) {
      if (!Array.isArray(texts)) throw new Error("texts must be an array.");
      if (texts.length > 25) throw new Error("Thread length exceeds maximum of 25 tweets.");
      for (let i = 0; i < texts.length; i++) {
        const t = texts[i];
        if (!t || t.trim() === "") {
          throw new Error(`texts[${i}] must not be empty.`);
        }
        if (t.length > 280) {
          throw new Error(`texts[${i}] exceeds 280 characters (${t.length}).`);
        }
      }

      if (dryRun) {
        return jsonResponse({
          success: true,
          dryRun: true,
          account: "@kanta13jp1",
          thread: texts,
          threadLength: texts.length,
        });
      }

      const postedIds: string[] = [];
      let prevTweetId: string | null = replyToTweetId ?? null;

      for (const tweetText of texts) {
        const tweetUrl = "https://api.twitter.com/2/tweets";
        const oauthHeader = await buildOAuthHeader("POST", tweetUrl);
        const payload: Record<string, unknown> = { text: tweetText };
        if (prevTweetId) {
          payload["reply"] = { in_reply_to_tweet_id: prevTweetId };
        }

        const resp = await fetch(tweetUrl, {
          method: "POST",
          headers: {
            Authorization: oauthHeader,
            "Content-Type": "application/json",
          },
          body: JSON.stringify(payload),
        });

        if (!resp.ok) {
          const errText = await resp.text();
          throw new Error(
            `X API error ${resp.status} at thread tweet ${postedIds.length + 1}: ${errText}`,
          );
        }

        const result = await resp.json();
        const newId: string | null = result?.data?.id ?? null;
        if (newId) postedIds.push(newId);
        prevTweetId = newId;
      }

      return jsonResponse({
        success: true,
        account: "@kanta13jp1",
        thread: postedIds,
        threadLength: postedIds.length,
      });
    }

    // ── Single tweet mode ─────────────────────────────────────────────────
    if (!text || text.trim() === "") {
      throw new Error("text (or texts for thread) is required.");
    }
    if (text.length > 280) throw new Error("text exceeds 280 characters.");

    if (dryRun) {
      return jsonResponse({
        success: true,
        dryRun: true,
        account: "@kanta13jp1",
        text,
      });
    }

    const tweetUrl = "https://api.twitter.com/2/tweets";
    const oauthHeader = await buildOAuthHeader("POST", tweetUrl);
    const tweetPayload: Record<string, unknown> = { text };
    if (replyToTweetId) {
      tweetPayload["reply"] = { in_reply_to_tweet_id: replyToTweetId };
    }

    const resp = await fetch(tweetUrl, {
      method: "POST",
      headers: {
        Authorization: oauthHeader,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(tweetPayload),
    });

    if (!resp.ok) {
      const errText = await resp.text();
      throw new Error(`X API error ${resp.status}: ${errText}`);
    }

    const result = await resp.json();
    return jsonResponse({
      success: true,
      account: "@kanta13jp1",
      tweetId: result?.data?.id ?? null,
    });
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    return jsonResponse({ success: false, error: message }, 400);
  }
});

// -----------------------------------------------------------------------
// OAuth 1.0a signing helpers
// -----------------------------------------------------------------------

async function buildOAuthHeader(method: string, url: string): Promise<string> {
  const oauthParams: Record<string, string> = {
    oauth_consumer_key: X_API_KEY,
    oauth_nonce: crypto.randomUUID().replace(/-/g, ""),
    oauth_signature_method: "HMAC-SHA1",
    oauth_timestamp: String(Math.floor(Date.now() / 1000)),
    oauth_token: X_ACCESS_TOKEN,
    oauth_version: "1.0",
  };

  const signature = await computeOAuthSignature(method, url, oauthParams);
  oauthParams["oauth_signature"] = signature;

  const headerValue = "OAuth " +
    Object.entries(oauthParams)
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([k, v]) => `${pctEncode(k)}="${pctEncode(v)}"`)
      .join(", ");

  return headerValue;
}

async function computeOAuthSignature(
  method: string,
  url: string,
  oauthParams: Record<string, string>,
): Promise<string> {
  const allParams = { ...oauthParams };

  // Sort and build parameter string
  const paramStr = Object.entries(allParams)
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([k, v]) => `${pctEncode(k)}=${pctEncode(v)}`)
    .join("&");

  const baseString = [
    method.toUpperCase(),
    pctEncode(url),
    pctEncode(paramStr),
  ].join("&");

  const signingKey = `${pctEncode(X_API_SECRET)}&${pctEncode(X_ACCESS_TOKEN_SECRET)}`;

  const keyData = new TextEncoder().encode(signingKey);
  const msgData = new TextEncoder().encode(baseString);

  const cryptoKey = await crypto.subtle.importKey(
    "raw",
    keyData,
    { name: "HMAC", hash: "SHA-1" },
    false,
    ["sign"],
  );

  const sigBuf = await crypto.subtle.sign("HMAC", cryptoKey, msgData);
  return btoa(String.fromCharCode(...new Uint8Array(sigBuf)));
}

function pctEncode(str: string): string {
  return encodeURIComponent(str).replace(
    /[!'()*]/g,
    (c) => `%${c.charCodeAt(0).toString(16).toUpperCase()}`,
  );
}

function jsonResponse(payload: unknown, status = 200): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
