// schedule-hub — スケジュール・ブログ・X投稿・自動化統合EF
// Merges (6 EFs): schedule-daily-digest, schedule-manager, notification-center(reminders),
//   post-x-update, blog-post-manager, blog-auto-publisher
//
// Note: schedule-daily-digest and post-x-update have their own standalone files
// that are called externally by Claude Code Schedule. This hub is for new code;
// CLAUDE.md references will be updated to use this hub. The standalone EFs will
// be kept in Supabase but removed from the deploy list.

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient, SupabaseClient } from "npm:@supabase/supabase-js@2";
import {
  getXAccountHandle,
  isXConfigured,
  postTweet,
  uploadMediaFromUrl,
} from "../_shared/x-client.ts";
import {
  externalFetch,
  externalFetchErrorPayload,
  isExternalFetchError,
} from "../_shared/external_fetch.ts";
import { buildOwnSiteBlogPostUrl } from "./blog_canonical.ts";
import {
  isQiitaAccessEnabled,
  resolveBlogPublishPlatforms,
} from "./blog_publish_policy.ts";
import {
  allPlatformsFailed,
  type BlogUpstreamApi,
  buildUpstreamErrorPayload,
  summarizePlatformFailures,
} from "./upstream_error.ts";
import { requiredAuthLevel } from "./action_auth.ts";
import { summarizeStripeAccountReadiness } from "./stripe_account_readiness.ts";
import {
  billingAllowedHosts,
  resolveBillingReturnUrl,
} from "./billing_return_url.ts";
import {
  classifySupporterBuyer,
  type SupporterBuyerContext,
  supporterBuyerStripeParams,
} from "../_shared/supporter_buyer.ts";
import {
  videoCreditPack,
  videoCreditPackMetadata,
} from "../_shared/video_credit_packs.ts";
import {
  isMissingStripeCustomer,
  stripeApiErrorDetails,
  stripeApiErrorFromResponse,
} from "./stripe_api_error.ts";
import {
  buildNotionProperties,
  extractNotionErrorDetail,
  type NotionPropertyMapping as NotionBuilderMapping,
} from "../_shared/notion_property_builder.ts";
import {
  NOTION_API_VERSION,
  NotionDataSourceError,
  resolveNotionDataSourceId,
} from "../_shared/notion_data_source.ts";

// WBS -> Notion データベースの列マッピング (Issue #1287)。
// Notion は Title-type property の内部 ID を常に "title" に固定するため、
// rich_text 列は "task_title" にリネーム済 (title 名の衝突回避)。
// buildNotionProperties が型別の厳格ラップ + title 衝突検知を一元化する。
const NOTION_WBS_PROPERTY_MAPPINGS: NotionBuilderMapping[] = [
  { name: "id", type: "title" },
  { name: "task_title", type: "rich_text" },
  { name: "instance", type: "select" },
  { name: "status", type: "select" },
  { name: "progress", type: "number" },
  { name: "deadline", type: "date" },
  { name: "updated_at", type: "date" },
];

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, traceparent, tracestate, baggage, sentry-trace",
  "Access-Control-Max-Age": "86400",
};
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";
const NOTION_VERSION = NOTION_API_VERSION;

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

async function getUserId(req: Request): Promise<string | null> {
  const auth = req.headers.get("Authorization") ?? "";
  if (!auth) return null;
  const c = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: auth } },
  });
  const {
    data: { user },
  } = await c.auth.getUser();
  return user?.id ?? null;
}

function isServiceRoleRequest(req: Request): boolean {
  const token = (req.headers.get("Authorization") ?? "").replace(
    /^Bearer\s+/i,
    "",
  ).trim();
  return Boolean(SERVICE_ROLE_KEY && token && token === SERVICE_ROLE_KEY);
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

async function deleteItem(
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

function asString(value: unknown, fallback = ""): string {
  return typeof value === "string" ? value.trim() : fallback;
}

function asRecord(value: unknown): Record<string, unknown> | null {
  return typeof value === "object" && value !== null && !Array.isArray(value)
    ? value as Record<string, unknown>
    : null;
}

function asStringList(value: unknown, fallback: string[]): string[] {
  return Array.isArray(value)
    ? value.map((item) => String(item).trim()).filter(Boolean)
    : fallback;
}

function normalizeMaintenanceScope(value: unknown): "system" | "feature" {
  return asString(value).toLowerCase() === "feature" ? "feature" : "system";
}

function normalizeMaintenanceSeverity(
  value: unknown,
): "info" | "warning" | "critical" {
  const normalized = asString(value, "info").toLowerCase();
  if (normalized === "critical" || normalized === "warning") return normalized;
  return "info";
}

function normalizeMaintenanceTimestamp(value: unknown, field: string): string {
  const raw = asString(value);
  const parsed = raw ? new Date(raw) : null;
  if (!parsed || Number.isNaN(parsed.getTime())) {
    throw new Error(`${field} must be a valid ISO timestamp`);
  }
  return parsed.toISOString();
}

function normalizeMaintenanceNoticeDays(value: unknown): number {
  const raw = typeof value === "number" ? value : Number(value ?? 3);
  if (!Number.isFinite(raw)) return 3;
  return Math.max(0, Math.min(30, Math.round(raw)));
}

function maintenanceFeatureList(value: unknown): string[] {
  return asStringList(value, [])
    .map((item) => item.replace(/^\/+/, "").toLowerCase())
    .filter(Boolean);
}

function maintenancePayload(
  body: Record<string, unknown>,
  userId: string | null,
  partial = false,
): Record<string, unknown> {
  const payload: Record<string, unknown> = {};
  if (!partial || body.scope !== undefined) {
    payload.scope = normalizeMaintenanceScope(body.scope);
  }
  if (!partial || body.affected_features !== undefined) {
    payload.affected_features = maintenanceFeatureList(body.affected_features);
  }
  if (!partial || body.starts_at !== undefined) {
    payload.starts_at = normalizeMaintenanceTimestamp(
      body.starts_at,
      "starts_at",
    );
  }
  if (!partial || body.ends_at !== undefined) {
    payload.ends_at = normalizeMaintenanceTimestamp(body.ends_at, "ends_at");
  }
  if (!partial || body.notice_days_before !== undefined) {
    payload.notice_days_before = normalizeMaintenanceNoticeDays(
      body.notice_days_before,
    );
  }
  if (!partial || body.message_ja !== undefined) {
    const message = asString(body.message_ja);
    if (!message) throw new Error("message_ja is required");
    payload.message_ja = message;
  }
  if (body.message_en !== undefined) {
    payload.message_en = asString(body.message_en) || null;
  }
  if (!partial || body.severity !== undefined) {
    payload.severity = normalizeMaintenanceSeverity(body.severity);
  }
  if (!partial && userId) payload.created_by = userId;
  const scope = payload.scope ?? body.scope;
  const features = payload.affected_features ?? body.affected_features;
  if (scope === "feature" && maintenanceFeatureList(features).length === 0) {
    throw new Error("affected_features is required for feature scope");
  }
  const starts = payload.starts_at ? new Date(String(payload.starts_at)) : null;
  const ends = payload.ends_at ? new Date(String(payload.ends_at)) : null;
  if (starts && ends && ends <= starts) {
    throw new Error("ends_at must be after starts_at");
  }
  return payload;
}

function maintenanceWindowVisible(
  row: Record<string, unknown>,
  now: Date,
): boolean {
  const startsAt = new Date(asString(row.starts_at));
  const endsAt = new Date(asString(row.ends_at));
  if (Number.isNaN(startsAt.getTime()) || Number.isNaN(endsAt.getTime())) {
    return false;
  }
  const noticeDays = normalizeMaintenanceNoticeDays(row.notice_days_before);
  const visibleFrom = new Date(startsAt.getTime() - noticeDays * 86400000);
  return now >= visibleFrom && now < endsAt;
}

function billingPriceId(tier: string): string {
  const normalized = tier === "team" ? "TEAM" : "PRO";
  // .trim(): Supabase secret に紛れ込んだ前後の空白/改行で "No such price" 等に
  // ならないよう防御 (live 移行時のコピペ事故も吸収)。
  return (Deno.env.get(`STRIPE_${normalized}_PRICE_ID`) ??
    Deno.env.get(`STRIPE_PRICE_${normalized}`) ??
    "").trim();
}

function stripeSecretKey(): string {
  return (Deno.env.get("STRIPE_SECRET_KEY") ?? "").trim();
}

function normalizeCheckoutTier(value: unknown): "pro" | "team" {
  return String(value ?? "pro").toLowerCase() === "team" ? "team" : "pro";
}

function currentBillingPeriodStart(): string {
  const now = new Date();
  return new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1))
    .toISOString()
    .slice(0, 10);
}

function billingReturnUrl(value: unknown, fallbackPath: string): string {
  const base = (Deno.env.get("PUBLIC_SITE_URL") ??
    Deno.env.get("SITE_URL") ??
    "https://my-web-app-b67f4.web.app").trim();
  // open-redirect 対策: return_url は host allowlist で検証する。
  // billing.create_supporter_checkout_session は非ログイン公開 action のため、
  // 無検証だと攻撃者が checkout 後に任意の外部サイトへ誘導できる。
  const extraHosts = (Deno.env.get("BILLING_RETURN_URL_ALLOWED_HOSTS") ?? "")
    .split(",");
  const allowedHosts = billingAllowedHosts(base, extraHosts);
  return resolveBillingReturnUrl(value, fallbackPath, { base, allowedHosts });
}

function withBillingParam(url: string, value: string): string {
  const parsed = new URL(url);
  parsed.searchParams.set("billing", value);
  return parsed.toString();
}

function supporterAmountJpy(): number {
  const raw = Number(Deno.env.get("STRIPE_SUPPORTER_AMOUNT_JPY") ?? 100);
  return Number.isFinite(raw) && raw >= 100 ? Math.trunc(raw) : 100;
}

function stripeMetadataValue(value: unknown): string {
  const normalized = asString(value);
  return normalized.length > 160 ? normalized.slice(0, 160) : normalized;
}

function supporterAttributionParams(
  body: Record<string, unknown>,
): Record<string, string> {
  const fields = [
    "utm_source",
    "utm_medium",
    "utm_campaign",
    "utm_content",
    "experiment_key",
    "variant",
    "source_log_id",
    "landing_touchpoint",
  ];
  const params: Record<string, string> = {};
  for (const field of fields) {
    const value = stripeMetadataValue(body[field]);
    if (!value) continue;
    params[`metadata[${field}]`] = value;
    params[`payment_intent_data[metadata][${field}]`] = value;
  }
  return params;
}

function checkoutAttributionParams(
  body: Record<string, unknown>,
): Record<string, string> {
  const fields = [
    "latest_touchpoint",
    "signup_signal",
    "referral_channel",
  ];
  const params: Record<string, string> = {};
  for (const field of fields) {
    const value = stripeMetadataValue(body[field]);
    if (!value) continue;
    params[`metadata[${field}]`] = value;
    params[`subscription_data[metadata][${field}]`] = value;
  }
  return params;
}

async function stripePostForm(
  path: string,
  params: Record<string, string>,
): Promise<Record<string, unknown>> {
  const key = stripeSecretKey();
  if (!key) {
    throw new Error("STRIPE_SECRET_KEY not configured");
  }
  const response = await fetch(`https://api.stripe.com/v1${path}`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${key}`,
      "Content-Type": "application/x-www-form-urlencoded",
      "Stripe-Version": "2026-06-24.dahlia",
    },
    body: new URLSearchParams(params),
  });
  const data = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw stripeApiErrorFromResponse(response.status, data);
  }
  return asRecord(data) ?? {};
}

async function stripeGet(
  path: string,
): Promise<Record<string, unknown>> {
  const key = stripeSecretKey();
  if (!key) {
    throw new Error("STRIPE_SECRET_KEY not configured");
  }
  const response = await fetch(`https://api.stripe.com/v1${path}`, {
    method: "GET",
    headers: {
      Authorization: `Bearer ${key}`,
      "Stripe-Version": "2026-06-24.dahlia",
    },
  });
  const data = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw stripeApiErrorFromResponse(response.status, data);
  }
  return asRecord(data) ?? {};
}

async function getBillingSubscription(
  admin: SupabaseClient,
  userId: string,
): Promise<Record<string, unknown> | null> {
  const { data, error } = await admin
    .from("billing_subscriptions")
    .select("*")
    .eq("user_id", userId)
    .maybeSingle();
  if (error) throw new Error(error.message);
  return asRecord(data);
}

async function getOrCreateStripeCustomer(
  admin: SupabaseClient,
  userId: string,
  replaceExisting = false,
): Promise<string> {
  const current = await getBillingSubscription(admin, userId);
  const existingCustomer = asString(current?.stripe_customer_id);
  if (existingCustomer && !replaceExisting) return existingCustomer;

  const { data: userData, error: userError } = await admin.auth.admin
    .getUserById(userId);
  if (userError) throw new Error(userError.message);

  const customer = await stripePostForm("/customers", {
    email: userData.user?.email ?? "",
    "metadata[user_id]": userId,
  });
  const customerId = asString(customer.id);
  if (!customerId) throw new Error("Stripe customer id missing");

  const { error } = await admin.from("billing_subscriptions").upsert({
    user_id: userId,
    stripe_customer_id: customerId,
    tier: asString(current?.tier, "free"),
    status: asString(current?.status, "active"),
    metadata: {
      ...(asRecord(current?.metadata) ?? {}),
      source: replaceExisting ? "checkout_customer_repair" : "checkout",
    },
  }, { onConflict: "user_id" });
  if (error) throw new Error(error.message);
  return customerId;
}

async function resolveSupporterBuyerContext(
  admin: SupabaseClient,
  userId: string | null,
): Promise<SupporterBuyerContext> {
  if (!userId) return classifySupporterBuyer({ userId: null });

  const [authResult, profileResult] = await Promise.all([
    admin.auth.admin.getUserById(userId),
    admin
      .from("user_profiles")
      .select("is_admin, role")
      .eq("user_id", userId)
      .maybeSingle(),
  ]);
  if (authResult.error) throw new Error(authResult.error.message);
  if (profileResult.error) throw new Error(profileResult.error.message);

  const profile = asRecord(profileResult.data) ?? {};
  const authMetadata = asRecord(authResult.data.user?.app_metadata) ?? {};
  return classifySupporterBuyer({
    userId,
    isAnonymous: authResult.data.user?.is_anonymous === true,
    profileIsAdmin: profile.is_admin === true,
    profileRole: asString(profile.role) || null,
    authRole: asString(authMetadata.role) || null,
  });
}

function defaultNewsSignalFeeds(): Array<Record<string, string>> {
  return [
    {
      title: "NHK NEWS WEB",
      url: "https://www3.nhk.or.jp/rss/news/cat0.xml",
      category: "総合",
    },
    {
      title: "ITmedia NEWS",
      url: "https://rss.itmedia.co.jp/rss/2.0/news_bursts.xml",
      category: "IT",
    },
    {
      title: "ITmedia AI+",
      url: "https://rss.itmedia.co.jp/rss/2.0/aiplus.xml",
      category: "AI",
    },
    {
      title: "CNET Japan",
      url: "http://feed.japan.cnet.com/rss/index.rdf",
      category: "IT",
    },
  ];
}

async function fetchNewsSignalsForDraft(
  body: Record<string, unknown>,
): Promise<Record<string, unknown>> {
  const url = `${SUPABASE_URL.replace(/\/$/, "")}/functions/v1/tools-hub`;
  const feeds = Array.isArray(body.feeds) && body.feeds.length > 0
    ? body.feeds
    : defaultNewsSignalFeeds();
  const res = await externalFetch(
    "tools-hub.rss.fetch_latest",
    url,
    {
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
        per_feed_limit: Number(body.per_feed_limit ?? 10),
        limit: Number(body.limit ?? 80),
        signal_limit: Number(body.signal_limit ?? 8),
      }),
    },
    { traceId: "schedule-hub.blog.news_signal_draft" },
  );
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    throw new Error(`tools-hub rss.fetch_latest failed: ${res.status}`);
  }
  return asRecord(data) ?? {};
}

function newsSignalTitle(signal: Record<string, unknown>): string {
  return asString(signal.title, "(無題)");
}

function shortenNewsDraftTitle(value: string, maxLength = 80): string {
  return value.length <= maxLength
    ? value
    : `${value.slice(0, Math.max(1, maxLength - 3))}...`;
}

function buildNewsSignalDraftMarkdown(
  signals: Record<string, unknown>[],
  fetchedAt: string,
): string {
  const lead = signals[0] ?? {};
  const leadSummary = asString(lead.summary);
  const lines = [
    `# ${newsSignalTitle(lead)}`,
    "",
    "> RSSニュースをAI外部脳の素材として取り込み、重要シグナルを抽出した自動下書きです。",
    "",
    `- 取得時刻: ${fetchedAt}`,
    `- 主要カテゴリ: ${asString(lead.category, "総合")}`,
    `- 初期信頼度: ${asString(lead.confidence, "unknown")}`,
    "",
    "## 要点",
    "",
    leadSummary ? `- ${leadSummary}` : "- 本文要約は公開前に追記する。",
    "",
    "## 注目シグナル",
    "",
  ];
  for (const signal of signals) {
    lines.push(
      `### ${newsSignalTitle(signal)}`,
      "",
      `- スコア: ${String(signal.signal_score ?? 0)}`,
      `- 出典: ${asString(signal.source, "RSS")}`,
      `- URL: ${asString(signal.url)}`,
      `- なぜ重要か: ${asString(signal.why_it_matters, "要確認")}`,
      `- 検証メモ: ${asString(signal.verification_warning, "一次情報を確認")}`,
      "",
    );
  }
  lines.push(
    "## 公開前チェック",
    "",
    "- 一次情報と公開日時を確認する",
    "- 固有名詞、金額、引用元を確認する",
    "- 投資・医療・法律など高リスク領域は断定表現を避ける",
    "- 関連する既存メモやブログ記事へリンクする",
    "",
    "## 次の自動化",
    "",
    "- raw/news に原文を保存",
    "- wiki/sources に要約を保存",
    "- blog_posts の draft を人間レビュー後に公開",
  );
  return lines.join("\n");
}

function newsMemoryDate(fetchedAt: string): string {
  return (/^\d{4}-\d{2}-\d{2}/.exec(fetchedAt)?.[0]) ??
    new Date().toISOString().slice(0, 10);
}

function newsMemorySlug(signal: Record<string, unknown>): string {
  const key = asString(signal.id) ||
    asString(signal.cluster_key) ||
    asString(signal.url) ||
    newsSignalTitle(signal);
  const slug = key
    .toLowerCase()
    .replace(/^https?:\/\//, "")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 96);
  return slug || "news-signal";
}

function newsMemorySnippet(content: string): string {
  return content.replace(/\s+/g, " ").trim().slice(0, 280);
}

function buildRawNewsMemoryContent(
  signal: Record<string, unknown>,
  fetchedAt: string,
): string {
  return [
    `# ${newsSignalTitle(signal)}`,
    "",
    `Source: ${asString(signal.url)}`,
    `Fetched: ${fetchedAt}`,
    `Published: ${asString(signal.published_at, "unknown")}`,
    `RSS Source: ${asString(signal.source, "RSS")}`,
    `Category: ${asString(signal.category, "general")}`,
    "",
    "## Raw Summary",
    "",
    asString(signal.summary, "No summary supplied by RSS feed."),
    "",
    "## Signal Metadata",
    "",
    `- score: ${String(signal.signal_score ?? 0)}`,
    `- confidence: ${asString(signal.confidence, "unknown")}`,
    `- cluster_key: ${asString(signal.cluster_key)}`,
  ].join("\n");
}

function buildWikiNewsSourceContent(
  signal: Record<string, unknown>,
  fetchedAt: string,
): string {
  return [
    `# ${newsSignalTitle(signal)}`,
    "",
    "## Source",
    "",
    `- URL: ${asString(signal.url)}`,
    `- RSS: ${asString(signal.source, "RSS")}`,
    `- fetched_at: ${fetchedAt}`,
    "",
    "## Summary",
    "",
    asString(signal.summary, "公開前に本文要約を追記する。"),
    "",
    "## Why It Matters",
    "",
    asString(signal.why_it_matters, "要確認"),
    "",
    "## Verification",
    "",
    asString(
      signal.verification_warning,
      "一次情報、日時、固有名詞を確認する。",
    ),
    "",
    "## Links",
    "",
    "- [[blog-news-automation]]",
    "- [[ai-external-brain]]",
  ].join("\n");
}

async function sha256Hex(content: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(content),
  );
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

async function memoryIndexRow(
  filePath: string,
  title: string,
  content: string,
  source: string,
  metadata: Record<string, unknown>,
) {
  return {
    file_path: filePath,
    title,
    content,
    snippet: newsMemorySnippet(content),
    content_hash: await sha256Hex(content),
    source,
    metadata,
  };
}

async function upsertExternalBrainNewsSignals(
  admin: SupabaseClient,
  signals: Record<string, unknown>[],
  fetchedAt: string,
  context: {
    dedupeKey: string;
    postId: string;
    userId: string | null;
    targetPlatforms: string[];
    tags: string[];
  },
) {
  const date = newsMemoryDate(fetchedAt);
  const rows = [];
  for (const signal of signals.slice(0, 8)) {
    const slug = newsMemorySlug(signal);
    const baseMetadata = {
      kind: "news_signal",
      generated_by: "schedule-hub.blog.news_signal_draft",
      fetched_at: fetchedAt,
      post_id: context.postId,
      dedupe_key: context.dedupeKey,
      user_id: context.userId,
      url: asString(signal.url),
      source_name: asString(signal.source, "RSS"),
      category: asString(signal.category, "general"),
      signal_score: Number(signal.signal_score ?? 0),
      confidence: asString(signal.confidence, "unknown"),
      target_platforms: context.targetPlatforms,
      tags: context.tags,
    };
    const rawContent = buildRawNewsMemoryContent(signal, fetchedAt);
    rows.push(
      await memoryIndexRow(
        `raw/news/${date}/${slug}.md`,
        `raw: ${newsSignalTitle(signal)}`,
        rawContent,
        "ai_external_brain_raw_news",
        { ...baseMetadata, layer: "raw" },
      ),
    );
    const wikiContent = buildWikiNewsSourceContent(signal, fetchedAt);
    rows.push(
      await memoryIndexRow(
        `wiki/sources/news/${date}/${slug}.md`,
        `wiki: ${newsSignalTitle(signal)}`,
        wikiContent,
        "ai_external_brain_wiki_source",
        { ...baseMetadata, layer: "wiki" },
      ),
    );
  }
  if (rows.length === 0) {
    return { success: true, upserted: 0, file_paths: [] };
  }
  const { data, error } = await admin
    .from("memory_index")
    .upsert(rows, { onConflict: "file_path" })
    .select("file_path");
  if (error) throw new Error(error.message);
  const filePaths = (data ?? [])
    .map((row: Record<string, unknown>) => asString(row.file_path))
    .filter(Boolean);
  return {
    success: true,
    upserted: filePaths.length || rows.length,
    file_paths: filePaths.length ? filePaths : rows.map((row) => row.file_path),
  };
}

type NewsLintSeverity = "info" | "warning" | "review_required" | "error";

type NewsLintFinding = {
  severity: NewsLintSeverity;
  code: string;
  file_path: string;
  title: string;
  message: string;
  post_id?: string;
  url?: string;
};

function newsRiskFlags(text: string): string[] {
  const lower = text.toLowerCase();
  const groups: Array<[string, string[]]> = [
    ["finance", [
      "投資",
      "利益",
      "市場",
      "株",
      "暗号資産",
      "仮想通貨",
      "トレード",
      "trading",
      "crypto",
      "market",
      "profit",
      "price",
    ]],
    ["election", ["選挙", "投票", "候補", "政党", "議員", "election", "vote"]],
    ["medical", ["医療", "病院", "薬", "治療", "medical", "medicine"]],
    ["legal", ["法律", "規制", "訴訟", "判決", "legal", "lawsuit"]],
    ["disaster", ["地震", "災害", "避難", "台風", "disaster", "earthquake"]],
    ["security", [
      "脆弱性",
      "漏洩",
      "攻撃",
      "security",
      "breach",
      "vulnerability",
    ]],
  ];
  return groups
    .filter(([, keywords]) =>
      keywords.some((keyword) => lower.includes(keyword.toLowerCase()))
    )
    .map(([name]) => name);
}

function sourceUrlFromNewsMemory(
  content: string,
  metadata: Record<string, unknown>,
): string {
  const fromMeta = asString(metadata.url);
  if (fromMeta) return fromMeta;
  const sourceMatch = content.match(/^Source:\s*(https?:\/\/\S+)/im);
  if (sourceMatch) return sourceMatch[1].trim();
  const urlMatch = content.match(/^-\s*URL:\s*(https?:\/\/\S+)/im);
  return urlMatch?.[1]?.trim() ?? "";
}

function fetchedAtFromNewsMemory(
  row: Record<string, unknown>,
  metadata: Record<string, unknown>,
): string {
  return asString(metadata.fetched_at) || asString(row.updated_at) ||
    new Date().toISOString();
}

function lintBlock(
  summary: Record<string, unknown>,
  findings: NewsLintFinding[],
) {
  const lines = [
    "NEWS_SIGNAL_LINT_START",
    `checked_at=${summary.checked_at}`,
    `status=${summary.status}`,
    `findings=${summary.finding_count}`,
  ];
  for (const finding of findings.slice(0, 8)) {
    lines.push(
      `- [${finding.severity}] ${finding.code}: ${finding.message} (${finding.file_path})`,
    );
  }
  lines.push("NEWS_SIGNAL_LINT_END");
  return lines.join("\n");
}

function replaceLintBlock(notes: string, block: string): string {
  const cleaned = notes
    .replace(/NEWS_SIGNAL_LINT_START[\s\S]*?NEWS_SIGNAL_LINT_END/g, "")
    .trim();
  return [cleaned, block].filter(Boolean).join("\n\n");
}

async function checkNewsUrl(url: string): Promise<boolean> {
  if (!/^https?:\/\//i.test(url)) return false;
  try {
    const head = await externalFetch("news-source", url, {
      method: "HEAD",
      headers: {
        "User-Agent":
          "my-web-app-news-lint/1.0 (+https://my-web-app-b67f4.web.app)",
      },
    }, {
      retries: 1,
      timeoutMs: 7_000,
      traceId: "schedule-hub.blog.news_signal_lint.head",
    });
    if (head.ok || head.status === 405 || head.status === 403) return true;
    const get = await externalFetch("news-source", url, {
      method: "GET",
      headers: {
        "User-Agent":
          "my-web-app-news-lint/1.0 (+https://my-web-app-b67f4.web.app)",
      },
    }, {
      retries: 1,
      timeoutMs: 7_000,
      traceId: "schedule-hub.blog.news_signal_lint.get",
    });
    return get.ok || get.status === 403;
  } catch (_) {
    return false;
  }
}

async function lintExternalBrainNewsSignals(
  admin: SupabaseClient,
  body: Record<string, unknown>,
) {
  const limit = clampNumber(body.limit, 80, 1, 300);
  const maxAgeDays = clampNumber(body.max_age_days, 3, 1, 30);
  const verifyLinks = Boolean(body.verify_links ?? false);
  const updatePosts = body.update_posts !== false;
  const checkedAt = new Date().toISOString();
  const { data, error } = await admin
    .from("memory_index")
    .select("file_path,title,content,source,metadata,updated_at")
    .in("source", [
      "ai_external_brain_raw_news",
      "ai_external_brain_wiki_source",
    ])
    .order("updated_at", { ascending: false })
    .limit(limit);
  if (error) throw new Error(error.message);

  const rows = ((data ?? []) as Array<Record<string, unknown>>)
    .filter((row) => asString(row.file_path));
  const findings: NewsLintFinding[] = [];
  const byKey = new Map<string, { raw: boolean; wiki: boolean }>();
  const postFindings = new Map<string, NewsLintFinding[]>();
  const linkChecks: Array<Promise<void>> = [];

  for (const row of rows) {
    const filePath = asString(row.file_path);
    const title = asString(row.title, filePath);
    const content = asString(row.content);
    const metadata = asRecord(row.metadata) ?? {};
    const postId = asString(metadata.post_id);
    const url = sourceUrlFromNewsMemory(content, metadata);
    const key = asString(metadata.dedupe_key) || asString(metadata.url) ||
      filePath.replace(/^(raw\/news|wiki\/sources\/news)\//, "");
    const pair = byKey.get(key) ?? { raw: false, wiki: false };
    if (filePath.startsWith("raw/news/")) pair.raw = true;
    if (filePath.startsWith("wiki/sources/news/")) pair.wiki = true;
    byKey.set(key, pair);

    const addFinding = (
      severity: NewsLintSeverity,
      code: string,
      message: string,
      targetUrl = url,
    ) => {
      const finding: NewsLintFinding = {
        severity,
        code,
        file_path: filePath,
        title,
        message,
        post_id: postId || undefined,
        url: targetUrl || undefined,
      };
      findings.push(finding);
      if (postId) {
        postFindings.set(postId, [
          ...(postFindings.get(postId) ?? []),
          finding,
        ]);
      }
    };

    if (!url) {
      addFinding("error", "missing_source_url", "Source URL is missing.");
    } else if (!/^https?:\/\//i.test(url)) {
      addFinding("error", "invalid_source_url", "Source URL is not http(s).");
    }
    if (
      content.includes("公開前に本文要約を追記") ||
      content.includes("No summary supplied")
    ) {
      addFinding("warning", "summary_stub", "Summary is still a stub.");
    }
    const risks = newsRiskFlags(`${title}\n${content}`);
    if (risks.length > 0) {
      addFinding(
        "review_required",
        "high_risk_topic",
        `Human review required before publish: ${risks.join(",")}.`,
      );
    }
    const fetchedAt = Date.parse(fetchedAtFromNewsMemory(row, metadata));
    if (Number.isFinite(fetchedAt)) {
      const ageDays = (Date.now() - fetchedAt) / 86_400_000;
      if (ageDays > maxAgeDays) {
        addFinding(
          "warning",
          "stale_source",
          `Source is older than ${maxAgeDays} days.`,
        );
      }
    }
    if (verifyLinks && url && linkChecks.length < 20) {
      linkChecks.push((async () => {
        if (!(await checkNewsUrl(url))) {
          addFinding(
            "error",
            "source_link_unreachable",
            "Source URL did not respond.",
          );
        }
      })());
    }
  }

  await Promise.all(linkChecks);
  for (const [key, pair] of byKey.entries()) {
    if (!pair.raw || !pair.wiki) {
      findings.push({
        severity: "warning",
        code: "raw_wiki_pair_incomplete",
        file_path: key,
        title: key,
        message: "External-brain raw/wiki pair is incomplete.",
      });
    }
  }

  const blocking = findings.filter((finding) =>
    finding.severity === "error" || finding.severity === "review_required"
  );
  const summary = {
    checked_at: checkedAt,
    status: blocking.length > 0 ? "review_required" : "pass",
    row_count: rows.length,
    finding_count: findings.length,
    blocking_count: blocking.length,
  };

  let updatedPosts = 0;
  if (updatePosts && postFindings.size > 0) {
    const postIds = [...postFindings.keys()].filter(Boolean);
    const { data: posts } = await admin
      .from("blog_posts")
      .select("id,notes,status")
      .in("id", postIds);
    for (const rawPost of posts ?? []) {
      const post = rawPost as Record<string, unknown>;
      const postId = asString(post.id);
      const localFindings = postFindings.get(postId) ?? [];
      const nextNotes = replaceLintBlock(
        asString(post.notes),
        lintBlock(summary, localFindings),
      );
      const shouldHold = localFindings.some((finding) =>
        finding.severity === "error" ||
        finding.severity === "review_required"
      );
      const update: Record<string, unknown> = { notes: nextNotes };
      if (shouldHold && asString(post.status) === "ready") {
        update.status = "draft";
      }
      const { error: updateErr } = await admin
        .from("blog_posts")
        .update(update)
        .eq("id", postId);
      if (!updateErr) updatedPosts++;
    }
  }

  await admin.from("hub_data").insert({
    source: "blog_news_signal_lint",
    metadata: {
      ...summary,
      updated_posts: updatedPosts,
      verify_links: verifyLinks,
    },
  });

  return {
    success: blocking.length === 0,
    ...summary,
    updated_posts: updatedPosts,
    findings,
  };
}

function normalizeNotionId(value: unknown): string {
  const raw = asString(value);
  if (!raw) return "";
  const compactIds = raw.replace(/-/g, "").match(/[0-9a-fA-F]{32}/g);
  const compact = compactIds?.at(-1)?.toLowerCase();
  if (!compact) return raw.replace(/^['"]|['"]$/g, "");
  return [
    compact.slice(0, 8),
    compact.slice(8, 12),
    compact.slice(12, 16),
    compact.slice(16, 20),
    compact.slice(20),
  ].join("-");
}

function asNumber(value: unknown, fallback: number): number {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string") {
    const parsed = Number(value);
    if (Number.isFinite(parsed)) return parsed;
  }
  return fallback;
}

function clampNumber(
  value: unknown,
  fallback: number,
  min: number,
  max: number,
): number {
  return Math.min(Math.max(asNumber(value, fallback), min), max);
}

function notionHeaders(token: string): Record<string, string> {
  return {
    "Authorization": `Bearer ${token}`,
    "Notion-Version": NOTION_VERSION,
    "Content-Type": "application/json",
  };
}

function mergeHeaders(
  base: Record<string, string>,
  extra: HeadersInit | undefined,
): HeadersInit {
  return { ...base, ...Object.fromEntries(new Headers(extra ?? {}).entries()) };
}

async function qiitaFetch(
  path: string,
  token: string,
  init: RequestInit = {},
  traceId = "schedule-hub.qiita",
): Promise<Response> {
  // 2026-07-12: account suspension kill switch. A token alone must never
  // reactivate traffic; operations must explicitly set QIITA_ACCESS_ENABLED=true.
  if (!isQiitaAccessEnabled(Deno.env.get("QIITA_ACCESS_ENABLED"))) {
    return new Response(
      JSON.stringify({
        message: "Qiita access disabled by QIITA_ACCESS_ENABLED",
      }),
      {
        status: 503,
        headers: { "Content-Type": "application/json" },
      },
    );
  }
  const url = path.startsWith("http")
    ? path
    : `https://qiita.com/api/v2${path}`;
  return await externalFetch(
    "qiita",
    url,
    {
      ...init,
      headers: mergeHeaders({ Authorization: `Bearer ${token}` }, init.headers),
    },
    { traceId },
  );
}

async function devtoFetch(
  path: string,
  apiKey: string,
  init: RequestInit = {},
  traceId = "schedule-hub.devto",
): Promise<Response> {
  const url = path.startsWith("http") ? path : `https://dev.to/api${path}`;
  return await externalFetch(
    "dev.to",
    url,
    {
      ...init,
      headers: mergeHeaders({ "api-key": apiKey }, init.headers),
    },
    { traceId },
  );
}

// 上流 4xx/5xx を統一 502 応答へ (単一 upstream action 用 / 方針は upstream_error.ts)
async function upstreamErrorJson(
  targetApi: BlogUpstreamApi,
  res: Response,
): Promise<Response> {
  const detail = await res.text().catch(() => "");
  return json(
    {
      success: false,
      ...buildUpstreamErrorPayload({ targetApi, status: res.status, detail }),
    },
    502,
  );
}

async function notionFetch(
  token: string,
  path: string,
  init: RequestInit = {},
): Promise<Response> {
  const traceId = `schedule-hub.notion${path}`;
  const response = await externalFetch(
    "notion",
    `https://api.notion.com/v1${path}`,
    {
      ...init,
      headers: mergeHeaders(notionHeaders(token), init.headers),
    },
    {
      traceId,
      retryStatuses: [408, 429, 500, 502, 503, 504],
      baseDelayMs: 1_000,
      maxDelayMs: 30_000,
      jitterRatio: 0.2,
    },
  );

  // Retryable responses only reach this point after succeeding; exhausted
  // retries throw ExternalFetchError. Log validation/auth details immediately
  // without retrying so CI and Edge logs retain Notion's request context.
  if (!response.ok) {
    const detail = await response.clone().text().catch(() => "");
    console.error(JSON.stringify({
      level: "ERROR",
      at: new Date().toISOString(),
      target_api: "notion",
      status: response.status,
      retryable: false,
      response_body: detail.slice(0, 500),
      request_id: response.headers.get("x-notion-request-id"),
      trace_id: traceId,
    }));
  }
  return response;
}

async function configuredNotionDataSourceId(
  token: string,
  databaseId: string | null | undefined,
  dataSourceId: string | null | undefined,
  dataSourceName: string | null | undefined,
): Promise<string> {
  return await resolveNotionDataSourceId(
    (path, init) => notionFetch(token, path, init),
    { databaseId, dataSourceId, dataSourceName },
  );
}

function notionRichText(content: string): Array<Record<string, unknown>> {
  const text = content.slice(0, 2000);
  return text ? [{ text: { content: text } }] : [];
}

function notionParagraph(content: string): Record<string, unknown> {
  return {
    object: "block",
    type: "paragraph",
    paragraph: { rich_text: notionRichText(content) },
  };
}

function notionCodeBlock(content: string): Record<string, unknown> {
  return {
    object: "block",
    type: "code",
    code: {
      language: "markdown",
      rich_text: notionRichText(content),
    },
  };
}

function chunkText(text: string, chunkSize = 1800, maxChunks = 80): string[] {
  const chunks: string[] = [];
  let rest = text;
  while (rest.length > 0 && chunks.length < maxChunks) {
    chunks.push(rest.slice(0, chunkSize));
    rest = rest.slice(chunkSize);
  }
  return chunks;
}

async function listNotionChildren(
  token: string,
  blockId: string,
  pageSize = 100,
): Promise<Array<Record<string, unknown>>> {
  const notionBlockId = normalizeNotionId(blockId);
  const children: Array<Record<string, unknown>> = [];
  let cursor: string | null = null;
  for (let i = 0; i < 10; i++) {
    const url = new URL(
      `https://api.notion.com/v1/blocks/${notionBlockId}/children`,
    );
    url.searchParams.set("page_size", String(pageSize));
    if (cursor) url.searchParams.set("start_cursor", cursor);
    const resp = await externalFetch(
      "notion",
      url,
      { headers: notionHeaders(token) },
      { traceId: "schedule-hub.notion.children" },
    );
    if (!resp.ok) {
      const detail = await resp.text().catch(() => "");
      throw new Error(
        `notion_children_failed: HTTP ${resp.status} ${detail.slice(0, 200)}`,
      );
    }
    const payload = await resp.json() as {
      results?: Array<Record<string, unknown>>;
      has_more?: boolean;
      next_cursor?: string | null;
    };
    children.push(...(payload.results ?? []));
    if (!payload.has_more || !payload.next_cursor) break;
    cursor = payload.next_cursor;
  }
  return children;
}

async function findOrCreateNotionChildPage(
  token: string,
  parentPageId: string,
  title: string,
): Promise<{ pageId: string; created: boolean }> {
  const notionParentPageId = normalizeNotionId(parentPageId);
  const children = await listNotionChildren(token, notionParentPageId);
  for (const child of children) {
    if (child.type !== "child_page") continue;
    const childPage = (child.child_page ?? {}) as Record<string, unknown>;
    if (asString(childPage.title) === title && child.id) {
      return { pageId: String(child.id), created: false };
    }
  }

  const resp = await notionFetch(token, "/pages", {
    method: "POST",
    body: JSON.stringify({
      parent: { page_id: notionParentPageId },
      properties: {
        title: { title: [{ text: { content: title } }] },
      },
    }),
  });
  if (!resp.ok) {
    const detail = await resp.text().catch(() => "");
    throw new Error(
      `notion_child_page_create_failed: HTTP ${resp.status} ${
        detail.slice(0, 200)
      }`,
    );
  }
  const payload = await resp.json() as { id?: string };
  if (!payload.id) {
    throw new Error("notion_child_page_create_failed: missing page id");
  }
  return { pageId: payload.id, created: true };
}

async function replaceNotionPageChildren(
  token: string,
  pageId: string,
  blocks: Array<Record<string, unknown>>,
  delayMs: number,
): Promise<{ archived: number; appended: number }> {
  const notionPageId = normalizeNotionId(pageId);
  const existing = await listNotionChildren(token, notionPageId);
  let archived = 0;
  for (const block of existing) {
    if (!block.id) continue;
    const resp = await notionFetch(token, `/blocks/${block.id}`, {
      method: "DELETE",
    });
    if (!resp.ok) {
      const detail = await resp.text().catch(() => "");
      throw new Error(
        `notion_block_delete_failed: HTTP ${resp.status} ${
          detail.slice(0, 180)
        }`,
      );
    }
    archived++;
    await new Promise((r) => setTimeout(r, delayMs));
  }

  let appended = 0;
  for (let i = 0; i < blocks.length; i += 100) {
    const children = blocks.slice(i, i + 100);
    const resp = await notionFetch(token, `/blocks/${notionPageId}/children`, {
      method: "PATCH",
      body: JSON.stringify({ children }),
    });
    if (!resp.ok) {
      const detail = await resp.text().catch(() => "");
      throw new Error(
        `notion_block_append_failed: HTTP ${resp.status} ${
          detail.slice(0, 180)
        }`,
      );
    }
    appended += children.length;
    await new Promise((r) => setTimeout(r, delayMs));
  }
  return { archived, appended };
}

async function upsertNotionDataSourcePage(
  token: string,
  dataSourceId: string,
  titleProperty: string,
  titleValue: string,
  properties: Record<string, unknown>,
): Promise<"created" | "updated"> {
  const notionDataSourceId = normalizeNotionId(dataSourceId);
  const queryResp = await notionFetch(
    token,
    `/data_sources/${notionDataSourceId}/query`,
    {
      method: "POST",
      body: JSON.stringify({
        filter: { property: titleProperty, title: { equals: titleValue } },
        page_size: 1,
      }),
    },
  );
  if (!queryResp.ok) {
    const detail = await queryResp.text().catch(() => "");
    throw new Error(
      `notion_db_query_failed: HTTP ${queryResp.status} ${
        detail.slice(0, 180)
      }`,
    );
  }
  const queryJson = await queryResp.json() as {
    results?: Array<{ id?: string }>;
  };
  const existingPageId = queryJson.results?.[0]?.id;

  if (existingPageId) {
    const patchResp = await notionFetch(
      token,
      `/pages/${normalizeNotionId(existingPageId)}`,
      {
        method: "PATCH",
        body: JSON.stringify({ properties }),
      },
    );
    if (!patchResp.ok) {
      const detail = await patchResp.text().catch(() => "");
      throw new Error(
        `notion_db_patch_failed: HTTP ${patchResp.status} ${
          detail.slice(0, 180)
        }`,
      );
    }
    return "updated";
  }

  const createResp = await notionFetch(token, "/pages", {
    method: "POST",
    body: JSON.stringify({
      parent: {
        type: "data_source_id",
        data_source_id: notionDataSourceId,
      },
      properties,
    }),
  });
  if (!createResp.ok) {
    const detail = await createResp.text().catch(() => "");
    throw new Error(
      `notion_db_create_failed: HTTP ${createResp.status} ${
        detail.slice(0, 180)
      }`,
    );
  }
  return "created";
}

type RequiredNotionProperty = {
  name: string;
  type: string;
};

type NotionPreflightCategory =
  | "missing_permission"
  | "missing_property"
  | "type_mismatch"
  | "internal_name_mismatch"
  | "advanced_property_constraint";

type NotionPreflightSeverity = "error" | "warning" | "info";

type NotionPreflightFinding = {
  category: NotionPreflightCategory;
  severity: NotionPreflightSeverity;
  message: string;
  property_name?: string;
  property_id?: string;
  property_type?: string;
  expected?: string;
  actual?: string;
  recommendation?: string;
};

type NotionPropertyMapping = {
  name: string;
  id: string;
  type: string;
};

const NOTION_WBS_REQUIRED_PROPERTIES: RequiredNotionProperty[] = [
  { name: "id", type: "title" },
  { name: "task_title", type: "rich_text" },
  { name: "instance", type: "select" },
  { name: "status", type: "select" },
  { name: "progress", type: "number" },
  { name: "deadline", type: "date" },
  { name: "updated_at", type: "date" },
];

function notionPreflightFetchCategory(
  status: number,
  detail: string,
): NotionPreflightCategory {
  const normalized = detail.toLowerCase();
  if (
    status === 401 ||
    status === 403 ||
    status === 404 ||
    normalized.includes("object_not_found") ||
    normalized.includes("unauthorized")
  ) {
    return "missing_permission";
  }
  return "advanced_property_constraint";
}

function notionPreflightFixes(
  findings: NotionPreflightFinding[],
): string[] {
  const fixes = new Set<string>();
  for (const finding of findings) {
    if (finding.severity === "info") continue;
    if (finding.recommendation) fixes.add(finding.recommendation);
  }
  return [...fixes];
}

async function validateNotionDatabaseSchema(
  token: string,
  dataSourceId: string,
  required: RequiredNotionProperty[],
  options: { checkAdvancedProperties?: boolean } = {},
): Promise<{
  ok: boolean;
  preflight_ok: boolean;
  error?: string;
  status?: number;
  detail?: string;
  missing: RequiredNotionProperty[];
  mismatched: Array<RequiredNotionProperty & { actual: string }>;
  detected: Record<string, string>;
  property_mappings: NotionPropertyMapping[];
  findings: NotionPreflightFinding[];
  human_fix_required: string[];
}> {
  const notionDataSourceId = normalizeNotionId(dataSourceId);
  const resp = await notionFetch(
    token,
    `/data_sources/${notionDataSourceId}`,
  );
  if (!resp.ok) {
    const detail = await resp.text().catch(() => "");
    const category = notionPreflightFetchCategory(resp.status, detail);
    const finding: NotionPreflightFinding = {
      category,
      severity: "error",
      message: `Notion data-source schema fetch failed: HTTP ${resp.status}.`,
      recommendation: category === "missing_permission"
        ? "Share the target Notion data source with the integration and verify the configured Notion IDs."
        : "Retry the Notion schema preflight and inspect the returned API detail.",
    };
    return {
      ok: false,
      preflight_ok: false,
      error: "notion_schema_fetch_failed",
      status: resp.status,
      detail: detail.slice(0, 300),
      missing: [],
      mismatched: [],
      detected: {},
      property_mappings: [],
      findings: [finding],
      human_fix_required: notionPreflightFixes([finding]),
    };
  }

  const payload = await resp.json() as {
    properties?: Record<string, Record<string, unknown>>;
  };
  const properties = payload.properties ?? {};
  const detected: Record<string, string> = {};
  const propertyMappings: NotionPropertyMapping[] = [];
  const findings: NotionPreflightFinding[] = [];
  for (const [name, property] of Object.entries(properties)) {
    const type = asString(property.type, "unknown");
    const propertyId = asString(property.id, name);
    detected[name] = type;
    propertyMappings.push({ name, id: propertyId, type });
    if (propertyId && propertyId !== name) {
      findings.push({
        category: "internal_name_mismatch",
        severity: "info",
        property_name: name,
        property_id: propertyId,
        property_type: type,
        message:
          `Notion property "${name}" uses API/internal id "${propertyId}".`,
        recommendation:
          "Persist UI name to internal id mappings from database schema/pages.retrieve before batch updates.",
      });
    }
  }

  const missing: RequiredNotionProperty[] = [];
  const mismatched: Array<RequiredNotionProperty & { actual: string }> = [];
  for (const property of required) {
    const actual = detected[property.name];
    if (!actual) {
      missing.push(property);
      findings.push({
        category: "missing_property",
        severity: "error",
        property_name: property.name,
        expected: property.type,
        message: `Required Notion property "${property.name}" is missing.`,
        recommendation:
          `Create a "${property.name}" property with type "${property.type}" in the WBS database.`,
      });
    } else if (actual !== property.type) {
      mismatched.push({ ...property, actual });
      findings.push({
        category: "type_mismatch",
        severity: "error",
        property_name: property.name,
        expected: property.type,
        actual,
        message:
          `Notion property "${property.name}" has type "${actual}", expected "${property.type}".`,
        recommendation:
          `Change "${property.name}" to type "${property.type}" or update the sync property mapping.`,
      });
    }
  }

  if (options.checkAdvancedProperties === true) {
    for (const [name, property] of Object.entries(properties)) {
      const type = asString(property.type, "unknown");
      const propertyId = asString(property.id, name);
      if (type === "relation") {
        const relation = (property.relation ?? {}) as Record<string, unknown>;
        let relationDataSourceId = asString(relation.data_source_id);
        const relationDbId = asString(relation.database_id);
        if (!relationDataSourceId && !relationDbId) {
          findings.push({
            category: "advanced_property_constraint",
            severity: "warning",
            property_name: name,
            property_id: propertyId,
            property_type: type,
            message:
              `Relation property "${name}" does not expose a target data-source or database ID.`,
            recommendation:
              "Verify the relation target database is shared with the Notion integration.",
          });
          continue;
        }

        if (!relationDataSourceId) {
          try {
            relationDataSourceId = await configuredNotionDataSourceId(
              token,
              relationDbId,
              null,
              null,
            );
          } catch (error) {
            findings.push({
              category: "advanced_property_constraint",
              severity: "error",
              property_name: name,
              property_id: propertyId,
              property_type: type,
              message:
                `Relation target for "${name}" could not be resolved to a data source: ${
                  String(error)
                }.`,
              recommendation:
                "Share the related database and configure an explicit data-source ID if it has multiple data sources.",
            });
            continue;
          }
        }
        const relationResp = await notionFetch(
          token,
          `/data_sources/${normalizeNotionId(relationDataSourceId)}`,
        );
        if (!relationResp.ok) {
          const detail = await relationResp.text().catch(() => "");
          findings.push({
            category: notionPreflightFetchCategory(relationResp.status, detail),
            severity: "error",
            property_name: name,
            property_id: propertyId,
            property_type: type,
            message:
              `Relation target for "${name}" is not accessible: HTTP ${relationResp.status}.`,
            recommendation:
              "Share every related Notion database with the integration before WBS sync.",
          });
        }
      } else if (type === "formula") {
        const formula = (property.formula ?? {}) as Record<string, unknown>;
        const expression = asString(formula.expression);
        const referencedProps = (expression.match(/prop\(/g) ?? []).length;
        findings.push({
          category: "advanced_property_constraint",
          severity: referencedProps >= 10 ? "warning" : "info",
          property_name: name,
          property_id: propertyId,
          property_type: type,
          message:
            `Formula property "${name}" should be treated as read-only computed data in sync preflight.`,
          recommendation:
            "Do not write Formula values directly; fetch page values after update and warn if Formula depth or dependencies become unstable.",
        });
      } else if (type === "rollup") {
        const rollup = (property.rollup ?? {}) as Record<string, unknown>;
        const rollupFunction = asString(rollup.function, "unknown");
        findings.push({
          category: "advanced_property_constraint",
          severity: "warning",
          property_name: name,
          property_id: propertyId,
          property_type: type,
          actual: rollupFunction,
          message:
            `Rollup property "${name}" uses aggregate "${rollupFunction}" and may require page property item pagination.`,
          recommendation:
            "Use the Page property item API for Rollup/Relation values over 25 references, or compute the aggregate in Supabase before syncing.",
        });
      }
    }
  }

  const preflightOk = !findings.some((finding) => finding.severity === "error");
  return {
    ok: missing.length === 0 && mismatched.length === 0,
    preflight_ok: preflightOk,
    missing,
    mismatched,
    detected,
    property_mappings: propertyMappings,
    findings,
    human_fix_required: notionPreflightFixes(findings),
  };
}

function memoryTypeFor(filePath: string, source: unknown): string {
  const name = filePath.split(/[\\/]/).pop() ?? filePath;
  if (name.startsWith("feedback_success_")) return "feedback_success";
  if (name.startsWith("feedback_correction_")) return "feedback_correction";
  if (name.startsWith("project_")) return "project";
  const s = asString(source, "project");
  return ["feedback_success", "feedback_correction", "project"].includes(s)
    ? s
    : "project";
}

function dateFromMemoryPath(
  filePath: string,
  fallback: unknown,
): string | null {
  const match = filePath.match(/(20\d{2})(\d{2})(\d{2})/);
  if (match) return `${match[1]}-${match[2]}-${match[3]}`;
  const fallbackString = asString(fallback);
  return fallbackString ? fallbackString.slice(0, 10) : null;
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

    // 認可: action ごとの必要レベルは action_auth.ts (純ロジック) に集約
    const authLevel = requiredAuthLevel(action);
    const serviceRoleRequest = isServiceRoleRequest(req);
    let userId: string | null = null;
    if (authLevel === "service_role" && !serviceRoleRequest) {
      return json({ error: "Unauthorized" }, 401);
    }
    if (authLevel === "user" && !serviceRoleRequest) {
      userId = await getUserId(req);
      if (!userId) return json({ error: "Unauthorized" }, 401);
    }
    if (
      authLevel === "public" &&
      !serviceRoleRequest &&
      action === "billing.create_supporter_checkout_session"
    ) {
      userId = await getUserId(req);
    }

    switch (action) {
      case "billing.get_stripe_account_readiness": {
        const key = stripeSecretKey();
        const account = await stripeGet("/account");
        return json({
          success: true,
          checked_at: new Date().toISOString(),
          account: summarizeStripeAccountReadiness(account, key),
        });
      }

      case "billing.status": {
        const billing = await getBillingSubscription(admin, userId!);
        const periodStart = currentBillingPeriodStart();
        const { data: usage, error: usageError } = await admin
          .from("billing_usage_counters")
          .select("*")
          .eq("user_id", userId!)
          .eq("period_start", periodStart)
          .maybeSingle();
        if (usageError) throw new Error(usageError.message);
        return json({
          success: true,
          billing: billing ?? {
            user_id: userId,
            tier: "free",
            status: "active",
            current_period_end: null,
            cancel_at_period_end: false,
          },
          usage: usage ?? {
            user_id: userId,
            period_start: periodStart,
            ai_query_count: 0,
            ef_call_count: 0,
          },
        });
      }

      case "billing.create_checkout_session": {
        const tier = normalizeCheckoutTier(body.tier);
        const priceId = billingPriceId(tier);
        if (!priceId) {
          return json({
            error: `STRIPE_${tier.toUpperCase()}_PRICE_ID not configured`,
          }, 503);
        }
        const customerId = await getOrCreateStripeCustomer(admin, userId!);
        const returnUrl = billingReturnUrl(
          body.return_url,
          "/subscription-billing",
        );
        const session = await stripePostForm("/checkout/sessions", {
          mode: "subscription",
          customer: customerId,
          "line_items[0][price]": priceId,
          "line_items[0][quantity]": "1",
          success_url: withBillingParam(returnUrl, "success"),
          cancel_url: withBillingParam(returnUrl, "cancel"),
          allow_promotion_codes: "true",
          "metadata[user_id]": userId!,
          "metadata[tier]": tier,
          "subscription_data[metadata][user_id]": userId!,
          "subscription_data[metadata][tier]": tier,
          ...checkoutAttributionParams(body),
        });
        return json({
          success: true,
          id: session.id,
          checkout_url: session.url,
        });
      }

      case "billing.create_supporter_checkout_session": {
        const amountJpy = supporterAmountJpy();
        const buyerContext = await resolveSupporterBuyerContext(admin, userId);
        const returnUrl = billingReturnUrl(
          body.return_url,
          "/subscription-billing",
        );
        const session = await stripePostForm("/checkout/sessions", {
          mode: "payment",
          locale: "ja",
          success_url: withBillingParam(returnUrl, "supporter_success"),
          cancel_url: withBillingParam(returnUrl, "supporter_cancel"),
          "line_items[0][price_data][currency]": "jpy",
          "line_items[0][price_data][product_data][name]":
            "AI仕事OS 初期サポーター",
          "line_items[0][price_data][product_data][description]":
            "役に立ったと感じた方のための、1回100円・自動更新なしの開発応援です。",
          "line_items[0][price_data][unit_amount]": String(amountJpy),
          "line_items[0][quantity]": "1",
          "metadata[offer]": "founding_supporter",
          "metadata[milestone_code]": "first-yen-revenue",
          "metadata[amount_jpy]": String(amountJpy),
          "payment_intent_data[metadata][offer]": "founding_supporter",
          "payment_intent_data[metadata][milestone_code]": "first-yen-revenue",
          "payment_intent_data[metadata][amount_jpy]": String(amountJpy),
          ...supporterBuyerStripeParams(buyerContext),
          ...supporterAttributionParams(body),
        });
        return json({
          success: true,
          id: session.id,
          checkout_url: session.url,
          amount_jpy: amountJpy,
        });
      }

      case "billing.create_video_credit_checkout_session": {
        const pack = videoCreditPack(body.pack_key);
        if (!pack) {
          return json({ error: "invalid_video_credit_pack" }, 400);
        }
        try {
          let customerId = await getOrCreateStripeCustomer(admin, userId!);
          const returnUrl = billingReturnUrl(body.return_url, "/video-studio");
          const metadata = videoCreditPackMetadata(userId!, pack);
          const createSession = (stripeCustomerId: string) =>
            stripePostForm("/checkout/sessions", {
              mode: "payment",
              locale: "ja",
              customer: stripeCustomerId,
              success_url: withBillingParam(
                returnUrl,
                "video_credits_success",
              ),
              cancel_url: withBillingParam(returnUrl, "video_credits_cancel"),
              "line_items[0][price_data][currency]": "jpy",
              "line_items[0][price_data][product_data][name]":
                `AI動画クレジット ${pack.name}`,
              "line_items[0][price_data][product_data][description]":
                pack.description,
              "line_items[0][price_data][unit_amount]": String(pack.amountJpy),
              "line_items[0][quantity]": "1",
              "metadata[offer]": metadata.offer,
              "metadata[user_id]": metadata.user_id,
              "metadata[video_credit_pack_key]": metadata.video_credit_pack_key,
              "metadata[video_credits]": metadata.video_credits,
              "metadata[amount_jpy]": metadata.amount_jpy,
              "payment_intent_data[metadata][offer]": metadata.offer,
              "payment_intent_data[metadata][user_id]": metadata.user_id,
              "payment_intent_data[metadata][video_credit_pack_key]":
                metadata.video_credit_pack_key,
              "payment_intent_data[metadata][video_credits]":
                metadata.video_credits,
              "payment_intent_data[metadata][amount_jpy]": metadata.amount_jpy,
            });

          let session: Record<string, unknown>;
          try {
            session = await createSession(customerId);
          } catch (error) {
            if (!isMissingStripeCustomer(error)) throw error;
            console.warn(
              "[schedule-hub] repairing stale Stripe customer",
              stripeApiErrorDetails(error),
            );
            customerId = await getOrCreateStripeCustomer(admin, userId!, true);
            session = await createSession(customerId);
          }

          return json({
            success: true,
            id: session.id,
            checkout_url: session.url,
            pack: {
              key: pack.key,
              credits: pack.credits,
              amount_jpy: pack.amountJpy,
            },
          });
        } catch (error) {
          console.error(
            "[schedule-hub] video credit checkout failed",
            stripeApiErrorDetails(error) ?? { code: "internal_error" },
          );
          return json({ error: "video_credit_checkout_unavailable" }, 502);
        }
      }

      case "billing.create_portal_session": {
        const customerId = await getOrCreateStripeCustomer(admin, userId!);
        const returnUrl = billingReturnUrl(
          body.return_url,
          "/subscription-billing",
        );
        const session = await stripePostForm("/billing_portal/sessions", {
          customer: customerId,
          return_url: returnUrl,
        });
        return json({
          success: true,
          id: session.id,
          portal_url: session.url,
        });
      }

      // ─── Digest ───────────────────────────────────────────────────────────────
      case "maintenance.list_active": {
        const now = new Date(asString(body.now) || new Date().toISOString());
        if (Number.isNaN(now.getTime())) {
          return json(
            { success: false, error: "now must be ISO timestamp" },
            400,
          );
        }
        const { data, error } = await admin
          .from("maintenance_windows")
          .select("*")
          .gt("ends_at", now.toISOString())
          .order("starts_at", { ascending: true })
          .limit(50);
        if (error) throw new Error(error.message);
        const windows = (data ?? [])
          .map((row) => asRecord(row) ?? {})
          .filter((row) => maintenanceWindowVisible(row, now))
          .map((row) => {
            const startsAt = new Date(asString(row.starts_at));
            const noticeDays = normalizeMaintenanceNoticeDays(
              row.notice_days_before,
            );
            return {
              ...row,
              banner_visible_from: new Date(
                startsAt.getTime() - noticeDays * 86400000,
              ).toISOString(),
              active: startsAt <= now,
            };
          });
        return json({ success: true, windows });
      }

      case "maintenance.list": {
        const { data, error } = await admin
          .from("maintenance_windows")
          .select("*")
          .order("starts_at", { ascending: false })
          .limit(100);
        if (error) throw new Error(error.message);
        return json({ success: true, windows: data ?? [] });
      }

      case "maintenance.create": {
        const payload = maintenancePayload(body, userId);
        const { data, error } = await admin
          .from("maintenance_windows")
          .insert(payload)
          .select("*")
          .single();
        if (error) throw new Error(error.message);
        return json({ success: true, window: data });
      }

      case "maintenance.update": {
        const id = asString(body.id);
        if (!id) return json({ success: false, error: "id required" }, 400);
        const payload = maintenancePayload(body, userId, true);
        const { data, error } = await admin
          .from("maintenance_windows")
          .update(payload)
          .eq("id", id)
          .select("*")
          .single();
        if (error) throw new Error(error.message);
        return json({ success: true, window: data });
      }

      case "maintenance.delete": {
        const id = asString(body.id);
        if (!id) return json({ success: false, error: "id required" }, 400);
        const { error } = await admin
          .from("maintenance_windows")
          .delete()
          .eq("id", id);
        if (error) throw new Error(error.message);
        return json({ success: true });
      }

      case "digest.run": {
        const today = new Date().toISOString().split("T")[0];
        const [usersRes, newFrRes, openFrRes, topFrRes, achievementsRes] =
          await Promise.all([
            admin.auth.admin.listUsers({ page: 1, perPage: 1 }),
            admin
              .from("feature_requests")
              .select("id, title, created_at")
              .gte("created_at", `${today}T00:00:00Z`)
              .order("created_at", { ascending: false })
              .limit(10),
            admin
              .from("feature_requests")
              .select("count", { count: "exact", head: true })
              .eq("status", "open"),
            admin
              .from("feature_requests")
              .select("title, votes")
              .eq("status", "open")
              .order("votes", { ascending: false })
              .limit(5),
            admin
              .from("development_achievements")
              .select("title, completed_at")
              .order("completed_at", { ascending: false })
              .limit(5),
          ]);
        return json({
          success: true,
          digest: {
            date: today,
            users: {
              total: ((usersRes.data as { total?: number } | null)?.total) ?? 0,
            },
            featureRequests: {
              newToday: newFrRes.data?.length ?? 0,
              openCount: openFrRes.count ?? 0,
              newTodayList: newFrRes.data ?? [],
              topOpen: topFrRes.data ?? [],
            },
            recentAchievements: achievementsRes.data ?? [],
          },
        });
      }

      case "digest.daily_summary": {
        const r = await listItems(admin, "daily_digest", userId!, 7);
        return json({ success: true, digests: r });
      }

      // ─── Schedule Manager ────────────────────────────────────────────────────
      case "manager.list": {
        const items = await listItems(admin, "scheduled_task", userId!);
        return json({ success: true, items });
      }

      case "manager.create": {
        const item = await addItem(admin, "scheduled_task", userId!, {
          name: body.name,
          cron: body.cron,
          task_type: body.task_type,
          status: "active",
          last_run: null,
        });
        return json({ success: true, item });
      }

      case "manager.update": {
        const { error } = await admin
          .from("hub_data")
          .update({ metadata: { ...body, user_id: userId! } })
          .eq("id", String(body.id))
          .eq("source", "scheduled_task");
        if (error) throw new Error(error.message);
        return json({ success: true });
      }

      case "manager.delete": {
        await deleteItem(admin, "scheduled_task", userId!, String(body.id));
        return json({ success: true });
      }

      // ─── X Post ───────────────────────────────────────────────────────────────
      case "x.post": {
        const text = String(body.text ?? "").trim();
        const mediaUrl = String(body.mediaUrl ?? body.media_url ?? "").trim();
        const mediaType = String(body.mediaType ?? body.media_type ?? "")
          .trim();
        const dryRun = body.dryRun === true;
        if (!text) return json({ success: false, error: "text required" }, 400);
        if (text.length > 280) {
          return json({
            success: false,
            error: "text exceeds 280 characters",
          }, 400);
        }

        const baseLog = {
          text,
          posted_at: new Date().toISOString(),
          source: body.source ?? "schedule-hub",
          media_url: mediaUrl || null,
        };

        if (dryRun || !isXConfigured()) {
          const log = await addItem(admin, "x_post", userId ?? "gha", {
            ...baseLog,
            status: dryRun ? "dry_run" : "credentials_missing",
          });
          return json({
            success: true,
            posted: false,
            dryRun,
            account: getXAccountHandle(),
            text,
            log,
            warning: dryRun
              ? undefined
              : "X API credentials are not configured in Supabase secrets.",
          });
        }

        const uploadedMedia = mediaUrl
          ? await uploadMediaFromUrl(mediaUrl, {
            mediaType: mediaType || undefined,
          })
          : null;
        const result = await postTweet({
          text,
          mediaIds: uploadedMedia ? [uploadedMedia.mediaId] : undefined,
        });
        const logOwnerUserId = userId ?? `gha`;
        const log = await addItem(admin, `x_post`, logOwnerUserId, {
          ...baseLog,
          status: "posted",
          tweet_id: result.tweetId,
          account: result.account,
          media_id: uploadedMedia?.mediaId ?? null,
          media_type: uploadedMedia?.mediaType ?? null,
        });
        return json({
          success: true,
          posted: true,
          text,
          tweetId: result.tweetId,
          account: result.account,
          log,
        });
      }

      case "x.history": {
        const items = await listItems(admin, "x_post", userId!);
        return json({ success: true, items });
      }

      case "x.post_with_media": {
        const text = String(body.text ?? "").trim();
        const mediaUrl = String(body.mediaUrl ?? "").trim();
        const dryRun = body.dryRun === true;
        if (!text) return json({ success: false, error: "text required" }, 400);
        if (text.length > 280) {
          return json(
            { success: false, error: "text exceeds 280 characters" },
            400,
          );
        }
        if (!mediaUrl) {
          return json({ success: false, error: "mediaUrl required" }, 400);
        }

        const baseLog = {
          text,
          media_url: mediaUrl,
          posted_at: new Date().toISOString(),
          source: body.source ?? "schedule-hub",
        };

        if (dryRun || !isXConfigured()) {
          const log = await addItem(admin, "x_post", userId ?? "gha", {
            ...baseLog,
            status: dryRun ? "dry_run" : "credentials_missing",
          });
          return json({
            success: true,
            posted: false,
            dryRun,
            account: getXAccountHandle(),
            text,
            mediaUrl,
            log,
            warning: dryRun
              ? undefined
              : "X API credentials are not configured in Supabase secrets.",
          });
        }

        const mediaType = String(body.mediaType ?? "image/png");
        const mediaCategory = String(body.mediaCategory ?? "tweet_image");
        const uploadResult = await uploadMediaFromUrl(mediaUrl, {
          mediaType,
          mediaCategory,
        });
        const result = await postTweet({
          text,
          mediaIds: [uploadResult.mediaId],
        });
        const log = await addItem(admin, "x_post", userId ?? "gha", {
          ...baseLog,
          status: "posted",
          tweet_id: result.tweetId,
          account: result.account,
          media_id: uploadResult.mediaId,
        });
        return json({
          success: true,
          posted: true,
          text,
          mediaUrl,
          tweetId: result.tweetId,
          account: result.account,
          mediaId: uploadResult.mediaId,
          log,
        });
      }

      // ─── Blog ─────────────────────────────────────────────────────────────────
      case "blog.list": {
        const items = await listItems(admin, "blog_post", userId!);
        return json({ success: true, items });
      }

      case "blog.create": {
        const effectiveUserId = userId ?? "system";
        const item = await addItem(admin, "blog_post", effectiveUserId, {
          title: body.title,
          content: body.content ?? "",
          status: "draft",
          platform: body.platform ?? "qiita",
          tags: body.tags ?? [],
        });
        return json({ success: true, item });
      }

      case "blog.publish": {
        // Mark as published and attempt Qiita/dev.to API post
        const qiitaToken = Deno.env.get("QIITA_ACCESS_TOKEN") ?? "";
        const devtoKey = Deno.env.get("DEVTO_API_KEY") ?? "";
        const results: Record<string, unknown> = {};

        if (qiitaToken && body.platform === "qiita") {
          const qr = await qiitaFetch("/items", qiitaToken, {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
            },
            body: JSON.stringify({
              title: body.title,
              body: body.content ?? "",
              tags: ((body.tags as string[]) ?? []).map((t: string) => ({
                name: t,
              })),
              private: false,
            }),
          }, "schedule-hub.blog.publish.qiita");
          results.qiita = { ok: qr.ok, status: qr.status };
        }

        if (devtoKey && body.platform === "devto") {
          const dr = await devtoFetch("/articles", devtoKey, {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
            },
            body: JSON.stringify({
              article: {
                title: body.title,
                body_markdown: body.content ?? "",
                published: true,
                tags: body.tags ?? [],
              },
            }),
          }, "schedule-hub.blog.publish.devto");
          results.devto = { ok: dr.ok, status: dr.status };
        }

        await addItem(admin, "blog_publish_log", userId!, {
          title: body.title,
          results,
          published_at: new Date().toISOString(),
        });
        return json({ success: true, results });
      }

      case "blog.delete": {
        await deleteItem(admin, "blog_post", userId!, String(body.id));
        return json({ success: true });
      }

      // blog-auto-publisher 互換: Qiita / dev.to への一括投稿 (SERVICE_ROLE_KEY 認証)
      case "blog.auto_publish": {
        const qiitaToken = Deno.env.get("QIITA_ACCESS_TOKEN") ?? "";
        const devtoKey = Deno.env.get("DEVTO_API_KEY") ?? "";
        const title = String(body.title ?? "");
        const rawContent = String(body.content ?? "");
        // YAML frontmatter (---...---) を除去
        const content = rawContent.replace(
          /^---[\r\n][\s\S]*?[\r\n]---[\r\n]?/,
          "",
        ).trimStart();
        const rawTags = (body.tags as string[]) ?? [];
        const platformsRaw = String(body.platforms ?? "qiita,devto");
        const platforms = platformsRaw.split(",").map((p: string) => p.trim());
        const results: Record<string, unknown> = {};

        if (platforms.includes("qiita") && qiitaToken) {
          try {
            const tagObjects = rawTags.slice(0, 5).map((t: string) => ({
              name: t.slice(0, 20),
            }));
            const qr = await qiitaFetch("/items", qiitaToken, {
              method: "POST",
              headers: {
                "Content-Type": "application/json",
              },
              body: JSON.stringify({
                title,
                body: content,
                tags: tagObjects.length > 0
                  ? tagObjects
                  : [{ name: "Flutter" }],
                private: false,
                tweet: false,
              }),
            }, "schedule-hub.blog.auto_publish.qiita");
            if (qr.ok) {
              const qd = await qr.json() as { url: string; id: string };
              results.qiita = { ok: true, url: qd.url };
            } else {
              results.qiita = buildUpstreamErrorPayload({
                targetApi: "qiita",
                status: qr.status,
                detail: await qr.text().catch(() => ""),
              });
            }
          } catch (e) {
            results.qiita = isExternalFetchError(e)
              ? externalFetchErrorPayload(e)
              : { ok: false, error: String(e) };
          }
        } else if (platforms.includes("qiita")) {
          results.qiita = { ok: false, error: "QIITA_ACCESS_TOKEN not set" };
        }

        if (platforms.includes("devto") && devtoKey) {
          try {
            const cleanTags = rawTags.slice(0, 4).map((t: string) =>
              t.toLowerCase().replace(/[^a-z0-9]/g, "").slice(0, 30)
            ).filter((t: string) => t.length > 0);
            const dr = await devtoFetch("/articles", devtoKey, {
              method: "POST",
              headers: {
                "Content-Type": "application/json",
              },
              body: JSON.stringify({
                article: {
                  title,
                  body_markdown: content,
                  published: true,
                  tags: cleanTags.length > 0 ? cleanTags : ["flutter"],
                },
              }),
            }, "schedule-hub.blog.auto_publish.devto");
            if (dr.ok) {
              const dd = await dr.json() as { url: string; id: number };
              results.devto = { ok: true, url: dd.url };
            } else {
              results.devto = buildUpstreamErrorPayload({
                targetApi: "dev.to",
                status: dr.status,
                detail: await dr.text().catch(() => ""),
              });
            }
          } catch (e) {
            results.devto = isExternalFetchError(e)
              ? externalFetchErrorPayload(e)
              : { ok: false, error: String(e) };
          }
        } else if (platforms.includes("devto")) {
          results.devto = { ok: false, error: "DEVTO_API_KEY not set" };
        }

        // Win版#132 part 124: 投稿成功後、hub_data に status='posted' を記録
        // (= tech-blog-tracker page が EF blog.recent_posted 経由で集計可能にする)
        try {
          const successPlatforms: string[] = [];
          const platformUrls: Record<string, string> = {};
          for (const p of ["qiita", "devto"]) {
            const r = results[p] as { ok?: boolean; url?: string } | undefined;
            if (r?.ok && typeof r.url === "string") {
              successPlatforms.push(p);
              platformUrls[p] = r.url;
            }
          }
          if (successPlatforms.length > 0) {
            const blogId = body.id ? String(body.id) : null;
            const postedAt = new Date().toISOString();
            const baseMeta = {
              title,
              status: "posted",
              posted_at: postedAt,
              target_platforms: successPlatforms,
              platform_urls: platformUrls,
              tags: rawTags,
            };
            if (blogId) {
              // 既存 hub_data row (= blog.create で作った draft) を update.
              // Workflow が qiita + devto 別 call で auto_publish するため、
              // target_platforms + platform_urls は merge する.
              const { data: existing } = await admin
                .from("hub_data")
                .select("metadata")
                .eq("id", blogId)
                .single();
              const currentMeta =
                (existing?.metadata as Record<string, unknown>) ?? {};
              const prevTargets = Array.isArray(currentMeta.target_platforms)
                ? (currentMeta.target_platforms as string[])
                : [];
              const prevUrls =
                (currentMeta.platform_urls as Record<string, string>) ?? {};
              const mergedTargets = Array.from(
                new Set([...prevTargets, ...successPlatforms]),
              );
              const mergedUrls = { ...prevUrls, ...platformUrls };
              await admin
                .from("hub_data")
                .update({
                  metadata: {
                    ...currentMeta,
                    ...baseMeta,
                    target_platforms: mergedTargets,
                    platform_urls: mergedUrls,
                  },
                })
                .eq("id", blogId);
            } else {
              // id 未指定 (= 直接 auto_publish 呼び出し) の場合は新規 insert
              await admin.from("hub_data").insert({
                source: "blog_post",
                metadata: { ...baseMeta, user_id: "system" },
              });
            }
          }
        } catch (dbErr) {
          // DB 書き込み失敗しても publish 結果は返す (= degrade safe)
          console.error("blog.auto_publish DB write failed:", dbErr);
        }

        // 部分成功は 200 (成功済み platform への再投稿リトライ防止) / 全滅のみ 502
        if (allPlatformsFailed(results)) {
          return json({
            success: false,
            error: summarizePlatformFailures(results),
            error_code: "all_platforms_failed",
            results,
          }, 502);
        }
        return json({ success: true, results });
      }

      // blog.publish_post — blog_posts行のcontentを読んでQiita/dev.toに公開し、statusを更新
      case "blog.publish_post": {
        const postId = String(body.id ?? "");
        if (!postId) return json({ error: "id required" }, 400);

        const { data: post, error: fetchErr } = await admin
          .from("blog_posts")
          .select("id, title, content, target_platforms, tags")
          .eq("id", postId)
          .single();
        if (fetchErr || !post) return json({ error: "Post not found" }, 404);

        const qiitaToken = Deno.env.get("QIITA_ACCESS_TOKEN") ?? "";
        const devtoKey = Deno.env.get("DEVTO_API_KEY") ?? "";
        const ppTitle = String((post as Record<string, unknown>).title ?? "");
        const rawContent = String(
          (post as Record<string, unknown>).content ?? body.content ?? "",
        );
        const ppContent = rawContent
          .replace(/^---[\r\n][\s\S]*?[\r\n]---[\r\n]?/, "")
          .trimStart();

        if (!ppContent.trim()) {
          return json(
            {
              error:
                "Content is empty. Edit the draft and add markdown content before publishing.",
            },
            400,
          );
        }

        const ppRawTags: string[] =
          Array.isArray((post as Record<string, unknown>).tags)
            ? ((post as Record<string, unknown>).tags as string[])
            : (body.tags as string[]) ?? [];
        const ppTargetPlatforms = (post as Record<string, unknown>)
          .target_platforms;
        const ppPlatformResolution = resolveBlogPublishPlatforms(
          ppTargetPlatforms,
          body.platforms,
        );
        if (ppPlatformResolution.error) {
          return json({
            error: ppPlatformResolution.error,
            error_code: "invalid_platform_override",
          }, 400);
        }
        const ppPlatforms = ppPlatformResolution.platforms;
        const ppResults: Record<string, unknown> = {};

        if (ppPlatforms.includes("qiita") && qiitaToken) {
          try {
            const tagObjects = ppRawTags
              .slice(0, 5)
              .map((t: string) => ({ name: t.slice(0, 20) }));
            const qr = await qiitaFetch("/items", qiitaToken, {
              method: "POST",
              headers: {
                "Content-Type": "application/json",
              },
              body: JSON.stringify({
                title: ppTitle,
                body: ppContent,
                tags: tagObjects.length > 0
                  ? tagObjects
                  : [{ name: "Flutter" }],
                private: false,
                tweet: false,
              }),
            }, "schedule-hub.blog.publish_post.qiita");
            if (qr.ok) {
              const qd = await qr.json() as { url: string; id: string };
              ppResults.qiita = { ok: true, url: qd.url };
            } else {
              ppResults.qiita = buildUpstreamErrorPayload({
                targetApi: "qiita",
                status: qr.status,
                detail: await qr.text().catch(() => ""),
              });
            }
          } catch (e) {
            ppResults.qiita = isExternalFetchError(e)
              ? externalFetchErrorPayload(e)
              : { ok: false, error: String(e) };
          }
        } else if (ppPlatforms.includes("qiita")) {
          ppResults.qiita = { ok: false, error: "QIITA_ACCESS_TOKEN not set" };
        }

        if (ppPlatforms.includes("devto") && devtoKey) {
          try {
            const cleanTags = ppRawTags
              .slice(0, 4)
              .map((t: string) =>
                t.toLowerCase().replace(/[^a-z0-9]/g, "").slice(0, 30)
              )
              .filter((t: string) => t.length > 0);
            const dr = await devtoFetch("/articles", devtoKey, {
              method: "POST",
              headers: {
                "Content-Type": "application/json",
              },
              body: JSON.stringify({
                article: {
                  title: ppTitle,
                  body_markdown: ppContent,
                  published: true,
                  tags: cleanTags.length > 0 ? cleanTags : ["flutter"],
                  // SEO 監査 H7: postId は blog_posts.id で、直後に status='posted'
                  // へ更新され core-hub blog_view.ts が /blog/post?id=X で SSR 配信する。
                  // canonical_url を自サイトへ向け、dev.to へ流出していた検索 authority を
                  // 自ドメインに集約する。
                  canonical_url: buildOwnSiteBlogPostUrl(postId),
                },
              }),
            }, "schedule-hub.blog.publish_post.devto");
            if (dr.ok) {
              const dd = await dr.json() as { url: string; id: number };
              ppResults.devto = { ok: true, url: dd.url };
            } else {
              ppResults.devto = buildUpstreamErrorPayload({
                targetApi: "dev.to",
                status: dr.status,
                detail: await dr.text().catch(() => ""),
              });
            }
          } catch (e) {
            ppResults.devto = isExternalFetchError(e)
              ? externalFetchErrorPayload(e)
              : { ok: false, error: String(e) };
          }
        } else if (ppPlatforms.includes("devto")) {
          ppResults.devto = { ok: false, error: "DEVTO_API_KEY not set" };
        }

        const successUrls = (
          Object.values(ppResults) as Array<{ ok: boolean; url?: string }>
        )
          .filter((v) => v.ok)
          .map((v) => v.url)
          .filter(Boolean) as string[];

        if (successUrls.length > 0) {
          await admin
            .from("blog_posts")
            .update({
              status: "posted",
              posted_at: new Date().toISOString(),
              url: successUrls[0],
            })
            .eq("id", postId);
        }

        // 部分成功は 200 (成功済み platform への再投稿リトライ防止) / 全滅のみ 502
        if (allPlatformsFailed(ppResults)) {
          return json({
            success: false,
            error: summarizePlatformFailures(ppResults),
            error_code: "all_platforms_failed",
            results: ppResults,
          }, 502);
        }
        return json({ success: true, results: ppResults });
      }

      // blog.update_post — blog_posts行のフィールドを更新
      case "blog.update_post": {
        const upId = String(body.id ?? "");
        if (!upId) return json({ error: "id required" }, 400);
        const upFields: Record<string, unknown> = {};
        if (body.title !== undefined) upFields.title = String(body.title);
        if (body.content !== undefined) upFields.content = String(body.content);
        if (body.notes !== undefined) upFields.notes = String(body.notes);
        if (
          body.status !== undefined &&
          ["draft", "ready", "posted", "skipped"].includes(String(body.status))
        ) {
          upFields.status = String(body.status);
        }
        if (Array.isArray(body.target_platforms)) {
          upFields.target_platforms = body.target_platforms;
        }
        if (Array.isArray(body.tags)) upFields.tags = body.tags;
        if (Object.keys(upFields).length === 0) {
          return json({ error: "No fields to update" }, 400);
        }
        const { error: upErr } = await admin
          .from("blog_posts")
          .update(upFields)
          .eq("id", upId);
        if (upErr) return json({ error: upErr.message }, 500);
        return json({ success: true });
      }

      // blog.delete_post — blog_postsから削除 (admin SERVICE_ROLE_KEY必要)
      case "blog.delete_post": {
        const delId = String(body.id ?? "");
        if (!delId) return json({ error: "id required" }, 400);
        const { error: delErr } = await admin
          .from("blog_posts")
          .delete()
          .eq("id", delId);
        if (delErr) return json({ error: delErr.message }, 500);
        return json({ success: true });
      }

      // blog.insert_post — blog_postsに新規ドラフトを直接挿入
      case "blog.insert_post": {
        const insTitle = String(body.title ?? "");
        if (!insTitle) return json({ error: "title required" }, 400);
        const { data: newPost, error: insErr } = await admin
          .from("blog_posts")
          .insert({
            title: insTitle,
            content: String(body.content ?? ""),
            notes: String(body.notes ?? ""),
            status: "draft",
            target_platforms: Array.isArray(body.target_platforms)
              ? body.target_platforms
              : ["qiita", "devto"],
            tags: Array.isArray(body.tags) ? body.tags : [],
            ...(userId ? { created_by: userId } : {}),
          })
          .select("id, title, status, created_at")
          .single();
        if (insErr) return json({ error: insErr.message }, 500);
        return json({ success: true, post: newPost });
      }

      case "blog.news_signal_draft": {
        const force = Boolean(body.force ?? false);
        const signalData = await fetchNewsSignalsForDraft(body);
        const rawSignals = Array.isArray(signalData.signals)
          ? signalData.signals
          : [];
        const signals = rawSignals
          .map((signal) => asRecord(signal))
          .filter((signal): signal is Record<string, unknown> =>
            signal !== null
          )
          .slice(0, Math.min(Math.max(Number(body.signal_limit ?? 5), 1), 12));
        if (signals.length === 0) {
          return json({
            success: true,
            created: false,
            reason: "no_signals",
            fetched_at: signalData.fetched_at ?? null,
          });
        }

        const fetchedAt = asString(
          signalData.fetched_at,
          new Date().toISOString(),
        );
        const topKey = asString(signals[0].id) ||
          asString(signals[0].cluster_key) ||
          newsSignalTitle(signals[0]);
        const dedupeKey = asString(
          body.dedupe_key,
          `news-signal:${fetchedAt.slice(0, 10)}:${topKey}`,
        );
        if (!force) {
          const { data: existing, error: existingErr } = await admin
            .from("blog_posts")
            .select("id, title, status, created_at")
            .ilike("notes", `%AI_NEWS_SIGNAL_DRAFT_KEY=${dedupeKey}%`)
            .limit(1)
            .maybeSingle();
          if (existingErr) return json({ error: existingErr.message }, 500);
          if (existing) {
            return json({
              success: true,
              created: false,
              duplicate: true,
              post: existing,
              dedupe_key: dedupeKey,
            });
          }
        }

        const title = shortenNewsDraftTitle(
          asString(body.title) ||
            `ニュースシグナル: ${newsSignalTitle(signals[0])}`,
        );
        const content = buildNewsSignalDraftMarkdown(signals, fetchedAt);
        const targetPlatforms = asStringList(body.target_platforms, [
          "note",
          "qiita",
          "devto",
        ]);
        const tags = asStringList(body.tags, [
          "AI",
          "ニュース",
          "自動化",
          "外部脳",
        ]);
        const notes = [
          `AI_NEWS_SIGNAL_DRAFT_KEY=${dedupeKey}`,
          `Generated from schedule-hub blog.news_signal_draft at ${
            new Date().toISOString()
          }`,
          asString(body.notes),
        ].filter(Boolean).join("\n");
        const { data: newPost, error: insertErr } = await admin
          .from("blog_posts")
          .insert({
            title,
            content,
            notes,
            status: "draft",
            target_platforms: targetPlatforms,
            tags,
            ...(userId ? { created_by: userId } : {}),
          })
          .select("id, title, status, created_at")
          .single();
        if (insertErr) return json({ error: insertErr.message }, 500);
        const postId = asString(
          (newPost as Record<string, unknown> | null)?.id,
        );
        let externalBrain: Record<string, unknown> | null = null;
        if (body.external_brain !== false) {
          try {
            externalBrain = await upsertExternalBrainNewsSignals(
              admin,
              signals,
              fetchedAt,
              {
                dedupeKey,
                postId,
                userId,
                targetPlatforms,
                tags,
              },
            );
            const filePaths = Array.isArray(externalBrain.file_paths)
              ? externalBrain.file_paths.map((path) => String(path)).filter(
                Boolean,
              )
              : [];
            if (postId && filePaths.length > 0) {
              const { error: notesErr } = await admin
                .from("blog_posts")
                .update({
                  notes: [
                    notes,
                    `EXTERNAL_BRAIN_FILE_PATHS=${filePaths.join(",")}`,
                  ].join("\n"),
                })
                .eq("id", postId);
              if (notesErr) {
                externalBrain = {
                  ...externalBrain,
                  notes_warning: notesErr.message,
                };
              }
            }
          } catch (err) {
            externalBrain = {
              success: false,
              error: err instanceof Error ? err.message : String(err),
            };
          }
        }
        return json({
          success: true,
          created: true,
          post: newPost,
          dedupe_key: dedupeKey,
          signal_count: signals.length,
          fetched_at: fetchedAt,
          external_brain: externalBrain,
        });
      }

      case "blog.news_signal_lint": {
        const result = await lintExternalBrainNewsSignals(admin, body);
        return json(result, result.success ? 200 : 207);
      }
      // Win版#132 part 124: 過去 dispatch 済の dev.to + Qiita 記事を hub_data に backfill する.
      // 既存の T-1 dispatch (= part 124 fix 前) は hub_data に記録されていないため、
      // tech-blog-tracker page で過去投稿が見えない. 本 action で API 経由で取得 → 既存 row 検出 →
      // 未登録分を新規 insert する (= 同 url 重複は skip).
      case "blog.backfill_from_apis": {
        const qiitaToken = Deno.env.get("QIITA_ACCESS_TOKEN") ?? "";
        const devtoKey = Deno.env.get("DEVTO_API_KEY") ?? "";
        const days = Math.min(Math.max(Number(body.days ?? 30), 1), 365);
        const since = new Date(Date.now() - days * 24 * 60 * 60 * 1000);
        const sinceIso = since.toISOString();

        // 既存 hub_data の url を全部集めて dedup 用 set 構築
        const { data: existingData } = await admin
          .from("hub_data")
          .select("metadata")
          .eq("source", "blog_post")
          .gte("created_at", sinceIso);
        const existingUrls = new Set<string>();
        for (const row of existingData ?? []) {
          const m = (row.metadata as Record<string, unknown>) ?? {};
          const urls = (m.platform_urls as Record<string, string>) ?? {};
          for (const u of Object.values(urls)) {
            if (u) existingUrls.add(u);
          }
        }

        const inserts: Array<Record<string, unknown>> = [];
        const summary: Record<string, number> = {
          qiita_fetched: 0,
          devto_fetched: 0,
          inserted: 0,
          skipped_dup: 0,
          skipped_old: 0,
        };
        // source ごとの取得失敗を記録 (黙殺すると 0 件と区別できない)
        const backfillErrors: Record<string, unknown> = {};

        // ── Qiita 取得 ──────────────────────────────────────────────────
        if (qiitaToken) {
          try {
            const qr = await qiitaFetch(
              "/authenticated_user/items?per_page=100",
              qiitaToken,
              {},
              "schedule-hub.blog.backfill.qiita",
            );
            if (qr.ok) {
              const articles = await qr.json() as Array<{
                id: string;
                title: string;
                url: string;
                created_at: string;
                tags: Array<{ name: string }>;
              }>;
              summary.qiita_fetched = articles.length;
              for (const a of articles) {
                if (new Date(a.created_at) < since) {
                  summary.skipped_old++;
                  continue;
                }
                if (existingUrls.has(a.url)) {
                  summary.skipped_dup++;
                  continue;
                }
                inserts.push({
                  source: "blog_post",
                  metadata: {
                    title: a.title,
                    status: "posted",
                    posted_at: a.created_at,
                    target_platforms: ["qiita"],
                    platform_urls: { qiita: a.url },
                    tags: a.tags.map((t) => t.name),
                    user_id: "system",
                    backfilled: true,
                    source_api: "qiita",
                    external_id: a.id,
                  },
                });
                existingUrls.add(a.url);
              }
            } else {
              backfillErrors.qiita = buildUpstreamErrorPayload({
                targetApi: "qiita",
                status: qr.status,
                detail: await qr.text().catch(() => ""),
              });
            }
          } catch (e) {
            console.error("qiita backfill fetch failed:", e);
            backfillErrors.qiita = isExternalFetchError(e)
              ? externalFetchErrorPayload(e)
              : { ok: false, error: String(e) };
          }
        }

        // ── dev.to 取得 ─────────────────────────────────────────────────
        if (devtoKey) {
          try {
            const dr = await devtoFetch(
              "/articles/me/published?per_page=1000",
              devtoKey,
              {},
              "schedule-hub.blog.backfill.devto",
            );
            if (dr.ok) {
              const articles = await dr.json() as Array<{
                id: number;
                title: string;
                url: string;
                published_at: string;
                tag_list: string[];
              }>;
              summary.devto_fetched = articles.length;
              for (const a of articles) {
                if (!a.published_at) continue;
                if (new Date(a.published_at) < since) {
                  summary.skipped_old++;
                  continue;
                }
                if (existingUrls.has(a.url)) {
                  summary.skipped_dup++;
                  continue;
                }
                inserts.push({
                  source: "blog_post",
                  metadata: {
                    title: a.title,
                    status: "posted",
                    posted_at: a.published_at,
                    target_platforms: ["devto"],
                    platform_urls: { devto: a.url },
                    tags: a.tag_list,
                    user_id: "system",
                    backfilled: true,
                    source_api: "devto",
                    external_id: String(a.id),
                  },
                });
                existingUrls.add(a.url);
              }
            } else {
              backfillErrors.devto = buildUpstreamErrorPayload({
                targetApi: "dev.to",
                status: dr.status,
                detail: await dr.text().catch(() => ""),
              });
            }
          } catch (e) {
            console.error("devto backfill fetch failed:", e);
            backfillErrors.devto = isExternalFetchError(e)
              ? externalFetchErrorPayload(e)
              : { ok: false, error: String(e) };
          }
        }

        // 全 source 失敗時のみ 502 (部分成功は 200 + errors で継続)
        const attemptedSources = [
          qiitaToken ? "qiita" : "",
          devtoKey ? "devto" : "",
        ].filter(Boolean);
        if (
          attemptedSources.length > 0 &&
          attemptedSources.every((s) => backfillErrors[s] !== undefined)
        ) {
          return json({
            success: false,
            error: summarizePlatformFailures(backfillErrors),
            error_code: "all_sources_failed",
            errors: backfillErrors,
            summary,
          }, 502);
        }

        // ── 一括 insert ─────────────────────────────────────────────────
        if (inserts.length > 0) {
          const { error: insErr } = await admin.from("hub_data").insert(
            inserts,
          );
          if (insErr) {
            return json({
              success: false,
              error: insErr.message,
              summary,
            }, 500);
          }
          summary.inserted = inserts.length;
        }

        return json({
          success: true,
          summary,
          ...(Object.keys(backfillErrors).length > 0
            ? { errors: backfillErrors }
            : {}),
        });
      }

      // Win版#132 part 124: tech-blog-tracker page 用 public read action.
      // service_role 経由で hub_data の posted blog_post を返す (= user 認証不要 / 安全な metadata のみ).
      case "blog.recent_posted": {
        const days = Math.min(Math.max(Number(body.days ?? 30), 1), 365);
        const limit = Math.min(Math.max(Number(body.limit ?? 200), 1), 500);
        const since = new Date(Date.now() - days * 24 * 60 * 60 * 1000)
          .toISOString();
        const { data, error } = await admin
          .from("hub_data")
          .select("id, metadata, created_at")
          .eq("source", "blog_post")
          .filter("metadata->>status", "eq", "posted")
          .gte("created_at", since)
          .order("created_at", { ascending: false })
          .limit(limit);
        if (error) {
          return json({ error: error.message }, 500);
        }
        const items = (data ?? []).map((row) => {
          const m = (row.metadata as Record<string, unknown>) ?? {};
          return {
            id: row.id,
            title: m.title ?? "",
            status: m.status ?? "posted",
            posted_at: m.posted_at ?? row.created_at,
            target_platforms: m.target_platforms ?? [],
            platform_urls: m.platform_urls ?? {},
            tags: m.tags ?? [],
            created_at: row.created_at,
          };
        });
        return json({ success: true, items, count: items.length });
      }

      // ─── Blog Management: Qiita / dev.to ─────────────────────────────────────

      // blog.qiita_list — 自分の全記事一覧 (per_page最大100)
      case "blog.qiita_list": {
        const qiitaToken = Deno.env.get("QIITA_ACCESS_TOKEN") ?? "";
        if (!qiitaToken) {
          return json({ error: "QIITA_ACCESS_TOKEN not set" }, 500);
        }
        const page = Number(body.page ?? 1);
        const perPage = Math.min(Number(body.per_page ?? 100), 100);
        const qr = await qiitaFetch(
          `/authenticated_user/items?page=${page}&per_page=${perPage}`,
          qiitaToken,
          {},
          "schedule-hub.blog.qiita_list",
        );
        if (!qr.ok) return await upstreamErrorJson("qiita", qr);
        const articles = await qr.json() as Array<{
          id: string;
          title: string;
          url: string;
          likes_count: number;
          comments_count: number;
          created_at: string;
          tags: Array<{ name: string }>;
        }>;
        return json({ success: true, articles, total: articles.length });
      }

      // blog.qiita_comments — 記事のコメント一覧
      case "blog.qiita_comments": {
        const qiitaToken = Deno.env.get("QIITA_ACCESS_TOKEN") ?? "";
        if (!qiitaToken) {
          return json({ error: "QIITA_ACCESS_TOKEN not set" }, 500);
        }
        const itemId = String(body.item_id ?? "");
        if (!itemId) return json({ error: "item_id required" }, 400);
        const qr = await qiitaFetch(
          `/items/${itemId}/comments`,
          qiitaToken,
          {},
          "schedule-hub.blog.qiita_comments",
        );
        if (!qr.ok) return await upstreamErrorJson("qiita", qr);
        const comments = await qr.json() as Array<{
          id: string;
          body: string;
          rendered_body: string;
          created_at: string;
          user: { id: string; name: string; profile_image_url: string };
        }>;
        return json({ success: true, comments, item_id: itemId });
      }

      // blog.qiita_comment_post — コメントに返信 (Qiita では同記事へのコメント追加)
      case "blog.qiita_comment_post": {
        const qiitaToken = Deno.env.get("QIITA_ACCESS_TOKEN") ?? "";
        if (!qiitaToken) {
          return json({ error: "QIITA_ACCESS_TOKEN not set" }, 500);
        }
        const itemId = String(body.item_id ?? "");
        const replyBody = String(body.body ?? "");
        if (!itemId || !replyBody) {
          return json({ error: "item_id and body required" }, 400);
        }
        const qr = await qiitaFetch("/comments", qiitaToken, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
          },
          body: JSON.stringify({ item_id: itemId, body: replyBody }),
        }, "schedule-hub.blog.qiita_comment_post");
        if (!qr.ok) return await upstreamErrorJson("qiita", qr);
        const comment = await qr.json();
        return json({ success: true, comment });
      }

      // blog.qiita_likers — 記事にLGTMした人の一覧
      case "blog.qiita_likers": {
        const qiitaToken = Deno.env.get("QIITA_ACCESS_TOKEN") ?? "";
        if (!qiitaToken) {
          return json({ error: "QIITA_ACCESS_TOKEN not set" }, 500);
        }
        const itemId = String(body.item_id ?? "");
        if (!itemId) return json({ error: "item_id required" }, 400);
        const qr = await qiitaFetch(
          `/items/${itemId}/likes`,
          qiitaToken,
          {},
          "schedule-hub.blog.qiita_likers",
        );
        if (!qr.ok) return await upstreamErrorJson("qiita", qr);
        const likers = await qr.json() as Array<
          { user: { id: string; name: string; profile_image_url: string } }
        >;
        return json({ success: true, likers, item_id: itemId });
      }

      // blog.qiita_follow は恒久廃止 (2026-07-13): 他ユーザーへの自動フォローは
      // Qiita アカウント停止 (2026-07-12 / ToS 違反) の最有力原因。
      // 対他者自動アクションは再実装禁止 — 410 Gone で明示する。
      case "blog.qiita_follow": {
        return json({
          success: false,
          error:
            "blog.qiita_follow is permanently removed (auto-follow caused the 2026-07-12 Qiita account suspension)",
        }, 410);
      }

      // blog.qiita_delete — 記事を削除
      case "blog.qiita_delete": {
        const qiitaToken = Deno.env.get("QIITA_ACCESS_TOKEN") ?? "";
        if (!qiitaToken) {
          return json({ error: "QIITA_ACCESS_TOKEN not set" }, 500);
        }
        const itemId = String(body.item_id ?? "");
        if (!itemId) return json({ error: "item_id required" }, 400);
        const qr = await qiitaFetch(
          `/items/${itemId}`,
          qiitaToken,
          { method: "DELETE" },
          "schedule-hub.blog.qiita_delete",
        );
        if (!qr.ok) return await upstreamErrorJson("qiita", qr);
        return json({ success: true, status: qr.status, item_id: itemId });
      }

      // blog.qiita_update — 記事を更新 (内容訂正)
      case "blog.qiita_update": {
        const qiitaToken = Deno.env.get("QIITA_ACCESS_TOKEN") ?? "";
        if (!qiitaToken) {
          return json({ error: "QIITA_ACCESS_TOKEN not set" }, 500);
        }
        const itemId = String(body.item_id ?? "");
        if (!itemId) return json({ error: "item_id required" }, 400);
        const patchBody: Record<string, unknown> = {};
        if (body.title) patchBody.title = String(body.title);
        if (body.body) patchBody.body = String(body.body);
        if (body.tags) {
          patchBody.tags = (body.tags as string[]).map((t: string) => ({
            name: t,
          }));
        }
        const qr = await qiitaFetch(
          `/items/${itemId}`,
          qiitaToken,
          {
            method: "PATCH",
            headers: {
              "Content-Type": "application/json",
            },
            body: JSON.stringify(patchBody),
          },
          "schedule-hub.blog.qiita_update",
        );
        if (!qr.ok) return await upstreamErrorJson("qiita", qr);
        const updated = await qr.json() as {
          id: string;
          url: string;
          title: string;
        };
        return json({
          success: true,
          item: { id: updated.id, url: updated.url, title: updated.title },
        });
      }

      // blog.devto_list — dev.to 全記事一覧
      case "blog.devto_list": {
        const devtoKey = Deno.env.get("DEVTO_API_KEY") ?? "";
        if (!devtoKey) return json({ error: "DEVTO_API_KEY not set" }, 500);
        const page = Number(body.page ?? 1);
        const perPage = Math.min(Number(body.per_page ?? 100), 1000);
        const dr = await devtoFetch(
          `/articles/me?page=${page}&per_page=${perPage}`,
          devtoKey,
          {},
          "schedule-hub.blog.devto_list",
        );
        if (!dr.ok) return await upstreamErrorJson("dev.to", dr);
        const articles = await dr.json() as Array<{
          id: number;
          title: string;
          url: string;
          public_reactions_count: number;
          comments_count: number;
          published_at: string;
          tag_list: string[];
        }>;
        return json({ success: true, articles, total: articles.length });
      }

      case "blog.devto_sync_engagement": {
        const devtoKey = Deno.env.get("DEVTO_API_KEY") ?? "";
        if (!devtoKey) return json({ error: "DEVTO_API_KEY not set" }, 500);
        const perPage = Math.min(Number(body.per_page ?? 1000), 1000);
        const dr = await fetch(
          `https://dev.to/api/articles/me/published?per_page=${perPage}`,
          { headers: { "api-key": devtoKey } },
        );
        if (!dr.ok) return await upstreamErrorJson("dev.to", dr);
        const articles = await dr.json() as Array<{
          id: number;
          title: string;
          url: string;
          public_reactions_count?: number;
          comments_count?: number;
          page_views_count?: number;
        }>;
        const rows = articles.map((article) => ({
          platform: "devto",
          article_id: String(article.id),
          title: article.title,
          url: article.url,
          likes_count: Number(article.public_reactions_count ?? 0),
          comments_count: Number(article.comments_count ?? 0),
          views_count: Number(article.page_views_count ?? 0),
          updated_at: new Date().toISOString(),
        }));
        if (rows.length > 0) {
          const { error: upsertErr } = await admin
            .from("blog_engagement")
            .upsert(rows, { onConflict: "platform,article_id" });
          if (upsertErr) return json({ error: upsertErr.message }, 500);
        }
        return json({ success: true, synced: rows.length });
      }

      // blog.sync_engagement — Qiita 全記事の likes/comments/likers を DB に同期
      // (read-only 同期のみ)。auto_reply / auto_follow は恒久廃止 (2026-07-13):
      // 対他者自動アクションは Qiita アカウント停止 (2026-07-12 / ToS 違反) の
      // 最有力原因のため再実装禁止。
      case "blog.sync_engagement": {
        const qiitaToken = Deno.env.get("QIITA_ACCESS_TOKEN") ?? "";
        if (!qiitaToken) {
          return json({ error: "QIITA_ACCESS_TOKEN not set" }, 500);
        }

        // 1. 全記事取得
        const articlesRes = await qiitaFetch(
          "/authenticated_user/items?page=1&per_page=100",
          qiitaToken,
          {},
          "schedule-hub.blog.sync_engagement.articles",
        );
        if (!articlesRes.ok) {
          return await upstreamErrorJson("qiita", articlesRes);
        }
        const articles = await articlesRes.json() as Array<{
          id: string;
          title: string;
          url: string;
          likes_count: number;
          comments_count: number;
          page_views_count: number;
        }>;

        // 2. blog_engagement に UPSERT
        const engRows = articles.map((a) => ({
          platform: "qiita",
          article_id: a.id,
          title: a.title,
          url: a.url,
          likes_count: a.likes_count,
          comments_count: a.comments_count,
          views_count: a.page_views_count ?? 0,
          updated_at: new Date().toISOString(),
        }));
        await admin.from("blog_engagement").upsert(engRows, {
          onConflict: "platform,article_id",
        });

        let totalComments = 0;
        let totalLikers = 0;

        // 3. 各記事のコメント・ライカーを取得
        for (const article of articles) {
          // comments
          if (article.comments_count > 0) {
            const cr = await qiitaFetch(
              `/items/${article.id}/comments`,
              qiitaToken,
              {},
              "schedule-hub.blog.sync_engagement.comments",
            );
            if (cr.ok) {
              const comments = await cr.json() as Array<{
                id: string;
                body: string;
                created_at: string;
                user: { id: string };
              }>;
              totalComments += comments.length;
              for (const c of comments) {
                // DB に upsert (既存は上書きしない → on conflict do nothing)
                const { data: existing } = await admin
                  .from("blog_comments")
                  .select("replied")
                  .eq("platform", "qiita")
                  .eq("comment_id", c.id)
                  .single();

                const alreadyReplied =
                  (existing as { replied?: boolean } | null)?.replied === true;
                await admin.from("blog_comments").upsert({
                  platform: "qiita",
                  article_id: article.id,
                  comment_id: c.id,
                  author: c.user.id,
                  body: c.body.replace(/<[^>]+>/g, ""),
                  created_at: c.created_at,
                  fetched_at: new Date().toISOString(),
                  replied: alreadyReplied,
                }, {
                  onConflict: "platform,comment_id",
                  ignoreDuplicates: true,
                });
              }
            }
          }

          // likers (LGTM)
          if (article.likes_count > 0) {
            const lr = await qiitaFetch(
              `/items/${article.id}/likes`,
              qiitaToken,
              {},
              "schedule-hub.blog.sync_engagement.likes",
            );
            if (lr.ok) {
              const likers = await lr.json() as Array<
                { user: { id: string; name: string } }
              >;
              totalLikers += likers.length;
              for (const liker of likers) {
                const uid = liker.user.id;
                const { data: existingLiker } = await admin
                  .from("blog_likers")
                  .select("followed")
                  .eq("article_id", article.id)
                  .eq("qiita_user_id", uid)
                  .single();

                const alreadyFollowed =
                  (existingLiker as { followed?: boolean } | null)?.followed ===
                    true;
                await admin.from("blog_likers").upsert({
                  article_id: article.id,
                  qiita_user_id: uid,
                  username: liker.user.name,
                  followed: alreadyFollowed,
                  fetched_at: new Date().toISOString(),
                }, {
                  onConflict: "article_id,qiita_user_id",
                  ignoreDuplicates: true,
                });
              }
            }
          }
        }

        return json({
          success: true,
          articles_synced: articles.length,
          total_comments: totalComments,
          total_likers: totalLikers,
        });
      }

      // blog.devto_delete — dev.to 記事を削除 (unpublish)
      case "blog.devto_delete": {
        const devtoKey = Deno.env.get("DEVTO_API_KEY") ?? "";
        if (!devtoKey) return json({ error: "DEVTO_API_KEY not set" }, 500);
        const articleId = Number(body.article_id);
        if (!articleId) return json({ error: "article_id required" }, 400);
        // dev.to は物理削除不可 → unpublish で対応
        const dr = await devtoFetch(`/articles/${articleId}`, devtoKey, {
          method: "PUT",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ article: { published: false } }),
        }, "schedule-hub.blog.devto_delete");
        if (!dr.ok) return await upstreamErrorJson("dev.to", dr);
        return json({
          success: true,
          status: dr.status,
          article_id: articleId,
        });
      }

      // ─── Study Reminders (AI大学 学習リマインダー) ────────────────────────────
      case "reminders.study": {
        // service_role authorization check
        const authHeader = req.headers.get("Authorization");
        const svcToken = authHeader?.replace("Bearer ", "") ?? "";
        if (svcToken !== SERVICE_ROLE_KEY) {
          return json({ error: "Service role required" }, 403);
        }

        const minIdleDays = typeof body.min_idle_days === "number"
          ? Math.max(1, Math.min(30, body.min_idle_days as number))
          : 3;
        const maxIdleDays = typeof body.max_idle_days === "number"
          ? Math.max(minIdleDays, Math.min(90, body.max_idle_days as number))
          : 30;
        const dryRun = Boolean(body.dry_run);

        const nowJst = new Date(Date.now() + 9 * 60 * 60 * 1000);
        const todayStr = nowJst.toISOString().slice(0, 10);
        const minDate = new Date(nowJst.getTime() - maxIdleDays * 86_400_000)
          .toISOString().slice(0, 10);
        const maxDate = new Date(nowJst.getTime() - minIdleDays * 86_400_000)
          .toISOString().slice(0, 10);

        const { data: streakRows, error: streakErr } = await admin
          .from("ai_university_streaks")
          .select("user_id, current_streak, longest_streak, last_studied_date")
          .gte("last_studied_date", minDate)
          .lte("last_studied_date", maxDate);

        if (streakErr) throw streakErr;

        const candidates = streakRows ?? [];
        if (candidates.length === 0) {
          return json({
            success: true,
            eligible: 0,
            sent: 0,
            skipped_recently_reminded: 0,
            dry_run: dryRun,
            today: todayStr,
            window: { min_idle_days: minIdleDays, max_idle_days: maxIdleDays },
          });
        }

        const REMINDER_PREFIX = "[AI大学] 学習リマインダー";
        const reminderSinceIso = new Date(
          Date.now() - minIdleDays * 86_400_000,
        ).toISOString();

        const userIds = candidates.map((r) =>
          (r as { user_id: string }).user_id
        );

        const { data: recentRows, error: recentErr } = await admin
          .from("app_notifications")
          .select("user_id")
          .in("user_id", userIds)
          .eq("type", "system")
          .ilike("title", `${REMINDER_PREFIX}%`)
          .gte("created_at", reminderSinceIso);

        if (recentErr) throw recentErr;

        const recentlyReminded = new Set<string>();
        for (const row of recentRows ?? []) {
          const uid = (row as { user_id: string | null }).user_id;
          if (typeof uid === "string") recentlyReminded.add(uid);
        }

        const targets = candidates.filter((r) => {
          const uid = (r as { user_id: string }).user_id;
          return !recentlyReminded.has(uid);
        });

        if (targets.length === 0 || dryRun) {
          return json({
            success: true,
            eligible: candidates.length,
            sent: 0,
            skipped_recently_reminded: recentlyReminded.size,
            targets: dryRun ? targets.length : undefined,
            dry_run: dryRun,
            today: todayStr,
            window: { min_idle_days: minIdleDays, max_idle_days: maxIdleDays },
          });
        }

        const createdAt = new Date().toISOString();
        const payload = targets.map((row) => {
          const r = row as {
            user_id: string;
            current_streak: number;
            longest_streak: number;
            last_studied_date: string;
          };
          const idleDays = Math.max(
            0,
            Math.floor(
              (Date.parse(todayStr) - Date.parse(r.last_studied_date)) /
                86_400_000,
            ),
          );
          const bestStreak = Math.max(r.current_streak, r.longest_streak);
          const title = `${REMINDER_PREFIX} — ${idleDays}日ぶりにAIを学ぼう`;
          const message = bestStreak > 1
            ? `前回の学習から${idleDays}日経過。過去最長 ${bestStreak} 日連続を更新しよう！１分クイズでストリーク復活。`
            : `前回の学習から${idleDays}日経過。AI大学で１分クイズに挑戦して知識をアップデート。`;
          return {
            user_id: r.user_id,
            title,
            message,
            type: "system",
            link: "/ai-university",
            is_read: false,
            created_at: createdAt,
          };
        });

        const { error: insertErr } = await admin
          .from("app_notifications")
          .insert(payload);

        if (insertErr) throw insertErr;

        return json({
          success: true,
          eligible: candidates.length,
          sent: payload.length,
          skipped_recently_reminded: recentlyReminded.size,
          dry_run: false,
          today: todayStr,
          window: { min_idle_days: minIdleDays, max_idle_days: maxIdleDays },
        });
      }

      // ─── Health Check ─────────────────────────────────────────────────────────
      case "health.check": {
        const start = Date.now();
        const dbCheck = await admin.from("hub_data").select("id").limit(1);
        return json({
          success: true,
          db_ok: !dbCheck.error,
          latency_ms: Date.now() - start,
          timestamp: new Date().toISOString(),
        });
      }

      // ─── Notion WBS DB preflight ─────────────────────────────────────────
      case "notion.preflight_wbs": {
        const token = Deno.env.get("NOTION_API_TOKEN");
        const dbId = Deno.env.get("NOTION_WBS_DATABASE_ID");
        const configuredDataSourceId = Deno.env.get(
          "NOTION_WBS_DATA_SOURCE_ID",
        );
        if (!token || (!dbId && !configuredDataSourceId)) {
          return json(
            {
              success: false,
              error: "notion_not_configured",
              missing: !token
                ? "NOTION_API_TOKEN"
                : "NOTION_WBS_DATABASE_ID or NOTION_WBS_DATA_SOURCE_ID",
            },
            503,
          );
        }

        const dataSourceId = await configuredNotionDataSourceId(
          token,
          dbId,
          configuredDataSourceId,
          Deno.env.get("NOTION_WBS_DATA_SOURCE_NAME"),
        );
        const schema = await validateNotionDatabaseSchema(
          token,
          dataSourceId,
          NOTION_WBS_REQUIRED_PROPERTIES,
          { checkAdvancedProperties: true },
        );
        if (schema.error) {
          return json({
            success: false,
            error: schema.error,
            detail: schema.detail ?? "",
            findings: schema.findings,
            human_fix_required: schema.human_fix_required,
          }, schema.status ?? 502);
        }

        return json({
          success: schema.ok && schema.preflight_ok,
          schema_ok: schema.ok,
          preflight_ok: schema.preflight_ok,
          required_properties: NOTION_WBS_REQUIRED_PROPERTIES,
          detected_properties: schema.detected,
          property_mappings: schema.property_mappings,
          missing_properties: schema.missing,
          mismatched_properties: schema.mismatched,
          findings: schema.findings,
          human_fix_required: schema.human_fix_required,
        }, schema.ok && schema.preflight_ok ? 200 : 422);
      }

      // ─── Notion Sync (Multi-AI resilience / Win#132 part 6 · Backlog N2) ────
      // Win版#132 part 4 設計の N2 実装。Supabase wbs_tasks → Notion Database
      // upsert (last_edited 順で最新 500 件)。Anthropic outage 時もユーザーが
      // Notion mirror で WBS を閲覧できる = SPOF 解消。
      // Auth: service_role (public action / GHA cron から呼ぶ想定)
      // Secrets: NOTION_API_TOKEN / NOTION_WBS_DATABASE_ID or DATA_SOURCE_ID
      case "notion.sync_wbs": {
        const token = Deno.env.get("NOTION_API_TOKEN");
        const dbId = Deno.env.get("NOTION_WBS_DATABASE_ID");
        const configuredDataSourceId = Deno.env.get(
          "NOTION_WBS_DATA_SOURCE_ID",
        );
        if (!token || (!dbId && !configuredDataSourceId)) {
          return json(
            {
              success: false,
              error: "notion_not_configured",
              missing: !token
                ? "NOTION_API_TOKEN"
                : "NOTION_WBS_DATABASE_ID or NOTION_WBS_DATA_SOURCE_ID",
            },
            503,
          );
        }

        const dataSourceId = await configuredNotionDataSourceId(
          token,
          dbId,
          configuredDataSourceId,
          Deno.env.get("NOTION_WBS_DATA_SOURCE_NAME"),
        );
        // Supabase 側から最新 WBS (last_edited 順 30 件) を取得
        // 30件 × ~150ms/task ≈ 4.5s sleep + HTTP = ~30s 合計 (Supabase 150s limit に余裕)
        // 毎時 cron で 30件ずつローリング sync → 141件 ≒ 5h で全件完了
        const schema = await validateNotionDatabaseSchema(
          token,
          dataSourceId,
          NOTION_WBS_REQUIRED_PROPERTIES,
          { checkAdvancedProperties: body.advanced_preflight === true },
        );
        if (schema.error) {
          return json({
            success: false,
            error: schema.error,
            detail: schema.detail ?? "",
            findings: schema.findings,
            human_fix_required: schema.human_fix_required,
          }, schema.status ?? 502);
        }
        if (!schema.ok) {
          return json({
            success: false,
            error: "notion_schema_mismatch",
            missing_properties: schema.missing,
            mismatched_properties: schema.mismatched,
            required_properties: NOTION_WBS_REQUIRED_PROPERTIES,
            detected_properties: schema.detected,
            property_mappings: schema.property_mappings,
            findings: schema.findings,
            human_fix_required: schema.human_fix_required,
          }, 422);
        }
        if (body.advanced_preflight === true && !schema.preflight_ok) {
          return json({
            success: false,
            error: "notion_preflight_failed",
            required_properties: NOTION_WBS_REQUIRED_PROPERTIES,
            detected_properties: schema.detected,
            property_mappings: schema.property_mappings,
            findings: schema.findings,
            human_fix_required: schema.human_fix_required,
          }, 422);
        }
        if (body.schema_only === true) {
          return json({
            success: true,
            schema_ok: true,
            preflight_ok: schema.preflight_ok,
            required_properties: NOTION_WBS_REQUIRED_PROPERTIES,
            detected_properties: schema.detected,
            property_mappings: schema.property_mappings,
            findings: schema.findings,
            human_fix_required: schema.human_fix_required,
          });
        }

        const limitN = Math.min(Math.max(Number(body.limit ?? 30), 1), 50);
        const offsetN = Math.max(Number(body.offset ?? 0), 0);
        const delayMs = Math.min(
          Math.max(Number(body.delay_ms ?? 750), 350),
          2000,
        );
        const rangeTo = offsetN + limitN - 1;
        const { data: tasks, error: fetchErr } = await admin
          .from("wbs_tasks")
          .select("id, title, instance, status, progress, end_date, updated_at")
          .order("updated_at", { ascending: false })
          .order("id", { ascending: true })
          .range(offsetN, rangeTo);

        if (fetchErr) {
          return json({
            success: false,
            error: `supabase_fetch_failed: ${fetchErr.message}`,
          }, 500);
        }

        // Notion Database に upsert 相当 (id で検索 → 存在すれば patch / 無ければ create)
        let created = 0;
        let updated = 0;
        let failed = 0;
        const errors: string[] = [];

        // Notion select property options (DB schema の options と一致必須)
        // mismatch 値は default にフォールバック (400 error 回避)
        // 2026-04-25 Win#132 part 16: 'all' 廃止 / 'codex' 追加
        // ('schedule' / 'gha' は CHECK 上は有効だが Notion options 未登録のため
        //  fallback で 'win' に振り分け)
        const VALID_INSTANCES = new Set([
          "vscode",
          "win",
          "ps1",
          "ps2",
          "ps3",
          "ps4",
          "ps5",
          "ps6",
          "web",
          "mobile",
          "schedule",
          "gha",
          "codex",
          "gemini",
          "co-pilot",
          "user",
        ]);
        const VALID_STATUSES = new Set([
          "pending",
          "in_progress",
          "completed",
          "blocked",
        ]);
        const normalizeInstance = (v: unknown): string => {
          const s = String(v ?? "win").trim();
          // alias: legacy 'all' は Codex に寄せ、実行系の schedule/gha は維持する
          if (s === "all") return "codex";
          if (s === "copilot" || s === "github-copilot") return "co-pilot";
          return VALID_INSTANCES.has(s) ? s : "win";
        };
        const normalizeStatus = (v: unknown): string => {
          const s = String(v ?? "pending").trim();
          // alias: Supabase 側が "in-progress" / "not_started" を使うケースを吸収
          if (s === "in-progress") return "in_progress";
          if (s === "not_started" || s === "draft") return "pending";
          if (s === "done") return "completed";
          return VALID_STATUSES.has(s) ? s : "pending";
        };

        for (const t of tasks ?? []) {
          // Notion DB 側: id = Title-type (内部 ID "title") / task_title = rich_text
          //
          // 重要: Notion は Title-type property の内部 ID を常に "title" に固定する
          // 仕様。user の DB で Title 名が "id" でも、内部 ID "title" と重複する
          // ため、rich_text property に "title" という名前を付けると
          // "title is expected to be title" validation_error が出る。
          // → rich_text property は task_title にリネーム済 (user 手動)。
          //
          // null 値の property は omit (Notion API は `{date: null}` を受けるが
          // 他の type では 400 になるため未設定値は skip)。
          // buildNotionProperties が型別ラップ + title 衝突検知を一元化 (Issue #1287)。
          const propertyValues: Record<string, unknown> = {
            id: String(t.id),
            task_title: String(t.title ?? ""),
            instance: normalizeInstance(t.instance),
            status: normalizeStatus(t.status),
            progress: Number(t.progress ?? 0),
          };
          if (t.end_date) propertyValues.deadline = String(t.end_date);
          if (t.updated_at) propertyValues.updated_at = String(t.updated_at);

          const built = buildNotionProperties(
            NOTION_WBS_PROPERTY_MAPPINGS,
            propertyValues,
          );
          const properties = built.properties;
          for (const warning of built.warnings) {
            errors.push(`mapping ${t.id}: ${warning}`);
          }

          try {
            // 既存 page を id (Title) で検索
            const queryResp = await notionFetch(
              token,
              `/data_sources/${dataSourceId}/query`,
              {
                method: "POST",
                body: JSON.stringify({
                  filter: { property: "id", title: { equals: String(t.id) } },
                  page_size: 1,
                }),
              },
            );

            if (!queryResp.ok) {
              failed++;
              const eb = await queryResp.text().catch(() => "");
              errors.push(
                `query ${t.id}: HTTP ${queryResp.status} ${eb.slice(0, 150)}`,
              );
              continue;
            }

            const queryJson = await queryResp.json();
            const existingPageId = queryJson?.results?.[0]?.id;

            if (existingPageId) {
              // patch
              const patchResp = await notionFetch(
                token,
                `/pages/${existingPageId}`,
                {
                  method: "PATCH",
                  body: JSON.stringify({ properties }),
                },
              );
              if (patchResp.ok) updated++;
              else {
                failed++;
                const eb = await patchResp.text().catch(() => "");
                errors.push(
                  `patch ${t.id}: ${
                    extractNotionErrorDetail(patchResp.status, eb).detail
                  }`,
                );
              }
            } else {
              // create
              const createResp = await notionFetch(token, "/pages", {
                method: "POST",
                body: JSON.stringify({
                  parent: {
                    type: "data_source_id",
                    data_source_id: dataSourceId,
                  },
                  properties,
                }),
              });
              if (createResp.ok) created++;
              else {
                failed++;
                const eb = await createResp.text().catch(() => "");
                errors.push(
                  `create ${t.id}: ${
                    extractNotionErrorDetail(createResp.status, eb).detail
                  }`,
                );
              }
            }

            // Notion rate limit 対策 (3 req/sec → 150ms interval = 6.7 req/sec で余裕)
            await new Promise((r) => setTimeout(r, delayMs));
          } catch (e) {
            failed++;
            errors.push(`${t.id}: ${String(e)}`);
          }
        }

        return json({
          success: failed === 0,
          total: tasks?.length ?? 0,
          limit: limitN,
          offset: offsetN,
          delay_ms: delayMs,
          created,
          updated,
          failed,
          errors: errors.slice(0, 10), // 最初の 10 件のみ返す
        });
      }

      // ─── Notion ROADMAP Mirror (Backlog N3) ───
      // EF は repository file を直接読めないため、GHA から渡された markdown
      // content を Notion child page に置換同期する。親 ROADMAP page の手書き
      // content は保持し、"ROADMAP mirror (auto)" child page だけを更新する。
      case "notion.sync_roadmap": {
        const token = Deno.env.get("NOTION_API_TOKEN");
        const pageId = normalizeNotionId(
          Deno.env.get("NOTION_ROADMAP_PAGE_ID"),
        );
        if (!token || !pageId) {
          return json(
            {
              success: false,
              error: "notion_not_configured",
              missing: !token ? "NOTION_API_TOKEN" : "NOTION_ROADMAP_PAGE_ID",
            },
            503,
          );
        }

        const rawContent = String(body.content ?? "");
        if (!rawContent.trim()) {
          return json({ success: false, error: "content required" }, 400);
        }
        const maxChars = clampNumber(body.max_chars, 24000, 1000, 60000);
        const delayMs = clampNumber(body.delay_ms, 800, 400, 2500);
        const mirrorTitle = asString(body.title, "ROADMAP mirror (auto)");
        const sourcePath = asString(
          body.source_path,
          "docs/GROWTH_STRATEGY_ROADMAP.md",
        );
        const contentMode = asString(body.mode, "tail");
        const content = rawContent.length <= maxChars
          ? rawContent
          : contentMode === "head"
          ? rawContent.slice(0, maxChars)
          : rawContent.slice(rawContent.length - maxChars);
        const syncedAt = new Date().toISOString();
        const childPage = await findOrCreateNotionChildPage(
          token,
          pageId,
          mirrorTitle,
        );
        const chunks = chunkText(content, 1800, 80);
        const blocks: Array<Record<string, unknown>> = [
          {
            object: "block",
            type: "heading_2",
            heading_2: { rich_text: notionRichText(mirrorTitle) },
          },
          notionParagraph(
            `Synced at ${syncedAt}. Source: ${sourcePath}. Mode: ${contentMode}. ` +
              `Chars: ${content.length}/${rawContent.length}.`,
          ),
          ...chunks.map(notionCodeBlock),
        ];

        const result = await replaceNotionPageChildren(
          token,
          childPage.pageId,
          blocks,
          delayMs,
        );

        return json({
          success: true,
          page_id: childPage.pageId,
          child_page_created: childPage.created,
          source_path: sourcePath,
          mode: contentMode,
          source_chars: rawContent.length,
          synced_chars: content.length,
          chunks: chunks.length,
          archived_blocks: result.archived,
          appended_blocks: result.appended,
        });
      }

      // ─── Notion Memory Index Mirror (Backlog N4) ───
      // Primary: Supabase memory_index table (memory-search-sync.yml が更新).
      // Fallback: GHA から rows を渡して Notion DB へ upsert.
      case "notion.sync_memory_index": {
        const token = Deno.env.get("NOTION_API_TOKEN");
        const dbId = Deno.env.get("NOTION_MEMORY_DATABASE_ID");
        const configuredDataSourceId = Deno.env.get(
          "NOTION_MEMORY_DATA_SOURCE_ID",
        );
        if (!token || (!dbId && !configuredDataSourceId)) {
          return json(
            {
              success: false,
              error: "notion_not_configured",
              missing: !token
                ? "NOTION_API_TOKEN"
                : "NOTION_MEMORY_DATABASE_ID or NOTION_MEMORY_DATA_SOURCE_ID",
            },
            503,
          );
        }

        const dataSourceId = await configuredNotionDataSourceId(
          token,
          dbId,
          configuredDataSourceId,
          Deno.env.get("NOTION_MEMORY_DATA_SOURCE_NAME"),
        );
        const limitN = clampNumber(body.limit, 50, 1, 100);
        const offsetN = Math.max(asNumber(body.offset, 0), 0);
        const delayMs = clampNumber(body.delay_ms, 800, 400, 2500);
        const rowsFromBody = Array.isArray(body.rows)
          ? (body.rows as Array<Record<string, unknown>>).slice(0, limitN)
          : null;
        let rows: Array<Record<string, unknown>>;

        if (rowsFromBody) {
          rows = rowsFromBody;
        } else {
          const { data, error } = await admin
            .from("memory_index")
            .select(
              "file_path, title, snippet, source, metadata, updated_at, content_hash",
            )
            .order("updated_at", { ascending: false })
            .range(offsetN, offsetN + limitN - 1);
          if (error) {
            return json({
              success: false,
              error: `supabase_fetch_failed: ${error.message}`,
            }, 500);
          }
          rows = (data ?? []) as Array<Record<string, unknown>>;
        }

        let created = 0;
        let updated = 0;
        let failed = 0;
        const errors: string[] = [];

        for (const row of rows) {
          const filePath = asString(row.file_path ?? row.filename);
          if (!filePath) {
            failed++;
            errors.push("row skipped: file_path required");
            continue;
          }
          const title = asString(
            row.title,
            filePath.split(/[\\/]/).pop() ?? filePath,
          );
          const description = asString(row.snippet ?? row.description, title)
            .slice(0, 1800);
          const type = memoryTypeFor(filePath, row.source);
          const timestamp = dateFromMemoryPath(filePath, row.updated_at);
          const properties: Record<string, unknown> = {
            filename: {
              title: [{ text: { content: filePath.slice(0, 2000) } }],
            },
            type: { select: { name: type } },
            description: { rich_text: notionRichText(description) },
          };
          if (timestamp) {
            properties.timestamp = { date: { start: timestamp } };
          }

          try {
            const result = await upsertNotionDataSourcePage(
              token,
              dataSourceId,
              "filename",
              filePath,
              properties,
            );
            if (result === "created") created++;
            else updated++;
          } catch (e) {
            failed++;
            errors.push(`${filePath}: ${String(e).slice(0, 220)}`);
          }
          await new Promise((r) => setTimeout(r, delayMs));
        }

        return json({
          success: failed === 0,
          total: rows.length,
          source: rowsFromBody ? "request_rows" : "memory_index",
          limit: limitN,
          offset: offsetN,
          created,
          updated,
          failed,
          errors: errors.slice(0, 10),
        });
      }

      // ─── Notion Wiki Index Mirror (Karpathy Compile → Notion) ──────────────
      // wiki_compile.py が生成した docs/INDEX.md を Notion へ自動ミラー。
      // 親ページ: NOTION_WIKI_PAGE_ID (未設定時は NOTION_ROADMAP_PAGE_ID にフォールバック)
      // 子ページ "Wiki Index (auto)" を find-or-create して全文置換。
      case "notion.sync_wiki_index": {
        const token = Deno.env.get("NOTION_API_TOKEN");
        const pageId = normalizeNotionId(
          Deno.env.get("NOTION_WIKI_PAGE_ID") ??
            Deno.env.get("NOTION_ROADMAP_PAGE_ID"),
        );
        if (!token || !pageId) {
          return json(
            {
              success: false,
              error: "notion_not_configured",
              missing: !token
                ? "NOTION_API_TOKEN"
                : "NOTION_WIKI_PAGE_ID (or NOTION_ROADMAP_PAGE_ID)",
            },
            503,
          );
        }

        const rawContent = String(body.content ?? "");
        if (!rawContent.trim()) {
          return json({ success: false, error: "content required" }, 400);
        }
        const maxChars = clampNumber(body.max_chars, 24000, 1000, 60000);
        const delayMs = clampNumber(body.delay_ms, 800, 400, 2500);
        const mirrorTitle = asString(body.title, "Wiki Index (auto)");
        const sourcePath = asString(body.source_path, "docs/INDEX.md");
        const content = rawContent.length <= maxChars
          ? rawContent
          : rawContent.slice(0, maxChars);
        const syncedAt = new Date().toISOString();
        const childPage = await findOrCreateNotionChildPage(
          token,
          pageId,
          mirrorTitle,
        );
        const chunks = chunkText(content, 1800, 80);
        const blocks: Array<Record<string, unknown>> = [
          {
            object: "block",
            type: "heading_2",
            heading_2: { rich_text: notionRichText(mirrorTitle) },
          },
          notionParagraph(
            `Synced at ${syncedAt}. Source: ${sourcePath}. ` +
              `Chars: ${content.length}/${rawContent.length}.`,
          ),
          ...chunks.map(notionCodeBlock),
        ];

        const result = await replaceNotionPageChildren(
          token,
          childPage.pageId,
          blocks,
          delayMs,
        );

        return json({
          success: true,
          page_id: childPage.pageId,
          child_page_created: childPage.created,
          source_path: sourcePath,
          source_chars: rawContent.length,
          synced_chars: content.length,
          chunks: chunks.length,
          archived_blocks: result.archived,
          appended_blocks: result.appended,
        });
      }

      // ─── Notion WBS Mirror Repair ───
      case "notion.fix_wbs_all_instances": {
        const token = Deno.env.get("NOTION_API_TOKEN");
        const dbId = Deno.env.get("NOTION_WBS_DATABASE_ID");
        const configuredDataSourceId = Deno.env.get(
          "NOTION_WBS_DATA_SOURCE_ID",
        );
        if (!token || (!dbId && !configuredDataSourceId)) {
          return json(
            {
              success: false,
              error: "notion_not_configured",
              missing: !token
                ? "NOTION_API_TOKEN"
                : "NOTION_WBS_DATABASE_ID or NOTION_WBS_DATA_SOURCE_ID",
            },
            503,
          );
        }

        const dataSourceId = await configuredNotionDataSourceId(
          token,
          dbId,
          configuredDataSourceId,
          Deno.env.get("NOTION_WBS_DATA_SOURCE_NAME"),
        );
        const notionHeaders = {
          "Authorization": `Bearer ${token}`,
          "Notion-Version": NOTION_VERSION,
          "Content-Type": "application/json",
        };
        const validInstances = new Set([
          "codex",
          "gemini",
          "co-pilot",
          "vscode",
          "win",
          "ps1",
          "ps2",
          "ps3",
          "ps4",
          "ps5",
          "ps6",
          "web",
          "mobile",
          "schedule",
          "gha",
          "user",
        ]);
        const normalizeInstance = (v: unknown): string => {
          const s = String(v ?? "codex").trim();
          if (s === "all") return "codex";
          if (s === "copilot" || s === "github-copilot") return "co-pilot";
          return validInstances.has(s) ? s : "codex";
        };
        const normalizeStatus = (v: unknown): string => {
          const s = String(v ?? "pending").trim();
          if (s === "in-progress") return "in_progress";
          if (s === "not_started" || s === "draft") return "pending";
          if (s === "done") return "completed";
          return ["pending", "in_progress", "completed", "blocked"].includes(s)
            ? s
            : "pending";
        };

        const maxPages = Math.min(
          Math.max(Number(body.max_pages ?? 40), 1),
          80,
        );
        const pages: Record<string, unknown>[] = [];
        let cursor: string | null = null;
        for (let i = 0; i < 10; i++) {
          const pageSize = Math.min(maxPages - pages.length, 100);
          if (pageSize <= 0) break;
          const queryResp: Response = await externalFetch(
            "notion",
            `https://api.notion.com/v1/data_sources/${dataSourceId}/query`,
            {
              method: "POST",
              headers: notionHeaders,
              body: JSON.stringify({
                filter: { property: "instance", select: { equals: "all" } },
                page_size: pageSize,
                ...(cursor ? { start_cursor: cursor } : {}),
              }),
            },
            { traceId: "schedule-hub.notion.fix_wbs_all_instances.query" },
          );
          if (!queryResp.ok) {
            const text = await queryResp.text().catch(() => "");
            return json({
              success: false,
              error: `notion_query_failed: HTTP ${queryResp.status}`,
              details: text.slice(0, 300),
            }, 502);
          }
          const queryJson = await queryResp.json() as {
            results?: Record<string, unknown>[];
            has_more?: boolean;
            next_cursor?: string | null;
          };
          pages.push(...(queryJson.results ?? []));
          if (pages.length >= maxPages) break;
          if (!queryJson.has_more || !queryJson.next_cursor) break;
          cursor = queryJson.next_cursor;
        }

        const pageIdByTaskId = new Map<string, string>();
        for (const page of pages) {
          const props = (page.properties ?? {}) as Record<string, unknown>;
          const idProp = (props.id ?? {}) as Record<string, unknown>;
          const titleItems = (idProp.title ?? []) as Record<string, unknown>[];
          const taskId = String(
            titleItems[0]?.plain_text ??
              ((titleItems[0]?.text as Record<string, unknown> | undefined)
                ?.content) ??
              "",
          ).trim();
          if (taskId && page.id) pageIdByTaskId.set(taskId, String(page.id));
        }

        const taskIds = Array.from(pageIdByTaskId.keys());
        const tasksById = new Map<string, Record<string, unknown>>();
        if (taskIds.length > 0) {
          const { data: tasks, error: tasksErr } = await admin
            .from("wbs_tasks")
            .select(
              "id, title, instance, status, progress, end_date, updated_at",
            )
            .in("id", taskIds);
          if (tasksErr) {
            return json({
              success: false,
              error: `supabase_fetch_failed: ${tasksErr.message}`,
            }, 500);
          }
          for (const task of tasks ?? []) {
            tasksById.set(String(task.id), task as Record<string, unknown>);
          }
        }

        let updated = 0;
        let missing = 0;
        let failed = 0;
        const errors: string[] = [];
        const delayMs = Math.min(
          Math.max(Number(body.delay_ms ?? 900), 500),
          2500,
        );

        for (const [taskId, pageId] of pageIdByTaskId.entries()) {
          const task = tasksById.get(taskId);
          if (!task) missing++;
          // buildNotionProperties が型別ラップ + title 衝突検知を一元化 (Issue #1287)。
          // id (title) は pageId 指定 patch のため values に含めず skip させる。
          const propertyValues: Record<string, unknown> = {
            instance: normalizeInstance(task?.instance ?? "codex"),
          };
          if (task) {
            propertyValues.task_title = String(task.title ?? "");
            propertyValues.status = normalizeStatus(task.status);
            propertyValues.progress = Number(task.progress ?? 0);
            if (task.end_date) propertyValues.deadline = String(task.end_date);
            if (task.updated_at) {
              propertyValues.updated_at = String(task.updated_at);
            }
          }
          const properties = buildNotionProperties(
            NOTION_WBS_PROPERTY_MAPPINGS,
            propertyValues,
          ).properties;

          const patchResp = await externalFetch(
            "notion",
            `https://api.notion.com/v1/pages/${pageId}`,
            {
              method: "PATCH",
              headers: notionHeaders,
              body: JSON.stringify({ properties }),
            },
            { traceId: "schedule-hub.notion.fix_wbs_all_instances.patch" },
          );
          if (patchResp.ok) {
            updated++;
          } else {
            failed++;
            const text = await patchResp.text().catch(() => "");
            errors.push(
              `patch ${taskId}: ${
                extractNotionErrorDetail(patchResp.status, text).detail
              }`,
            );
          }
          await new Promise((r) => setTimeout(r, delayMs));
        }

        const verifyResp = await externalFetch(
          "notion",
          `https://api.notion.com/v1/data_sources/${dataSourceId}/query`,
          {
            method: "POST",
            headers: notionHeaders,
            body: JSON.stringify({
              filter: { property: "instance", select: { equals: "all" } },
              page_size: 1,
            }),
          },
          { traceId: "schedule-hub.notion.fix_wbs_all_instances.verify" },
        );
        let remainingAll: number | null = null;
        if (verifyResp.ok) {
          const verifyJson = await verifyResp.json();
          remainingAll = Number(verifyJson.results?.length ?? 0);
          if (verifyJson.has_more) remainingAll = -1;
        }

        return json({
          success: failed === 0,
          max_pages: maxPages,
          found_all_pages: pages.length,
          matched_task_ids: taskIds.length,
          updated,
          missing,
          failed,
          remaining_all_sample_count: remainingAll,
          errors: errors.slice(0, 10),
        });
      }

      // ─── WBS Unblock Dependents (Win版#132 part 12 / wbs-ai-review.yml 補完) ───
      // pending かつ depends_on の全要素が completed の task を in_progress に遷移。
      // Public action (GHA cron から呼ぶ) / service_role で raw SQL 相当の logic を実行。
      // 設計: docs/BUSINESS_WBS_AI_AUTOMATION.md (Phase 2 unblock loop)
      case "wbs.unblock_dependents": {
        // 全 pending task を fetch (depends_on を含む)
        const { data: pending, error: pendingErr } = await admin
          .from("wbs_tasks")
          .select("id, depends_on")
          .eq("status", "pending")
          .not("depends_on", "is", null);

        if (pendingErr) {
          return json({
            success: false,
            error: `fetch_pending_failed: ${pendingErr.message}`,
          }, 500);
        }

        // 全 completed task の id set を取得
        const { data: completed, error: completedErr } = await admin
          .from("wbs_tasks")
          .select("id")
          .eq("status", "completed");

        if (completedErr) {
          return json({
            success: false,
            error: `fetch_completed_failed: ${completedErr.message}`,
          }, 500);
        }

        const completedSet = new Set((completed ?? []).map((c) => c.id));

        // depends_on の全要素が completed の task を unblock
        const unblockable: string[] = [];
        for (const t of pending ?? []) {
          const deps = (t.depends_on ?? []) as string[];
          if (deps.length === 0) continue; // depends_on 空 = ここでは触らない
          const allCompleted = deps.every((d) => completedSet.has(d));
          if (allCompleted) unblockable.push(t.id);
        }

        // bulk update
        let unblocked = 0;
        if (unblockable.length > 0) {
          const { error: updErr } = await admin
            .from("wbs_tasks")
            .update({ status: "in_progress" })
            .in("id", unblockable);
          if (updErr) {
            return json({
              success: false,
              error: `update_failed: ${updErr.message}`,
            }, 500);
          }
          unblocked = unblockable.length;
        }

        return json({
          success: true,
          checked: pending?.length ?? 0,
          unblocked,
          ids: unblockable.slice(0, 20),
        });
      }

      // ─── Default ──────────────────────────────────────────────────────────────
      default:
        return json({ error: `Unknown action: ${action}` }, 400);
    }
  } catch (e) {
    if (isExternalFetchError(e)) {
      return json({
        success: false,
        ...externalFetchErrorPayload(e),
      }, 503);
    }
    if (e instanceof NotionDataSourceError) {
      return json({
        success: false,
        error: e.code,
        detail: e.detail ?? e.message,
        upstream_status: e.status ?? null,
      }, e.status ? 502 : 422);
    }
    return json({ error: String(e) }, 500);
  }
});
