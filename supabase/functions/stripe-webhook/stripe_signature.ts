export const DEFAULT_STRIPE_SIGNATURE_TOLERANCE_SECONDS = 300;

type StripeSignature = {
  timestamp: string;
  signatures: string[];
};

function parseStripeSignature(header: string): StripeSignature {
  let timestamp = "";
  const signatures: string[] = [];
  for (const part of header.split(",")) {
    const [rawKey, rawValue] = part.split("=", 2);
    const key = rawKey?.trim();
    const value = rawValue?.trim() ?? "";
    if (key === "t") timestamp = value;
    if (key === "v1" && value) signatures.push(value);
  }
  return { timestamp, signatures };
}

async function hmacSha256Hex(
  secret: string,
  payload: string,
): Promise<string> {
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "HMAC",
    key,
    encoder.encode(payload),
  );
  return Array.from(new Uint8Array(signature))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

function safeEqualHex(left: string, right: string): boolean {
  if (left.length !== right.length) return false;
  let diff = 0;
  for (let index = 0; index < left.length; index++) {
    diff |= left.charCodeAt(index) ^ right.charCodeAt(index);
  }
  return diff === 0;
}

export async function verifyStripeEvent(
  rawBody: string,
  signatureHeader: string,
  webhookSecret: string,
  options: {
    nowMs?: number;
    toleranceSeconds?: number;
  } = {},
): Promise<Record<string, unknown>> {
  if (!webhookSecret) {
    throw new Error("STRIPE_WEBHOOK_SECRET not configured");
  }
  const { timestamp, signatures } = parseStripeSignature(signatureHeader);
  if (!timestamp || signatures.length === 0) {
    throw new Error("invalid signature header");
  }

  const timestampSeconds = Number(timestamp);
  if (!Number.isSafeInteger(timestampSeconds) || timestampSeconds <= 0) {
    throw new Error("invalid signature timestamp");
  }
  const nowSeconds = Math.floor((options.nowMs ?? Date.now()) / 1000);
  const toleranceSeconds = options.toleranceSeconds ??
    DEFAULT_STRIPE_SIGNATURE_TOLERANCE_SECONDS;
  if (
    !Number.isSafeInteger(toleranceSeconds) || toleranceSeconds <= 0 ||
    Math.abs(nowSeconds - timestampSeconds) > toleranceSeconds
  ) {
    throw new Error("signature timestamp outside tolerance");
  }

  const expected = await hmacSha256Hex(
    webhookSecret,
    `${timestamp}.${rawBody}`,
  );
  if (!signatures.some((signature) => safeEqualHex(signature, expected))) {
    throw new Error("invalid signature");
  }
  return JSON.parse(rawBody) as Record<string, unknown>;
}
