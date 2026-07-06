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
  extractPostedTexts,
  findDuplicateContent,
  resolveDuplicateGuardConfig,
  type XPostLogRowLike,
} from "./x_duplicate_content.ts";
import {
  buildSignupSlackPayload,
  isRecentSignupCreatedAt,
  resolveSignupChannel,
} from "./signup_notification.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ??
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
// x.post 近似重複ガードの調整用 env (未設定時は既定 0.9 / 直近 5 件)。
const X_DUP_SIMILARITY_THRESHOLD = Deno.env.get("X_DUP_SIMILARITY_THRESHOLD") ??
  null;
const X_DUP_RECENT_COUNT = Deno.env.get("X_DUP_RECENT_COUNT") ?? null;

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
  if (error) throw new Error(error.message);
  return data ?? [];
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

const SUPPORTED_ACQUISITION_SIGNALS = new Set([
  "touch_landing",
  "touch_profile",
  "touch_import",
  "touch_public_memo",
  "touch_referral",
  "touch_comparison",
  "touch_guitar_gallery",
  "touch_x_first_user_growth",
  "import_preview_notion",
  "import_preview_evernote",
  "import_preview_markdown",
  "import_signup_cta",
  "public_memo_signup_cta",
  "x_first_user_trial_intent",
  "x_first_user_feedback_summary",
  "x_first_user_feedback_memo",
  "x_first_user_feedback_search",
  "x_first_user_feedback_x_intent",
  "signup_submit_landing",
  "signup_submit_profile",
  "signup_submit_import",
  "signup_submit_public_memo",
  "signup_submit_referral",
  "signup_submit_comparison",
  "signup_submit_guitar",
]);

function formatDateKey(date: Date): string {
  return `${date.getFullYear()}-${
    String(date.getMonth() + 1).padStart(2, "0")
  }-${String(date.getDate()).padStart(2, "0")}`;
}

function resolveDateKey(rawDateKey: unknown): string {
  return typeof rawDateKey === "string" &&
      /^\d{4}-\d{2}-\d{2}$/.test(rawDateKey)
    ? rawDateKey
    : formatDateKey(new Date());
}

function isSupportedAcquisitionSignal(signalKey: string): boolean {
  return SUPPORTED_ACQUISITION_SIGNALS.has(signalKey) ||
    /^touch_comparison_[a-z0-9_-]{1,64}$/i.test(signalKey);
}

async function recordAcquisitionSignal(
  admin: SupabaseClient,
  rawSignalKey: unknown,
  rawDateKey?: unknown,
) {
  const signalKey = String(rawSignalKey ?? "").trim();
  if (!signalKey || !isSupportedAcquisitionSignal(signalKey)) {
    return {
      success: false,
      error: "signalKey required / unsupported",
    };
  }

  const dateKey = resolveDateKey(rawDateKey);
  const { data: existing, error: existingError } = await admin
    .from("app_analytics")
    .select("date, source_details")
    .eq("date", dateKey)
    .maybeSingle();
  if (existingError) throw new Error(existingError.message);

  if (!existing) {
    const { error } = await admin.from("app_analytics").upsert({
      date: dateKey,
      landing_views: 0,
      conversions: 0,
      share_count: 0,
      source_details: { [signalKey]: 1 },
    });
    if (error) throw new Error(error.message);
    return { success: true, signalKey, dateKey };
  }

  const details = (existing.source_details ?? {}) as Record<string, unknown>;
  const next: Record<string, number> = {};
  for (const [key, value] of Object.entries(details)) {
    const count = typeof value === "number" ? value : Number(value);
    if (Number.isFinite(count) && count > 0) next[key] = count;
  }
  next[signalKey] = (next[signalKey] ?? 0) + 1;

  const { error } = await admin
    .from("app_analytics")
    .update({ source_details: next })
    .eq("date", dateKey);
  if (error) throw new Error(error.message);
  return { success: true, signalKey, dateKey };
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
    has_media: Boolean(metadata.media_url),
    media_url: firstString(metadata.media_url) || null,
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
  const targetsByLogId = new Map(
    logs.map((item) => [item.id, tweetTargetsForLog(item)]),
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
      warning: "No posted x_post_log rows with tweet_id were found.",
    };
  }

  const metrics = await fetchXTweetMetrics(tweetIds);
  const metricById = new Map(metrics.map((metric) => [metric.tweetId, metric]));
  const checkedAt = new Date().toISOString();
  const snapshots: Record<string, unknown>[] = [];

  for (const item of logs) {
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

function compactPostText(value: unknown): string {
  return firstString(value)
    .replace(/\s+/g, " ")
    .slice(0, 120);
}

function buildXPerformanceContextFromLogs(logs: XPostLogItem[]) {
  const rows = logs
    .map((item) => {
      const metadata = asRecord(item.metadata);
      const latest = asRecord(metadata.latest_metrics);
      const impressions = firstNumber(latest.impressions, metadata.impressions);
      const score = firstNumber(latest.score, metadata.engagement_score);
      if (impressions == null && score == null) return null;
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
        score: score ?? impressions ?? 0,
        createdAt: firstString(item.created_at),
      };
    })
    .filter((row): row is NonNullable<typeof row> => row !== null)
    .sort((left, right) => right.score - left.score);

  const winners = rows.slice(0, 5);
  const underperformers = rows.slice(-5).reverse();
  const byVariant = new Map<
    string,
    { variant: string; count: number; totalScore: number; maxScore: number }
  >();
  for (const row of rows) {
    const key = row.variant || "unknown";
    const current = byVariant.get(key) ?? {
      variant: key,
      count: 0,
      totalScore: 0,
      maxScore: 0,
    };
    current.count += 1;
    current.totalScore += row.score;
    current.maxScore = Math.max(current.maxScore, row.score);
    byVariant.set(key, current);
  }
  const variants = [...byVariant.values()]
    .map((entry) => ({
      ...entry,
      averageScore: Math.round(entry.totalScore / Math.max(1, entry.count)),
    }))
    .sort((left, right) => right.averageScore - left.averageScore);

  const bestVariant = variants[0]?.variant ?? "daily_briefing";
  // 集計ロールアップ (guarded): 両バケットに十分なサンプルがあるときだけ、
  // 変動要因(メディア有無/リンク位置/スレッド長)ごとの平均スコア差を測定事実と
  // して LLM へ渡す。データが薄い間は行自体を出さない(=実質 default-off で、
  // 投稿が貯まるほど自動的に有効化される)。従来は top-1 variant と逸話的な
  // winner 行のみで、集計済みの variants ランキングが未提示だった。
  const avgScore = (list: typeof rows): number =>
    list.length === 0
      ? 0
      : Math.round(list.reduce((sum, r) => sum + r.score, 0) / list.length);
  const structuralLines: string[] = [];
  const withMedia = rows.filter((r) => r.hasMedia);
  const withoutMedia = rows.filter((r) => !r.hasMedia);
  if (withMedia.length >= 2 && withoutMedia.length >= 2) {
    structuralLines.push(
      `Structural lift (media): avg score with media=${
        avgScore(withMedia)
      } (n=${withMedia.length}) vs without=${
        avgScore(withoutMedia)
      } (n=${withoutMedia.length}).`,
    );
  }
  const linkReply = rows.filter((r) => r.linkInReply);
  const linkLead = rows.filter((r) => !r.linkInReply);
  if (linkReply.length >= 2 && linkLead.length >= 2) {
    structuralLines.push(
      `Structural lift (link placement): avg score link-in-reply=${
        avgScore(linkReply)
      } (n=${linkReply.length}) vs link-in-lead=${
        avgScore(linkLead)
      } (n=${linkLead.length}).`,
    );
  }
  if (rows.length >= 3) {
    const buckets = [
      ["0 replies", rows.filter((r) => r.threadReplyCount === 0)],
      [
        "1-4 replies",
        rows.filter((r) => r.threadReplyCount >= 1 && r.threadReplyCount <= 4),
      ],
      ["5-8 replies", rows.filter((r) => r.threadReplyCount >= 5)],
    ].filter(([, list]) => (list as typeof rows).length > 0) as Array<
      [string, typeof rows]
    >;
    if (buckets.length >= 2) {
      buckets.sort((a, b) => avgScore(b[1]) - avgScore(a[1]));
      const [label, list] = buckets[0];
      structuralLines.push(
        `Best thread length so far: ${label} (avg score ${
          avgScore(list)
        }, n=${list.length}).`,
      );
    }
  }
  const distinctVariants = variants.filter((v) => v.variant !== "unknown");
  const rankingLine = distinctVariants.length >= 2
    ? `Variant ranking (avg score, n): ${
      distinctVariants.slice(0, 5).map((v) =>
        `${v.variant}=${v.averageScore} (n=${v.count})`
      ).join(", ")
    }.`
    : "";
  const promptContext = rows.length === 0
    ? [
      "No measured X performance has been collected yet.",
      "Run A/B test: daily_briefing vs question_post vs useful_reply.",
      "Target: 10K impressions. Lead with information value, put product CTA later, and collect metrics after posting.",
    ].join("\n")
    : [
      "Measured X performance context for the next post:",
      `Target: 10K impressions. Current best variant: ${bestVariant}.`,
      ...winners.map((row, index) =>
        `Winner ${index + 1}: variant=${row.variant}, impressions=${
          row.impressions ?? "unknown"
        }, score=${row.score}, media=${row.hasMedia}, linkInReply=${row.linkInReply}, replies=${row.threadReplyCount}, hook="${row.text}"`
      ),
      ...underperformers.slice(0, 3).map((row, index) =>
        `Avoid ${
          index + 1
        }: variant=${row.variant}, score=${row.score}, media=${row.hasMedia}, linkInReply=${row.linkInReply}, replies=${row.threadReplyCount}, hook="${row.text}"`
      ),
      ...(rankingLine ? [rankingLine] : []),
      ...structuralLines,
      ...(winners[0]
        ? [
          `Top hook to emulate (copy the structure, not the words): "${
            winners[0].text
          }"`,
        ]
        : []),
      "Use the winning structure, test one variable at a time, and keep the first post useful before adding the product CTA.",
    ].join("\n");

  return {
    success: true,
    rows,
    winners,
    underperformers,
    variants,
    bestVariant,
    promptContext,
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
  const logs = (await listXPostLogs(admin, userId, limit)) as XPostLogItem[];
  return buildXPerformanceContextFromLogs(logs);
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
  const performance = buildXPerformanceContextFromLogs(xLogs);
  const { data: payments, error } = await admin
    .from("hub_data")
    .select("id, metadata, created_at")
    .eq("source", "stripe_supporter_payment")
    .order("created_at", { ascending: false })
    .limit(limit);
  if (error) throw new Error(error.message);

  const paidPayments = (payments ?? [])
    .map((item) => {
      const metadata = asRecord(item.metadata);
      return {
        id: String(item.id),
        createdAt: String(item.created_at),
        amountJpy: firstNumber(metadata.amount_jpy, metadata.amount_total) ?? 0,
        paymentStatus: firstString(metadata.payment_status),
        variant: firstString(metadata.variant, "unknown"),
        experimentKey: firstString(metadata.experiment_key),
        sourceLogId: firstString(metadata.source_log_id),
        utmSource: firstString(metadata.utm_source),
        utmMedium: firstString(metadata.utm_medium),
        utmCampaign: firstString(metadata.utm_campaign),
        utmContent: firstString(metadata.utm_content),
        stripeCheckoutSessionId: firstString(
          metadata.stripe_checkout_session_id,
        ),
      };
    })
    .filter((row) => row.paymentStatus === "paid");

  const xRows = performance.rows as Array<{
    id: string;
    variant: string;
    impressions?: number | null;
    score: number;
  }>;
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
  for (const row of xRows) {
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
    current.impressions += firstNumber(row.impressions) ?? 0;
    current.score += row.score;
    byVariant.set(key, current);
  }
  for (const payment of paidPayments) {
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
      measuredXPosts: xRows.length,
      latestPaidSupporters: paidPayments.length,
      revenueJpy: paidPayments.reduce(
        (sum, payment) => sum + payment.amountJpy,
        0,
      ),
      bestVariantForRevenue: variants[0]?.variant ?? null,
      bestVariantForReach: performance.bestVariant,
    },
    variants,
    payments: paidPayments,
    xPerformance: {
      winners: performance.winners,
      underperformers: performance.underperformers,
      promptContext: performance.promptContext,
    },
    nextActions: paidPayments.length === 0
      ? [
        "Post the next high-information X variant with link-in-reply enabled.",
        "Use the Founding Supporter checkout URL from the billing page for one real supporter payment.",
        "After payment, rerun revenue.funnel_report and first_supporter_webhook_evidence.sql.",
      ]
      : [
        "Double down on the revenue-winning variant for the next 3 posts.",
        "Verify Stripe payout eligibility and bank payout evidence.",
      ],
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
    status: "completed",
    completed_at: new Date().toISOString(),
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
      "id, referrer_user_id, referred_user_id, referral_code, bonus_points, status, completed_at, created_at",
    )
    .eq("referrer_user_id", userId)
    .order("created_at", { ascending: false });
  if (error) throw new Error(error.message);

  const rows = (referrals ?? []) as ReferralRow[];
  const successfulReferrals =
    rows.filter((row) => row.status === "completed").length;
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
      },
    })),
    totalReferrals: rows.length,
    successfulReferrals,
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
      "acquisition.track",
      "acquisition.touchpoint_report",
      "signup.notify",
    ];
    let userId: string | null = null;
    if (!publicActions.includes(action)) {
      userId = await getUserId(req);
      if (!userId) return json({ error: "Unauthorized" }, 401);
    }

    switch (action) {
      // ─── Acquisition ───────────────────────────────────────────────────────
      case "acquisition.get": {
        const items = await listItems(admin, "growth_signal", userId!);
        return json({ success: true, items });
      }

      case "acquisition.track": {
        const result = await recordAcquisitionSignal(
          admin,
          body.signalKey ?? body.channel,
          body.dateKey,
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
        const result = await recordAcquisitionSignal(
          admin,
          body.signalKey,
          body.dateKey,
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
        const totalUsers = totalUsersResponse.data?.total ?? null;
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
        const [
          authListResult,
          { data: plansData },
          { count: achievementsCount },
        ] = await Promise.all([
          admin.auth.admin.listUsers({ page: 1, perPage: 1 }),
          admin
            .from("growth_plans")
            .select(
              "label, deadline, target, features_done, features_total, sort_order",
            )
            .order("sort_order", { ascending: true })
            .order("target", { ascending: true }),
          admin
            .from("development_achievements")
            .select("id", { count: "exact", head: true }),
        ]);
        const totalUsers =
          ((authListResult.data as { total?: number } | null)?.total) ?? 0;
        const totalAchievements = achievementsCount ?? 0;
        const plans = _applyAchievements(
          (plansData ?? []) as Array<
            {
              label: string;
              deadline: string;
              target: number;
              features_done: number;
              features_total: number;
              sort_order?: number;
            }
          >,
          totalAchievements,
        );
        return json({
          success: true,
          userCount: totalUsers,
          achievementsCount: totalAchievements,
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
        try {
          return json(await collectXPostMetrics(admin, userId!, body.limit));
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

      case "x.performance_context": {
        return json(await buildXPerformanceContext(admin, userId!, body.limit));
      }

      case "revenue.funnel_report": {
        return json(
          await buildRevenueFunnelReport(admin, userId!, body.limit),
        );
      }

      case "x.post": {
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

        const baseLog = {
          text,
          reply_text: replyTexts[0] ?? null,
          reply_texts: replyTexts,
          posted_at: new Date().toISOString(),
          source: body.source ?? "growth-hub",
          media_url: mediaUrl || null,
          route: body.route ?? null,
          experiment_key: body.experimentKey ?? body.experiment_key ??
            "x_first_user_growth_10k",
          variant: body.variant ?? body.utmContent ?? body.utm_content ?? null,
          prompt_profile: body.promptProfile ?? body.prompt_profile ?? null,
          // 定型文フォールバック投稿を perf 計測で LLM 投稿と分離するための
          // 明示フラグ(旧行はフィールド欠落 = 非フォールバック扱いで後方互換)。
          fallback_used: body.fallbackUsed === true ||
            body.fallback_used === true,
          content_kind: body.contentKind ?? body.content_kind ?? null,
          link_in_reply: body.linkInReply === true ||
            body.link_in_reply === true,
        };

        if (dryRun || !isXConfigured()) {
          const log = await addItem(admin, "x_post_log", userId!, {
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
          const recentLogs = await listXPostLogs(admin, userId!, scanLimit);
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
              log = await addItem(admin, "x_post_log", userId!, rejectionLog);
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
          const log = await addItem(admin, "x_post_log", userId!, {
            ...baseLog,
            status: "posted",
            tweet_id: result.tweetId,
            reply_tweet_id: replyTweetIds[0] ?? null,
            reply_tweet_ids: replyTweetIds,
            account: result.account,
            media_id: uploadedMedia?.mediaId ?? null,
            media_type: uploadedMedia?.mediaType ?? null,
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
          };
          let log: unknown = null;
          try {
            log = await addItem(admin, "x_post_log", userId!, failureLog);
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
