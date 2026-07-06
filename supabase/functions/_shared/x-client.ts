import { asString, requireEnv, sleep } from "./edge.ts";

const X_API_KEY = Deno.env.get("X_API_KEY") ?? "";
const X_API_SECRET = Deno.env.get("X_API_SECRET") ?? "";
const X_ACCESS_TOKEN = Deno.env.get("X_ACCESS_TOKEN") ?? "";
const X_ACCESS_TOKEN_SECRET = Deno.env.get("X_ACCESS_TOKEN_SECRET") ?? "";
const X_BEARER_TOKEN = Deno.env.get("X_BEARER_TOKEN") ?? "";
const X_ACCOUNT_HANDLE = Deno.env.get("X_ACCOUNT_HANDLE") ?? "@kanta13jp1";
const MAX_REMOTE_MEDIA_BYTES = 64 * 1024 * 1024;
const CHUNK_SIZE_BYTES = 4 * 1024 * 1024;

export interface UploadedXMedia {
  mediaId: string;
  mediaKey: string | null;
  mediaType: string;
  sizeBytes: number;
  processingState: string;
}

export interface XTweetResult {
  tweetId: string | null;
  account: string;
  raw: Record<string, unknown>;
}

export interface XTrend {
  name: string;
  query: string | null;
  tweetCount: number | null;
  url: string | null;
}

export interface XTweetMetrics {
  tweetId: string;
  text: string | null;
  createdAt: string | null;
  publicMetrics: Record<string, unknown>;
  nonPublicMetrics: Record<string, unknown>;
  organicMetrics: Record<string, unknown>;
  impressions: number | null;
  engagements: number;
  likeCount: number;
  replyCount: number;
  repostCount: number;
  quoteCount: number;
  bookmarkCount: number;
  score: number;
  raw: Record<string, unknown>;
}

export interface XApiErrorPayload {
  code: string;
  status: number;
  reason: string | null;
  title: string | null;
  detail: string | null;
  requiredEnrollment: string | null;
  registrationUrl: string | null;
  actionRequired: string;
  raw: Record<string, unknown> | string;
}

export class XApiError extends Error {
  readonly payload: XApiErrorPayload;

  constructor(payload: XApiErrorPayload) {
    super(buildXApiErrorMessage(payload));
    this.name = "XApiError";
    this.payload = payload;
  }
}

export function getXAccountHandle(): string {
  return X_ACCOUNT_HANDLE;
}

export function isXConfigured(): boolean {
  return (
    X_API_KEY !== "" &&
    X_API_SECRET !== "" &&
    X_ACCESS_TOKEN !== "" &&
    X_ACCESS_TOKEN_SECRET !== ""
  );
}

export function assertXConfigured() {
  if (!isXConfigured()) {
    throw new Error(
      "X API credentials not configured. Set X_API_KEY, X_API_SECRET, X_ACCESS_TOKEN, and X_ACCESS_TOKEN_SECRET in Supabase secrets.",
    );
  }
}

export async function fetchXTrendsByWoeid(options: {
  woeid: number;
  maxTrends?: number;
}): Promise<XTrend[]> {
  const woeid = Number.isFinite(options.woeid) ? Math.trunc(options.woeid) : 0;
  if (woeid <= 0) throw new Error("woeid must be a positive number.");
  const maxTrends = Math.max(1, Math.min(50, options.maxTrends ?? 10));

  if (X_BEARER_TOKEN !== "") {
    const url = new URL(
      `https://api.x.com/2/trends/by/woeid/${
        encodeURIComponent(String(woeid))
      }`,
    );
    url.searchParams.set("max_trends", String(maxTrends));
    url.searchParams.set("trend.fields", "trend_name,tweet_count");
    const response = await fetch(url, {
      headers: { Authorization: `Bearer ${X_BEARER_TOKEN}` },
    });
    const parsed = await parseXResponse(response);
    return normalizeXTrends(parsed).slice(0, maxTrends);
  }

  assertXConfigured();
  const url = new URL("https://api.twitter.com/1.1/trends/place.json");
  url.searchParams.set("id", String(woeid));
  const oauthHeader = await buildOAuthHeader("GET", url.toString());
  const response = await fetch(url, {
    headers: { Authorization: oauthHeader },
  });
  const parsed = await parseXResponse(response);
  return normalizeXTrends(parsed).slice(0, maxTrends);
}

export async function fetchXTweetMetrics(
  tweetIds: string[],
): Promise<XTweetMetrics[]> {
  assertXConfigured();
  // X API v2 の /2/tweets は 1 リクエスト最大 100 id。従来は `.slice(0, 100)` で
  // 101 件目以降を黙って切り捨てており、投稿数が増えるほど計測から漏れた
  // (perf フィードバックループの入力欠損)。100 件ずつ順次バッチで全件取得する。
  const ids = [...new Set(tweetIds.map(asString).filter((id) => id !== ""))];
  if (ids.length === 0) return [];

  const results: XTweetMetrics[] = [];
  for (let i = 0; i < ids.length; i += 100) {
    const batch = ids.slice(i, i + 100);
    try {
      results.push(
        ...await fetchXTweetMetricsWithFields(batch, [
          "created_at",
          "text",
          "public_metrics",
          "non_public_metrics",
          "organic_metrics",
        ]),
      );
    } catch (error) {
      const payload = isXApiError(error) ? error.payload : null;
      if (payload && (payload.status === 400 || payload.status === 403)) {
        // 昇格フィールド非対応(未認可)時のダウングレードはバッチ単位で維持。
        results.push(
          ...await fetchXTweetMetricsWithFields(batch, [
            "created_at",
            "text",
            "public_metrics",
          ]),
        );
      } else {
        throw error;
      }
    }
  }
  return results;
}

async function fetchXTweetMetricsWithFields(
  tweetIds: string[],
  fields: string[],
): Promise<XTweetMetrics[]> {
  const url = new URL("https://api.twitter.com/2/tweets");
  url.searchParams.set("ids", tweetIds.join(","));
  url.searchParams.set("tweet.fields", fields.join(","));
  const oauthHeader = await buildOAuthHeader("GET", url.toString());
  const response = await fetch(url, {
    headers: { Authorization: oauthHeader },
  });
  const parsed = await parseXResponse(response);
  return normalizeXTweetMetrics(parsed);
}

export function isXApiError(error: unknown): error is XApiError {
  return error instanceof XApiError;
}

export async function uploadMediaFromUrl(
  mediaUrl: string,
  options: {
    fileName?: string;
    mediaType?: string;
    mediaCategory?: string;
    altText?: string;
  } = {},
): Promise<UploadedXMedia> {
  assertXConfigured();
  const binary = await fetchRemoteBinary(mediaUrl, options.mediaType);
  return await uploadMediaBytes(binary.bytes, {
    fileName: options.fileName || inferFileName(mediaUrl, binary.mediaType),
    mediaType: options.mediaType || binary.mediaType,
    mediaCategory: options.mediaCategory,
    altText: options.altText,
  });
}

export async function uploadMediaBytes(
  bytes: Uint8Array,
  options: {
    fileName?: string;
    mediaType?: string;
    mediaCategory?: string;
    altText?: string;
  } = {},
): Promise<UploadedXMedia> {
  assertXConfigured();
  if (bytes.byteLength === 0) {
    throw new Error("Cannot upload empty media.");
  }

  const mediaType = normalizeMediaType(options.mediaType);
  const mediaCategory = asString(options.mediaCategory) ||
    inferMediaCategory(mediaType);
  const fileName = asString(options.fileName) || inferFileName("", mediaType);

  const initResponse = await postForm(
    "https://upload.twitter.com/1.1/media/upload.json",
    {
      command: "INIT",
      total_bytes: String(bytes.byteLength),
      media_type: mediaType,
      media_category: mediaCategory,
    },
  );

  const mediaId = asString(initResponse.media_id_string) ||
    asString(initResponse.media_id);
  if (mediaId === "") {
    throw new Error("X media upload INIT did not return media_id.");
  }

  let segmentIndex = 0;
  for (let offset = 0; offset < bytes.byteLength; offset += CHUNK_SIZE_BYTES) {
    const chunk = bytes.slice(offset, offset + CHUNK_SIZE_BYTES);
    await appendChunk(mediaId, segmentIndex, chunk, fileName, mediaType);
    segmentIndex += 1;
  }

  const finalizeResponse = await postForm(
    "https://upload.twitter.com/1.1/media/upload.json",
    {
      command: "FINALIZE",
      media_id: mediaId,
    },
  );

  const processingState = await waitForMediaProcessing(
    mediaId,
    finalizeResponse,
  );

  // アクセシビリティ用の alt text を付与 (= 到達を僅かに広げ、ペナルティ無し)。
  // 失敗しても投稿を絶対にブロックしないよう log のみで飲み込む。
  const altText = asString(options.altText);
  if (altText !== "") {
    try {
      await setMediaAltText(mediaId, altText);
    } catch (error) {
      console.error(
        `[x-client] setMediaAltText failed for media ${mediaId} (non-fatal):`,
        error,
      );
    }
  }

  return {
    mediaId,
    mediaKey: asString(finalizeResponse.media_key) || null,
    mediaType,
    sizeBytes: bytes.byteLength,
    processingState,
  };
}

/**
 * media/metadata/create の JSON body を組み立てる純粋関数 (= test 可能に分離)。
 * alt_text.text は X の上限 1000 字で切り詰める。
 */
export function buildMediaAltTextBody(
  mediaId: string,
  altText: string,
): { media_id: string; alt_text: { text: string } } {
  return {
    media_id: mediaId,
    alt_text: { text: altText.slice(0, 1000) },
  };
}

/**
 * アップロード済み media に alt text を付与する。
 * JSON body なので requestParams は空 = postTweet と同じ署名パス。
 * 呼び出し側 (uploadMediaBytes) が try/catch で飲み込むため、ここでは throw してよい。
 */
export async function setMediaAltText(
  mediaId: string,
  altText: string,
): Promise<void> {
  const url = "https://upload.twitter.com/1.1/media/metadata/create";
  const oauthHeader = await buildOAuthHeader("POST", url);
  await fetch(url, {
    method: "POST",
    headers: {
      Authorization: oauthHeader,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(buildMediaAltTextBody(mediaId, altText)),
  });
}

export interface XTweetPoll {
  options: string[];
  durationMinutes: number;
}

export interface PostTweetInput {
  text: string;
  mediaIds?: string[];
  replyToTweetId?: string;
  // ネイティブ投票(H7 / impressions ブースター)。省略時は従来と完全に同一の
  // payload になる(additive / default-off)。
  poll?: XTweetPoll;
}

/**
 * POST /2/tweets の request body を組み立てる純関数(ネットワーク非依存)。
 * postTweet 本体から切り出して deno test 可能にしている。
 * poll+media 同居ガードと 2 選択肢以上のゲートはここに集約する。
 */
export function buildTweetPayload(
  input: PostTweetInput,
): Record<string, unknown> {
  const text = asString(input.text);
  if (text === "") {
    throw new Error("text is required.");
  }
  // X Premium(認証済みアカウント)は最大25,000字の長文ポストが可能。280字で弾かない。
  if (text.length > 25000) {
    throw new Error("text exceeds 25000 characters.");
  }

  const payload: Record<string, unknown> = { text };
  const mediaIds = (input.mediaIds ?? [])
    .map((entry) => asString(entry))
    .filter((entry) => entry !== "")
    .slice(0, 4);
  if (mediaIds.length > 0) {
    payload.media = { media_ids: mediaIds };
  }

  const replyToTweetId = asString(input.replyToTweetId);
  if (replyToTweetId !== "") {
    payload.reply = { in_reply_to_tweet_id: replyToTweetId };
  }

  // X API v2 は POST /2/tweets に poll を直接受け付ける(新エンドポイント/scope 不要)。
  // 各選択肢<=25字・2〜4個・期間5〜10080分。X は 1 ツイートに poll と media の同居を
  // 禁止するため、poll は media を持たない text-only の最初のリプライにのみ載せる
  // (media 付きのリード投稿には絶対に載せない)。
  const pollOptions = (input.poll?.options ?? [])
    .map((option) => asString(option))
    .filter((option) => option !== "")
    .slice(0, 4);
  if (pollOptions.length >= 2) {
    if (payload.media) {
      throw new Error("poll and media cannot coexist on one tweet");
    }
    payload.poll = {
      options: pollOptions,
      duration_minutes: Math.max(
        5,
        Math.min(10080, Math.trunc(input.poll!.durationMinutes || 1440)),
      ),
    };
  }
  return payload;
}

export async function postTweet(input: PostTweetInput): Promise<XTweetResult> {
  assertXConfigured();
  const payload = buildTweetPayload(input);

  const tweetUrl = "https://api.twitter.com/2/tweets";
  const oauthHeader = await buildOAuthHeader("POST", tweetUrl);
  const response = await fetch(tweetUrl, {
    method: "POST",
    headers: {
      Authorization: oauthHeader,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(payload),
  });

  const result = await parseXResponse(response);
  return {
    tweetId: asString(asObject(result.data).id) || null,
    account: X_ACCOUNT_HANDLE,
    raw: result,
  };
}

async function appendChunk(
  mediaId: string,
  segmentIndex: number,
  chunk: Uint8Array,
  fileName: string,
  mediaType: string,
) {
  const uploadUrl = "https://upload.twitter.com/1.1/media/upload.json";
  const oauthHeader = await buildOAuthHeader("POST", uploadUrl);
  const formData = new FormData();
  formData.set("command", "APPEND");
  formData.set("media_id", mediaId);
  formData.set("segment_index", String(segmentIndex));
  formData.set(
    "media",
    new Blob([chunk.slice().buffer as ArrayBuffer], { type: mediaType }),
    fileName,
  );

  const response = await fetch(uploadUrl, {
    method: "POST",
    headers: {
      Authorization: oauthHeader,
    },
    body: formData,
  });

  if (!response.ok) {
    const text = await response.text();
    throw new Error(
      `X media upload APPEND failed (${response.status}): ${text}`,
    );
  }
}

async function waitForMediaProcessing(
  mediaId: string,
  initialResponse: Record<string, unknown>,
): Promise<string> {
  let info = asObject(initialResponse.processing_info);
  let state = asString(info.state);
  if (state === "" || state === "succeeded") {
    return state || "ready";
  }

  for (let attempt = 0; attempt < 8; attempt += 1) {
    const checkAfterSeconds = Math.min(
      15,
      Math.max(1, Number(info.check_after_secs ?? 2)),
    );
    await sleep(checkAfterSeconds * 1000);

    const statusUrl = new URL(
      "https://upload.twitter.com/1.1/media/upload.json",
    );
    statusUrl.searchParams.set("command", "STATUS");
    statusUrl.searchParams.set("media_id", mediaId);
    const oauthHeader = await buildOAuthHeader("GET", statusUrl.toString());
    const response = await fetch(statusUrl, {
      method: "GET",
      headers: {
        Authorization: oauthHeader,
      },
    });

    const result = await parseXResponse(response);
    info = asObject(result.processing_info);
    state = asString(info.state);
    if (state === "succeeded") {
      return state;
    }
    if (state === "failed") {
      const errorMessage = asString(asObject(info.error).message) ||
        "media processing failed";
      throw new Error(`X media processing failed: ${errorMessage}`);
    }
  }

  return state || "pending";
}

async function fetchRemoteBinary(
  mediaUrl: string,
  requestedMediaType?: string,
): Promise<{ bytes: Uint8Array; mediaType: string }> {
  const normalizedUrl = asString(mediaUrl);
  if (normalizedUrl === "") {
    throw new Error("mediaUrl is required.");
  }

  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), 30000);
  try {
    const response = await fetch(normalizedUrl, {
      method: "GET",
      redirect: "follow",
      signal: controller.signal,
    });
    if (!response.ok) {
      throw new Error(
        `Failed to fetch media from ${normalizedUrl}: ${response.status}`,
      );
    }

    const arrayBuffer = await response.arrayBuffer();
    const bytes = new Uint8Array(arrayBuffer);
    if (bytes.byteLength > MAX_REMOTE_MEDIA_BYTES) {
      throw new Error(
        `Remote media exceeds ${
          MAX_REMOTE_MEDIA_BYTES / 1024 / 1024
        }MB safety limit.`,
      );
    }

    return {
      bytes,
      mediaType: normalizeMediaType(
        requestedMediaType || response.headers.get("content-type") || "",
      ),
    };
  } finally {
    clearTimeout(timeoutId);
  }
}

async function postForm(
  url: string,
  params: Record<string, string>,
): Promise<Record<string, unknown>> {
  const oauthHeader = await buildOAuthHeader("POST", url, params);
  const response = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: oauthHeader,
      "Content-Type": "application/x-www-form-urlencoded;charset=UTF-8",
    },
    body: new URLSearchParams(params),
  });
  return await parseXResponse(response);
}

async function buildOAuthHeader(
  method: string,
  url: string,
  requestParams: Record<string, string> = {},
): Promise<string> {
  const oauthParams: Record<string, string> = {
    oauth_consumer_key: requireEnv("X_API_KEY"),
    oauth_nonce: crypto.randomUUID().replace(/-/g, ""),
    oauth_signature_method: "HMAC-SHA1",
    oauth_timestamp: String(Math.floor(Date.now() / 1000)),
    oauth_token: requireEnv("X_ACCESS_TOKEN"),
    oauth_version: "1.0",
  };
  oauthParams.oauth_signature = await computeOAuthSignature(
    method,
    url,
    oauthParams,
    requestParams,
  );

  return "OAuth " + Object.entries(oauthParams)
    .sort(([left], [right]) => left.localeCompare(right))
    .map(([key, value]) => `${percentEncode(key)}="${percentEncode(value)}"`)
    .join(", ");
}

async function computeOAuthSignature(
  method: string,
  url: string,
  oauthParams: Record<string, string>,
  requestParams: Record<string, string>,
): Promise<string> {
  const parsedUrl = new URL(url);
  const signatureParams: Record<string, string> = {
    ...oauthParams,
    ...Object.fromEntries(parsedUrl.searchParams.entries()),
    ...requestParams,
  };

  const parameterString = Object.entries(signatureParams)
    .sort(([left], [right]) => left.localeCompare(right))
    .map(([key, value]) => `${percentEncode(key)}=${percentEncode(value)}`)
    .join("&");

  const baseString = [
    method.toUpperCase(),
    percentEncode(`${parsedUrl.origin}${parsedUrl.pathname}`),
    percentEncode(parameterString),
  ].join("&");
  const signingKey = `${percentEncode(requireEnv("X_API_SECRET"))}&${
    percentEncode(requireEnv("X_ACCESS_TOKEN_SECRET"))
  }`;

  const cryptoKey = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(signingKey),
    { name: "HMAC", hash: "SHA-1" },
    false,
    ["sign"],
  );
  const signatureBuffer = await crypto.subtle.sign(
    "HMAC",
    cryptoKey,
    new TextEncoder().encode(baseString),
  );

  return btoa(String.fromCharCode(...new Uint8Array(signatureBuffer)));
}

async function parseXResponse(
  response: Response,
): Promise<Record<string, unknown>> {
  const text = await response.text();
  const parsed = safeJsonParse(text);
  if (!response.ok) {
    throw new XApiError(buildXApiErrorPayload(response.status, parsed, text));
  }
  return parsed;
}

export function buildXApiErrorPayload(
  status: number,
  parsed: Record<string, unknown>,
  rawText: string,
): XApiErrorPayload {
  const reason = asString(parsed.reason) || null;
  const title = asString(parsed.title) || null;
  const detail = asString(parsed.detail) || null;
  const registrationUrl = asString(parsed.registration_url) || null;
  const requiredEnrollment = asString(parsed.required_enrollment) || null;
  // 実障害(2026-07-06): X API のクレジット制プランで残高ゼロになると
  // 402 "does not have any credits" で全投稿・計測がブロックされる。
  // spend cap 到達由来の 403 も同じ課金起因なので単一コードへ正規化する。
  const billingText = `${detail ?? ""} ${title ?? ""} ${rawText}`;
  const isBillingBlocked = status === 402 ||
    (status === 403 && /spend cap|billing cycle|credit/i.test(billingText));
  const code = isBillingBlocked
    ? "x_billing_blocked"
    : reason === "client-not-enrolled"
    ? "x_client_not_enrolled"
    : status === 403
    ? "x_forbidden"
    : `x_api_${status}`;
  return {
    code,
    status,
    reason,
    title,
    detail,
    requiredEnrollment,
    registrationUrl,
    actionRequired: buildXActionRequired(code, requiredEnrollment),
    raw: Object.keys(parsed).length > 0 ? parsed : rawText,
  };
}

function normalizeXTrends(payload: unknown): XTrend[] {
  const root = Array.isArray(payload) ? payload[0] : payload;
  const rootObject = asObject(root);
  const data = Array.isArray(rootObject.data)
    ? rootObject.data
    : Array.isArray(rootObject.trends)
    ? rootObject.trends
    : Array.isArray(payload)
    ? payload
    : [];
  return data
    .map((entry) => asObject(entry))
    .map((entry) => {
      const name = asString(entry.trend_name) ||
        asString(entry.name) ||
        asString(entry.topic);
      if (name === "") return null;
      return {
        name,
        query: asString(entry.query) || null,
        tweetCount: firstFiniteNumber(entry.tweet_count, entry.tweet_volume),
        url: asString(entry.url) || null,
      };
    })
    .filter((entry): entry is XTrend => entry !== null);
}

function normalizeXTweetMetrics(payload: unknown): XTweetMetrics[] {
  const root = asObject(payload);
  const data = Array.isArray(root.data) ? root.data : [];
  return data
    .map((entry) => asObject(entry))
    .map((tweet) => {
      const tweetId = asString(tweet.id);
      if (tweetId === "") return null;
      const publicMetrics = asObject(tweet.public_metrics);
      const nonPublicMetrics = asObject(tweet.non_public_metrics);
      const organicMetrics = asObject(tweet.organic_metrics);
      const likeCount = firstFiniteNumber(publicMetrics.like_count) ?? 0;
      const replyCount = firstFiniteNumber(publicMetrics.reply_count) ?? 0;
      const repostCount = firstFiniteNumber(publicMetrics.retweet_count) ?? 0;
      const quoteCount = firstFiniteNumber(publicMetrics.quote_count) ?? 0;
      const bookmarkCount = firstFiniteNumber(publicMetrics.bookmark_count) ??
        0;
      const urlClicks = firstFiniteNumber(
        nonPublicMetrics.url_link_clicks,
        organicMetrics.url_link_clicks,
      ) ?? 0;
      const profileClicks = firstFiniteNumber(
        nonPublicMetrics.user_profile_clicks,
        organicMetrics.user_profile_clicks,
      ) ?? 0;
      const impressions = firstFiniteNumber(
        publicMetrics.impression_count,
        nonPublicMetrics.impression_count,
        organicMetrics.impression_count,
      );
      const engagements = likeCount + replyCount + repostCount + quoteCount +
        bookmarkCount + urlClicks + profileClicks;
      const score = impressions ??
        (repostCount * 120 + quoteCount * 100 + replyCount * 80 +
          bookmarkCount * 60 + likeCount * 20 + urlClicks * 150);
      return {
        tweetId,
        text: asString(tweet.text) || null,
        createdAt: asString(tweet.created_at) || null,
        publicMetrics,
        nonPublicMetrics,
        organicMetrics,
        impressions,
        engagements,
        likeCount,
        replyCount,
        repostCount,
        quoteCount,
        bookmarkCount,
        score,
        raw: tweet,
      };
    })
    .filter((entry): entry is XTweetMetrics => entry !== null);
}

function firstFiniteNumber(...values: unknown[]): number | null {
  for (const value of values) {
    if (typeof value === "number" && Number.isFinite(value)) return value;
    if (typeof value === "string") {
      const parsed = Number(value);
      if (Number.isFinite(parsed)) return parsed;
    }
  }
  return null;
}

function buildXActionRequired(
  code: string,
  requiredEnrollment: string | null,
): string {
  if (code === "x_client_not_enrolled") {
    return [
      "Open the X Developer Portal, create or select a Project, attach the App",
      "that owns X_API_KEY/X_API_SECRET to that Project, confirm API access",
      requiredEnrollment ? `(${requiredEnrollment})` : "",
      "and regenerate the OAuth 1.0a access token/secret with Read and write permissions.",
    ].filter((part) => part !== "").join(" ");
  }
  if (code === "x_forbidden") {
    return "Check the X Developer App permissions, API access tier, and OAuth user-context access token.";
  }
  if (code === "x_billing_blocked") {
    return "X APIのクレジット不足/spend cap到達です。X Developer Portal (console.x.com) の該当プロジェクトでクレジット追加または上限引き上げをしてください。解除まで投稿・計測は失敗します。";
  }
  return "Check the X API response, credentials, and endpoint permissions.";
}

function buildXApiErrorMessage(payload: XApiErrorPayload): string {
  if (payload.code === "x_client_not_enrolled") {
    return [
      "X API app is not enrolled for v2 posting.",
      payload.detail ||
      "Use keys and tokens from an X Developer App attached to a Project.",
      payload.actionRequired,
    ].join(" ");
  }
  if (payload.code === "x_billing_blocked") {
    // 生 detail はデバッグ用に残しつつ、対処が一目で分かる日本語を先頭に。
    return [
      `X APIのクレジットが不足しています（${
        payload.detail ?? payload.status
      }）。`,
      payload.actionRequired,
    ].filter((part) => part).join(" ");
  }
  return `X API error ${payload.status}: ${
    payload.detail || payload.title || JSON.stringify(payload.raw)
  }`;
}

function safeJsonParse(value: string): Record<string, unknown> {
  if (value.trim() === "") {
    return {};
  }
  try {
    return asObject(JSON.parse(value));
  } catch {
    return { raw: value };
  }
}

function asObject(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return {};
  }
  return value as Record<string, unknown>;
}

function normalizeMediaType(value: string | undefined): string {
  const normalized = asString(value).toLowerCase();
  if (normalized === "image/gif" || normalized === "gif") {
    return "image/gif";
  }
  if (normalized.startsWith("image/")) {
    return normalized;
  }
  if (normalized.startsWith("video/")) {
    return normalized;
  }
  return "video/mp4";
}

function inferMediaCategory(mediaType: string): string {
  if (mediaType === "image/gif") {
    return "tweet_gif";
  }
  if (mediaType.startsWith("image/")) {
    return "tweet_image";
  }
  return "tweet_video";
}

function inferFileName(mediaUrl: string, mediaType: string): string {
  const normalizedUrl = asString(mediaUrl);
  if (normalizedUrl !== "") {
    try {
      const parsedUrl = new URL(normalizedUrl);
      const candidate = parsedUrl.pathname.split("/").pop() ?? "";
      if (candidate.includes(".")) {
        return candidate;
      }
    } catch {
      // Fall through.
    }
  }

  const extension = mediaType === "image/gif"
    ? "gif"
    : mediaType.startsWith("image/")
    ? "png"
    : "mp4";
  return `media.${extension}`;
}

function percentEncode(value: string): string {
  return encodeURIComponent(value).replace(
    /[!'()*]/g,
    (character) => `%${character.charCodeAt(0).toString(16).toUpperCase()}`,
  );
}
