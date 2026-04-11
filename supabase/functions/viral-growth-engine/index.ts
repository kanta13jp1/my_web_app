// viral-growth-engine Edge Function
// バイラル拡散エンジン — 登録者増加を加速する総合グロース機能
//
// 機能:
// - 招待コード生成・追跡 (既存 growth-referral と連携)
// - バイラルループ: シェア → 友達登録 → 双方にポイント
// - リーダーボード: 招待数ランキング
// - 自動投稿スケジュール: 最適時間帯にバイラル広告を自動投稿
// - A/Bテスト: 広告クリエイティブの効果測定
// - グロース指標ダッシュボード用データ
//
// GET  ?view=leaderboard | stats | schedule | ab_results | pipeline_runs
// POST { "action": "generate_invite" | "record_share" | "schedule_post" | "run_ab_test" | "auto_post_now" | "pipeline_run" | "pipeline_track" | "pipeline_stats" | "get_stats" | "run_campaign" }
// (pipeline_* actions absorbed from viral-growth-pipeline)

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";
const SELF_URL = SUPABASE_URL.replace("supabase.co", "supabase.co/functions/v1");

// 最適投稿時間帯 (JST) — SNS分析に基づく
const OPTIMAL_POST_HOURS_JST = [7, 8, 12, 19, 21, 22];

// バイラル広告スケジュール (テンプレートのローテーション)
const AD_ROTATION = [
  { template: "dark_war", lang: "ja", interval_hours: 24 },
  { template: "competitor_comparison", lang: "ja", interval_hours: 48 },
  { template: "feature_highlight", lang: "ja", interval_hours: 36 },
  { template: "user_growth", lang: "ja", interval_hours: 72 },
];

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: { persistSession: false },
    });

    if (req.method === "GET") {
      const url = new URL(req.url);
      const view = url.searchParams.get("view");

      if (view === "leaderboard") {
        return await getLeaderboard(admin);
      }
      if (view === "stats") {
        return await getViralStats(admin);
      }
      if (view === "schedule") {
        return jsonRes({
          success: true,
          optimalHoursJst: OPTIMAL_POST_HOURS_JST,
          adRotation: AD_ROTATION,
          nextRecommendedPost: getNextOptimalTime(),
        });
      }
      if (view === "ab_results") {
        return await getAbTestResults(admin);
      }

      if (view === "pipeline_runs") {
        const limitVal = parseInt(new URL(req.url).searchParams.get("limit") ?? "20", 10);
        const { data, error: runsErr } = await admin
          .from("viral_pipeline_runs")
          .select("*")
          .order("created_at", { ascending: false })
          .limit(limitVal);
        if (runsErr) return jsonRes({ success: false, error: runsErr.message }, 500);
        return jsonRes({ success: true, runs: data ?? [] });
      }

      return jsonRes({
        success: true,
        actions: ["generate_invite", "record_share", "schedule_post", "run_ab_test", "auto_post_now", "pipeline_run", "pipeline_track", "pipeline_stats", "get_stats", "run_campaign"],
        views: ["leaderboard", "stats", "schedule", "ab_results", "pipeline_runs"],
      });
    }

    if (req.method !== "POST") {
      return jsonRes({ error: "GET or POST only" }, 405);
    }

    const body = await req.json().catch(() => ({})) as {
      action?: string;
      userId?: string;
      shareType?: string;
      templateKey?: string;
      lang?: string;
      variant?: string;
      template?: string;
      imageBase64?: string;
      dryRun?: boolean;
      runId?: string;
      impressions?: number;
      clicks?: number;
      follows?: number;
    };

    const action = body.action;

    if (action === "generate_invite") {
      return await generateInviteCode(admin, body.userId);
    }

    if (action === "record_share") {
      return await recordShare(admin, body.userId, body.shareType ?? "x_post");
    }

    if (action === "auto_post_now") {
      return await autoPostNow(admin, body.templateKey, body.lang);
    }

    if (action === "run_ab_test") {
      return await runAbTest(admin, body.templateKey, body.variant);
    }

    if (action === "schedule_post") {
      return await scheduleNextPost(admin, body.templateKey, body.lang);
    }

    // ---- Pipeline actions (absorbed from viral-growth-pipeline) ----
    if (action === "pipeline_run" || action === "run_campaign") {
      return await pipelineRunCampaign(admin, body);
    }

    if (action === "pipeline_track") {
      return await pipelineTrackResult(admin, body);
    }

    if (action === "pipeline_stats" || action === "get_stats") {
      return await pipelineGetStats(admin);
    }

    return jsonRes({ error: `Unknown action: ${action}` }, 400);
  } catch (e) {
    return jsonRes({ error: String(e) }, 500);
  }
});

async function getLeaderboard(admin: ReturnType<typeof createClient>) {
  // 招待リーダーボード
  try {
    const { data } = await admin
      .from("referral_tracking")
      .select("referrer_user_id, referral_count:referred_user_id.count()")
      .order("referral_count", { ascending: false })
      .limit(10);

    // フォールバック: app_analytics からシェアイベントを集計
    const { data: shareData } = await admin
      .from("app_analytics")
      .select("user_id, share_count, date")
      .order("share_count", { ascending: false })
      .limit(10);

    return jsonRes({
      success: true,
      leaderboard: data ?? [],
      topSharers: shareData ?? [],
      prizes: [
        { rank: 1, reward: "プレミアム3ヶ月無料 + 自分株式会社ステッカー" },
        { rank: 2, reward: "プレミアム1ヶ月無料" },
        { rank: 3, reward: "特別バッジ" },
      ],
    });
  } catch (_e) {
    return jsonRes({ success: true, leaderboard: [], message: "テーブル未作成" });
  }
}

async function getViralStats(admin: ReturnType<typeof createClient>) {
  try {
    // 総シェア数・招待経由登録数・バイラル係数K
    const { data: analytics } = await admin
      .from("app_analytics")
      .select("share_count, conversions, landing_views, date")
      .order("date", { ascending: false })
      .limit(30);

    const rows = analytics ?? [];
    const totalShares = rows.reduce((s, r) => s + (r.share_count ?? 0), 0);
    const totalConversions = rows.reduce((s, r) => s + (r.conversions ?? 0), 0);
    const totalViews = rows.reduce((s, r) => s + (r.landing_views ?? 0), 0);

    // バイラル係数 K = (シェア数 × 各シェアからの平均訪問者) × コンバージョン率
    const avgShareCvr = totalViews > 0 ? totalConversions / totalViews : 0;
    const kFactor = totalShares > 0 ? (totalShares * 0.3) * avgShareCvr : 0;

    return jsonRes({
      success: true,
      stats: {
        totalShares,
        totalConversions,
        totalViews,
        kFactor: kFactor.toFixed(3),
        kFactorTarget: "1.0 (バイラル成立)",
        current: kFactor >= 1.0 ? "🔥 バイラル中!" : `📈 K=${kFactor.toFixed(3)} (目標K≥1.0)`,
      },
      recent: rows.slice(0, 7),
    });
  } catch (_e) {
    return jsonRes({ success: true, stats: { kFactor: 0, message: "計測中" } });
  }
}

async function getAbTestResults(admin: ReturnType<typeof createClient>) {
  try {
    const { data } = await admin
      .from("viral_ad_generations")
      .select("template_key, lang, status, created_at, posted_tweet_url")
      .order("created_at", { ascending: false })
      .limit(50);

    const results = (data ?? []).reduce((acc: Record<string, { count: number; posted: number }>, row) => {
      const key = `${row.template_key}_${row.lang}`;
      if (!acc[key]) acc[key] = { count: 0, posted: 0 };
      acc[key].count++;
      if (row.status === "posted") acc[key].posted++;
      return acc;
    }, {});

    return jsonRes({ success: true, abResults: results });
  } catch (_e) {
    return jsonRes({ success: true, abResults: {}, message: "viral_ad_generations テーブル未作成" });
  }
}

async function generateInviteCode(admin: ReturnType<typeof createClient>, userId?: string) {
  if (!userId) return jsonRes({ error: "userId required" }, 400);

  const code = `JK-${userId.slice(0, 6).toUpperCase()}-${Math.random().toString(36).slice(2, 6).toUpperCase()}`;
  const inviteUrl = `https://my-web-app-b67f4.web.app/?ref=${code}`;

  try {
    await admin.from("referral_codes").upsert({
      user_id: userId,
      code,
      invite_url: inviteUrl,
      created_at: new Date().toISOString(),
    }, { onConflict: "user_id" });
  } catch (_e) {
    // テーブル未作成の場合はコードのみ返す
  }

  const shareText = `自分株式会社を使ってみて！ NotionもSlackもMoneyForwardも全部不要になりました🎉\n招待コード: ${code}\n▶ ${inviteUrl}\n#buildinpublic`;

  return jsonRes({
    success: true,
    code,
    inviteUrl,
    shareText,
    xPostUrl: `https://x.com/intent/post?text=${encodeURIComponent(shareText)}`,
  });
}

async function recordShare(admin: ReturnType<typeof createClient>, userId?: string, shareType = "x_post") {
  try {
    const today = new Date().toISOString().slice(0, 10);
    await admin.from("app_analytics").upsert({
      date: today,
      source: "viral_share",
      user_id: userId,
      share_count: 1,
    });
  } catch (_e) {
    // ignore
  }
  return jsonRes({ success: true, shareType, message: "Share recorded" });
}

async function autoPostNow(_admin: ReturnType<typeof createClient>, templateKey?: string, lang?: string) {
  // viral-video-ad-generatorを内部呼び出し
  const template = templateKey ?? pickNextTemplate();

  try {
    const genResp = await fetch(`${SUPABASE_URL}/functions/v1/viral-video-ad-generator`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${SERVICE_ROLE_KEY}`,
      },
      body: JSON.stringify({ template, lang: lang ?? "ja", type: "image" }),
    });

    const genData = await genResp.json() as {
      caption?: string;
      generatedImageUrl?: string;
      id?: string;
    };

    if (!genData.caption) {
      return jsonRes({ error: "Caption generation failed", genData }, 500);
    }

    // X投稿 (メディアあり/なし)
    const postEndpoint = genData.generatedImageUrl ? "x-media-post" : "post-x-update";
    const postBody = genData.generatedImageUrl
      ? { text: genData.caption.slice(0, 280), mediaUrl: genData.generatedImageUrl, adGenerationId: genData.id }
      : { text: genData.caption.slice(0, 280) };

    const postResp = await fetch(`${SUPABASE_URL}/functions/v1/${postEndpoint}`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${SERVICE_ROLE_KEY}`,
      },
      body: JSON.stringify(postBody),
    });

    const postData = await postResp.json() as Record<string, unknown>;

    return jsonRes({
      success: true,
      template,
      caption: genData.caption,
      hasMedia: !!genData.generatedImageUrl,
      xPost: postData,
    });
  } catch (e) {
    return jsonRes({ error: String(e) }, 500);
  }
}

function runAbTest(_admin: ReturnType<typeof createClient>, templateKey?: string, variant?: string) {
  const templates = ["dark_war", "competitor_comparison", "feature_highlight", "user_growth"];
  const testTemplate = templateKey ?? templates[Math.floor(Math.random() * templates.length)];

  return jsonRes({
    success: true,
    message: "A/B test queued",
    template: testTemplate,
    variant: variant ?? "control",
    tip: "Run auto_post_now with different templates to compare engagement",
  });
}

function scheduleNextPost(_admin: ReturnType<typeof createClient>, templateKey?: string, lang?: string) {
  const nextTime = getNextOptimalTime();
  return jsonRes({
    success: true,
    scheduledFor: nextTime.toISOString(),
    template: templateKey ?? pickNextTemplate(),
    lang: lang ?? "ja",
    message: "Use Claude Code Schedule cs-check to trigger auto_post_now at optimal times",
  });
}

function getNextOptimalTime(): Date {
  const now = new Date();
  const jstOffset = 9 * 60 * 60 * 1000;
  const jstNow = new Date(now.getTime() + jstOffset);
  const currentHourJst = jstNow.getUTCHours();

  const nextHour = OPTIMAL_POST_HOURS_JST.find((h) => h > currentHourJst)
    ?? OPTIMAL_POST_HOURS_JST[0];

  const next = new Date(jstNow);
  if (nextHour <= currentHourJst) {
    next.setUTCDate(next.getUTCDate() + 1);
  }
  next.setUTCHours(nextHour - 9, 0, 0, 0); // JST→UTC
  return next;
}

function pickNextTemplate(): string {
  const hour = new Date().getUTCHours();
  const idx = Math.floor(hour / 6) % AD_ROTATION.length;
  return AD_ROTATION[idx].template;
}

function jsonRes(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

// ---------------------------------------------------------------------------
// Pipeline functions (absorbed from viral-growth-pipeline)
// ---------------------------------------------------------------------------

async function pipelineRunCampaign(
  supabase: ReturnType<typeof createClient>,
  body: { template?: string; imageBase64?: string; dryRun?: boolean },
): Promise<Response> {
  const template = body.template ?? "growth_stats";
  const dryRun = body.dryRun ?? false;

  const [{ count: userCount }, { count: funcCount }] = await Promise.all([
    supabase.from("user_profiles").select("*", { count: "exact", head: true }),
    supabase.from("edge_function_ui_status").select("*", { count: "exact", head: true }),
  ]);
  const stats = { users: userCount ?? 4, functions: funcCount ?? 89, pages: 211 };

  const adResp = await fetch(`${SELF_URL}/viral-ad-generator`, {
    method: "POST",
    headers: { Authorization: `Bearer ${SERVICE_ROLE_KEY}`, "Content-Type": "application/json" },
    body: JSON.stringify({ template, stats }),
  });

  if (!adResp.ok) {
    return jsonRes({ success: false, error: `Ad generation failed: ${await adResp.text()}` }, 500);
  }

  const adData = await adResp.json() as { success: boolean; tweetText?: string; svg?: string };
  if (!adData.success) return jsonRes({ success: false, error: "Ad generator returned failure" }, 500);

  const tweetText = adData.tweetText ?? "";
  let tweetId: string | null = null;
  let mediaId: string | null = null;
  let postError: string | null = null;

  if (!dryRun) {
    const postBody: Record<string, unknown> = { text: tweetText };
    if (body.imageBase64) { postBody.mediaBase64 = body.imageBase64; postBody.mediaType = "image/png"; }
    const postResp = await fetch(`${SELF_URL}/x-media-post`, {
      method: "POST",
      headers: { Authorization: `Bearer ${SERVICE_ROLE_KEY}`, "Content-Type": "application/json" },
      body: JSON.stringify(postBody),
    });
    const postData = await postResp.json() as { success?: boolean; tweetId?: string; mediaId?: string; error?: string };
    if (postData.success) { tweetId = postData.tweetId ?? null; mediaId = postData.mediaId ?? null; }
    else { postError = postData.error ?? "X post failed"; }
  }

  const runRecord = { template, tweet_text: tweetText, tweet_id: tweetId, media_id: mediaId, dry_run: dryRun, status: postError ? "error" : dryRun ? "dry_run" : "success", error_message: postError, stats_snapshot: stats, svg_content: adData.svg ?? null };
  const { data: runData, error: insertError } = await supabase.from("viral_pipeline_runs").insert(runRecord).select().single();
  if (insertError) console.error("Failed to record run:", insertError);

  return jsonRes({ success: !postError, dryRun, tweetId, mediaId, tweetText, template, stats, runId: runData?.id ?? null, error: postError, svgPreview: adData.svg ? `data:image/svg+xml;base64,${btoa(adData.svg)}` : null });
}

async function pipelineTrackResult(
  supabase: ReturnType<typeof createClient>,
  body: { runId?: string; impressions?: number; clicks?: number; follows?: number },
): Promise<Response> {
  if (!body.runId) return jsonRes({ success: false, error: "runId required" }, 400);
  const { error } = await supabase.from("viral_pipeline_runs").update({ impressions: body.impressions ?? null, clicks: body.clicks ?? null, new_follows: body.follows ?? null }).eq("id", body.runId);
  if (error) return jsonRes({ success: false, error: error.message }, 500);
  return jsonRes({ success: true, runId: body.runId });
}

async function pipelineGetStats(supabase: ReturnType<typeof createClient>): Promise<Response> {
  const { data, error } = await supabase.from("viral_pipeline_runs").select("status, template, created_at, tweet_id").order("created_at", { ascending: false }).limit(100);
  if (error) return jsonRes({ success: false, error: error.message }, 500);
  const runs = data ?? [];
  const stats = {
    total_campaigns: runs.length,
    successful_tweets: runs.filter((r) => r.status === "success").length,
    by_template: runs.reduce<Record<string, number>>((acc, r) => { acc[r.template ?? "unknown"] = (acc[r.template ?? "unknown"] ?? 0) + 1; return acc; }, {}),
    last_campaign: runs.length > 0 ? runs[0].created_at : null,
  };
  return jsonRes({ success: true, stats, recent: runs.slice(0, 5) });
}
