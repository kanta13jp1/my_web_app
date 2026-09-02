// growth-hub — グロース・バイラル・マーケティング統合EF
// Merges (20 EFs): growth-acquisition, growth-command-center, growth-referral,
//   growth-share-signal, growth-achievement-summary, growth-import-preview,
//   growth-import-commit, get-growth-roadmap-progress, video-ad-generator,
//   viral-share-engine, x-media-post, growth-automation-controller,
//   landing-ab-test, referral-program, share-quote, generate-quote-image,
//   seo-optimizer, send-waitlist-notification, viral-ad-generator, viral-growth-engine

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient, SupabaseClient } from "npm:@supabase/supabase-js@2";
import {
  fetchXTrendsByWoeid,
  fetchXTweetMetrics,
  getXAccountHandle,
  isXApiError,
  isXConfigured,
  postTweet,
  uploadMediaFromUrl,
  type XTweetMetrics,
} from "../_shared/x-client.ts";
import {
  isExternalRevenueCandidate,
  normalizeSupporterBuyerContext,
} from "../_shared/supporter_buyer.ts";
import { isSupportedAcquisitionSignal } from "./acquisition_signals.ts";
import { analyticsActorHash } from "./analytics_actor.ts";
import {
  extractPostedTexts,
  findDuplicateContent,
  resolveDuplicateGuardConfig,
  type XPostLogRowLike,
} from "./x_duplicate_content.ts";
import { pickBestVariant, pickConfidentVariant } from "./x_best_variant.ts";
import {
  buildAcquisitionRankingLine,
  computeAcquisitionScore,
  resolveAcquisitionScoreInput,
} from "./x_acquisition_score.ts";
import {
  buildAccountAcquisitionLine,
  buildAnalyticsImportMetadata,
  parseXAnalyticsCsv,
} from "./x_analytics_import.ts";
import {
  buildArchetypeTopicInteractionLine,
  buildIcpHistoricalExemplarLine,
  buildIcpScopeLine,
  buildTopicLiftLine,
  classifyPostTopic,
  normalizeTopicBucket,
  selectIcpCohort,
} from "./x_topic_audience.ts";
import {
  buildSignupSlackPayload,
  isRecentSignupCreatedAt,
  resolveSignupChannel,
} from "./signup_notification.ts";
import {
  filterCurrentStrategyLogs,
  filterRecentLogs,
} from "./metrics_window.ts";
import {
  metricWindowLabel,
  type NormalizedXPostMetrics,
  normalizeXMetricWindows,
  selectXMetricComparisonWindow,
  X_METRIC_LEARNING_SELECTION_RULE,
  X_METRIC_WINDOW_SELECTION_RULE,
} from "./x_metric_windows.ts";
import { compactXMetricSnapshotMedia } from "./x_metric_snapshot.ts";
import { decideXPostPreflight } from "./x_post_preflight.ts";
import { resolveXPostAttribution } from "./x_post_attribution.ts";
import { computeTodayStatus } from "./x_today_status.ts";
import { buildMediaLiftLine, classifyPostMediaType } from "./x_media_type.ts";
import {
  buildArchetypeLiftLine,
  buildOwnDataFactsLine,
  classifyPostArchetype,
  normalizeArchetypeBucket,
  resolveLoggedArchetype,
} from "./x_post_archetype.ts";
import {
  buildGrowthDataReport,
  type GrowthReportRow,
} from "./x_growth_data_report.ts";
import { buildAiToolTrackerPost } from "./x_ai_tool_tracker.ts";
import {
  buildHouseholdTrackerReport,
  HOUSEHOLD_TRACKER_CONSENT_MIRROR_KEY,
  HOUSEHOLD_TRACKER_MIRROR_KEY,
  parseHouseholdTrackerConsent,
} from "./x_household_tracker.ts";
import { isUuid, resolveXLogOwnerUserId } from "./x_operator_auth.ts";
import {
  approveXPostCandidateMetadata,
  buildXPostCandidateMetadata,
  finalizeXPostCandidateMetadata,
  rejectXPostCandidateMetadata,
  X_POST_CANDIDATE_SOURCE,
} from "./x_post_candidate.ts";
import {
  canReadRoadmapShareStats,
  parseRoadmapCounts,
  type RoadmapPlan,
  selectShareableRoadmapPlans,
} from "./roadmap_share_stats.ts";
import {
  DEFAULT_LANDING_TRIAL_MODEL,
  generateLandingTrialSuggestion,
  hashLandingTrialClient,
  LandingTrialInputError,
  normalizeLandingTrialPrompt,
} from "./landing_trial.ts";
import {
  buildFirstUserFunnelReport,
  FIRST_USER_FUNNEL_STAGES,
  type FirstUserAcquisitionEvent,
  type FirstUserPayment,
  type FirstUserXPost,
} from "./first_user_funnel.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, traceparent, tracestate, baggage, sentry-trace",
  "Access-Control-Max-Age": "86400",
};
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ??
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY") ?? "";
const LANDING_TRIAL_AI_MODEL = Deno.env.get("LANDING_TRIAL_AI_MODEL") ?? "";
const LANDING_TRIAL_RATE_LIMIT_SALT =
  Deno.env.get("LANDING_TRIAL_RATE_LIMIT_SALT") ?? SERVICE_ROLE_KEY;
// x.post 近似重複ガードの調整用 env (未設定時は既定 0.9 / 直近 5 件)。
const X_DUP_SIMILARITY_THRESHOLD = Deno.env.get("X_DUP_SIMILARITY_THRESHOLD") ??
  null;
const X_DUP_RECENT_COUNT = Deno.env.get("X_DUP_RECENT_COUNT") ?? null;
// metrics 収集の鮮度窓(日)。X 指標は ~72h で定常化するため、窓外の再読は
// X API の spend cap を浪費するだけ(実障害 2026-07-05〜07)。既定 7 日。
// `supabase secrets set X_METRICS_WINDOW_DAYS=14` で再デプロイなしに調整可。
const X_METRICS_WINDOW_DAYS = Deno.env.get("X_METRICS_WINDOW_DAYS") ?? null;
const metricsWindowDays = (() => {
  const n = Number(X_METRICS_WINDOW_DAYS);
  return Number.isFinite(n) && n > 0 ? n : 7;
})();

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function errorMessage(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}

// X trends API 不可時(未設定/退役/空)の無料フォールバック。既存の tools-hub
// rss.fetch_latest で当日ニュース見出しを取得し、trend トピックとして返す。
// これで文面・動画が「今日のニュース」を反映し毎回変化する(有料 X API 不要)。
async function fetchTodayNewsTrendTopics(
  limit: number,
): Promise<Array<{ name: string; tweetCount: number | null }>> {
  const feeds = [
    {
      title: "ITmedia AI+",
      url: "https://rss.itmedia.co.jp/rss/2.0/aiplus.xml",
      category: "AI",
    },
    {
      title: "ITmedia NEWS",
      url: "https://rss.itmedia.co.jp/rss/2.0/news_bursts.xml",
      category: "IT",
    },
    {
      title: "NHK NEWS WEB",
      url: "https://www3.nhk.or.jp/rss/news/cat0.xml",
      category: "総合",
    },
  ];
  const url = `${SUPABASE_URL.replace(/\/$/, "")}/functions/v1/tools-hub`;
  const res = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      ...(SUPABASE_ANON_KEY ? { apikey: SUPABASE_ANON_KEY } : {}),
      ...(SERVICE_ROLE_KEY
        ? { Authorization: `Bearer ${SERVICE_ROLE_KEY}` }
        : {}),
    },
    body: JSON.stringify({
      action: "rss.fetch_latest",
      feeds,
      per_feed_limit: 8,
      limit: 48,
      signal_limit: Math.max(limit, 8),
    }),
  });
  if (!res.ok) {
    throw new Error(`tools-hub rss.fetch_latest failed: ${res.status}`);
  }
  const data = await res.json().catch(() => ({})) as Record<string, unknown>;
  const rawList = [
    data["signals"],
    data["items"],
    data["latest"],
    data["results"],
  ].find((value) => Array.isArray(value)) as unknown[] | undefined;
  const list = Array.isArray(rawList) ? rawList : [];
  const seen = new Set<string>();
  const topics: Array<{ name: string; tweetCount: number | null }> = [];
  for (const entry of list) {
    const rec = (entry && typeof entry === "object")
      ? entry as Record<string, unknown>
      : {};
    const name = String(rec["title"] ?? rec["name"] ?? "").trim();
    if (!name || seen.has(name)) continue;
    seen.add(name);
    topics.push({ name: name.slice(0, 120), tweetCount: null });
    if (topics.length >= limit) break;
  }
  return topics;
}

async function getUserId(req: Request): Promise<string | null> {
  const auth = req.headers.get("Authorization") ?? "";
  if (!auth) return null;
  const bearer = auth.replace(/^Bearer\s+/i, "").trim();
  if (SERVICE_ROLE_KEY && bearer === SERVICE_ROLE_KEY) {
    return "service_role";
  }
  const c = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: auth } },
  });
  const {
    data: { user },
  } = await c.auth.getUser();
  return user?.id ?? null;
}

/// 共有X資格情報を使う操作は service role または user_profiles.is_admin のみ。
/// 認証済みであることと、運営アカウントへ投稿できることを分離する。
async function isXOperator(
  admin: SupabaseClient,
  userId: string,
): Promise<boolean> {
  if (userId === "service_role") return true;
  if (!isUuid(userId)) return false;
  const { data, error } = await admin
    .from("user_profiles")
    .select("is_admin")
    .eq("user_id", userId)
    .maybeSingle();
  if (error) return false;
  return data?.is_admin === true;
}

async function xReadScopeUserId(
  admin: SupabaseClient,
  userId: string,
): Promise<string> {
  return await isXOperator(admin, userId) ? "service_role" : userId;
}

function asRecord(value: unknown): Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value)
    ? value as Record<string, unknown>
    : {};
}

function firstString(...values: unknown[]): string {
  for (const value of values) {
    if (typeof value === "string" && value.trim() !== "") {
      return value.trim();
    }
  }
  return "";
}

function firstNumber(...values: unknown[]): number | null {
  for (const value of values) {
    if (typeof value === "number" && Number.isFinite(value)) return value;
    if (typeof value === "string") {
      const parsed = Number(value);
      if (Number.isFinite(parsed)) return parsed;
    }
  }
  return null;
}

async function listItems(
  admin: SupabaseClient,
  source: string,
  userId: string,
  limit = 50,
) {
  const { data, error } = await admin
    .from("hub_data")
    .select("id, metadata, created_at")
    .eq("source", source)
    .filter("metadata->>user_id", "eq", userId)
    .order("created_at", { ascending: false })
    .limit(limit);
  if (error) throw new Error(error.message);
  return data ?? [];
}

async function listXPostLogs(
  admin: SupabaseClient,
  userId: string,
  limit = 50,
) {
  let query = admin
    .from("hub_data")
    .select("id, metadata, created_at")
    .eq("source", "x_post_log")
    .order("created_at", { ascending: false })
    .limit(limit);
  if (userId !== "service_role") {
    query = query.filter("metadata->>user_id", "eq", userId);
  }
  const { data, error } = await query;
  if (error) throw new Error(`x_post_logs: ${error.message}`);
  return data ?? [];
}

async function listXHistoricalBenchmarkLogs(
  admin: SupabaseClient,
  userId: string,
  limit = 10,
) {
  let query = admin
    .from("hub_data")
    .select("id, metadata, created_at")
    .eq("source", "x_post_log")
    .filter("metadata->>learning_cohort", "eq", "historical_benchmark")
    .order("created_at", { ascending: false })
    .limit(limit);
  if (userId !== "service_role") {
    query = query.filter("metadata->>user_id", "eq", userId);
  }
  const { data, error } = await query;
  if (error) throw new Error(`x_historical_benchmarks: ${error.message}`);
  return data ?? [];
}

async function listXMetricSnapshots(
  admin: SupabaseClient,
  userId: string,
  sourceLogIds: readonly string[],
) {
  if (sourceLogIds.length === 0) return [];
  const rows: Array<{
    id: string;
    metadata: Record<string, unknown>;
    created_at: string;
  }> = [];
  // Snapshot volume can exceed PostgREST's usual 1,000-row response limit.
  // Page by bounded source-log batches so early post-age windows are retained.
  // Metrics collection stops after seven days. Ten posts therefore fit in a
  // single 1,000-row page under the normal three-hour collection cadence, and
  // keep each PostgREST statement small enough for the production timeout.
  const batchSize = 10;
  const pageSize = 1000;
  const maxPagesPerBatch = 10;
  for (let offset = 0; offset < sourceLogIds.length; offset += batchSize) {
    const ids = sourceLogIds.slice(offset, offset + batchSize);
    for (let page = 0; page < maxPagesPerBatch; page += 1) {
      // ORDER は (source_log_id, created_at) — partial index
      // idx_hub_data_x_metric_snapshot_log_created (#4030) と一致させ、
      // source_log_id IN(...) を index 走査 + merge-append で返す (sort 回避)。
      // created_at 単独 order だと index を order に使えず大量行 sort →
      // service_role (cron) 経路で statement timeout していた。
      // normalizeXMetricWindows は source_log_id 毎に snapshot を突合するため
      // post 跨ぎの並び順には非依存。
      let query = admin
        .from("hub_data")
        .select("id, metadata, created_at")
        .eq("source", "x_post_metric_snapshot")
        .in("metadata->>source_log_id", ids)
        .order("metadata->>source_log_id", { ascending: true })
        .order("created_at", { ascending: true })
        .range(page * pageSize, (page + 1) * pageSize - 1);
      if (userId !== "service_role") {
        query = query.filter("metadata->>user_id", "eq", userId);
      }
      const { data, error } = await query;
      if (error) {
        throw new Error(
          `x_metric_snapshots(batch=${
            Math.trunc(offset / batchSize)
          },page=${page}): ${error.message}`,
        );
      }
      const pageRows = (data ?? []) as typeof rows;
      rows.push(...pageRows);
      if (pageRows.length < pageSize) break;
    }
  }
  return rows;
}

async function addItem(
  admin: SupabaseClient,
  source: string,
  userId: string,
  meta: Record<string, unknown>,
) {
  const { data, error } = await admin
    .from("hub_data")
    .insert({ source, metadata: { ...meta, user_id: userId } })
    .select("id, metadata, created_at")
    .single();
  if (error) throw new Error(error.message);
  return data;
}

type ReferralCodeRow = {
  id: number;
  user_id: string;
  referral_code: string;
  total_referrals: number | null;
  successful_referrals: number | null;
  bonus_points_earned: number | null;
  created_at: string;
  updated_at: string;
};

type ReferralRow = {
  id: number;
  referrer_user_id: string;
  referred_user_id: string;
  referral_code: string;
  bonus_points: number | null;
  status: string | null;
  completed_at: string | null;
  created_at: string;
  metadata?: Record<string, unknown> | null;
};

type BillingSubscriptionRow = {
  user_id: string;
  tier: string | null;
  status: string | null;
  metadata?: Record<string, unknown> | null;
};

const TOUCHPOINT_DEFS = [
  {
    id: "landing",
    label: "Landing",
    touchSignal: "touch_landing",
    signupSignal: "signup_submit_landing",
  },
  {
    id: "profile",
    label: "X profile",
    touchSignal: "touch_profile",
    signupSignal: "signup_submit_profile",
  },
  {
    id: "x_first_user_growth",
    label: "X first-user campaign",
    touchSignal: "touch_x_first_user_growth",
    signupSignal: "signup_submit_x_first_user_growth",
  },
  {
    id: "import",
    label: "Import",
    touchSignal: "touch_import",
    signupSignal: "signup_submit_import",
  },
  {
    id: "public_memo",
    label: "Public memo",
    touchSignal: "touch_public_memo",
    signupSignal: "signup_submit_public_memo",
  },
  {
    id: "referral",
    label: "Referral",
    touchSignal: "touch_referral",
    signupSignal: "signup_submit_referral",
  },
  {
    id: "comparison",
    label: "Comparison",
    touchSignal: "touch_comparison",
    signupSignal: "signup_submit_comparison",
  },
  {
    id: "guitar",
    label: "Guitar",
    touchSignal: "touch_guitar_gallery",
    signupSignal: "signup_submit_guitar",
  },
];

const IMPORT_PREVIEW_DEFS = [
  {
    id: "notion",
    label: "Notion previews",
    signalKey: "import_preview_notion",
  },
  {
    id: "evernote",
    label: "Evernote previews",
    signalKey: "import_preview_evernote",
  },
  {
    id: "markdown",
    label: "Markdown previews",
    signalKey: "import_preview_markdown",
  },
];

function formatDateKey(date: Date): string {
  return `${date.getFullYear()}-${
    String(date.getMonth() + 1).padStart(2, "0")
  }-${String(date.getDate()).padStart(2, "0")}`;
}

function resolveDateKey(): string {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: "Asia/Tokyo",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(new Date());
  const year = parts.find((part) => part.type === "year")?.value ?? "";
  const month = parts.find((part) => part.type === "month")?.value ?? "";
  const day = parts.find((part) => part.type === "day")?.value ?? "";
  return `${year}-${month}-${day}`;
}

async function recordAcquisitionSignal(
  admin: SupabaseClient,
  rawSignalKey: unknown,
  rawShareIncrement?: unknown,
  actorHash?: string,
) {
  const signalKey = String(rawSignalKey ?? "").trim();
  if (!signalKey || !isSupportedAcquisitionSignal(signalKey)) {
    return {
      success: false,
      error: "signalKey required / unsupported",
    };
  }

  const dateKey = resolveDateKey();
  const shareIncrement = Number(rawShareIncrement ?? 0);
  if (
    !Number.isInteger(shareIncrement) || shareIncrement < 0 ||
    shareIncrement > 1
  ) {
    return {
      success: false,
      error: "shareIncrement must be 0 or 1",
    };
  }
  if (!actorHash) throw new Error("analytics actor hash is required");

  const { data: recorded, error } = await admin.rpc(
    "record_app_analytics_event",
    {
      p_source_key: signalKey,
      p_event_date: dateKey,
      p_share_increment: shareIncrement,
      p_actor_hash: actorHash,
    },
  );
  if (error) throw new Error(error.message);
  return { success: true, recorded: recorded === true, signalKey, dateKey };
}

const firstUserFunnelStageSet = new Set<string>(FIRST_USER_FUNNEL_STAGES);
const firstUserAcquisitionSourceSet = new Set(["x", "zenn"]);
const firstUserTokenPattern = /^[a-z0-9_-]{1,64}$/;

async function recordFirstUserFunnelSignal(
  admin: SupabaseClient,
  actorUserId: string | null,
  body: Record<string, unknown>,
) {
  const visitorId = firstString(body.visitorId, body.visitor_id).toLowerCase();
  const stage = firstString(body.stage).toLowerCase();
  const utmSource = firstString(
    body.utmSource,
    body.utm_source,
  ).toLowerCase();
  const utmMedium = firstString(
    body.utmMedium,
    body.utm_medium,
  ).toLowerCase();
  const utmCampaign = firstString(
    body.utmCampaign,
    body.utm_campaign,
  ).toLowerCase();
  const utmContent = firstString(
    body.utmContent,
    body.utm_content,
  ).toLowerCase();

  if (
    !isUuid(visitorId) ||
    !firstUserFunnelStageSet.has(stage) ||
    !firstUserAcquisitionSourceSet.has(utmSource) ||
    utmCampaign !== "first_user_growth" ||
    !firstUserTokenPattern.test(utmMedium) ||
    !firstUserTokenPattern.test(utmContent)
  ) {
    return {
      success: false,
      error: "invalid first-user funnel signal",
    };
  }

  const { data, error } = await admin
    .from("first_user_acquisition_events")
    .upsert({
      visitor_id: visitorId,
      auth_user_id: actorUserId && isUuid(actorUserId) ? actorUserId : null,
      stage,
      utm_source: utmSource,
      utm_medium: utmMedium,
      utm_campaign: utmCampaign,
      utm_content: utmContent,
    }, {
      onConflict:
        "visitor_id,utm_source,utm_medium,utm_campaign,utm_content,stage",
      ignoreDuplicates: true,
    })
    .select("visitor_id")
    .maybeSingle();
  if (error) throw new Error(error.message);
  return {
    success: true,
    duplicate: data === null,
    stage,
    attribution: {
      utmSource,
      utmMedium,
      utmCampaign,
      utmContent,
    },
  };
}

type XPostLogItem = {
  id: string;
  metadata: Record<string, unknown>;
  created_at: string;
};

function metricSnapshotForLog(
  item: XPostLogItem,
  metric: XTweetMetrics,
  tweetRole = "lead",
  replyIndex: number | null = null,
): Record<string, unknown> {
  const metadata = asRecord(item.metadata);
  return {
    tweet_id: metric.tweetId,
    tweet_role: tweetRole,
    reply_index: replyIndex,
    source_log_id: item.id,
    source_log_created_at: item.created_at,
    checked_at: new Date().toISOString(),
    text: firstString(metric.text, metadata.text),
    source: firstString(metadata.source, "growth-hub"),
    route: firstString(metadata.route),
    variant: firstString(metadata.variant, metadata.utm_content, "unknown"),
    experiment_key: firstString(
      metadata.experiment_key,
      "x_first_user_growth_10k",
    ),
    ...compactXMetricSnapshotMedia(metadata),
    // 動画 vs 画像の構造 lift 判定用(1:1 アスペクト実験のトリガーデータ)。
    media_type: firstString(metadata.media_type) || null,
    link_in_reply: metadata.link_in_reply === true,
    thread_reply_count: Array.isArray(metadata.reply_texts)
      ? metadata.reply_texts.length
      : 0,
    impressions: metric.impressions,
    engagements: metric.engagements,
    like_count: metric.likeCount,
    reply_count: metric.replyCount,
    repost_count: metric.repostCount,
    quote_count: metric.quoteCount,
    bookmark_count: metric.bookmarkCount,
    // 保存性/プロフィール変換シグナル(アカウント成長レバーの判定用)。
    url_clicks: metric.urlClicks,
    profile_clicks: metric.profileClicks,
    score: metric.score,
    public_metrics: metric.publicMetrics,
    non_public_metrics: metric.nonPublicMetrics,
    organic_metrics: metric.organicMetrics,
  };
}

function tweetTargetsForLog(
  item: XPostLogItem,
): { id: string; role: string; replyIndex: number | null }[] {
  const metadata = asRecord(item.metadata);
  const targets: { id: string; role: string; replyIndex: number | null }[] = [];
  const leadId = firstString(metadata.tweet_id);
  if (leadId !== "") {
    targets.push({ id: leadId, role: "lead", replyIndex: null });
  }
  const replyIds = Array.isArray(metadata.reply_tweet_ids)
    ? metadata.reply_tweet_ids
    : [];
  replyIds.forEach((rawId, index) => {
    const id = firstString(rawId);
    if (id !== "") targets.push({ id, role: "reply", replyIndex: index });
  });
  return targets;
}

async function collectXPostMetrics(
  admin: SupabaseClient,
  userId: string,
  rawLimit: unknown,
) {
  const limit = Math.max(
    1,
    Math.min(100, Math.trunc(firstNumber(rawLimit) ?? 50)),
  );
  const logs = (await listXPostLogs(admin, userId, limit)) as XPostLogItem[];
  // 鮮度窓フィルタ: 窓外の計測済み行を毎サイクル再読しない(X 指標は ~72h で
  // 定常化)。未計測行は年齢に関わらず 1 回はレスキューされる(cap 停止中の
  // 投稿を復旧後に必ず計測するため)。詳細は metrics_window.ts。
  const recentLogs = filterRecentLogs(logs, metricsWindowDays, Date.now());
  const targetsByLogId = new Map(
    recentLogs.map((item) => [item.id, tweetTargetsForLog(item)]),
  );
  const tweetIds = [
    ...new Set(
      [...targetsByLogId.values()].flat().map((target) => target.id),
    ),
  ].filter((id) => id !== "");
  if (tweetIds.length === 0) {
    return {
      success: true,
      collected: 0,
      metrics: [],
      warning: "No posted x_post_log rows with tweet_id were found " +
        `within the ${metricsWindowDays}-day metrics window.`,
    };
  }

  const metrics = await fetchXTweetMetrics(tweetIds);
  const metricById = new Map(metrics.map((metric) => [metric.tweetId, metric]));
  const checkedAt = new Date().toISOString();
  const snapshots: Record<string, unknown>[] = [];

  for (const item of recentLogs) {
    const metadata = asRecord(item.metadata);
    const targets = targetsByLogId.get(item.id) ?? [];
    const itemSnapshots = targets
      .map((target) => {
        const metric = metricById.get(target.id);
        return metric
          ? metricSnapshotForLog(item, metric, target.role, target.replyIndex)
          : null;
      })
      .filter((snapshot): snapshot is Record<string, unknown> =>
        snapshot !== null
      );
    if (itemSnapshots.length === 0) continue;
    const leadSnapshot = itemSnapshots.find((snapshot) =>
      snapshot.tweet_role === "lead"
    ) ?? itemSnapshots[0];
    const replySnapshots = itemSnapshots.filter((snapshot) =>
      snapshot.tweet_role === "reply"
    );
    snapshots.push(...itemSnapshots);
    const leadMetric = metricById.get(firstString(leadSnapshot.tweet_id));
    const nextMetadata = {
      ...metadata,
      latest_metrics: leadSnapshot,
      latest_reply_metrics: replySnapshots,
      metrics_checked_at: checkedAt,
      metric_provenance: "x_api",
      impressions: leadMetric?.impressions ?? firstNumber(
        leadSnapshot.impressions,
      ),
      engagement_score: leadMetric?.score ?? firstNumber(leadSnapshot.score),
    };
    await admin
      .from("hub_data")
      .update({ metadata: nextMetadata })
      .eq("id", item.id)
      .eq("source", "x_post_log");
    for (const snapshot of itemSnapshots) {
      await addItem(
        admin,
        "x_post_metric_snapshot",
        firstString(metadata.user_id, userId),
        snapshot,
      );
    }
  }

  return {
    success: true,
    collected: snapshots.length,
    checkedAt,
    metrics: snapshots,
  };
}

async function loadNormalizedXMetricWindows(
  admin: SupabaseClient,
  userId: string,
  logs: readonly XPostLogItem[],
  nowMs = Date.now(),
): Promise<NormalizedXPostMetrics[]> {
  const sourceLogIds = logs
    .map((log) => String(log.id))
    .filter((id) => id !== "");
  const snapshots = await listXMetricSnapshots(
    admin,
    userId,
    sourceLogIds,
  );
  return normalizeXMetricWindows(logs, snapshots, nowMs);
}

async function buildNormalizedXMetricReport(
  admin: SupabaseClient,
  userId: string,
  rawLimit: unknown,
) {
  const limit = Math.max(
    10,
    Math.min(100, Math.trunc(firstNumber(rawLimit) ?? 50)),
  );
  const logs = (await listXPostLogs(admin, userId, limit)) as XPostLogItem[];
  const rows = await loadNormalizedXMetricWindows(admin, userId, logs);
  const comparisonWindow = selectXMetricComparisonWindow(rows);
  const comparisonSampleCount = comparisonWindow
    ? rows.filter((row) => row[comparisonWindow] !== null).length
    : 0;
  return {
    success: true,
    selectionRule: `${X_METRIC_WINDOW_SELECTION_RULE}; ` +
      X_METRIC_LEARNING_SELECTION_RULE,
    snapshotSelectionRule: X_METRIC_WINDOW_SELECTION_RULE,
    learningSelectionRule: X_METRIC_LEARNING_SELECTION_RULE,
    comparisonWindow,
    comparisonLabel: comparisonWindow
      ? metricWindowLabel(comparisonWindow)
      : null,
    comparisonSampleCount,
    sampleCount: comparisonSampleCount,
    coverage: {
      logs: rows.length,
      i3h: rows.filter((row) => row.i3h !== null).length,
      i24h: rows.filter((row) => row.i24h !== null).length,
      i72h: rows.filter((row) => row.i72h !== null).length,
    },
    rows,
  };
}

function compactPostText(value: unknown): string {
  return firstString(value)
    .replace(/\s+/g, " ")
    .slice(0, 120);
}

function buildXPerformanceContextFromLogs(
  logs: XPostLogItem[],
  normalizedMetrics: readonly NormalizedXPostMetrics[] = [],
) {
  // R18: 学習(勝ち型/winner exemplar/生成プロンプトの Top hook)を「現行コピー
  // 戦略」の投稿だけで測る。旧フォーマット(誤年 2024 の「デイリーブリーフィング —
  // 日付 朝」)の高スコア旧投稿が勝ち型を占拠し廃止スタイルを再教育する実障害
  // (2026-07-09)への対策。epoch 既定 2026-07-05 = 実日付注入/コピーリセット着地日。
  // フィルタで全滅したら未フィルタへ fallback(データを絶対に隠さない)。両 knob は env。
  const windowDays = Number(Deno.env.get("X_PERF_LEARN_WINDOW_DAYS") ?? "28");
  const epochMs = Date.parse(
    Deno.env.get("X_PERF_STRATEGY_EPOCH") ?? "2026-07-05",
  );
  const strategyLogs = filterCurrentStrategyLogs(
    logs,
    {
      windowDays: Number.isFinite(windowDays) && windowDays > 0
        ? windowDays
        : 28,
      epochMs,
    },
    Date.now(),
  );
  const currentLogs = strategyLogs.length > 0 ? strategyLogs : logs;
  const historicalLogs = logs.filter((item) =>
    firstString(asRecord(item.metadata).learning_cohort) ===
      "historical_benchmark"
  );
  const effectiveLogs = [
    ...currentLogs,
    ...historicalLogs.filter((historical) =>
      !currentLogs.some((current) =>
        String(current.id) === String(historical.id)
      )
    ),
  ];
  const normalizedByLogId = new Map(
    normalizedMetrics.map((row) => [row.sourceLogId, row]),
  );
  const baseRows = effectiveLogs
    .map((item) => {
      const metadata = asRecord(item.metadata);
      const latest = asRecord(metadata.latest_metrics);
      const normalized = normalizedByLogId.get(String(item.id));
      const impressions = firstNumber(latest.impressions, metadata.impressions);
      const score = firstNumber(latest.score, metadata.engagement_score);
      if (impressions == null && score == null && normalized == null) {
        return null;
      }
      return {
        id: item.id,
        tweetId: firstString(metadata.tweet_id),
        text: compactPostText(latest.text ?? metadata.text),
        // 定型文フォールバック投稿は `${variant}_fallback` の別バケットで計測
        // する(低品質な定型データが winner exemplar / ランキングを汚染しない
        // ように)。旧行はフィールド欠落 = 非フォールバック扱いで後方互換。
        variant: (metadata.fallback_used === true ||
            String(metadata.prompt_profile ?? "") === "fallback_template_v1")
          ? `${
            firstString(
              latest.variant,
              metadata.variant,
              metadata.utm_content,
              "unknown",
            )
          }_fallback`
          : firstString(
            latest.variant,
            metadata.variant,
            metadata.utm_content,
            "unknown",
          ),
        route: firstString(latest.route, metadata.route),
        source: firstString(latest.source, metadata.source),
        hasMedia: Boolean(latest.has_media ?? metadata.media_url),
        mediaType: firstString(metadata.media_type, latest.media_type),
        // R23: 保存済みアーキタイプ優先、旧行は本文から best-effort 分類。
        archetype: resolveLoggedArchetype(
          firstString(metadata.content_archetype),
          firstString(metadata.text, latest.text),
          Array.isArray(metadata.reply_texts) ? metadata.reply_texts : [],
        ),
        // R24: 「どの既存オーディエンスに乗ったか」の軸 (x_topic_audience.ts)。
        // archetype と独立に測らないと、勝ち型の移植失敗を繰り返す。
        topic: classifyPostTopic(
          [
            firstString(metadata.text, latest.text),
            ...(Array.isArray(metadata.reply_texts)
              ? metadata.reply_texts.map((entry: unknown) => String(entry))
              : []),
          ].join("\n"),
        ),
        linkInReply: latest.link_in_reply === true ||
          metadata.link_in_reply === true,
        threadReplyCount: firstNumber(
          latest.thread_reply_count,
          Array.isArray(metadata.reply_texts) ? metadata.reply_texts.length : 0,
        ) ?? 0,
        contentKind: firstString(metadata.content_kind, "text"),
        impressions,
        engagements: firstNumber(latest.engagements) ?? 0,
        likeCount: firstNumber(latest.like_count) ?? 0,
        replyCount: firstNumber(latest.reply_count) ?? 0,
        repostCount: firstNumber(latest.repost_count) ?? 0,
        bookmarkCount: firstNumber(latest.bookmark_count) ?? 0,
        urlClicks: firstNumber(latest.url_clicks) ?? 0,
        profileClicks: firstNumber(latest.profile_clicks) ?? 0,
        score: score ?? impressions ?? normalized?.i24h ?? normalized?.i72h ??
          normalized?.i3h ?? 0,
        postedAt: firstString(metadata.posted_at, item.created_at),
        createdAt: firstString(item.created_at),
        observedAt: firstString(metadata.observed_at),
        learningCohort: firstString(metadata.learning_cohort),
        historicalBenchmarkImpressions: firstNumber(
          metadata.historical_benchmark_impressions,
        ),
        i3h: normalized?.i3h ?? null,
        i24h: normalized?.i24h ?? null,
        i72h: normalized?.i72h ?? null,
        normalizedWindows: normalized?.windows ?? null,
      };
    })
    .filter((row): row is NonNullable<typeof row> => row !== null);

  // Rank every post against one shared age window. This prevents a mature
  // post's cumulative 72-hour count from competing with a fresh post's 3-hour
  // count. I24h is preferred, with I72h/I3h fallbacks when at least three rows
  // share that window; sparse cohorts retain the legacy cumulative behavior.
  const comparisonWindow = selectXMetricComparisonWindow(
    baseRows
      .map((row) => normalizedByLogId.get(String(row.id)))
      .filter((row): row is NormalizedXPostMetrics => row !== undefined),
  );
  const comparisonLabel = comparisonWindow
    ? metricWindowLabel(comparisonWindow)
    : "latest cumulative";
  const rows = baseRows
    .map((row) => {
      const sample = comparisonWindow
        ? row.normalizedWindows?.[comparisonWindow] ?? null
        : null;
      const normalizedValue = comparisonWindow ? row[comparisonWindow] : null;
      const rankingEligible = comparisonWindow === null ||
        normalizedValue !== null;
      return {
        ...row,
        rankingEligible,
        rankingMetric: comparisonWindow
          ? (rankingEligible ? comparisonLabel : "unranked")
          : "latest_cumulative",
        rankingImpressions: comparisonWindow
          ? normalizedValue
          : row.impressions ?? row.score,
        rankingEngagementRate: sample?.engagementRate ?? null,
        rankingBookmarkRate: sample?.bookmarkRate ?? null,
        rankingProfileClickRate: sample?.profileClickRate ?? null,
        rankingUrlClickRate: sample?.urlClickRate ?? null,
        // R24: 学習ランキングの基準値。到達ではなく獲得(URL クリック最上位・
        // impressions は上限キャップ付き補助項)で並べる (x_acquisition_score.ts)。
        // R24 fix: 全項を同じ期間基準で渡す (all-or-nothing)。従来は
        // impressions だけ窓の値・残り 6 項が lifetime 累積で、重み 1000 の
        // urlClicks に年齢バイアスが丸ごと残っていた (上限 100 点の
        // impressions 項では埋め合わせ不可能)。
        acquisitionScore: computeAcquisitionScore(
          resolveAcquisitionScoreInput(sample, {
            urlClicks: row.urlClicks,
            profileClicks: row.profileClicks,
            bookmarkCount: row.bookmarkCount,
            replyCount: row.replyCount,
            repostCount: row.repostCount,
            likeCount: row.likeCount,
            impressions: row.impressions,
          }).input,
        ),
        acquisitionBasis: resolveAcquisitionScoreInput(sample, {
          impressions: row.impressions,
        }).basis,
      };
    })
    .sort((left, right) =>
      Number(right.rankingEligible) - Number(left.rankingEligible) ||
      (right.rankingImpressions ?? -1) -
        (left.rankingImpressions ?? -1) ||
      right.score - left.score
    );

  const postAgeComparableRows = rows.filter((row) =>
    row.learningCohort !== "historical_benchmark"
  );
  const learningRows = comparisonWindow
    ? postAgeComparableRows.filter((row) => row.rankingEligible)
    : postAgeComparableRows;
  const historicalBenchmarks = rows
    .filter((row) => row.historicalBenchmarkImpressions !== null)
    .sort((left, right) =>
      (right.historicalBenchmarkImpressions ?? 0) -
      (left.historicalBenchmarkImpressions ?? 0)
    );

  // R24: 勝ち/負け exemplar は獲得スコア順で選ぶ。到達順のままだと
  // 「122,978 imp / 0 クリック」の投稿が「500 imp / 3 クリック」を永久に
  // 上回り、サイトへ 1 人も送っていない投稿を LLM に手本提示してしまう。
  // 年齢コホート (learningRows) の絞り込みは従来どおり効かせる。
  const acquisitionRanked = [...learningRows].sort((left, right) =>
    right.acquisitionScore - left.acquisitionScore ||
    (right.rankingImpressions ?? -1) - (left.rankingImpressions ?? -1)
  );
  // R28: 勝ち exemplar と勝ち型は ICP トピックのコホート内で選ぶ。実測では
  // URL クリックの 94% が japan_politics の定点観測シリーズから出ており、
  // 素朴に最大値を取ると学習ループが「政治の集計レポートを再生産せよ」と
  // 指示する。2026-07-28 の戦略確定で楔は「借金・リボ払いからの生活再建」に
  // 絞られており、その受け手は楔の客ではない。
  // コホートが薄いときはグローバルへ落ちず、勝者を宣言しない (落とすと
  // 政治シリーズが復活し、このスコープの意味が消える)。
  const icpCohort = selectIcpCohort(
    acquisitionRanked,
    (row) => row.topic,
  );
  // R28 fix: CSV 取込の行は historical_benchmark として learningRows から
  // 除外されるため、ICP の実績があっても icpCohort には 1 件も入らない。
  // 返済報告カードの共有はクリップボードのみで x_post_log に残らないので、
  // ICP の実績は事実上「取り込んだ履歴」にしか存在しない。件数を数えて
  // 「1本も無い」と「あるが年齢比較できない」を区別して報告する。
  const icpHistoricalRows = rows.filter((row) =>
    row.learningCohort === "historical_benchmark" &&
    normalizeTopicBucket(row.topic) === icpCohort.target
  );
  const icpScopeLine = buildIcpScopeLine(icpCohort, icpHistoricalRows.length);
  // R29: 順位付けと手本提示を分ける。取り込んだ ICP 履歴は lifetime cumulative
  // なので winners には載せない (期間基準の混在は #4367 で禁止) が、
  // 「どのフックがこの受け手にクリックされたか」は手本として渡す。
  // 返済報告カードの共有は HITL 厳守でクリップボード専用のため、ICP の実績は
  // 事実上ここにしか存在しない。
  const icpExemplarLine = buildIcpHistoricalExemplarLine(
    icpHistoricalRows,
    (row) => row.urlClicks,
    (row) => row.impressions,
    (row) => row.text,
    icpCohort.target,
  );
  const winners = icpCohort.sufficient ? icpCohort.rows.slice(0, 5) : [];
  const underperformers = icpCohort.sufficient
    ? icpCohort.rows.slice(-5).reverse()
    : [];
  const byVariant = new Map<
    string,
    { variant: string; count: number; totalScore: number; maxScore: number }
  >();
  // R28: 勝ち型 (variant) も ICP コホート内で数える。グローバルで数えると
  // 政治シリーズの variant が「勝ち型」として昇格してしまう。
  for (const row of (icpCohort.sufficient ? icpCohort.rows : [])) {
    const key = row.variant || "unknown";
    const current = byVariant.get(key) ?? {
      variant: key,
      count: 0,
      totalScore: 0,
      maxScore: 0,
    };
    current.count += 1;
    // R24: 型ごとの優劣も獲得スコアで測る (到達平均ではない)。
    const rankingScore = row.acquisitionScore;
    current.totalScore += rankingScore;
    current.maxScore = Math.max(current.maxScore, rankingScore);
    byVariant.set(key, current);
  }
  const variants = [...byVariant.values()]
    .map((entry) => ({
      ...entry,
      averageScore: Math.round(entry.totalScore / Math.max(1, entry.count)),
    }))
    .sort((left, right) => right.averageScore - left.averageScore);

  // 勝ち型は unknown 除外 + `_fallback` を base へ畳む + 最小サンプル(n>=2)で
  // 選ぶ (x_best_variant.ts)。畳まないと 1 サンプルの `daily_briefing_fallback`
  // (平均89 n=1) が 7 サンプルの `daily_briefing` (平均76 n=7) を抑えて勝ち型に
  // 昇格していた。bestVariant は保存/後方互換用、confidentBest は「実測で勝ちと
  // 言える型」(無ければ null=断定しない)。
  const bestVariant = pickBestVariant(variants);
  const confidentBest = pickConfidentVariant(variants);
  // 集計ロールアップ (guarded): 両バケットに十分なサンプルがあるときだけ、
  // 変動要因(メディア有無/リンク位置/スレッド長)ごとの平均スコア差を測定事実と
  // して LLM へ渡す。データが薄い間は行自体を出さない(=実質 default-off で、
  // 投稿が貯まるほど自動的に有効化される)。従来は top-1 variant と逸話的な
  // winner 行のみで、集計済みの variants ランキングが未提示だった。
  // R24: 構造 lift の平均も獲得スコア基準へ統一する。到達平均のままだと
  // 「メディアありは到達が高い」等の結論が、クリック 0 でも勝ちに見える。
  const avgScore = (list: typeof rows): number =>
    list.length === 0 ? 0 : Math.round(
      list.reduce((sum, row) => sum + row.acquisitionScore, 0) / list.length,
    );
  const structuralLines: string[] = [];
  if (comparisonWindow) {
    structuralLines.push(
      `Normalized comparison cohort: ${comparisonLabel} ` +
        `(n=${learningRows.length}); ${X_METRIC_WINDOW_SELECTION_RULE}; ` +
        `${X_METRIC_LEARNING_SELECTION_RULE}.`,
    );
  }
  const withMedia = learningRows.filter((r) => r.hasMedia);
  const withoutMedia = learningRows.filter((r) => !r.hasMedia);
  if (withMedia.length >= 2 && withoutMedia.length >= 2) {
    structuralLines.push(
      `Structural lift (media): avg acquisition score with media=${
        avgScore(withMedia)
      } (n=${withMedia.length}) vs without=${
        avgScore(withoutMedia)
      } (n=${withoutMedia.length}).`,
    );
  }
  // media_type 別 lift(R13: video/image/text を第1級 A/B 次元に昇格 / #3764)。
  // 純ロジックは x_media_type.ts に抽出。n>=2 のバケットだけ表示・比較可能が 2 つ
  // 以上で勝ちメディア recommendation を付す・判定不能な既存行は unknown で保持。
  // media_type が貯まるまでは null(=データ希薄時は自動的に沈黙 / 実質 default-off)。
  const mediaLine = buildMediaLiftLine(
    learningRows,
    (row) => row.mediaType,
    (row) => row.acquisitionScore,
  );
  if (mediaLine) structuralLines.push(mediaLine);
  // R23: 内容アーキタイプ別 lift。実測(2026-07-12 同日3連投: データレポート型
  // 3.2K vs ニュース要約 517 vs ニュース→製品転換 28)を恒常的な A/B 次元へ
  // 昇格。n>=2 のバケットのみ表示(データ希薄時は沈黙 / 実質 default-off)。
  // Archetype lift is a strict I72 cohort. Historical/lifetime observations
  // remain useful benchmarks but must not masquerade as a 72-hour sample.
  const matureArchetypeRows = rows.filter((row) =>
    row.learningCohort !== "historical_benchmark" && row.i72h !== null
  );
  const archetypeLine = buildArchetypeLiftLine(
    matureArchetypeRows,
    (row) => row.archetype,
    (row) => row.i72h ?? Number.NaN,
  );
  if (archetypeLine) structuralLines.push(archetypeLine);
  // R24: topic 単独の lift と、archetype × topic の交互作用。
  // 実測では同一の data_report 型が topic 違いで 122,978 → 58 まで落ちており、
  // archetype 単独の結論だけを渡すと勝ち型の移植失敗を再生産する。
  const topicLine = buildTopicLiftLine(
    learningRows,
    (row) => row.topic,
    (row) => row.acquisitionScore,
  );
  if (topicLine) structuralLines.push(topicLine);
  const interactionLine = buildArchetypeTopicInteractionLine(
    learningRows,
    (row) => row.archetype,
    (row) => row.topic,
    (row) => row.acquisitionScore,
  );
  if (interactionLine) structuralLines.push(interactionLine);
  const linkReply = learningRows.filter((r) => r.linkInReply);
  const linkLead = learningRows.filter((r) => !r.linkInReply);
  if (linkReply.length >= 2 && linkLead.length >= 2) {
    structuralLines.push(
      `Structural lift (link placement): avg acquisition score link-in-reply=${
        avgScore(linkReply)
      } (n=${linkReply.length}) vs link-in-lead=${
        avgScore(linkLead)
      } (n=${linkLead.length}).`,
    );
  }
  if (learningRows.length >= 3) {
    const buckets = [
      [
        "0 replies",
        learningRows.filter((r) => r.threadReplyCount === 0),
      ],
      [
        "1-4 replies",
        learningRows.filter((r) =>
          r.threadReplyCount >= 1 && r.threadReplyCount <= 4
        ),
      ],
      [
        "5-8 replies",
        learningRows.filter((r) => r.threadReplyCount >= 5),
      ],
    ].filter(([, list]) => (list as typeof rows).length > 0) as Array<
      [string, typeof rows]
    >;
    if (buckets.length >= 2) {
      buckets.sort((a, b) => avgScore(b[1]) - avgScore(a[1]));
      const [label, list] = buckets[0];
      structuralLines.push(
        `Best thread length so far: ${label} (avg acquisition score ${
          avgScore(list)
        }, n=${list.length}).`,
      );
    }
  }
  // 保存性/プロフィール変換のリーダーを露出(アカウント成長レバーの判定材料)。
  // どちらも >=2 サンプルかつ非ゼロ合計のときだけ出す(データ希薄時は沈黙)。
  const bookmarkRows = learningRows.filter((r) => r.bookmarkCount > 0);
  if (bookmarkRows.length >= 2) {
    const top = [...bookmarkRows]
      .sort((a, b) => b.bookmarkCount - a.bookmarkCount)
      .slice(0, 2);
    structuralLines.push(
      `Save-worthiness leaders (by bookmarks): ${
        top.map((r) => `${r.bookmarkCount} bookmarks — "${r.text}"`).join(" | ")
      }. Emulate what made these save-worthy (checklist/まとめ structure).`,
    );
  }
  const normalizedSaveRows = learningRows.filter((row) =>
    row.rankingBookmarkRate !== null
  );
  if (normalizedSaveRows.length >= 2) {
    const top = [...normalizedSaveRows]
      .sort((left, right) =>
        (right.rankingBookmarkRate ?? 0) -
        (left.rankingBookmarkRate ?? 0)
      )
      .slice(0, 2);
    structuralLines.push(
      `Normalized save-rate leaders (${comparisonLabel}): ${
        top.map((row) =>
          `${((row.rankingBookmarkRate ?? 0) * 100).toFixed(3)}% ` +
          `(${row.bookmarkCount} latest bookmarks) - "${row.text}"`
        ).join(" | ")
      }.`,
    );
  }
  const profileRows = learningRows.filter((r) => r.profileClicks > 0);
  if (profileRows.length >= 2) {
    const top = [...profileRows]
      .sort((a, b) => b.profileClicks - a.profileClicks)
      .slice(0, 2);
    structuralLines.push(
      `Best profile-conversion posts (by profile clicks): ${
        top.map((r) => `${r.profileClicks} clicks — "${r.text}"`).join(" | ")
      }. These drove the most profile visits — reuse their hook/format.`,
    );
  }
  const distinctVariants = variants.filter((v) => v.variant !== "unknown");
  const rankingLine = distinctVariants.length >= 2
    ? `Variant ranking (avg acquisition score, n): ${
      distinctVariants.slice(0, 5).map((v) =>
        `${v.variant}=${v.averageScore} (n=${v.count})`
      ).join(", ")
    }.`
    : "";
  // R23: データレポート型投稿の「捏造せず公開できる実数」をアカウント自身の
  // 実測インプレから供給する(実測 3 件未満は沈黙)。
  const ownDataLine = buildOwnDataFactsLine(
    learningRows,
    (row) => row.rankingImpressions,
  );
  // R24: 獲得ランキングと、到達 1 位 ≠ 獲得 1 位のときの乖離警告。
  // 実測 (90 日 350 投稿) では URL クリックの 94% が単一シリーズに集中し、
  // 到達上位の共感型 (57K/いいね 2.5K) のクリックは 0 だった。
  const acquisitionLine = buildAcquisitionRankingLine(
    learningRows,
    (row) => row.acquisitionScore,
    (row) => row.rankingImpressions ?? row.impressions,
    (row) => row.text,
    (row) => row.urlClicks,
  );
  const historicalBenchmarkLine = historicalBenchmarks.length === 0
    ? ""
    : `Historical lifetime benchmark (not post-age comparable; excluded from winner ranking): ${
      historicalBenchmarks.slice(0, 3).map((row) =>
        `variant=${row.variant}, archetype=${row.archetype}, ` +
        `impressions=${row.historicalBenchmarkImpressions}, ` +
        `observedAt=${row.observedAt || "unknown"}`
      ).join(" | ")
    }.`;
  const promptContext = rows.length === 0
    ? [
      "No measured X performance has been collected yet.",
      "Run A/B test: daily_briefing vs question_post vs useful_reply.",
      "Target: 10K impressions. Lead with information value, put product CTA later, and collect metrics after posting.",
    ].join("\n")
    : [
      "Measured X performance context for the next post:",
      // n>=2 で畳み込んだ勝ち型が無いとき、1 サンプルの外れ値や fallback 名を
      // 実測済みの勝ち型かのように LLM へ主張しない。
      confidentBest
        ? `Target: 10K impressions. Current best variant: ${confidentBest.variant} (n=${confidentBest.count}).`
        : "Target: 10K impressions. No post-age comparable winner yet.",
      // R24: 目的は「サイトへ 1 人送ること」。手本の選定基準は到達ではなく獲得。
      `Ranking basis: acquisition score (url clicks weighted first, ` +
      `impressions capped; every term read from the same period basis — ` +
      `${
        learningRows.filter((r) => r.acquisitionBasis === "window").length
      }/${learningRows.length} rows scored on the age window, the rest on ` +
      `lifetime cumulative); age cohort = ${comparisonLabel} ` +
      `(comparable n=${learningRows.length}; total measured n=${rows.length}). ` +
      `Optimize for site visits and replies, not for raw reach.`,
      ...(acquisitionLine ? [acquisitionLine] : []),
      icpScopeLine,
      ...(icpExemplarLine ? [icpExemplarLine] : []),
      ...winners.map((row, index) =>
        `Winner ${
          index + 1
        }: acquisition=${row.acquisitionScore}, variant=${row.variant}, impressions=${
          row.impressions ?? "unknown"
        }, comparison=${row.rankingMetric}:${
          row.rankingImpressions ?? "unknown"
        }, score=${row.score}, bookmarks=${row.bookmarkCount}, saveRate=${
          row.rankingBookmarkRate === null
            ? "unknown"
            : `${(row.rankingBookmarkRate * 100).toFixed(3)}%`
        }, engagementRate=${
          row.rankingEngagementRate === null
            ? "unknown"
            : `${(row.rankingEngagementRate * 100).toFixed(3)}%`
        }, profileClicks=${row.profileClicks}, profileClickRate=${
          row.rankingProfileClickRate === null
            ? "unknown"
            : `${(row.rankingProfileClickRate * 100).toFixed(3)}%`
        }, urlClicks=${row.urlClicks}, urlClickRate=${
          row.rankingUrlClickRate === null
            ? "unknown"
            : `${(row.rankingUrlClickRate * 100).toFixed(3)}%`
        }, media=${row.hasMedia}, linkInReply=${row.linkInReply}, replies=${row.threadReplyCount}, hook="${row.text}"`
      ),
      ...underperformers.slice(0, 3).map((row, index) =>
        `Avoid ${
          index + 1
        }: acquisition=${row.acquisitionScore}, variant=${row.variant}, comparison=${row.rankingMetric}:${
          row.rankingImpressions ?? "unknown"
        }, score=${row.score}, media=${row.hasMedia}, linkInReply=${row.linkInReply}, replies=${row.threadReplyCount}, hook="${row.text}"`
      ),
      ...(rankingLine ? [rankingLine] : []),
      ...(historicalBenchmarkLine ? [historicalBenchmarkLine] : []),
      ...structuralLines,
      ...(ownDataLine ? [ownDataLine] : []),
      ...(winners[0]
        ? [
          `Top hook to emulate (copy the structure, not the words): "${
            winners[0].text
          }"`,
        ]
        : []),
      winners.length > 0
        ? "Use the winning structure, test one variable at a time, and keep the first post useful before adding the product CTA."
        : "Keep collecting post-age comparable metrics; do not declare a winning structure yet.",
    ].join("\n");

  return {
    success: true,
    rows,
    winners,
    underperformers,
    variants,
    bestVariant,
    comparisonWindow,
    comparisonLabel,
    comparisonSampleCount: learningRows.length,
    historicalBenchmarks,
    metricWindowSelectionRule: X_METRIC_WINDOW_SELECTION_RULE,
    metricLearningSelectionRule: X_METRIC_LEARNING_SELECTION_RULE,
    selectionRule: comparisonWindow
      ? X_METRIC_LEARNING_SELECTION_RULE
      : "latest cumulative fallback because no normalized cohort has 3 posts",
    promptContext,
  };
}

/// R24: X Analytics CSV をパースして x_post_log へ upsert する。
/// 既に公式 X API で計測済みの行 (metric_provenance='x_api') は上書きしない
/// — CSV は lifetime cumulative の観測値で、API の窓付き実測より弱いため。
async function importXAnalyticsCsv(
  admin: SupabaseClient,
  userId: string,
  options: { csv: string; exportRange: string; dryRun: boolean },
) {
  const rows = parseXAnalyticsCsv(options.csv);
  if (rows.length === 0) {
    return {
      success: false,
      imported: 0,
      skipped: 0,
      error: "No rows parsed. Expected the X Analytics content CSV export.",
    };
  }
  const observedAt = new Date().toISOString();
  const accountAcquisitionLine = buildAccountAcquisitionLine(rows);
  if (options.dryRun) {
    return {
      success: true,
      dryRun: true,
      parsed: rows.length,
      imported: 0,
      skipped: 0,
      accountAcquisitionLine,
    };
  }

  const tweetIds = rows.map((row) => row.postId);
  const { data: existingRows, error: existingError } = await admin
    .from("hub_data")
    .select("id, metadata")
    .eq("source", "x_post_log")
    .filter("metadata->>tweet_id", "in", `(${tweetIds.join(",")})`);
  if (existingError) {
    throw new Error(`x_analytics_import lookup: ${existingError.message}`);
  }
  const existingByTweetId = new Map(
    (existingRows ?? []).map((
      item: { id: string; metadata: unknown },
    ) => [firstString(asRecord(item.metadata).tweet_id), item]),
  );

  let imported = 0;
  let skipped = 0;
  for (const row of rows) {
    const metadata = buildAnalyticsImportMetadata(row, {
      userId,
      archetype: classifyPostArchetype(row.text),
      observedAt,
      exportRange: options.exportRange,
    });
    const existing = existingByTweetId.get(row.postId);
    if (existing === undefined) {
      const { error } = await admin
        .from("hub_data")
        .insert({ source: "x_post_log", metadata });
      if (error) throw new Error(`x_analytics_import insert: ${error.message}`);
      imported += 1;
      continue;
    }
    const existingMetadata = asRecord(existing.metadata);
    // 公式 API 実測が既にある行は、CSV の累積値で塗り潰さない。
    if (firstString(existingMetadata.metric_provenance) === "x_api") {
      skipped += 1;
      continue;
    }
    const { error } = await admin
      .from("hub_data")
      .update({ metadata: { ...existingMetadata, ...metadata } })
      .eq("id", existing.id)
      .eq("source", "x_post_log");
    if (error) throw new Error(`x_analytics_import update: ${error.message}`);
    imported += 1;
  }
  return {
    success: true,
    parsed: rows.length,
    imported,
    skipped,
    observedAt,
    accountAcquisitionLine,
  };
}

async function buildXPerformanceContext(
  admin: SupabaseClient,
  userId: string,
  rawLimit: unknown,
) {
  const limit = Math.max(
    10,
    Math.min(100, Math.trunc(firstNumber(rawLimit) ?? 50)),
  );
  const [recentLogs, benchmarkLogs] = await Promise.all([
    listXPostLogs(admin, userId, limit),
    listXHistoricalBenchmarkLogs(admin, userId),
  ]);
  const logs = [
    ...recentLogs,
    ...benchmarkLogs.filter((benchmark) =>
      !recentLogs.some((recent) => String(recent.id) === String(benchmark.id))
    ),
  ] as XPostLogItem[];
  const normalized = await loadNormalizedXMetricWindows(admin, userId, logs);
  return buildXPerformanceContextFromLogs(logs, normalized);
}

async function buildXGrowthDataReportContext(
  admin: SupabaseClient,
  userId: string,
  rawLimit: unknown,
) {
  const limit = Math.max(
    10,
    Math.min(100, Math.trunc(firstNumber(rawLimit) ?? 50)),
  );
  // The weekly report excludes historical benchmark rows before composing its
  // copy. Loading them through the generic performance context made the cron
  // scan old x_post_log rows for data it immediately discarded.
  const recentLogs = (await listXPostLogs(
    admin,
    userId,
    limit,
  )) as XPostLogItem[];
  const normalized = await loadNormalizedXMetricWindows(
    admin,
    userId,
    recentLogs,
  );
  return buildXPerformanceContextFromLogs(recentLogs, normalized);
}

async function buildScheduledHouseholdTrackerReport(
  admin: SupabaseClient,
  actorUserId: string,
  rawMaxAgeDays: unknown,
) {
  if (!await isXOperator(admin, actorUserId)) {
    return { available: false, reason: "forbidden", status: 403 };
  }
  const maxAgeRaw = firstNumber(rawMaxAgeDays) ?? 8;
  const maxAgeDays = Math.max(1, Math.min(14, Math.trunc(maxAgeRaw)));

  let targetUserIds: string[];
  if (actorUserId === "service_role") {
    const { data: profiles, error: profileError } = await admin
      .from("user_profiles")
      .select("user_id")
      .eq("is_admin", true)
      .limit(20);
    if (profileError) throw new Error(profileError.message);
    targetUserIds = (profiles ?? [])
      .map((row) => firstString(row.user_id))
      .filter((id) => id !== "");
  } else {
    targetUserIds = [actorUserId];
  }
  if (targetUserIds.length === 0) {
    return { available: false, reason: "no_admin_profile" };
  }

  const { data: rows, error } = await admin
    .from("asset_pref_mirror")
    .select("user_id,pref_key,value,updated_at")
    .in("pref_key", [
      HOUSEHOLD_TRACKER_MIRROR_KEY,
      HOUSEHOLD_TRACKER_CONSENT_MIRROR_KEY,
    ])
    .in("user_id", targetUserIds);
  if (error) throw new Error(error.message);
  const enabledUserIds = targetUserIds.filter((targetUserId) => {
    const consent = (rows ?? []).find((row) =>
      firstString(row.user_id) === targetUserId &&
      firstString(row.pref_key) === HOUSEHOLD_TRACKER_CONSENT_MIRROR_KEY
    );
    return consent !== undefined &&
      parseHouseholdTrackerConsent(consent.value) === true;
  });
  if (enabledUserIds.length === 0) {
    return { available: false, reason: "no_enabled_snapshot" };
  }
  if (enabledUserIds.length > 1) {
    return {
      available: false,
      reason: "ambiguous_enabled_snapshots",
      enabledCount: enabledUserIds.length,
    };
  }

  const row = (rows ?? []).find((candidate) =>
    firstString(candidate.user_id) === enabledUserIds[0] &&
    firstString(candidate.pref_key) === HOUSEHOLD_TRACKER_MIRROR_KEY
  );
  if (!row) {
    return { available: false, reason: "enabled_snapshot_missing" };
  }
  const report = buildHouseholdTrackerReport(row.value, new Date(), maxAgeDays);
  return {
    ...report,
    ownerUserId: firstString(row.user_id),
    snapshotUpdatedAt: firstString(row.updated_at),
  };
}

async function hasEnabledHouseholdTrackerConsent(
  admin: SupabaseClient,
  ownerUserId: string,
): Promise<boolean> {
  if (!isUuid(ownerUserId)) return false;
  const { data, error } = await admin
    .from("asset_pref_mirror")
    .select("value")
    .eq("user_id", ownerUserId)
    .eq("pref_key", HOUSEHOLD_TRACKER_CONSENT_MIRROR_KEY)
    .maybeSingle();
  if (error) throw new Error(error.message);
  return data !== null && parseHouseholdTrackerConsent(data.value) === true;
}

async function buildRevenueFunnelReport(
  admin: SupabaseClient,
  userId: string,
  rawLimit: unknown,
) {
  const limit = Math.max(
    10,
    Math.min(100, Math.trunc(firstNumber(rawLimit) ?? 50)),
  );
  const xLogs = (await listXPostLogs(admin, userId, limit)) as XPostLogItem[];
  const normalized = await loadNormalizedXMetricWindows(admin, userId, xLogs);
  const performance = buildXPerformanceContextFromLogs(xLogs, normalized);
  const { data: payments, error } = await admin
    .from("hub_data")
    .select("id, metadata, created_at")
    .eq("source", "stripe_supporter_payment")
    .order("created_at", { ascending: false })
    .limit(limit);
  if (error) throw new Error(error.message);

  const allPaidPayments = (payments ?? [])
    .map((item) => {
      const metadata = asRecord(item.metadata);
      const buyerContext = normalizeSupporterBuyerContext(
        metadata.auth_user_id,
        metadata.buyer_classification,
      );
      return {
        createdAt: String(item.created_at),
        amountJpy: firstNumber(metadata.amount_jpy, metadata.amount_total) ?? 0,
        paymentStatus: firstString(metadata.payment_status),
        buyerClassification: buyerContext.classification,
        externalRevenueCandidate: isExternalRevenueCandidate(buyerContext),
        variant: firstString(metadata.variant, "unknown"),
        experimentKey: firstString(metadata.experiment_key),
        sourceLogId: firstString(metadata.source_log_id),
        utmSource: firstString(metadata.utm_source),
        utmMedium: firstString(metadata.utm_medium),
        utmCampaign: firstString(metadata.utm_campaign),
        utmContent: firstString(metadata.utm_content),
      };
    })
    .filter((row) => row.paymentStatus === "paid");
  const externalPaidPayments = allPaidPayments.filter((row) =>
    row.externalRevenueCandidate &&
    row.utmSource === "x" &&
    row.utmCampaign === "first_user_growth"
  );

  const xRows = performance.rows as Array<{
    id: string;
    variant: string;
    learningCohort: string;
    impressions?: number | null;
    rankingEligible: boolean;
    rankingImpressions: number | null;
    score: number;
  }>;
  const comparableXRows = xRows.filter((row) =>
    row.learningCohort !== "historical_benchmark"
  );
  const learningXRows = performance.comparisonWindow
    ? comparableXRows.filter((row) => row.rankingEligible)
    : comparableXRows;
  const byVariant = new Map<
    string,
    {
      variant: string;
      posts: number;
      impressions: number;
      score: number;
      paidSupporters: number;
      revenueJpy: number;
    }
  >();
  for (const row of learningXRows) {
    const key = row.variant || "unknown";
    const current = byVariant.get(key) ?? {
      variant: key,
      posts: 0,
      impressions: 0,
      score: 0,
      paidSupporters: 0,
      revenueJpy: 0,
    };
    current.posts += 1;
    current.impressions += firstNumber(row.rankingImpressions) ?? 0;
    current.score += firstNumber(row.rankingImpressions) ?? row.score;
    byVariant.set(key, current);
  }
  for (const payment of externalPaidPayments) {
    const key = payment.variant || "unknown";
    const current = byVariant.get(key) ?? {
      variant: key,
      posts: 0,
      impressions: 0,
      score: 0,
      paidSupporters: 0,
      revenueJpy: 0,
    };
    current.paidSupporters += 1;
    current.revenueJpy += payment.amountJpy;
    byVariant.set(key, current);
  }
  const variants = [...byVariant.values()].sort((left, right) =>
    right.revenueJpy - left.revenueJpy ||
    right.paidSupporters - left.paidSupporters ||
    right.impressions - left.impressions ||
    right.score - left.score
  );

  return {
    success: true,
    target: {
      firstRevenueJpy: 1,
      xImpressionsPerPost: 10000,
    },
    summary: {
      xPostLogs: xLogs.length,
      measuredXPosts: learningXRows.length,
      comparisonWindow: performance.comparisonWindow,
      comparisonLabel: performance.comparisonLabel,
      comparisonSampleCount: performance.comparisonSampleCount,
      allPaidSupporters: allPaidPayments.length,
      excludedAdminSupporters:
        allPaidPayments.filter((payment) =>
          payment.buyerClassification === "admin_self"
        ).length,
      excludedUnclassifiedSupporters:
        allPaidPayments.filter((payment) =>
          payment.buyerClassification === "anonymous_unclassified"
        ).length,
      latestPaidSupporters: externalPaidPayments.length,
      revenueJpy: externalPaidPayments.reduce(
        (sum, payment) => sum + payment.amountJpy,
        0,
      ),
      bestVariantForRevenue: variants[0]?.variant ?? null,
      bestVariantForReach: performance.bestVariant,
    },
    variants,
    payments: externalPaidPayments,
    xPerformance: {
      winners: performance.winners,
      underperformers: performance.underperformers,
      promptContext: performance.promptContext,
    },
    nextActions: externalPaidPayments.length === 0
      ? [
        "Post the next high-information X variant with link-in-reply enabled.",
        "Acquire one signed-in non-admin supporter through the measured first_user_growth URL.",
        "After payment, rerun revenue.funnel_report and first_supporter_webhook_evidence.sql.",
      ]
      : [
        "Double down on the revenue-winning variant for the next 3 posts.",
        "Verify Stripe payout eligibility and bank payout evidence.",
      ],
  };
}

async function buildFirstUserAcquisitionReport(
  admin: SupabaseClient,
  userId: string,
  rawUtmSource: unknown,
  rawUtmMedium: unknown,
  rawUtmContent: unknown,
  rawCampaignStartedAt: unknown,
  rawLimit: unknown,
) {
  const utmSource = firstString(rawUtmSource, "x").toLowerCase();
  const utmMedium = firstString(rawUtmMedium, "organic").toLowerCase();
  const utmContent = firstString(rawUtmContent, "outcome_first_a")
    .toLowerCase();
  if (
    !firstUserAcquisitionSourceSet.has(utmSource) ||
    !firstUserTokenPattern.test(utmMedium) ||
    !firstUserTokenPattern.test(utmContent)
  ) {
    throw new Error("invalid first-user UTM");
  }
  const campaignStartedAtInput = firstString(rawCampaignStartedAt);
  if (
    campaignStartedAtInput !== "" &&
    !Number.isFinite(Date.parse(campaignStartedAtInput))
  ) {
    throw new Error("invalid first-user campaign start");
  }
  const limit = Math.max(
    10,
    Math.min(100, Math.trunc(firstNumber(rawLimit) ?? 50)),
  );
  const logs = utmSource === "x"
    ? (await listXPostLogs(admin, userId, limit)) as XPostLogItem[]
    : [];
  const matchingLogs = logs.filter((item) => {
    const metadata = asRecord(item.metadata);
    const variants = [
      metadata.utm_content,
      metadata.utmContent,
      metadata.variant,
      metadata.selected_variant,
    ].map((value) => firstString(value).toLowerCase());
    return firstString(metadata.tweet_id) !== "" &&
      variants.includes(utmContent);
  });
  const latestLog = matchingLogs[0] ?? null;
  let post: FirstUserXPost | null = null;
  if (latestLog) {
    const normalized = await loadNormalizedXMetricWindows(
      admin,
      userId,
      [latestLog],
    );
    const metadata = asRecord(latestLog.metadata);
    const latestMetrics = asRecord(metadata.latest_metrics);
    post = {
      sourceLogId: latestLog.id,
      tweetId: firstString(metadata.tweet_id),
      postedAt: firstString(metadata.posted_at, latestLog.created_at),
      latestImpressions: firstNumber(
        latestMetrics.impressions,
        metadata.impressions,
      ),
      latestUrlClicks: firstNumber(latestMetrics.url_clicks),
      normalized: normalized[0] ?? null,
    };
  }
  const campaignStartedAt = post?.postedAt || campaignStartedAtInput || null;

  let eventQuery = admin
    .from("first_user_acquisition_events")
    .select("visitor_id,stage,first_occurred_at")
    .eq("utm_source", utmSource)
    .eq("utm_medium", utmMedium)
    .eq("utm_campaign", "first_user_growth")
    .eq("utm_content", utmContent)
    .order("first_occurred_at", { ascending: true });
  if (campaignStartedAt) {
    eventQuery = eventQuery.gte("first_occurred_at", campaignStartedAt);
  }
  const { data: eventData, error: eventError } = await eventQuery;
  if (eventError) throw new Error(eventError.message);

  let paymentQuery = admin
    .from("hub_data")
    .select("metadata,created_at")
    .eq("source", "stripe_supporter_payment")
    .filter("metadata->>payment_status", "eq", "paid")
    .filter("metadata->>utm_source", "eq", utmSource)
    .filter("metadata->>utm_medium", "eq", utmMedium)
    .filter("metadata->>utm_campaign", "eq", "first_user_growth")
    .filter("metadata->>utm_content", "eq", utmContent)
    .filter(
      "metadata->>buyer_classification",
      "eq",
      "authenticated_non_admin",
    )
    .filter("metadata->>external_revenue_candidate", "eq", "true")
    .order("created_at", { ascending: true });
  if (campaignStartedAt) {
    paymentQuery = paymentQuery.gte("created_at", campaignStartedAt);
  }
  const { data: paymentData, error: paymentError } = await paymentQuery;
  if (paymentError) throw new Error(paymentError.message);

  const payments = (paymentData ?? []).map((row): FirstUserPayment => {
    const metadata = asRecord(row.metadata);
    return {
      amountJpy: firstNumber(metadata.amount_jpy, metadata.amount_total) ?? 0,
      createdAt: firstString(row.created_at),
    };
  });
  const report = buildFirstUserFunnelReport({
    utmSource,
    utmMedium,
    utmContent,
    campaignStartedAt,
    post,
    events: (eventData ?? []) as FirstUserAcquisitionEvent[],
    payments,
  });
  return {
    ...report,
    issue: utmSource === "zenn" ? 3749 : 3883,
    reportGeneratedAt: new Date().toISOString(),
  };
}

async function buildAcquisitionTouchpointReport(
  admin: SupabaseClient,
  rawWindowDays: unknown,
) {
  const windowDaysRaw = typeof rawWindowDays === "number"
    ? rawWindowDays
    : Number(rawWindowDays ?? 30);
  const windowDays = Number.isFinite(windowDaysRaw)
    ? Math.max(7, Math.min(90, Math.trunc(windowDaysRaw)))
    : 30;
  const endDate = new Date();
  endDate.setHours(0, 0, 0, 0);
  const startDate = new Date(endDate);
  startDate.setDate(startDate.getDate() - (windowDays - 1));
  const startKey = formatDateKey(startDate);
  const endKey = formatDateKey(endDate);
  const { data, error } = await admin
    .from("app_analytics")
    .select("date, source_details")
    .gte("date", startKey)
    .lte("date", endKey)
    .order("date", { ascending: true });
  if (error) throw new Error(error.message);

  const counts: Record<string, number> = {};
  for (const row of data ?? []) {
    const details = (row.source_details ?? {}) as Record<string, unknown>;
    for (const [key, value] of Object.entries(details)) {
      const count = typeof value === "number" ? value : Number(value);
      if (Number.isFinite(count) && count > 0) {
        counts[key] = (counts[key] ?? 0) + count;
      }
    }
  }

  const touchpoints = TOUCHPOINT_DEFS.map((def) => {
    const touches = counts[def.touchSignal] ?? 0;
    const signups = counts[def.signupSignal] ?? 0;
    const rate = touches > 0 ? Math.round((signups / touches) * 1000) / 10 : 0;
    return {
      id: def.id,
      label: def.label,
      touchpoint: def.label,
      touchCount: touches,
      signupSubmitCount: signups,
      signupSubmits: signups,
      touches,
      signups,
      rate,
    };
  });
  const totalTouches = touchpoints.reduce(
    (total, item) => total + item.touches,
    0,
  );
  const totalSignups = touchpoints.reduce(
    (total, item) => total + item.signups,
    0,
  );
  const conversionRate = totalTouches > 0
    ? Math.round((totalSignups / totalTouches) * 1000) / 10
    : 0;
  const importPreviews = IMPORT_PREVIEW_DEFS.map((def) => ({
    id: def.id,
    label: def.label,
    previewCount: counts[def.signalKey] ?? 0,
  }));

  return {
    success: true,
    windowDays,
    startDate: startKey,
    endDate: endKey,
    summary: { totalTouches, totalSignups, conversionRate },
    touchpoints,
    importPreviews,
    importSignupCtaCount: counts["import_signup_cta"] ?? 0,
    publicMemoSignupCtaCount: counts["public_memo_signup_cta"] ?? 0,
  };
}

function generateReferralCode(): string {
  const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  const bytes = crypto.getRandomValues(new Uint8Array(8));
  return Array.from(bytes)
    .map((byte) => alphabet[byte % alphabet.length])
    .join("");
}

async function fetchReferralCode(
  admin: SupabaseClient,
  userId: string,
): Promise<ReferralCodeRow | null> {
  const { data, error } = await admin
    .from("referral_codes")
    .select(
      "id, user_id, referral_code, total_referrals, successful_referrals, bonus_points_earned, created_at, updated_at",
    )
    .eq("user_id", userId)
    .maybeSingle();
  if (error) throw new Error(error.message);
  return (data as ReferralCodeRow | null) ?? null;
}

async function ensureReferralCode(
  admin: SupabaseClient,
  userId: string,
): Promise<ReferralCodeRow> {
  const existing = await fetchReferralCode(admin, userId);
  if (existing) return existing;

  for (let attempt = 0; attempt < 8; attempt++) {
    const code = generateReferralCode();
    const { error } = await admin.from("referral_codes").insert({
      user_id: userId,
      referral_code: code,
    });
    if (!error) {
      const created = await fetchReferralCode(admin, userId);
      if (created) return created;
    }
    if (!String(error?.message ?? "").includes("duplicate")) {
      throw new Error(error?.message ?? "Failed to create referral code");
    }
  }

  const afterRetry = await fetchReferralCode(admin, userId);
  if (afterRetry) return afterRetry;
  throw new Error("Failed to create unique referral code");
}

async function applyPendingReferral(
  admin: SupabaseClient,
  referredUserId: string,
  rawPendingCode: unknown,
): Promise<boolean> {
  const pendingCode = String(rawPendingCode ?? "").trim().toUpperCase();
  if (!pendingCode) return false;

  const { data: existingReferral, error: existingError } = await admin
    .from("referrals")
    .select("id")
    .eq("referred_user_id", referredUserId)
    .maybeSingle();
  if (existingError) throw new Error(existingError.message);
  if (existingReferral) return true;

  const { data: referrer, error: referrerError } = await admin
    .from("referral_codes")
    .select("user_id, referral_code")
    .eq("referral_code", pendingCode)
    .maybeSingle();
  if (referrerError) throw new Error(referrerError.message);
  if (!referrer) return false;

  const referrerUserId = String(
    (referrer as { user_id?: string }).user_id ?? "",
  );
  if (!referrerUserId || referrerUserId === referredUserId) return true;

  const { error: insertError } = await admin.from("referrals").insert({
    referrer_user_id: referrerUserId,
    referred_user_id: referredUserId,
    referral_code: pendingCode,
    bonus_points: 500,
    status: "pending_activation",
    completed_at: null,
    metadata: {
      channel: "referral",
      signup_signal: "signup_submit_referral",
      activation_gate: "billing_or_manual_activation",
      gated_at: new Date().toISOString(),
    },
  });
  if (insertError && !String(insertError.message).includes("duplicate")) {
    throw new Error(insertError.message);
  }

  const { data: rows, error: countError } = await admin
    .from("referrals")
    .select("status, bonus_points")
    .eq("referrer_user_id", referrerUserId);
  if (countError) throw new Error(countError.message);

  const totalReferrals = (rows ?? []).length;
  const successfulReferrals =
    (rows ?? []).filter((row) => row.status === "completed").length;
  const bonusPointsEarned = (rows ?? []).reduce((sum, row) => {
    return row.status === "completed"
      ? sum + (Number(row.bonus_points) || 0)
      : sum;
  }, 0);

  const { error: updateError } = await admin
    .from("referral_codes")
    .update({
      total_referrals: totalReferrals,
      successful_referrals: successfulReferrals,
      bonus_points_earned: bonusPointsEarned,
    })
    .eq("user_id", referrerUserId);
  if (updateError) throw new Error(updateError.message);

  return true;
}

function isPaidReferralSubscription(row: BillingSubscriptionRow): boolean {
  const tier = firstString(row.tier).toLowerCase();
  const status = firstString(row.status).toLowerCase();
  return (tier === "pro" || tier === "team") &&
    (status === "active" || status === "trialing");
}

async function buildReferralBillingAttribution(
  admin: SupabaseClient,
  rows: ReferralRow[],
) {
  const referredUserIds = Array.from(
    new Set(
      rows
        .map((row) => firstString(row.referred_user_id))
        .filter(Boolean),
    ),
  );
  if (referredUserIds.length === 0) {
    return {
      billingConvertedReferrals: 0,
      referralFreeToProCvr: 0,
      billingChannels: [{
        id: "referral",
        label: "Referral",
        totalReferrals: 0,
        proConversions: 0,
        freeToProCvr: 0,
      }],
    };
  }

  const { data, error } = await admin
    .from("billing_subscriptions")
    .select("user_id, tier, status, metadata")
    .in("user_id", referredUserIds);
  if (error) throw new Error(error.message);

  const paidUserIds = new Set(
    ((data ?? []) as BillingSubscriptionRow[])
      .filter(isPaidReferralSubscription)
      .map((row) => firstString(row.user_id))
      .filter(Boolean),
  );
  const proConversions =
    rows.filter((row) => paidUserIds.has(firstString(row.referred_user_id)))
      .length;
  const freeToProCvr = rows.length > 0
    ? Math.round((proConversions / rows.length) * 1000) / 10
    : 0;
  return {
    billingConvertedReferrals: proConversions,
    referralFreeToProCvr: freeToProCvr,
    billingChannels: [{
      id: "referral",
      label: "Referral",
      totalReferrals: rows.length,
      proConversions,
      freeToProCvr,
    }],
  };
}

async function buildReferralPayload(
  admin: SupabaseClient,
  userId: string,
  pendingCode?: unknown,
) {
  const clearPendingCode = await applyPendingReferral(
    admin,
    userId,
    pendingCode,
  );
  const referralCode = await ensureReferralCode(admin, userId);
  const { data: referrals, error } = await admin
    .from("referrals")
    .select(
      "id, referrer_user_id, referred_user_id, referral_code, bonus_points, status, completed_at, created_at, metadata",
    )
    .eq("referrer_user_id", userId)
    .order("created_at", { ascending: false });
  if (error) throw new Error(error.message);

  const rows = (referrals ?? []) as ReferralRow[];
  const successfulReferrals =
    rows.filter((row) => row.status === "completed").length;
  const billingAttribution = await buildReferralBillingAttribution(
    admin,
    rows,
  );
  return {
    success: true,
    referralCode,
    referrals: rows,
    items: rows.map((row) => ({
      id: row.id,
      created_at: row.created_at,
      metadata: {
        code: referralCode.referral_code,
        referral_code: row.referral_code,
        status: row.status,
        bonus_points: row.bonus_points,
        completed_at: row.completed_at,
        channel: firstString(row.metadata?.channel, "referral"),
        signup_signal: firstString(
          row.metadata?.signup_signal,
          "signup_submit_referral",
        ),
      },
    })),
    totalReferrals: rows.length,
    successfulReferrals,
    activationQualifiedReferrals: successfulReferrals,
    ...billingAttribution,
    clearPendingCode,
  };
}

async function _deleteItem(
  admin: SupabaseClient,
  source: string,
  userId: string,
  id: string,
) {
  const { error } = await admin
    .from("hub_data")
    .delete()
    .eq("id", id)
    .eq("source", source)
    .filter("metadata->>user_id", "eq", userId);
  if (error) throw new Error(error.message);
}

function _applyAchievements<
  T extends { label: string; features_done: number; features_total: number },
>(
  plans: T[],
  achievementsCount: number,
): T[] {
  return plans.map((p) => {
    if (p.label === "短期計画") {
      return {
        ...p,
        features_done: Math.min(achievementsCount, 50),
        features_total: 50,
      };
    }
    if (p.label === "中期計画") {
      return {
        ...p,
        features_done: Math.min(achievementsCount, 200),
        features_total: 200,
      };
    }
    if (p.label === "長期計画") {
      return {
        ...p,
        features_done: Math.min(achievementsCount, 500),
        features_total: 500,
      };
    }
    return p;
  });
}

type RoadmapProgressPayload = {
  userCount: number;
  achievementsCount: number;
  plans: RoadmapPlan[];
};

async function isRoadmapShareStatsAdmin(
  admin: SupabaseClient,
  userId: string,
): Promise<boolean> {
  if (userId === "service_role") return true;
  const { data, error } = await admin
    .from("user_profiles")
    .select("is_admin")
    .eq("user_id", userId)
    .maybeSingle();
  return canReadRoadmapShareStats(
    userId,
    error == null && data?.is_admin === true,
  );
}

/// roadmap.progress / roadmap.share_stats 共通の検証済み集計。
/// 旧実装は各クエリの error を捨て、障害時にも 0 件を success:true で返していた。
/// X のデータダイジェストへ偽のゼロを供給しないため、3 系統のどれか1つでも
/// 失敗・不定値なら throw し、呼び出し元を fail closed にする。
async function loadRoadmapProgress(
  admin: SupabaseClient,
): Promise<RoadmapProgressPayload> {
  const [authListResult, plansResult, achievementsResult] = await Promise.all([
    admin.auth.admin.listUsers({ page: 1, perPage: 1 }),
    admin
      .from("growth_plans")
      .select(
        "label, deadline, target, features_done, features_total, sort_order, priority, effort",
      )
      .order("sort_order", { ascending: true })
      .order("target", { ascending: true }),
    admin
      .from("development_achievements")
      .select("id", { count: "exact", head: true }),
  ]);
  if (authListResult.error || plansResult.error || achievementsResult.error) {
    throw new Error("roadmap progress source query failed");
  }
  const totalUsers = (authListResult.data as { total?: unknown } | null)?.total;
  const totalAchievements = achievementsResult.count;
  const counts = parseRoadmapCounts(totalUsers, totalAchievements);
  const plans = _applyAchievements(
    (plansResult.data ?? []) as RoadmapPlan[],
    counts.achievementsCount,
  );
  return {
    ...counts,
    plans,
  };
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = (await req.json().catch(() => ({}))) as Record<
      string,
      unknown
    >;
    const action = (body.action as string) ?? "";

    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

    // Public actions that don't require auth
    const publicActions = [
      "waitlist.notify",
      "acquisition.report",
      "acquisition.signal",
      "acquisition.funnel_signal",
      "acquisition.track",
      "acquisition.touchpoint_report",
      "landing.trial",
      "signup.notify",
    ];
    let userId: string | null = null;
    if (!publicActions.includes(action)) {
      userId = await getUserId(req);
      if (!userId) return json({ error: "Unauthorized" }, 401);
    }

    switch (action) {
      // ─── Landing AI trial (anonymous, hard-capped server-side) ──────────────
      case "landing.trial": {
        let prompt: string;
        try {
          prompt = normalizeLandingTrialPrompt(body.prompt);
        } catch (error) {
          if (error instanceof LandingTrialInputError) {
            return json({
              success: false,
              error: error.message,
              canUseInstantPreview: true,
            }, 400);
          }
          throw error;
        }

        if (
          !OPENAI_API_KEY || !SERVICE_ROLE_KEY ||
          !LANDING_TRIAL_RATE_LIMIT_SALT
        ) {
          return json({
            success: false,
            error: "trial_ai_unavailable",
            canUseInstantPreview: true,
          }, 503);
        }

        const clientHash = await hashLandingTrialClient(
          req.headers,
          LANDING_TRIAL_RATE_LIMIT_SALT,
        );
        const { data: quotaData, error: quotaError } = await admin.rpc(
          "claim_landing_trial_ai_quota",
          { p_client_hash: clientHash },
        );
        if (quotaError) {
          console.error("landing.trial quota claim failed", quotaError.code);
          return json({
            success: false,
            error: "trial_ai_unavailable",
            canUseInstantPreview: true,
          }, 503);
        }

        const quota = (quotaData ?? {}) as Record<string, unknown>;
        if (quota.allowed !== true) {
          return json({
            success: false,
            error: "trial_quota_exhausted",
            canUseInstantPreview: true,
          }, 429);
        }

        try {
          const suggestion = await generateLandingTrialSuggestion({
            apiKey: OPENAI_API_KEY,
            prompt,
            model: LANDING_TRIAL_AI_MODEL,
          });
          return json({
            success: true,
            ...suggestion,
            model: LANDING_TRIAL_AI_MODEL || DEFAULT_LANDING_TRIAL_MODEL,
            remainingAttempts: quota.remaining_client,
          });
        } catch (error) {
          console.error("landing.trial provider failed", errorMessage(error));
          return json({
            success: false,
            error: "trial_ai_unavailable",
            canUseInstantPreview: true,
          }, 503);
        }
      }

      // ─── Acquisition ───────────────────────────────────────────────────────
      case "acquisition.get": {
        const items = await listItems(admin, "growth_signal", userId!);
        return json({ success: true, items });
      }

      case "acquisition.track": {
        const actorHash = await analyticsActorHash(req, await getUserId(req));
        const result = await recordAcquisitionSignal(
          admin,
          body.signalKey ?? body.channel,
          body.shareIncrement,
          actorHash,
        );
        return json(result, result.success ? 200 : 400);
      }

      case "acquisition.report": {
        const report = await buildAcquisitionTouchpointReport(
          admin,
          body.windowDays,
        );
        return json({ ...report, report });
      }

      // ─── Landing touchpoint signals (global / anonymous, app_analytics.source_details) ─
      case "acquisition.signal": {
        const actorHash = await analyticsActorHash(req, await getUserId(req));
        const result = await recordAcquisitionSignal(
          admin,
          body.signalKey,
          body.shareIncrement,
          actorHash,
        );
        return json(result, result.success ? 200 : 400);
      }

      case "acquisition.funnel_signal": {
        const actorUserId = await getUserId(req);
        const result = await recordFirstUserFunnelSignal(
          admin,
          actorUserId,
          body,
        );
        return json(result, result.success ? 200 : 400);
      }

      case "acquisition.touchpoint_report": {
        return json(
          await buildAcquisitionTouchpointReport(admin, body.windowDays),
        );
      }

      // ─── Command Center ─────────────────────────────────────────────────────
      // ─── Daily Challenges ─────────────────────────────────────────────────
      case "signup.notify": {
        const signupUserId = firstString(body.signupUserId, body.userId);
        if (!signupUserId) {
          return json({ error: "signupUserId required" }, 400);
        }

        const { data: signupUserData, error: signupUserError } = await admin
          .auth
          .admin
          .getUserById(signupUserId);
        if (signupUserError || !signupUserData?.user) {
          return json({ error: "signup user not found" }, 404);
        }

        const createdAt = signupUserData.user.created_at ?? "";
        if (!isRecentSignupCreatedAt(createdAt)) {
          return json({
            success: false,
            skipped: true,
            reason: "signup user is outside the notification window",
          }, 202);
        }

        const { data: existing, error: existingError } = await admin
          .from("hub_data")
          .select("id, created_at")
          .eq("source", "signup_slack_notification")
          .filter("metadata->>signup_user_id", "eq", signupUserId)
          .limit(1)
          .maybeSingle();
        if (existingError) throw new Error(existingError.message);
        if (existing) {
          return json({
            success: true,
            duplicate: true,
            skipped: true,
            id: existing.id,
          });
        }

        const totalUsersResponse = await admin.auth.admin.listUsers({
          page: 1,
          perPage: 1,
        });
        const totalUsersData = totalUsersResponse.data as
          | { total?: number }
          | null;
        const totalUsers = typeof totalUsersData?.total === "number"
          ? totalUsersData.total
          : null;
        const payload = buildSignupSlackPayload({
          totalUsers,
          signalKey: body.signalKey,
          signupUserId,
          createdAt,
          appUrl: Deno.env.get("PUBLIC_SITE_URL") ??
            "https://my-web-app-b67f4.web.app/",
        });
        const webhookUrl = Deno.env.get("SLACK_WEBHOOK_URL") ?? "";
        if (!webhookUrl) {
          return json({
            success: false,
            error: "webhook not configured: SLACK_WEBHOOK_URL",
          }, 500);
        }

        const slackResponse = await fetch(webhookUrl, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(payload),
        });
        if (!slackResponse.ok) {
          const detail = await slackResponse.text();
          return json({
            success: false,
            error: `slack webhook failed: ${slackResponse.status}`,
            detail: detail.slice(0, 500),
          }, 502);
        }

        const channel = resolveSignupChannel(body.signalKey);
        const item = await addItem(
          admin,
          "signup_slack_notification",
          "service_role",
          {
            signup_user_id: signupUserId,
            signup_created_at: createdAt,
            signal_key: body.signalKey ?? null,
            channel,
            total_users: totalUsers,
            slack_status: slackResponse.status,
            notified_at: new Date().toISOString(),
          },
        );

        return json({
          success: true,
          notified: true,
          channel,
          totalUsers,
          item,
        });
      }

      case "daily.challenges_generate": {
        const dateStr = typeof body.date === "string" &&
            /^\d{4}-\d{2}-\d{2}$/.test(body.date as string)
          ? (body.date as string)
          : (() => {
            const d = new Date();
            return `${d.getFullYear()}-${
              String(d.getMonth() + 1).padStart(2, "0")
            }-${String(d.getDate()).padStart(2, "0")}`;
          })();
        const defaults = [
          {
            challenge_type: "create_notes",
            challenge_title: "今日のメモ作成",
            challenge_description: "3つのメモを作成しよう",
            target_value: 3,
            reward_points: 50,
          },
          {
            challenge_type: "earn_points",
            challenge_title: "ポイント獲得",
            challenge_description: "100ポイントを獲得しよう",
            target_value: 100,
            reward_points: 30,
          },
          {
            challenge_type: "share_notes",
            challenge_title: "メモを共有",
            challenge_description: "1つのメモを共有しよう",
            target_value: 1,
            reward_points: 40,
          },
        ];
        const rows = defaults.map((d) => ({
          ...d,
          challenge_date: dateStr,
          is_active: true,
        }));
        const { data: upserted, error: upErr } = await admin
          .from("daily_challenges")
          .upsert(rows, {
            onConflict: "challenge_date,challenge_type",
            ignoreDuplicates: true,
          })
          .select("id, challenge_type");
        if (upErr) throw new Error(upErr.message);
        return json({
          success: true,
          dateKey: dateStr,
          insertedCount: upserted?.length ?? 0,
          totalDefaults: defaults.length,
        });
      }

      case "command.analyze": {
        const geminiKey = Deno.env.get("GEMINI_API_KEY") ?? "";
        if (!geminiKey) {
          return json({
            success: true,
            analysis: "Gemini API key not configured",
            stage: "unknown",
          });
        }
        const userCount = Number(body.totalUsers ?? 0);
        const stage = userCount < 100
          ? "Pre-PMF"
          : userCount < 1000
          ? "Early traction"
          : "Scale-up";
        const prompt =
          `あなたは自分株式会社のCGO（最高グロース責任者）です。ユーザー数: ${userCount}人, ステージ: ${stage}. 今週の最優先アクションを3つ提案してください。JSON形式: {"stage":"...","actions":["...","...","..."]}`;
        const res = await fetch(
          `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${geminiKey}`,
          {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ contents: [{ parts: [{ text: prompt }] }] }),
          },
        );
        const result = await res.json();
        const text = (
          result as {
            candidates?: [{ content: { parts: [{ text: string }] } }];
          }
        ).candidates?.[0]?.content?.parts?.[0]?.text ?? "{}";
        try {
          return json({
            success: true,
            ...JSON.parse(text.replace(/```json\n?|\n?```/g, "")),
          });
        } catch {
          return json({ success: true, analysis: text, stage });
        }
      }

      // ─── Referral ────────────────────────────────────────────────────────────
      case "referral.list": {
        return json(
          await buildReferralPayload(admin, userId!, body.pendingCode),
        );
      }

      case "referral.create": {
        const payload = await buildReferralPayload(admin, userId!);
        if (body.email) {
          const item = await addItem(admin, "referral_invite", userId!, {
            referral_code: payload.referralCode.referral_code,
            invited_email: body.email,
            status: "pending",
          });
          return json({ ...payload, item });
        }
        return json(payload);
      }

      case "referral.complete": {
        if (body.pendingCode) {
          return json(
            await buildReferralPayload(admin, userId!, body.pendingCode),
          );
        }
        const { error } = await admin
          .from("hub_data")
          .update({
            metadata: {
              user_id: userId!,
              status: "completed",
              completed_at: new Date().toISOString(),
            },
          })
          .eq("id", String(body.id))
          .eq("source", "referral");
        if (error) throw new Error(error.message);
        return json({ success: true });
      }

      case "referral.complete_pending": {
        return json(
          await buildReferralPayload(admin, userId!, body.pendingCode),
        );
      }

      // ─── Share Signal ────────────────────────────────────────────────────────
      case "share.track": {
        const item = await addItem(admin, "share_signal", userId!, {
          content_id: body.content_id,
          channel: body.channel ?? "unknown",
          url: body.url,
        });
        return json({ success: true, item });
      }

      case "share.list": {
        const items = await listItems(admin, "share_signal", userId!);
        return json({ success: true, items });
      }

      // ─── Achievement ─────────────────────────────────────────────────────────
      case "achievement.list": {
        const items = await listItems(admin, "growth_achievement", userId!);
        return json({ success: true, items });
      }

      case "achievement.unlock": {
        const item = await addItem(admin, "growth_achievement", userId!, {
          type: body.type,
          title: body.title,
          unlocked_at: new Date().toISOString(),
        });
        return json({ success: true, item });
      }

      // ─── Import ──────────────────────────────────────────────────────────────
      case "import.preview": {
        const items = await listItems(admin, "import_preview", userId!);
        return json({ success: true, items });
      }

      case "import.create": {
        const item = await addItem(admin, "import_preview", userId!, {
          source: body.source,
          count: body.count ?? 0,
          status: "pending",
        });
        return json({ success: true, item });
      }

      case "import.commit": {
        const item = await addItem(admin, "import_commit", userId!, {
          preview_id: body.preview_id,
          committed_at: new Date().toISOString(),
        });
        return json({ success: true, item });
      }

      // ─── Roadmap Progress (実データ: growth_plans テーブル) ───────────────────
      case "roadmap.progress": {
        return json({ success: true, ...await loadRoadmapProgress(admin) });
      }

      // AI シェアへ渡す公開可能な全体集計。通常ユーザーには service-role 集計を
      // 開示せず、user_profiles.is_admin / automation service-role だけが取得できる。
      // 競合別の内部計画は除き、公開シリーズに使う短/中/長期計画だけを返す。
      case "roadmap.share_stats": {
        if (!(await isRoadmapShareStatsAdmin(admin, userId!))) {
          return json({ success: false, error: "Forbidden" }, 403);
        }
        const progress = await loadRoadmapProgress(admin);
        const plans = selectShareableRoadmapPlans(progress.plans);
        return json({
          success: true,
          verified: true,
          source: "roadmap.share_stats",
          userCount: progress.userCount,
          achievementsCount: progress.achievementsCount,
          plans,
        });
      }

      // ─── Video Ad ─────────────────────────────────────────────────────────────
      case "video_ad.create": {
        const item = await addItem(admin, "video_ad", userId!, {
          title: body.title,
          script: body.script ?? "",
          style: body.style ?? "energetic",
          platform: body.platform ?? "tiktok",
          status: "draft",
        });
        return json({ success: true, item });
      }

      case "video_ad.list": {
        const items = await listItems(admin, "video_ad", userId!);
        return json({ success: true, items });
      }

      // ─── Viral Share ──────────────────────────────────────────────────────────
      case "viral.share": {
        const item = await addItem(admin, "viral_share", userId!, {
          content: body.content,
          channel: body.channel ?? "twitter",
          share_url: body.share_url,
        });
        return json({ success: true, item });
      }

      case "viral.list": {
        const items = await listItems(admin, "viral_share", userId!);
        return json({ success: true, items });
      }

      // ─── X Post ───────────────────────────────────────────────────────────────
      case "x.trends": {
        const rawWoeid = Number(body.woeid ?? 23424856);
        const rawLimit = Number(body.limit ?? body.maxTrends ?? 10);
        const woeid = Number.isFinite(rawWoeid)
          ? Math.max(1, Math.trunc(rawWoeid))
          : 23424856;
        const limit = Number.isFinite(rawLimit)
          ? Math.max(1, Math.min(20, Math.trunc(rawLimit)))
          : 10;
        // X trends API (v2 trends/by/woeid) は有料tier + X_BEARER_TOKEN が必要で、
        // v1.1 trends/place.json は退役済み。未設定/失敗時に "今日のトレンド" が
        // 空になり文面・動画がトレンド非反映で固定化する。→ 無料の RSS ニュース
        // (NHK/ITmedia) を代替トピックとしてフォールバックし、毎回変化+当日反映を保つ。
        let xError: unknown = null;
        try {
          const trends = await fetchXTrendsByWoeid({ woeid, maxTrends: limit });
          if (trends.length > 0) {
            return json({
              success: true,
              woeid,
              trends,
              source: "x_api",
              fetchedAt: new Date().toISOString(),
            });
          }
        } catch (error) {
          xError = error;
        }
        try {
          const newsTrends = await fetchTodayNewsTrendTopics(limit);
          if (newsTrends.length > 0) {
            return json({
              success: true,
              woeid,
              trends: newsTrends,
              source: "rss_news_fallback",
              fetchedAt: new Date().toISOString(),
            });
          }
        } catch (rssError) {
          return json({
            success: false,
            woeid,
            trends: [],
            error: `x_trends=${errorMessage(xError)}; rss=${
              errorMessage(rssError)
            }`,
            code: "trends_and_rss_failed",
            actionRequired:
              "Configure X_BEARER_TOKEN (paid X API) or check tools-hub rss.fetch_latest.",
          });
        }
        const xPayload = isXApiError(xError) ? xError.payload : null;
        return json({
          success: false,
          woeid,
          trends: [],
          error: xError ? errorMessage(xError) : "no trends available",
          code: xPayload?.code ?? "x_trends_empty",
          actionRequired: xPayload?.actionRequired ??
            "Check X API read access or configure X_BEARER_TOKEN.",
        });
      }

      case "x.metrics_collect": {
        if (!await isXOperator(admin, userId!)) {
          return json({ error: "Forbidden: X operator role required" }, 403);
        }
        try {
          return json(
            await collectXPostMetrics(admin, "service_role", body.limit),
          );
        } catch (error) {
          const xPayload = isXApiError(error) ? error.payload : null;
          // X API クレジット枯渇/spend cap は次の請求サイクルまで自然復旧
          // しない運用事象。3 時間毎の cron を赤く落とし続けず、HTTP 200 の
          // skipped で返して workflow 側の warning 表示に委ねる。
          if (xPayload?.code === "x_billing_blocked") {
            return json({
              success: false,
              skipped: true,
              collected: 0,
              error: errorMessage(error),
              code: "x_billing_blocked",
              actionRequired: xPayload?.actionRequired ??
                "X APIクレジット/spend cap枯渇。console.x.com で上限引き上げ、または次の請求サイクルまで収集は自動スキップされます。",
            });
          }
          return json({
            success: false,
            error: errorMessage(error),
            code: xPayload?.code ?? "x_metrics_collect_failed",
            actionRequired: xPayload?.actionRequired ??
              "Check X API read access. If impression fields are unavailable, public engagement metrics will be used when possible.",
          }, 502);
        }
      }

      // R24: X Analytics のコンテンツ CSV エクスポートをそのまま学習母集団へ
      // 取り込む。アプリ経由の投稿しか見ていなかった学習ループに、アカウント
      // 全体の実績 (= 実測でサイト流入の 99% を生んでいた手動投稿) を入れる。
      case "x.analytics_import": {
        if (!await isXOperator(admin, userId!)) {
          return json({ error: "Forbidden: X operator role required" }, 403);
        }
        return json(
          await importXAnalyticsCsv(admin, userId!, {
            csv: String(body.csv ?? ""),
            exportRange: String(body.exportRange ?? body.export_range ?? ""),
            dryRun: body.dryRun === true || body.dry_run === true,
          }),
        );
      }

      case "x.metrics_normalized": {
        const scopeUserId = await xReadScopeUserId(admin, userId!);
        return json(
          await buildNormalizedXMetricReport(admin, scopeUserId, body.limit),
        );
      }

      case "x.performance_context": {
        const scopeUserId = await xReadScopeUserId(admin, userId!);
        return json(
          await buildXPerformanceContext(admin, scopeUserId, body.limit),
        );
      }

      case "x.first_user_funnel":
      case "acquisition.first_user_funnel": {
        if (!await isXOperator(admin, userId!)) {
          return json({ error: "Forbidden: X operator role required" }, 403);
        }
        return json(
          await buildFirstUserAcquisitionReport(
            admin,
            "service_role",
            body.utmSource ?? body.utm_source,
            body.utmMedium ?? body.utm_medium,
            body.utmContent ?? body.utm_content,
            body.campaignStartedAt ?? body.campaign_started_at,
            body.limit,
          ),
        );
      }

      case "x.growth_data_report": {
        // R24: ポストA型の週次 build-in-public 実測レポートを合成する
        // (read-only / LLM 非使用 / 数値は全て x_post_log 実測)。実測 3 件
        // 未満は available:false で投稿見送りを指示する。
        const scopeUserId = await xReadScopeUserId(admin, userId!);
        const perf = await buildXGrowthDataReportContext(
          admin,
          scopeUserId,
          body.limit ?? 100,
        );
        const targetUrl = firstString(
          body.targetUrl,
          body.target_url,
          "https://my-web-app-b67f4.web.app/?utm_source=x&utm_medium=data_report&utm_campaign=first_user_growth&utm_content=weekly_data_report",
        );
        const growthReportRows = (perf.rows as Array<
          GrowthReportRow & {
            learningCohort: string;
            rankingEligible: boolean;
            rankingImpressions: number | null;
          }
        >)
          .filter((row) =>
            row.learningCohort !== "historical_benchmark" &&
            (!perf.comparisonWindow || row.rankingEligible)
          )
          .map((row) => ({
            ...row,
            impressions: row.rankingImpressions,
            score: row.rankingImpressions ?? row.score,
          }));
        const report = buildGrowthDataReport(
          growthReportRows,
          new Date(),
          targetUrl,
        );
        if (report === null) {
          return json({
            success: true,
            available: false,
            reason: "measured impressions rows < 3",
          });
        }
        return json({ success: true, available: true, ...report });
      }

      case "x.ai_tool_tracker_compose": {
        // R27: AIツール動向トラッカー系列の read-only 合成(playbook step 2)。
        // レポート(docs/ai-tool-watch/latest-report.json)は呼び出し元 cron が
        // body.report で渡す。変化 0 件/データ薄は available:false = 候補を
        // 作らない(投稿は x.candidate.create → HITL 承認経由のみ)。
        const targetUrl = firstString(
          body.targetUrl,
          body.target_url,
          "https://my-web-app-b67f4.web.app/?utm_source=x&utm_medium=data_report&utm_campaign=first_user_growth&utm_content=ai_tool_tracker",
        );
        const post = buildAiToolTrackerPost(body.report, targetUrl);
        if (post === null) {
          return json({
            success: true,
            available: false,
            reason: "no changed sources, thin data, or invalid checked_at",
          });
        }
        return json({ success: true, available: true, ...post });
      }

      case "x.household_tracker_report": {
        const report = await buildScheduledHouseholdTrackerReport(
          admin,
          userId!,
          body.maxAgeDays ?? body.max_age_days,
        );
        const status = firstNumber(report.status) ?? 200;
        return json({ success: status < 400, ...report }, status);
      }

      case "x.post_preflight": {
        // R15: spend cap 到達中に高価な創作パイプライン(GPT image + TTS +
        // Hedra)を燃やす前に、直近ログから「投稿しても billing で確定失敗
        // するか」を返す read-only チェック。X API は一切呼ばない(ゼロコスト)。
        const scopeUserId = await xReadScopeUserId(admin, userId!);
        const logs =
          (await listXPostLogs(admin, scopeUserId, 20)) as XPostLogItem[];
        const rows = logs.map((item) => ({
          created_at: item.created_at,
          metadata: asRecord(item.metadata),
        }));
        return json({
          success: true,
          ...decideXPostPreflight(rows, new Date()),
        });
      }

      case "x.today_status": {
        // R16: /admin ダッシュボードへ「今日すでに投稿したか / 最新tweetと初速
        // インプレ / spend-cap ブロック中か」を返す read-only チェック(X API 非
        // 呼出・ゼロコスト)。どんな例外でも 200 {available:false} を返し、
        // ダッシュボードが必ず degrade(現行文言に戻る)できることを保証する。
        try {
          const scopeUserId = await xReadScopeUserId(admin, userId!);
          const logs =
            (await listXPostLogs(admin, scopeUserId, 20)) as XPostLogItem[];
          const rows = logs.map((item) => ({
            created_at: item.created_at,
            metadata: asRecord(item.metadata),
          }));
          return json({
            success: true,
            ...computeTodayStatus(
              rows,
              String(body.startOfDayIso ?? ""),
              new Date(),
            ),
          });
        } catch (_error) {
          return json({ success: true, available: false });
        }
      }

      case "revenue.funnel_report": {
        if (!await isXOperator(admin, userId!)) {
          return json({ error: "Forbidden: X operator role required" }, 403);
        }
        return json(
          await buildRevenueFunnelReport(admin, "service_role", body.limit),
        );
      }

      case "x.candidate.list": {
        if (!await isXOperator(admin, userId!)) {
          return json({ error: "Forbidden: X operator role required" }, 403);
        }
        const limit = Math.max(
          1,
          Math.min(100, Math.trunc(firstNumber(body.limit) ?? 50)),
        );
        const requestedStatus = firstString(body.status);
        // #4080: statuses[] を渡すと 1 リクエストで複数 status を返す
        // (client は従来 3 status を 3 往復していた)。
        // 🔑 **per-status limit は維持する** — 単一 IN() + 共有 limit にすると
        // finalized 行が created_at 降順 window を埋めて古い承認待ちを黙って
        // 押し出す F2 の窓圧迫が status 間で再発する。
        const rawStatuses = Array.isArray(body.statuses)
          ? (body.statuses as unknown[]).map((entry) => firstString(entry))
            .filter(Boolean)
          : [];
        const batchStatuses = [...new Set(rawStatuses)].slice(0, 10);

        // R34: count:"exact" で「limit で切る前の総数」も返す。従来は limit 件しか
        // 返さないため client 側は上限に達したかしか分からず、承認待ちが 11 件でも
        // 200 件でも「10件以上」としか出せなかった (backlog の規模が掴めない)。
        // source は idx_hub_data_source があり EF は service_role なので、count は
        // x_post_candidate 部分集合への index scan で収まる (agent_memories のような
        // 無索引全表走査にはならない)。
        const runQuery = async (status: string) => {
          let query = admin
            .from("hub_data")
            .select("id, metadata, created_at", { count: "exact" })
            .eq("source", X_POST_CANDIDATE_SOURCE)
            .order("created_at", { ascending: false })
            .limit(limit);
          if (status) {
            query = query.filter("metadata->>status", "eq", status);
          }
          const { data, error, count } = await query;
          if (error) throw new Error(error.message);
          return {
            candidates: data ?? [],
            // limit で切る前の総数。取得できないときは null (client は従来の
            // 「N件以上」表示へ degrade する)。
            total: typeof count === "number" ? count : null,
          };
        };

        if (batchStatuses.length > 0) {
          const results = await Promise.all(
            batchStatuses.map(async (status) => ({
              status,
              ...(await runQuery(status)),
            })),
          );
          const byStatus: Record<string, unknown> = {};
          for (const result of results) {
            byStatus[result.status] = {
              candidates: result.candidates,
              total: result.total,
            };
          }
          return json({ success: true, byStatus });
        }

        const single = await runQuery(requestedStatus);
        return json({
          success: true,
          candidates: single.candidates,
          total: single.total,
        });
      }

      case "x.candidate.create": {
        if (!await isXOperator(admin, userId!)) {
          return json({ error: "Forbidden: X operator role required" }, 403);
        }
        let candidateMetadata: Record<string, unknown>;
        try {
          candidateMetadata = buildXPostCandidateMetadata(
            body.postPayload ?? body.post_payload ?? body,
            {
              candidateKey: body.candidateKey ?? body.candidate_key ??
                body.idempotencyKey ?? body.idempotency_key,
              candidateType: body.candidateType ?? body.candidate_type,
              sourceKind: body.sourceKind ?? body.source_kind,
              sourceUrls: body.sourceUrls ?? body.source_urls,
              createdBy: body.createdBy ?? body.created_by,
              context: body.context ?? body.generationContext ??
                body.generation_context,
            },
          );
        } catch (error) {
          return json({ success: false, error: errorMessage(error) }, 400);
        }

        const candidateKey = firstString(candidateMetadata.candidate_key);
        if (!candidateKey) {
          return json({ success: false, error: "candidateKey required" }, 400);
        }
        if (body.dryRun === true || body.dry_run === true) {
          return json({
            success: true,
            dryRun: true,
            candidateCreated: false,
            candidateId: null,
            status: "pending_approval",
            preview: candidateMetadata,
          });
        }

        const candidateOwnerUserId = userId!;
        const findExistingCandidate = async () => {
          const { data, error } = await admin
            .from("hub_data")
            .select("id, metadata, created_at")
            .eq("source", X_POST_CANDIDATE_SOURCE)
            .filter(
              "metadata->>user_id",
              "eq",
              candidateOwnerUserId,
            )
            .filter("metadata->>candidate_key", "eq", candidateKey)
            .limit(1)
            .maybeSingle();
          if (error) throw new Error(error.message);
          return data;
        };
        const existing = await findExistingCandidate();
        if (existing) {
          return json({
            success: true,
            dryRun: false,
            candidateCreated: false,
            idempotent: true,
            candidateId: existing.id,
            status: asRecord(existing.metadata).status ?? "pending_approval",
            candidate: existing,
          });
        }

        let candidate;
        try {
          candidate = await addItem(
            admin,
            X_POST_CANDIDATE_SOURCE,
            candidateOwnerUserId,
            candidateMetadata,
          );
        } catch (error) {
          // The partial unique index closes the read/insert race. Treat a
          // concurrent creator winning that race as an idempotent success.
          const racedCandidate = await findExistingCandidate();
          if (!racedCandidate) throw error;
          return json({
            success: true,
            dryRun: false,
            candidateCreated: false,
            idempotent: true,
            candidateId: racedCandidate.id,
            status: asRecord(racedCandidate.metadata).status ??
              "pending_approval",
            candidate: racedCandidate,
          });
        }
        return json({
          success: true,
          dryRun: false,
          candidateCreated: true,
          idempotent: false,
          candidateId: candidate.id,
          status: asRecord(candidate.metadata).status ?? "pending_approval",
          candidate,
        });
      }

      case "x.candidate.approve": {
        if (!await isXOperator(admin, userId!)) {
          return json({ error: "Forbidden: X operator role required" }, 403);
        }
        const candidateId = firstString(body.candidateId, body.candidate_id);
        if (!isUuid(candidateId)) {
          return json(
            { success: false, error: "valid candidateId required" },
            400,
          );
        }
        const { data: candidate, error: candidateError } = await admin
          .from("hub_data")
          .select("id, metadata, created_at")
          .eq("id", candidateId)
          .eq("source", X_POST_CANDIDATE_SOURCE)
          .maybeSingle();
        if (candidateError) throw new Error(candidateError.message);
        if (!candidate) {
          return json({ success: false, error: "candidate not found" }, 404);
        }
        const candidateMeta = asRecord(candidate.metadata);
        const expectedCandidateType = firstString(
          body.expectedCandidateType,
          body.expected_candidate_type,
        );
        const expectedSourceKind = firstString(
          body.expectedSourceKind,
          body.expected_source_kind,
        );
        if (
          expectedCandidateType &&
          firstString(candidateMeta.candidate_type) !== expectedCandidateType
        ) {
          return json({
            success: false,
            error: "candidate type does not match approval workflow",
          }, 409);
        }
        if (
          expectedSourceKind &&
          firstString(candidateMeta.source_kind) !== expectedSourceKind
        ) {
          return json({
            success: false,
            error: "candidate source does not match approval workflow",
          }, 409);
        }

        const approvedBy = userId === "service_role"
          ? firstString(body.approvedBy, body.approved_by, "service_role")
          : userId!;
        const approvalChannel = userId === "service_role"
          ? firstString(
            body.approvalChannel,
            body.approval_channel,
            "service_role",
          )
          : "admin_ui";
        let approved;
        try {
          approved = approveXPostCandidateMetadata(candidateMeta, {
            actorUserId: userId!,
            approvedBy,
            channel: approvalChannel,
            context: body.approvalContext ?? body.approval_context,
          });
        } catch (error) {
          return json({ success: false, error: errorMessage(error) }, 409);
        }
        const { data: updated, error: updateError } = await admin
          .from("hub_data")
          .update({ metadata: approved.metadata })
          .eq("id", candidateId)
          .eq("source", X_POST_CANDIDATE_SOURCE)
          .select("id, metadata, created_at")
          .single();
        if (updateError) throw new Error(updateError.message);
        return json({
          success: true,
          candidateId,
          status: "approved",
          candidate: updated,
          // x.post persists candidateId as provenance. All other fields are
          // the exact whitelisted payload reviewed by the operator.
          postPayload: { ...approved.postPayload, candidateId },
        });
      }

      case "x.candidate.reject": {
        if (!await isXOperator(admin, userId!)) {
          return json({ error: "Forbidden: X operator role required" }, 403);
        }
        // 単体 (candidateId) と一括 (candidateIds[]) の両対応。UI の
        // 「鮮度切れをまとめて却下」は後者を使う。
        const rawIds = Array.isArray(body.candidateIds ?? body.candidate_ids)
          ? (body.candidateIds ?? body.candidate_ids) as unknown[]
          : [];
        const singleId = firstString(body.candidateId, body.candidate_id);
        const requestedIds = [
          ...(singleId ? [singleId] : []),
          ...rawIds.map((entry) => firstString(entry)),
        ].filter(Boolean);
        // 重複除去して順序は入力順を維持 (結果の突き合わせを容易にする)。
        const candidateIds = [...new Set(requestedIds)];
        if (candidateIds.length === 0) {
          return json(
            { success: false, error: "candidateId or candidateIds required" },
            400,
          );
        }
        if (candidateIds.some((id) => !isUuid(id))) {
          return json(
            { success: false, error: "all candidate ids must be uuid" },
            400,
          );
        }
        // 一括は 1 リクエストあたり 50 件で頭打ち (F2 window 圧迫と
        // 長時間トランザクションを避ける)。超過は明示エラーで気付かせる。
        if (candidateIds.length > 50) {
          return json(
            { success: false, error: "at most 50 candidate ids per request" },
            400,
          );
        }
        const rejectedBy = userId === "service_role"
          ? firstString(body.rejectedBy, body.rejected_by, "service_role")
          : userId!;
        const reason = body.reason ?? body.rejectReason ?? body.reject_reason;

        const rejected: string[] = [];
        const unchanged: string[] = [];
        const failures: { candidateId: string; error: string }[] = [];
        for (const candidateId of candidateIds) {
          try {
            const { data: candidate, error: candidateError } = await admin
              .from("hub_data")
              .select("id, metadata, created_at")
              .eq("id", candidateId)
              .eq("source", X_POST_CANDIDATE_SOURCE)
              .maybeSingle();
            if (candidateError) throw new Error(candidateError.message);
            if (!candidate) {
              failures.push({ candidateId, error: "candidate not found" });
              continue;
            }
            const result = rejectXPostCandidateMetadata(
              asRecord(candidate.metadata),
              { actorUserId: userId!, rejectedBy, reason },
            );
            if (!result.changed) {
              // 既に終端 (rejected / rejected_duplicate) = 冪等 no-op。
              unchanged.push(candidateId);
              continue;
            }
            const { error: updateError } = await admin
              .from("hub_data")
              .update({ metadata: result.metadata })
              .eq("id", candidateId)
              .eq("source", X_POST_CANDIDATE_SOURCE);
            if (updateError) throw new Error(updateError.message);
            rejected.push(candidateId);
          } catch (error) {
            // 1 件の失敗で残りを巻き添えにしない (一括却下の途中終了防止)。
            failures.push({ candidateId, error: errorMessage(error) });
          }
        }
        return json({
          success: failures.length === 0,
          status: "rejected",
          requested: candidateIds.length,
          rejected,
          unchanged,
          failures,
        }, failures.length > 0 && rejected.length === 0 ? 400 : 200);
      }

      case "x.candidate.finalize": {
        if (!await isXOperator(admin, userId!)) {
          return json({ error: "Forbidden: X operator role required" }, 403);
        }
        const candidateId = firstString(body.candidateId, body.candidate_id);
        if (!isUuid(candidateId)) {
          return json(
            { success: false, error: "valid candidateId required" },
            400,
          );
        }
        const { data: candidate, error: candidateError } = await admin
          .from("hub_data")
          .select("id, metadata, created_at")
          .eq("id", candidateId)
          .eq("source", X_POST_CANDIDATE_SOURCE)
          .maybeSingle();
        if (candidateError) throw new Error(candidateError.message);
        if (!candidate) {
          return json({ success: false, error: "candidate not found" }, 404);
        }
        let finalizedMetadata;
        try {
          finalizedMetadata = finalizeXPostCandidateMetadata(
            candidate.metadata,
            body.result ?? body.postResult ?? body.post_result,
          );
        } catch (error) {
          return json({ success: false, error: errorMessage(error) }, 409);
        }
        const { data: updated, error: updateError } = await admin
          .from("hub_data")
          .update({ metadata: finalizedMetadata })
          .eq("id", candidateId)
          .eq("source", X_POST_CANDIDATE_SOURCE)
          .select("id, metadata, created_at")
          .single();
        if (updateError) throw new Error(updateError.message);
        return json({
          success: true,
          candidateId,
          status: asRecord(updated.metadata).status,
          candidate: updated,
        });
      }

      case "x.post": {
        if (!await isXOperator(admin, userId!)) {
          return json({ error: "Forbidden: X operator role required" }, 403);
        }
        const requestedOwnerUserId = firstString(
          body.ownerUserId,
          body.owner_user_id,
        );
        const logUserId = resolveXLogOwnerUserId(
          userId!,
          requestedOwnerUserId,
        );
        const scheduledHouseholdPost = firstString(body.source) ===
          "x-household-tracker-post.yml";
        const text = String(body.text ?? "").trim();
        const replyText = String(body.replyText ?? body.reply_text ?? "")
          .trim();
        const replyTexts = [
          ...(Array.isArray(body.replyTexts) ? body.replyTexts : []),
          ...(Array.isArray(body.reply_texts) ? body.reply_texts : []),
          ...(replyText ? [replyText] : []),
        ]
          .map((entry) => String(entry ?? "").trim())
          .filter((entry) => entry !== "")
          .slice(0, 8);
        const mediaUrl = String(body.mediaUrl ?? body.media_url ?? "").trim();
        const mediaType = String(body.mediaType ?? body.media_type ?? "")
          .trim();
        const mediaAlt = String(
          body.mediaAlt ?? body.media_alt ?? body.altText ?? "",
        ).trim();
        // ネイティブ投票(H7 / impressions ブースター)。>=2 選択肢のときだけ有効化し、
        // 最初の text-only リプライにのみ載せる(media 付きリードには載せない)。
        // 未指定(既定)のときは poll=null となり従来と完全に同一の投稿になる。
        const rawPoll = (body.poll ?? null) as
          | {
            options?: unknown;
            durationMinutes?: unknown;
            duration_minutes?: unknown;
          }
          | null;
        const pollOptions = Array.isArray(rawPoll?.options)
          ? rawPoll!.options
            .map((option) => String(option ?? "").trim())
            .filter((option) => option !== "")
            .slice(0, 4)
          : [];
        const poll = pollOptions.length >= 2
          ? {
            options: pollOptions,
            durationMinutes: Math.max(
              5,
              Math.min(
                10080,
                Math.trunc(
                  Number(
                    rawPoll?.durationMinutes ?? rawPoll?.duration_minutes,
                  ) ||
                    1440,
                ),
              ),
            ),
          }
          : null;
        const dryRun = body.dryRun === true;
        if (!text) return json({ success: false, error: "text required" }, 400);
        // X Premium(認証済みアカウント)は最大25,000字の長文ポストが可能。280字で弾かない。
        if (text.length > 25000) {
          return json({
            success: false,
            error: "text exceeds 25000 characters",
          }, 400);
        }
        const longReplyIndex = replyTexts.findIndex((entry) =>
          entry.length > 25000
        );
        if (longReplyIndex >= 0) {
          return json({
            success: false,
            error: `replyTexts[${longReplyIndex}] exceeds 25000 characters`,
          }, 400);
        }

        // R23: 内容アーキタイプ(data_report/news_briefing/product_promo)を
        // 第1級 A/B 次元として全投稿で記録する。クライアントの明示指定は意味値
        // のみ受理し、無ければリード+リプライ連結から決定的に分類する。
        const archetypeHint = normalizeArchetypeBucket(
          firstString(body.contentArchetype, body.content_archetype),
        );
        const contentArchetype = archetypeHint !== "unknown"
          ? archetypeHint
          : classifyPostArchetype([text, ...replyTexts].join("\n"));
        const postAttribution = resolveXPostAttribution(body);

        const baseLog = {
          text,
          reply_text: replyTexts[0] ?? null,
          reply_texts: replyTexts,
          posted_at: new Date().toISOString(),
          source: body.source ?? "growth-hub",
          media_url: mediaUrl || null,
          // R13: media 軸 A/B の一次データ。全投稿で video/image/text を必ず記録。
          // 実投稿時は下の posted 分岐が uploadMediaFromUrl の実 MIME で上書きする。
          media_type: classifyPostMediaType(mediaUrl, mediaType),
          content_archetype: contentArchetype,
          route: body.route ?? null,
          experiment_key: body.experimentKey ?? body.experiment_key ??
            "x_first_user_growth_10k",
          variant: postAttribution.variant,
          // Keep the canonical URL attribution beside variant so video posts
          // remain traceable through x_post_log -> snapshot -> performance.
          utm_content: postAttribution.utmContent,
          prompt_profile: body.promptProfile ?? body.prompt_profile ?? null,
          // 定型文フォールバック投稿を perf 計測で LLM 投稿と分離するための
          // 明示フラグ(旧行はフィールド欠落 = 非フォールバック扱いで後方互換)。
          fallback_used: body.fallbackUsed === true ||
            body.fallback_used === true,
          content_kind: body.contentKind ?? body.content_kind ?? null,
          link_in_reply: body.linkInReply === true ||
            body.link_in_reply === true,
          candidate_id: firstString(body.candidateId, body.candidate_id) ||
            null,
        };

        if (dryRun || !isXConfigured()) {
          const log = await addItem(admin, "x_post_log", logUserId, {
            ...baseLog,
            status: dryRun ? "dry_run" : "credentials_missing",
          });
          return json({
            success: true,
            posted: false,
            dryRun,
            account: getXAccountHandle(),
            text,
            replyText: replyTexts[0] ?? null,
            replyTexts,
            log,
            warning: dryRun
              ? undefined
              : "X API credentials are not configured in Supabase secrets.",
          });
        }

        // ── 近似重複ガード (実投稿の直前) ──────────────────────────────────
        // 同一/ほぼ同一の投稿を量産すると X に重複アカウント信号を送り、凍結
        // リスク+インプレ低下を招く。直近の投稿済み本文と類似度を測り、閾値
        // 超なら投稿せず拒否する。閾値/件数は env で調整可能。
        const dupConfig = resolveDuplicateGuardConfig({
          threshold: X_DUP_SIMILARITY_THRESHOLD,
          recentCount: X_DUP_RECENT_COUNT,
        });
        if (dupConfig.recentCount > 0) {
          // status!=posted の行で漏れないよう多めに取得してから posted を抽出。
          const scanLimit = Math.min(
            50,
            Math.max(dupConfig.recentCount * 4, dupConfig.recentCount),
          );
          const recentLogs = await listXPostLogs(
            admin,
            "service_role",
            scanLimit,
          );
          const recentPosts = extractPostedTexts(
            recentLogs as XPostLogRowLike[],
            dupConfig.recentCount,
          );
          const duplicate = findDuplicateContent(text, recentPosts, dupConfig);
          if (duplicate) {
            const rejectionLog = {
              ...baseLog,
              status: "rejected_duplicate",
              duplicate_similarity: duplicate.similarity,
              duplicate_threshold: duplicate.threshold,
              duplicate_matched_log_id: duplicate.matchedId,
              duplicate_matched_created_at: duplicate.matchedCreatedAt,
            };
            let log: unknown = null;
            try {
              log = await addItem(
                admin,
                "x_post_log",
                logUserId,
                rejectionLog,
              );
            } catch (_logError) {
              log = rejectionLog;
            }
            return json({
              success: false,
              posted: false,
              code: "duplicate_content",
              similarity: duplicate.similarity,
              threshold: duplicate.threshold,
              recentCount: dupConfig.recentCount,
              matchedCreatedAt: duplicate.matchedCreatedAt,
              account: getXAccountHandle(),
              actionRequired: "文面を変えて再生成してください",
              log,
            });
          }
        }

        // Re-read consent immediately before the irreversible API call. The
        // compose action may have run minutes earlier, and opt-out must win.
        if (
          scheduledHouseholdPost &&
          !await hasEnabledHouseholdTrackerConsent(admin, logUserId)
        ) {
          return json({
            success: false,
            posted: false,
            code: "household_consent_revoked",
            error: "Household tracker consent is no longer enabled",
          }, 409);
        }

        try {
          const uploadedMedia = mediaUrl
            ? await uploadMediaFromUrl(mediaUrl, {
              mediaType: mediaType || undefined,
              altText: mediaAlt || undefined,
            })
            : null;
          const result = await postTweet({
            text,
            mediaIds: uploadedMedia ? [uploadedMedia.mediaId] : undefined,
          });
          const replyResults = [];
          let parentTweetId = result.tweetId;
          let replyIndex = 0;
          for (const nextReplyText of replyTexts) {
            if (!parentTweetId) break;
            // poll は最初の text-only リプライにのみ添付する(media 付きリードには
            // 載せない = X の poll+media 同居禁止に準拠)。
            const replyResult = await postTweet({
              text: nextReplyText,
              replyToTweetId: parentTweetId,
              ...(replyIndex === 0 && poll ? { poll } : {}),
            });
            replyResults.push(replyResult);
            parentTweetId = replyResult.tweetId ?? parentTweetId;
            replyIndex += 1;
          }
          const replyTweetIds = replyResults
            .map((replyResult) => replyResult.tweetId)
            .filter((tweetId): tweetId is string => Boolean(tweetId));
          const log = await addItem(admin, "x_post_log", logUserId, {
            ...baseLog,
            status: "posted",
            tweet_id: result.tweetId,
            reply_tweet_id: replyTweetIds[0] ?? null,
            reply_tweet_ids: replyTweetIds,
            account: result.account,
            media_id: uploadedMedia?.mediaId ?? null,
            // R13: アップロード実 MIME(authoritative)を意味カテゴリへ正規化して
            // 記録(video/image/text)。baseLog の推定値を実測 MIME で上書きする。
            media_type: classifyPostMediaType(
              mediaUrl,
              uploadedMedia?.mediaType ?? mediaType,
            ),
            // 生 MIME も監査用に残す(拡張子判定の突合せ・将来の 1:1 実験用)。
            media_mime: uploadedMedia?.mediaType ?? null,
          });
          return json({
            success: true,
            posted: true,
            text,
            tweetId: result.tweetId,
            replyText: replyTexts[0] ?? null,
            replyTexts,
            replyTweetId: replyTweetIds[0] ?? null,
            replyTweetIds,
            account: result.account,
            ...(poll ? { pollAttached: true } : {}),
            log,
          });
        } catch (error) {
          const xPayload = isXApiError(error) ? error.payload : null;
          const message = errorMessage(error);
          const failureLog = {
            ...baseLog,
            status: "failed",
            error: message,
            code: xPayload?.code ?? "x_post_failed",
            x_api_status: xPayload?.status ?? null,
            x_api_reason: xPayload?.reason ?? null,
            action_required: xPayload?.actionRequired ?? null,
            // R15: spend cap 解除見込み日(ISO)。x.post_preflight が構造化値
            // として優先参照する(無ければ error 文の regex にフォールバック)。
            billing_blocked_until: xPayload?.billingBlockedUntil ?? null,
          };
          let log: unknown = null;
          try {
            log = await addItem(admin, "x_post_log", logUserId, failureLog);
          } catch (_logError) {
            log = failureLog;
          }
          return json({
            success: false,
            posted: false,
            error: message,
            code: xPayload?.code ?? "x_post_failed",
            account: getXAccountHandle(),
            xApiStatus: xPayload?.status ?? null,
            xApiReason: xPayload?.reason ?? null,
            xApiTitle: xPayload?.title ?? null,
            requiredEnrollment: xPayload?.requiredEnrollment ?? null,
            registrationUrl: xPayload?.registrationUrl ?? null,
            actionRequired: xPayload?.actionRequired ??
              "Check X API credentials and posting permissions.",
            billingBlockedUntil: xPayload?.billingBlockedUntil ?? null,
            log,
          });
        }
      }

      // ─── Automation ───────────────────────────────────────────────────────────
      case "automation.analyze": {
        const geminiKey2 = Deno.env.get("GEMINI_API_KEY") ?? "";
        if (!geminiKey2) return json({ success: true, recommendations: [] });
        const p2 = `グロース自動化の推奨事項を3つ提案してください。現状: ${
          JSON.stringify(body)
        }. JSON: {"recommendations":[{"action":"...","priority":"high|medium|low","impact":"..."}]}`;
        const r2 = await fetch(
          `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${geminiKey2}`,
          {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ contents: [{ parts: [{ text: p2 }] }] }),
          },
        );
        const res2 = await r2.json();
        const t2 = (
          res2 as {
            candidates?: [{ content: { parts: [{ text: string }] } }];
          }
        ).candidates?.[0]?.content?.parts?.[0]?.text ?? "{}";
        try {
          return json({
            success: true,
            ...JSON.parse(t2.replace(/```json\n?|\n?```/g, "")),
          });
        } catch {
          return json({ success: true, text: t2 });
        }
      }

      // ─── A/B Test ─────────────────────────────────────────────────────────────
      case "ab.list": {
        const items = await listItems(admin, "ab_test", userId!);
        return json({ success: true, items });
      }

      case "ab.create": {
        const item = await addItem(admin, "ab_test", userId!, {
          name: body.name,
          variants: body.variants ?? [],
          status: "active",
        });
        return json({ success: true, item });
      }

      case "ab.result": {
        const items = await listItems(admin, "ab_test", userId!, 100);
        return json({ success: true, tests: items });
      }

      // ─── Landing Page A/B Test (global, app_analytics 集計) ─────────────────
      case "landing.list_variants": {
        const CTA_VARIANTS = [
          {
            id: "cta_free",
            text: "無料で始める",
            color: "#4CAF50",
            style: "solid",
          },
          {
            id: "cta_try",
            text: "今すぐ試す",
            color: "#2196F3",
            style: "solid",
          },
          {
            id: "cta_join",
            text: "参加する（¥0）",
            color: "#FF5722",
            style: "solid",
          },
          {
            id: "cta_start",
            text: "5秒で登録 →",
            color: "#9C27B0",
            style: "outline",
          },
          {
            id: "cta_save",
            text: "月¥5,000節約する",
            color: "#FF9800",
            style: "gradient",
          },
          {
            id: "cta_ai",
            text: "AIに仕事を任せる",
            color: "#00BCD4",
            style: "gradient",
          },
        ];
        const HEADLINE_VARIANTS = [
          { id: "h_21apps", text: "21のアプリを1つに。しかも無料。" },
          { id: "h_ai", text: "AIが12部署を自動運営する次世代アプリ" },
          { id: "h_save", text: "月¥5,000以上のサブスクをゼロに" },
          { id: "h_future", text: "あなたがやるのは「ゴール設定」だけ" },
          { id: "h_all", text: "メモ・タスク・家計簿・SNS・AI — 全部入り" },
        ];
        const { data: assignments } = await admin
          .from("app_analytics")
          .select("metadata")
          .eq("source", "ab_test_assignment");
        const { data: conversions } = await admin
          .from("app_analytics")
          .select("metadata")
          .eq("source", "ab_test_conversion");
        const ctaStats: Record<string, { views: number; conversions: number }> =
          {};
        for (const a of assignments ?? []) {
          const cId = (a.metadata as Record<string, unknown>)
            .cta_variant as string;
          if (!cId) continue;
          if (!ctaStats[cId]) ctaStats[cId] = { views: 0, conversions: 0 };
          ctaStats[cId].views++;
        }
        for (const c of conversions ?? []) {
          const cId = (c.metadata as Record<string, unknown>)
            .cta_variant as string;
          if (cId && ctaStats[cId]) ctaStats[cId].conversions++;
        }
        const variants = [
          ...CTA_VARIANTS.map((v) => {
            const s = ctaStats[v.id] ?? { views: 0, conversions: 0 };
            const cvr = s.views > 0
              ? Math.round((s.conversions / s.views) * 10000) / 100
              : 0;
            return {
              ...v,
              kind: "cta",
              views: s.views,
              conversions: s.conversions,
              conversion_rate: cvr,
            };
          }),
          ...HEADLINE_VARIANTS.map((v) => ({
            ...v,
            kind: "headline",
            views: 0,
            conversions: 0,
            conversion_rate: 0,
          })),
        ];
        return json({ success: true, variants });
      }

      // ─── Quote ────────────────────────────────────────────────────────────────
      case "quote.create": {
        const item = await addItem(admin, "share_quote", userId!, {
          text: body.text,
          author: body.author ?? "",
          category: body.category ?? "general",
        });
        return json({ success: true, item });
      }

      case "quote.list": {
        const items = await listItems(admin, "share_quote", userId!);
        return json({ success: true, items });
      }

      case "quote.image": {
        // Return a placeholder image generation request stored in hub_data
        const item = await addItem(admin, "quote_image", userId!, {
          text: body.text,
          style: body.style ?? "minimal",
          status: "pending",
        });
        return json({ success: true, item });
      }

      // ─── SEO ──────────────────────────────────────────────────────────────────
      case "seo.optimize": {
        const geminiKey3 = Deno.env.get("GEMINI_API_KEY") ?? "";
        if (!geminiKey3) return json({ success: true, suggestions: [] });
        const p3 =
          `次のページのSEOを最適化してください: タイトル="${body.title}", 説明="${body.description}", キーワード="${body.keywords}". JSON: {"title":"...","description":"...","keywords":[],"score":0}`;
        const r3 = await fetch(
          `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${geminiKey3}`,
          {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ contents: [{ parts: [{ text: p3 }] }] }),
          },
        );
        const res3 = await r3.json();
        const t3 = (
          res3 as {
            candidates?: [{ content: { parts: [{ text: string }] } }];
          }
        ).candidates?.[0]?.content?.parts?.[0]?.text ?? "{}";
        try {
          return json({
            success: true,
            ...JSON.parse(t3.replace(/```json\n?|\n?```/g, "")),
          });
        } catch {
          return json({ success: true, text: t3 });
        }
      }

      // ─── Waitlist ─────────────────────────────────────────────────────────────
      case "waitlist.notify": {
        const resendKey = Deno.env.get("RESEND_API_KEY") ?? "";
        if (!resendKey) {
          return json({ error: "RESEND_API_KEY not configured" }, 503);
        }
        const wr = await fetch("https://api.resend.com/emails", {
          method: "POST",
          headers: {
            Authorization: `Bearer ${resendKey}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            from: "noreply@jibun.app",
            to: body.email,
            subject: "自分株式会社 — ウェイトリスト通知",
            html: `<p>${body.message ?? "ご登録ありがとうございます。"}</p>`,
          }),
        });
        return json({ success: wr.ok });
      }

      // ─── Viral Ad ─────────────────────────────────────────────────────────────
      case "viral_ad.create": {
        const item = await addItem(admin, "viral_ad", userId!, {
          title: body.title,
          headline: body.headline ?? "",
          cta: body.cta ?? "",
          platform: body.platform ?? "social",
          status: "draft",
        });
        return json({ success: true, item });
      }

      case "viral_ad.list": {
        const items = await listItems(admin, "viral_ad", userId!);
        return json({ success: true, items });
      }

      // ─── Viral Engine ─────────────────────────────────────────────────────────
      case "engine.run": {
        const item = await addItem(admin, "viral_engine_run", userId!, {
          trigger: body.trigger ?? "manual",
          target: body.target ?? "all",
          status: "queued",
        });
        return json({ success: true, item });
      }

      case "engine.stats": {
        const items = await listItems(admin, "viral_engine_run", userId!);
        return json({ success: true, items });
      }

      // ─── Default ──────────────────────────────────────────────────────────────
      default:
        return json({ error: `Unknown action: ${action}` }, 400);
    }
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
