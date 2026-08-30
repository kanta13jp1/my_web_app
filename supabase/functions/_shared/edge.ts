export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, traceparent, tracestate, baggage, sentry-trace",
  // Max-Age 無しだと preflight キャッシュは既定 5 秒しか効かず、hub への
  // 全 POST に OPTIONS 往復 (~200ms) が毎回付く。Chromium は 7200 秒に丸める。
  "Access-Control-Max-Age": "86400",
};

export function jsonResponse(payload: unknown, status = 200): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

export function asRecord(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return {};
  }
  return value as Record<string, unknown>;
}

export function asString(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

export function asNumber(value: unknown, fallback = 0): number {
  if (typeof value === "number" && Number.isFinite(value)) {
    return value;
  }
  if (typeof value === "string") {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : fallback;
  }
  return fallback;
}

export function asStringArray(value: unknown, limit = 20): string[] {
  if (!Array.isArray(value)) {
    return [];
  }
  return value
    .map((entry) => asString(entry))
    .filter((entry) => entry !== "")
    .slice(0, limit);
}

export function requireEnv(name: string): string {
  const value = Deno.env.get(name) ?? "";
  if (value === "") {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

export async function sleep(ms: number): Promise<void> {
  await new Promise((resolve) => setTimeout(resolve, ms));
}

export function buildUtmUrl(
  baseUrl: string,
  params: Record<string, string>,
): string {
  const normalizedUrl = asString(baseUrl);
  if (normalizedUrl === "") {
    return "";
  }

  const url = new URL(normalizedUrl);
  for (const [key, value] of Object.entries(params)) {
    const normalizedValue = asString(value);
    if (normalizedValue !== "") {
      url.searchParams.set(key, normalizedValue);
    }
  }
  return url.toString();
}
