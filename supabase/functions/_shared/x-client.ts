import { asString, requireEnv, sleep } from "./edge.ts";

const X_API_KEY = Deno.env.get("X_API_KEY") ?? "";
const X_API_SECRET = Deno.env.get("X_API_SECRET") ?? "";
const X_ACCESS_TOKEN = Deno.env.get("X_ACCESS_TOKEN") ?? "";
const X_ACCESS_TOKEN_SECRET = Deno.env.get("X_ACCESS_TOKEN_SECRET") ?? "";
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

export function isXApiError(error: unknown): error is XApiError {
  return error instanceof XApiError;
}

export async function uploadMediaFromUrl(
  mediaUrl: string,
  options: {
    fileName?: string;
    mediaType?: string;
    mediaCategory?: string;
  } = {},
): Promise<UploadedXMedia> {
  assertXConfigured();
  const binary = await fetchRemoteBinary(mediaUrl, options.mediaType);
  return await uploadMediaBytes(binary.bytes, {
    fileName: options.fileName || inferFileName(mediaUrl, binary.mediaType),
    mediaType: options.mediaType || binary.mediaType,
    mediaCategory: options.mediaCategory,
  });
}

export async function uploadMediaBytes(
  bytes: Uint8Array,
  options: {
    fileName?: string;
    mediaType?: string;
    mediaCategory?: string;
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
  return {
    mediaId,
    mediaKey: asString(finalizeResponse.media_key) || null,
    mediaType,
    sizeBytes: bytes.byteLength,
    processingState,
  };
}

export async function postTweet(input: {
  text: string;
  mediaIds?: string[];
  replyToTweetId?: string;
}): Promise<XTweetResult> {
  assertXConfigured();
  const text = asString(input.text);
  if (text === "") {
    throw new Error("text is required.");
  }
  if (text.length > 280) {
    throw new Error("text exceeds 280 characters.");
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
  const code = reason === "client-not-enrolled"
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
