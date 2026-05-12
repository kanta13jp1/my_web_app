const SIGNATURE_ALGORITHM = "hmac-sha256";
const DEFAULT_SKEW_MS = 5 * 60 * 1000;
const nonceCache = new Map<string, number>();

export type InternalHmacVerifyResult = {
  ok: boolean;
  reason?: string;
};

export type InternalHmacOptions = {
  secret?: string;
  now?: Date;
  skewMs?: number;
};

export type InternalHmacParts = {
  method: string;
  path: string;
  body: string;
  timestamp: string;
  nonce: string;
};

function encoder(): TextEncoder {
  return new TextEncoder();
}

function bytesToHex(bytes: Uint8Array): string {
  return [...bytes].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

async function hmacKey(secret: string): Promise<CryptoKey> {
  return await crypto.subtle.importKey(
    "raw",
    encoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
}

export async function sha256Hex(value: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", encoder().encode(value));
  return bytesToHex(new Uint8Array(digest));
}

export async function buildInternalHmacPayload(
  parts: InternalHmacParts,
): Promise<string> {
  const bodyHash = await sha256Hex(parts.body);
  return [
    parts.method.toUpperCase(),
    parts.path,
    parts.timestamp,
    parts.nonce,
    bodyHash,
  ].join(":");
}

export async function signInternalHmacParts(
  parts: InternalHmacParts,
  secret: string,
): Promise<string> {
  const key = await hmacKey(secret);
  const payload = await buildInternalHmacPayload(parts);
  const signature = await crypto.subtle.sign(
    "HMAC",
    key,
    encoder().encode(payload),
  );
  return `${SIGNATURE_ALGORITHM}:${bytesToHex(new Uint8Array(signature))}`;
}

export async function buildInternalHmacHeaders(
  method: string,
  path: string,
  body: string,
  secret: string,
  now = new Date(),
  nonce = crypto.randomUUID(),
): Promise<Headers> {
  const timestamp = Math.floor(now.getTime() / 1000).toString();
  const signature = await signInternalHmacParts(
    { method, path, body, timestamp, nonce },
    secret,
  );
  const headers = new Headers();
  headers.set("X-Internal-Signature", signature);
  headers.set("X-Internal-Timestamp", timestamp);
  headers.set("X-Internal-Nonce", nonce);
  return headers;
}

function pruneNonceCache(nowMs: number): void {
  for (const [nonce, expiresAt] of nonceCache) {
    if (expiresAt <= nowMs) nonceCache.delete(nonce);
  }
}

function validUuid(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
    .test(value);
}

function timingSafeEqual(left: string, right: string): boolean {
  if (left.length !== right.length) return false;
  let diff = 0;
  for (let index = 0; index < left.length; index++) {
    diff |= left.charCodeAt(index) ^ right.charCodeAt(index);
  }
  return diff === 0;
}

export async function verifyInternalHmacParts(
  parts: InternalHmacParts,
  signature: string,
  options: InternalHmacOptions = {},
): Promise<InternalHmacVerifyResult> {
  const secret = options.secret ?? Deno.env.get("INTERNAL_HMAC_SECRET") ?? "";
  if (!secret) return { ok: false, reason: "missing_secret" };

  const nowMs = (options.now ?? new Date()).getTime();
  const skewMs = options.skewMs ?? DEFAULT_SKEW_MS;
  const timestampSeconds = Number(parts.timestamp);
  if (!Number.isFinite(timestampSeconds)) {
    return { ok: false, reason: "invalid_timestamp" };
  }

  const timestampMs = timestampSeconds * 1000;
  if (Math.abs(nowMs - timestampMs) > skewMs) {
    return { ok: false, reason: "timestamp_skew" };
  }

  if (!validUuid(parts.nonce)) {
    return { ok: false, reason: "invalid_nonce" };
  }

  pruneNonceCache(nowMs);
  if (nonceCache.has(parts.nonce)) {
    return { ok: false, reason: "nonce_replay" };
  }

  const expected = await signInternalHmacParts(parts, secret);
  if (!timingSafeEqual(signature, expected)) {
    return { ok: false, reason: "signature_mismatch" };
  }

  nonceCache.set(parts.nonce, nowMs + skewMs);
  return { ok: true };
}

export async function verifyInternalHmacRequest(
  req: Request,
  options: InternalHmacOptions = {},
): Promise<InternalHmacVerifyResult> {
  const signature = req.headers.get("X-Internal-Signature") ?? "";
  const timestamp = req.headers.get("X-Internal-Timestamp") ?? "";
  const nonce = req.headers.get("X-Internal-Nonce") ?? "";
  if (!signature || !timestamp || !nonce) {
    return { ok: false, reason: "missing_headers" };
  }
  if (!signature.startsWith(`${SIGNATURE_ALGORITHM}:`)) {
    return { ok: false, reason: "invalid_signature_scheme" };
  }

  const url = new URL(req.url);
  const body = await req.clone().text();
  return await verifyInternalHmacParts(
    {
      method: req.method,
      path: url.pathname,
      body,
      timestamp,
      nonce,
    },
    signature,
    options,
  );
}

export function clearInternalHmacNonceCacheForTest(): void {
  nonceCache.clear();
}
