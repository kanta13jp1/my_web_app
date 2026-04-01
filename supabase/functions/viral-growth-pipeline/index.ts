// viral-growth-pipeline — バイラル成長自動パイプライン
//
// GET  → パイプライン実行履歴 (viral_pipeline_runs テーブル)
// POST → { "action": "run_campaign"|"track_result"|"get_stats" }
//
// パイプライン:
//   1. viral-ad-generator で SVG 広告カードを生成
//   2. SVG を PNG に変換 (resvg-js via Wasm — または外部 rasterize API)
//   3. x-media-post で画像付き X 投稿
//   4. 結果を viral_pipeline_runs テーブルに保存
//   5. growth-referral で紹介コードをツイートに含める
//
// 注意: PNG変換には resvg または外部サービスが必要。
//        SVG のまま X に投稿する場合、X は SVG 非対応のため
//        HTML→Canvas→PNG のフロント側変換フローも提供。

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";
const SELF_URL = SUPABASE_URL.replace("supabase.co", "supabase.co/functions/v1");

// ---------------------------------------------------------------------------
// Main handler
// ---------------------------------------------------------------------------
serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const auth = req.headers.get("authorization") ?? "";
  if (!auth.includes(SERVICE_ROLE_KEY) || SERVICE_ROLE_KEY === "") {
    return jsonResp({ success: false, error: "Unauthorized" }, 401);
  }

  const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: { persistSession: false },
  });

  if (req.method === "GET") {
    const url = new URL(req.url);
    const limit = parseInt(url.searchParams.get("limit") ?? "20", 10);
    const { data, error } = await supabase
      .from("viral_pipeline_runs")
      .select("*")
      .order("created_at", { ascending: false })
      .limit(limit);

    if (error) return jsonResp({ success: false, error: error.message }, 500);
    return jsonResp({ success: true, runs: data ?? [] });
  }

  if (req.method !== "POST") {
    return jsonResp({ success: false, error: "GET or POST only" }, 405);
  }

  try {
    const body = await req.json() as {
      action?: string;
      template?: string;
      imageBase64?: string; // PNG from frontend canvas conversion
      dryRun?: boolean;
    };

    const action = body.action ?? "run_campaign";

    if (action === "get_stats") {
      return await getViralStats(supabase);
    }

    if (action === "track_result") {
      return await trackResult(supabase, body as Record<string, unknown>);
    }

    if (action === "run_campaign") {
      return await runCampaign(supabase, body);
    }

    return jsonResp({ success: false, error: `Unknown action: ${action}` }, 400);
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    console.error("viral-growth-pipeline error:", err);
    return jsonResp({ success: false, error: msg }, 500);
  }
});

// ---------------------------------------------------------------------------
// Pipeline: generate ad → post tweet → record result
// ---------------------------------------------------------------------------
async function runCampaign(
  supabase: ReturnType<typeof createClient>,
  body: { template?: string; imageBase64?: string; dryRun?: boolean },
): Promise<Response> {
  const template = body.template ?? "growth_stats";
  const dryRun = body.dryRun ?? false;

  // Step 1: Fetch current stats
  const stats = await fetchCurrentStats(supabase);

  // Step 2: Generate ad content
  const adResp = await fetch(`${SELF_URL}/viral-ad-generator`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ template, stats }),
  });

  if (!adResp.ok) {
    return jsonResp({ success: false, error: `Ad generation failed: ${await adResp.text()}` }, 500);
  }

  const adData = await adResp.json() as {
    success: boolean;
    tweetText?: string;
    svg?: string;
  };
  if (!adData.success) {
    return jsonResp({ success: false, error: "Ad generator returned failure" }, 500);
  }

  const tweetText = adData.tweetText ?? "";

  // Step 3: Post to X (with image if PNG provided from frontend)
  let tweetId: string | null = null;
  let mediaId: string | null = null;
  let postError: string | null = null;

  if (!dryRun) {
    const postBody: Record<string, unknown> = { text: tweetText };
    if (body.imageBase64) {
      postBody.mediaBase64 = body.imageBase64;
      postBody.mediaType = "image/png";
    }

    const postResp = await fetch(`${SELF_URL}/x-media-post`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(postBody),
    });

    const postData = await postResp.json() as {
      success?: boolean;
      tweetId?: string;
      mediaId?: string;
      error?: string;
    };

    if (postData.success) {
      tweetId = postData.tweetId ?? null;
      mediaId = postData.mediaId ?? null;
    } else {
      postError = postData.error ?? "X post failed";
    }
  }

  // Step 4: Record run
  const runRecord = {
    template,
    tweet_text: tweetText,
    tweet_id: tweetId,
    media_id: mediaId,
    dry_run: dryRun,
    status: postError ? "error" : dryRun ? "dry_run" : "success",
    error_message: postError,
    stats_snapshot: stats,
    svg_content: adData.svg ?? null,
  };

  const { data: runData, error: insertError } = await supabase
    .from("viral_pipeline_runs")
    .insert(runRecord)
    .select()
    .single();

  if (insertError) {
    console.error("Failed to record run:", insertError);
  }

  return jsonResp({
    success: !postError,
    dryRun,
    tweetId,
    mediaId,
    tweetText,
    template,
    stats,
    runId: runData?.id ?? null,
    error: postError,
    svgPreview: adData.svg
      ? `data:image/svg+xml;base64,${btoa(adData.svg)}`
      : null,
  });
}

async function fetchCurrentStats(
  supabase: ReturnType<typeof createClient>,
): Promise<{ users: number; functions: number; pages: number }> {
  // User count from auth.users
  const { count: userCount } = await supabase
    .from("user_profiles")
    .select("*", { count: "exact", head: true });

  // Function count from edge_function_ui_status or static
  const { count: funcCount } = await supabase
    .from("edge_function_ui_status")
    .select("*", { count: "exact", head: true });

  return {
    users: userCount ?? 4,
    functions: funcCount ?? 223,
    pages: 130, // approximate from lib/pages count
  };
}

async function getViralStats(supabase: ReturnType<typeof createClient>): Promise<Response> {
  const { data, error } = await supabase
    .from("viral_pipeline_runs")
    .select("status, template, created_at, tweet_id")
    .order("created_at", { ascending: false })
    .limit(100);

  if (error) return jsonResp({ success: false, error: error.message }, 500);

  const runs = data ?? [];
  const stats = {
    total_campaigns: runs.length,
    successful_tweets: runs.filter((r) => r.status === "success").length,
    by_template: runs.reduce<Record<string, number>>((acc, r) => {
      acc[r.template ?? "unknown"] = (acc[r.template ?? "unknown"] ?? 0) + 1;
      return acc;
    }, {}),
    last_campaign: runs.length > 0 ? runs[0].created_at : null,
  };

  return jsonResp({ success: true, stats, recent: runs.slice(0, 5) });
}

async function trackResult(
  supabase: ReturnType<typeof createClient>,
  body: Record<string, unknown>,
): Promise<Response> {
  const { runId, impressions, clicks, follows } = body;
  if (!runId) return jsonResp({ success: false, error: "runId required" }, 400);

  const { error } = await supabase
    .from("viral_pipeline_runs")
    .update({
      impressions: impressions ?? null,
      clicks: clicks ?? null,
      new_follows: follows ?? null,
    })
    .eq("id", runId);

  if (error) return jsonResp({ success: false, error: error.message }, 500);
  return jsonResp({ success: true, runId });
}

function jsonResp(payload: unknown, status = 200): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
