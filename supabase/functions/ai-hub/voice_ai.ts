type UnknownRecord = Record<string, unknown>;

type QueryResult = {
  data?: unknown | null;
  error?: { message?: string } | null;
};

export type VoiceAiDbQuery = {
  select(columns?: string): VoiceAiDbQuery;
  eq(column: string, value: string | boolean | number): VoiceAiDbQuery;
  gte(column: string, value: string): VoiceAiDbQuery;
  order(column: string, options?: { ascending?: boolean }): VoiceAiDbQuery;
  limit(count: number): Promise<QueryResult>;
  maybeSingle(): Promise<QueryResult>;
};

export type VoiceAiDb = {
  from(table: string): VoiceAiDbQuery;
  rpc(name: string, args?: UnknownRecord): Promise<QueryResult>;
};

export type VoiceAiPolicy = {
  trainingConsent: boolean;
  zeroDataRetentionRequested: boolean;
  consentUpdatedAt: string | null;
};

export type VoiceAiUsageResult = {
  eventId: string | null;
  blocked: boolean;
  dailyTotal: number;
  monthlyTotal: number;
  dailyLimit: number | null;
  monthlyLimit: number | null;
  estimatedCostUsd: number;
};

export class VoiceAiError extends Error {
  status: number;
  payload: UnknownRecord;

  constructor(message: string, status = 400, payload: UnknownRecord = {}) {
    super(message);
    this.name = "VoiceAiError";
    this.status = status;
    this.payload = payload;
  }
}

const DEFAULT_TTS_DAILY_CHAR_LIMIT = 20_000;
const DEFAULT_TTS_MONTHLY_CHAR_LIMIT = 300_000;
const DEFAULT_STT_DAILY_SECONDS_LIMIT = 900;
const DEFAULT_STT_MONTHLY_SECONDS_LIMIT = 7_200;
const CARTESIA_VERSION = Deno.env.get("CARTESIA_VERSION") ?? "2026-03-01";
const CARTESIA_WS_URL = Deno.env.get("CARTESIA_TTS_WEBSOCKET_URL") ??
  "wss://api.cartesia.ai/tts/websocket";
const CARTESIA_MODEL_ID = Deno.env.get("CARTESIA_MODEL_ID") ??
  "sonic-3-2026-01-12";
const CARTESIA_MAX_SESSION_SECONDS = 300;
const VOICE_PROXY_SCOPE = "voice.cartesia.websocket";

export function normalizeVoiceProvider(value: unknown): string {
  const raw = String(value ?? "").trim().toLowerCase();
  if (raw === "cartesia") return "cartesia";
  if (raw === "deepgram") return "deepgram";
  if (raw === "webspeech") return "webspeech";
  return "elevenlabs";
}

export function countVoiceTextChars(text: string): number {
  return Array.from(text).length;
}

export function estimateVoiceSttSeconds(
  audioByteLength: number,
  declaredSeconds: unknown,
): number {
  const parsedDeclared = Number(declaredSeconds);
  const safeDeclared = Number.isFinite(parsedDeclared) && parsedDeclared > 0
    ? Math.ceil(parsedDeclared)
    : 0;
  const byteEstimated = Math.ceil(Math.max(0, audioByteLength) / 16000);
  return Math.max(1, safeDeclared, byteEstimated);
}

export function estimateVoiceAiCostUsd(
  provider: string,
  metricType: string,
  quantity: number,
): number {
  if (!Number.isFinite(quantity) || quantity <= 0) return 0;
  if (metricType === "tts_chars") {
    const providerRate = readEnvNumber(
      `VOICE_AI_${provider.toUpperCase()}_TTS_USD_PER_1M_CHARS`,
    );
    const sharedRate = readEnvNumber("VOICE_AI_TTS_USD_PER_1M_CHARS");
    const rate = Math.max(0, providerRate ?? sharedRate ?? 0);
    return roundUsd((quantity / 1_000_000) * rate);
  }
  if (metricType === "stt_seconds") {
    const providerRate = readEnvNumber(
      `VOICE_AI_${provider.toUpperCase()}_STT_USD_PER_HOUR`,
    );
    const sharedRate = readEnvNumber("VOICE_AI_STT_USD_PER_HOUR");
    const rate = Math.max(0, providerRate ?? sharedRate ?? 0);
    return roundUsd((quantity / 3600) * rate);
  }
  return 0;
}

export async function loadVoiceAiPolicy(
  db: VoiceAiDb,
  userId: string,
): Promise<VoiceAiPolicy> {
  const { data, error } = await db
    .from("voice_ai_user_preferences")
    .select("training_consent, consent_updated_at")
    .eq("user_id", userId)
    .maybeSingle();

  if (error?.message) {
    throw new VoiceAiError(error.message, 500);
  }

  const row = asRecord(data);
  const trainingConsent = row?.training_consent === true;
  return {
    trainingConsent,
    zeroDataRetentionRequested: !trainingConsent,
    consentUpdatedAt: asString(row?.consent_updated_at),
  };
}

export async function recordVoiceAiUsage(
  db: VoiceAiDb,
  params: {
    userId: string;
    provider: string;
    feature: string;
    metricType: string;
    quantity: number;
    estimatedCostUsd?: number;
    policy: VoiceAiPolicy;
    metadata?: UnknownRecord;
    dailyLimit?: number | null;
    monthlyLimit?: number | null;
  },
): Promise<VoiceAiUsageResult> {
  const { data, error } = await db.rpc("record_voice_ai_usage", {
    p_user_id: params.userId,
    p_provider: params.provider,
    p_feature: params.feature,
    p_metric_type: params.metricType,
    p_quantity: params.quantity,
    p_estimated_cost_usd: params.estimatedCostUsd ?? 0,
    p_consent_to_training: params.policy.trainingConsent,
    p_zero_data_retention_requested: params.policy.zeroDataRetentionRequested,
    p_metadata: params.metadata ?? {},
    p_daily_limit: params.dailyLimit ?? null,
    p_monthly_limit: params.monthlyLimit ?? null,
  });

  if (error?.message) {
    throw new VoiceAiError(error.message, 500);
  }

  const row = asRecord(data) ?? {};
  return {
    eventId: asString(row.event_id),
    blocked: row.blocked === true,
    dailyTotal: asNumber(row.daily_total),
    monthlyTotal: asNumber(row.monthly_total),
    dailyLimit: nullableNumber(row.daily_limit),
    monthlyLimit: nullableNumber(row.monthly_limit),
    estimatedCostUsd: asNumber(row.estimated_cost_usd),
  };
}

export async function reserveVoiceTtsUsage(
  db: VoiceAiDb,
  params: {
    userId: string;
    body: UnknownRecord;
    provider: string;
    feature: string;
    text: string;
    metadata?: UnknownRecord;
  },
): Promise<{ policy: VoiceAiPolicy; usage: VoiceAiUsageResult }> {
  const policy = await loadVoiceAiPolicy(db, params.userId);
  assertVoiceProviderPrivacy(policy, params.provider);
  const chars = countVoiceTextChars(params.text);
  const usage = await recordVoiceAiUsage(db, {
    userId: params.userId,
    provider: params.provider,
    feature: params.feature,
    metricType: "tts_chars",
    quantity: chars,
    estimatedCostUsd: estimateVoiceAiCostUsd(
      params.provider,
      "tts_chars",
      chars,
    ),
    policy,
    metadata: {
      ...params.metadata,
      text_chars: chars,
    },
    dailyLimit: readLimit(
      params.body.daily_char_limit,
      "VOICE_AI_TTS_DAILY_CHAR_LIMIT",
      DEFAULT_TTS_DAILY_CHAR_LIMIT,
    ),
    monthlyLimit: readLimit(
      params.body.monthly_char_limit,
      "VOICE_AI_TTS_MONTHLY_CHAR_LIMIT",
      DEFAULT_TTS_MONTHLY_CHAR_LIMIT,
    ),
  });
  return { policy, usage };
}

export async function recordVoiceSttUsage(
  db: VoiceAiDb,
  params: {
    userId: string;
    body: UnknownRecord;
    provider: string;
    feature: string;
    seconds: number;
    metadata?: UnknownRecord;
  },
): Promise<{ policy: VoiceAiPolicy; usage: VoiceAiUsageResult }> {
  const policy = await loadVoiceAiPolicy(db, params.userId);
  assertVoiceProviderPrivacy(policy, params.provider);
  const usage = await recordVoiceAiUsage(db, {
    userId: params.userId,
    provider: params.provider,
    feature: params.feature,
    metricType: "stt_seconds",
    quantity: params.seconds,
    estimatedCostUsd: estimateVoiceAiCostUsd(
      params.provider,
      "stt_seconds",
      params.seconds,
    ),
    policy,
    metadata: params.metadata,
    dailyLimit: readLimit(
      params.body.daily_seconds_limit,
      "VOICE_AI_STT_DAILY_SECONDS_LIMIT",
      DEFAULT_STT_DAILY_SECONDS_LIMIT,
    ),
    monthlyLimit: readLimit(
      params.body.monthly_seconds_limit,
      "VOICE_AI_STT_MONTHLY_SECONDS_LIMIT",
      DEFAULT_STT_MONTHLY_SECONDS_LIMIT,
    ),
  });
  return { policy, usage };
}

export async function handleVoiceCartesiaSessionAction(
  req: Request,
  db: VoiceAiDb,
  userId: string,
): Promise<UnknownRecord> {
  const policy = await loadVoiceAiPolicy(db, userId);
  const apiKey = Deno.env.get("CARTESIA_API_KEY") ?? "";
  const voiceId = Deno.env.get("CARTESIA_VOICE_ID") ?? "";
  const proxySecret = voiceProxyTokenSecret();
  if (!apiKey || !voiceId || !proxySecret) {
    return {
      success: false,
      available: false,
      reason: !apiKey
        ? "CARTESIA_API_KEY not configured"
        : !voiceId
        ? "CARTESIA_VOICE_ID not configured"
        : "VOICE_PROXY_TOKEN_SECRET not configured",
      policy: policyPayload(policy),
    };
  }
  if (!policy.trainingConsent && !isCartesiaZdrEnabled()) {
    return {
      success: false,
      available: false,
      reason: "voice_training_consent_or_cartesia_zdr_required",
      policy: policyPayload(policy),
    };
  }

  const url = new URL(req.url);
  url.protocol = url.protocol === "https:" ? "wss:" : "ws:";
  url.search = "";
  url.searchParams.set("action", "voice.cartesia.websocket");
  const accessToken = await createVoiceProxyToken(
    userId,
    proxySecret,
    CARTESIA_MAX_SESSION_SECONDS + 30,
  );

  return {
    success: true,
    available: true,
    provider: "cartesia",
    transport: "backend_proxy",
    websocket_access_token: accessToken,
    websocket_url: url.toString(),
    api_version: CARTESIA_VERSION,
    cartesia_version: CARTESIA_VERSION,
    model_id: CARTESIA_MODEL_ID,
    voice_id: voiceId,
    max_session_seconds: CARTESIA_MAX_SESSION_SECONDS,
    policy: policyPayload(policy),
  };
}

export function isCartesiaZdrEnabled(): boolean {
  return isVoiceProviderZdrEnabled("cartesia");
}

export function isVoiceProviderZdrEnabled(provider: string): boolean {
  const key = provider === "cartesia"
    ? "CARTESIA_ZDR_ENABLED"
    : provider === "elevenlabs"
    ? "ELEVENLABS_ZDR_ENABLED"
    : provider === "deepgram"
    ? "DEEPGRAM_ZDR_ENABLED"
    : "";
  if (!key) return false;
  return (Deno.env.get(key) ?? "").trim().toLowerCase() === "true";
}

export async function createVoiceProxyToken(
  userId: string,
  secret: string,
  ttlSeconds = CARTESIA_MAX_SESSION_SECONDS + 30,
): Promise<string> {
  if (!userId || !secret) throw new VoiceAiError("voice proxy unavailable", 503);
  const payload = base64UrlEncode(
    new TextEncoder().encode(JSON.stringify({
      sub: userId,
      scope: VOICE_PROXY_SCOPE,
      exp: Math.floor(Date.now() / 1000) + ttlSeconds,
      nonce: crypto.randomUUID(),
    })),
  );
  const signature = await signVoiceProxyPayload(payload, secret);
  return `${payload}.${base64UrlEncode(signature)}`;
}

export async function verifyVoiceProxyToken(
  token: string,
  secret: string,
): Promise<string | null> {
  if (!token || !secret) return null;
  const parts = token.split(".");
  if (parts.length !== 2 || !parts[0] || !parts[1]) return null;
  try {
    const key = await voiceProxySigningKey(secret, ["verify"]);
    const valid = await crypto.subtle.verify(
      "HMAC",
      key,
      base64UrlDecode(parts[1]),
      new TextEncoder().encode(parts[0]),
    );
    if (!valid) return null;
    const payload = JSON.parse(
      new TextDecoder().decode(base64UrlDecode(parts[0])),
    ) as UnknownRecord;
    const userId = asString(payload.sub);
    const expiresAt = asNumber(payload.exp);
    if (
      !userId || payload.scope !== VOICE_PROXY_SCOPE ||
      expiresAt <= Math.floor(Date.now() / 1000)
    ) {
      return null;
    }
    return userId;
  } catch {
    return null;
  }
}

export async function authenticateVoiceProxyRequest(
  req: Request,
): Promise<string | null> {
  const token = new URL(req.url).searchParams.get("voice_token") ?? "";
  return await verifyVoiceProxyToken(token, voiceProxyTokenSecret());
}

export function handleCartesiaRealtimeWebSocket(
  req: Request,
  db: VoiceAiDb,
  userId: string,
): Response {
  const apiKey = Deno.env.get("CARTESIA_API_KEY") ?? "";
  if (!apiKey) {
    return new Response("CARTESIA_API_KEY not configured", { status: 503 });
  }

  const { socket, response } = Deno.upgradeWebSocket(req);
  let upstream: WebSocket | null = null;
  let policy: VoiceAiPolicy | null = null;
  let generationStartedAt = 0;
  let lastChunkAt = 0;
  let firstChunkSeen = false;
  let contextId: string = crypto.randomUUID();
  let downstreamClosed = false;
  let generationInFlight = false;
  let sessionTimer: ReturnType<typeof setTimeout> | null = null;

  socket.onopen = async () => {
    sessionTimer = setTimeout(() => {
      upstream?.close(1000, "Voice session expired");
      if (socket.readyState === WebSocket.OPEN) {
        socket.close(1000, "Voice session expired");
      }
    }, CARTESIA_MAX_SESSION_SECONDS * 1000);
    try {
      policy = await loadVoiceAiPolicy(db, userId);
      if (!policy.trainingConsent && !isCartesiaZdrEnabled()) {
        sendClient(socket, {
          type: "error",
          message: "voice_training_consent_or_cartesia_zdr_required",
        });
        socket.close(1008, "Voice privacy policy blocked provider access");
        return;
      }
      const token = await createCartesiaAccessToken(apiKey);
      const upstreamUrl = new URL(CARTESIA_WS_URL);
      upstreamUrl.searchParams.set("cartesia_version", CARTESIA_VERSION);
      upstreamUrl.searchParams.set("access_token", token);
      upstream = new WebSocket(upstreamUrl.toString());

      upstream.onopen = () => {
        if (downstreamClosed || socket.readyState !== WebSocket.OPEN) {
          upstream?.close(1000, "Downstream closed");
          return;
        }
        sendClient(socket, {
          type: "ready",
          provider: "cartesia",
          cartesia_version: CARTESIA_VERSION,
          policy: policyPayload(policy),
        });
      };
      upstream.onerror = () => {
        sendClient(socket, {
          type: "error",
          message: "Cartesia upstream websocket error",
        });
        socket.close(1011, "Cartesia upstream websocket error");
      };
      upstream.onclose = () => {
        sendClient(socket, { type: "upstream_closed" });
        if (!downstreamClosed && socket.readyState === WebSocket.OPEN) {
          socket.close(1011, "Cartesia upstream websocket closed");
        }
      };
      upstream.onmessage = (event: MessageEvent) => {
        const parsed = parseMessageEvent(event);
        if (parsed) {
          if (parsed.type === "chunk") {
            const timing = observeCartesiaChunkTiming({
              generationStartedAt,
              lastChunkAt,
              firstChunkSeen,
              observedAt: Date.now(),
            });
            firstChunkSeen = timing.firstChunkSeen;
            lastChunkAt = timing.lastChunkAt;
            recordCartesiaRealtimeMetrics({
              db,
              userId,
              provider: "cartesia",
              policy,
              message: parsed,
              ttfaMs: timing.ttfaMs,
              chunkLatencyMs: timing.chunkLatencyMs,
              contextId: asString(parsed.context_id) ?? contextId,
            }).catch((error) => {
              console.warn("voice cartesia metric write failed", error);
            });
          } else if (parsed.type === "done" || parsed.type === "error") {
            generationInFlight = false;
          }
          sendClient(socket, parsed);
        }
      };
    } catch (error) {
      console.error("voice cartesia websocket setup failed", {
        detail: String(error).slice(0, 500),
      });
      sendClient(socket, {
        type: "error",
        message: "Cartesia upstream setup failed",
      });
      socket.close(1011, "Cartesia setup failed");
    }
  };

  socket.onmessage = (event: MessageEvent) => {
    (async () => {
      const message = parseMessageEvent(event);
      if (!message) return;
      if (message.type === "generate") {
        const transcript = String(message.transcript ?? "").slice(0, 5000);
        if (transcript.trim().length === 0) {
          sendClient(socket, {
            type: "error",
            message: "transcript required",
          });
          return;
        }
        if (upstream?.readyState !== WebSocket.OPEN) {
          sendClient(socket, {
            type: "error",
            message: "Cartesia upstream websocket is not ready",
          });
          return;
        }
        if (generationInFlight) {
          sendClient(socket, {
            type: "error",
            message: "voice_generation_already_in_progress",
          });
          return;
        }
        generationInFlight = true;

        const activePolicy = await loadVoiceAiPolicy(db, userId);
        policy = activePolicy;
        if (!activePolicy.trainingConsent && !isCartesiaZdrEnabled()) {
          sendClient(socket, {
            type: "error",
            message: "voice_training_consent_or_cartesia_zdr_required",
          });
          generationInFlight = false;
          return;
        }
        const usage = await recordVoiceAiUsage(db, {
          userId,
          provider: "cartesia",
          feature: String(message.feature ?? "cartesia_realtime_tts").slice(
            0,
            80,
          ),
          metricType: "tts_chars",
          quantity: countVoiceTextChars(transcript),
          estimatedCostUsd: estimateVoiceAiCostUsd(
            "cartesia",
            "tts_chars",
            countVoiceTextChars(transcript),
          ),
          policy: activePolicy,
          metadata: {
            realtime: true,
            cartesia_version: CARTESIA_VERSION,
            cartesia_zdr_enforced: isCartesiaZdrEnabled(),
          },
          dailyLimit: DEFAULT_TTS_DAILY_CHAR_LIMIT,
          monthlyLimit: DEFAULT_TTS_MONTHLY_CHAR_LIMIT,
        });

        if (usage.blocked) {
          sendClient(socket, {
            type: "blocked",
            reason: "voice_usage_limit_exceeded",
            usage: usagePayload(usage),
          });
          generationInFlight = false;
          return;
        }

        contextId = boundedContextId(message.context_id);
        generationStartedAt = Date.now();
        firstChunkSeen = false;
        lastChunkAt = 0;
        sendUpstream(
          upstream,
          buildCartesiaGenerationRequest({
            ...message,
            transcript,
            context_id: contextId,
          }),
        );
        return;
      }

      if (message.type === "cancel") {
        sendUpstream(upstream, {
          context_id: boundedContextId(message.context_id ?? contextId),
          cancel: true,
        });
        generationInFlight = false;
        return;
      }

      sendClient(socket, {
        type: "error",
        message: "unsupported message type",
      });
    })().catch((error) => {
      generationInFlight = false;
      console.error("voice cartesia client message failed", {
        detail: String(error).slice(0, 500),
      });
      sendClient(socket, {
        type: "error",
        message: "Voice usage validation failed",
      });
    });
  };

  socket.onclose = () => {
    downstreamClosed = true;
    if (sessionTimer !== null) clearTimeout(sessionTimer);
    sessionTimer = null;
    if (upstream?.readyState === 1) upstream.close();
  };

  return response;
}

export function observeCartesiaChunkTiming(params: {
  generationStartedAt: number;
  lastChunkAt: number;
  firstChunkSeen: boolean;
  observedAt: number;
}): {
  firstChunkSeen: true;
  lastChunkAt: number;
  ttfaMs: number | null;
  chunkLatencyMs: number | null;
} {
  return {
    firstChunkSeen: true,
    lastChunkAt: params.observedAt,
    ttfaMs: !params.firstChunkSeen && params.generationStartedAt > 0
      ? Math.max(0, params.observedAt - params.generationStartedAt)
      : null,
    chunkLatencyMs: params.firstChunkSeen && params.lastChunkAt > 0
      ? Math.max(0, params.observedAt - params.lastChunkAt)
      : null,
  };
}

export function policyPayload(
  policy: VoiceAiPolicy | null,
  provider = "cartesia",
): UnknownRecord {
  return {
    training_consent: policy?.trainingConsent ?? false,
    zero_data_retention_requested: policy?.zeroDataRetentionRequested ?? true,
    provider,
    provider_zdr_enforced: isVoiceProviderZdrEnabled(provider),
    cartesia_zdr_enforced: isCartesiaZdrEnabled(),
    consent_updated_at: policy?.consentUpdatedAt ?? null,
  };
}

export function assertVoiceProviderPrivacy(
  policy: VoiceAiPolicy,
  provider: string,
): void {
  if (policy.trainingConsent || isVoiceProviderZdrEnabled(provider)) return;
  throw new VoiceAiError(
    "voice_training_consent_or_provider_zdr_required",
    403,
    { provider, policy: policyPayload(policy, provider) },
  );
}

export function usagePayload(usage: VoiceAiUsageResult): UnknownRecord {
  return {
    event_id: usage.eventId,
    blocked: usage.blocked,
    daily_total: usage.dailyTotal,
    monthly_total: usage.monthlyTotal,
    daily_limit: usage.dailyLimit,
    monthly_limit: usage.monthlyLimit,
    estimated_cost_usd: usage.estimatedCostUsd,
  };
}

function buildCartesiaGenerationRequest(message: UnknownRecord): UnknownRecord {
  const generationConfig = asRecord(message.generation_config) ?? {};
  const request: UnknownRecord = {
    model_id: CARTESIA_MODEL_ID,
    transcript: String(message.transcript ?? ""),
    voice: {
      mode: "id",
      id: Deno.env.get("CARTESIA_VOICE_ID") ?? "",
    },
    language: "ja",
    context_id: boundedContextId(message.context_id),
    output_format: {
      container: "raw",
      encoding: "pcm_f32le",
      sample_rate: 44100,
    },
    generation_config: {
      speed: clampNumber(generationConfig.speed, 0.6, 1.5, 1),
      volume: clampNumber(generationConfig.volume, 0.5, 2, 1),
      emotion: String(generationConfig.emotion ?? "calm").slice(0, 32),
    },
    continue: false,
  };
  return request;
}

async function createCartesiaAccessToken(apiKey: string): Promise<string> {
  const resp = await fetch("https://api.cartesia.ai/access-token", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${apiKey}`,
      "Cartesia-Version": CARTESIA_VERSION,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      grants: { tts: true },
      expires_in: 300,
    }),
    signal: AbortSignal.timeout(8_000),
  });
  if (!resp.ok) {
    throw new VoiceAiError(
      `Cartesia access token error: ${await resp.text()}`,
      502,
    );
  }
  const data = await resp.json() as UnknownRecord;
  const token = asString(data.token);
  if (!token) throw new VoiceAiError("Cartesia access token missing", 502);
  return token;
}

async function recordCartesiaRealtimeMetrics(params: {
  db: VoiceAiDb;
  userId: string;
  provider: string;
  policy: VoiceAiPolicy | null;
  message: UnknownRecord;
  ttfaMs: number | null;
  chunkLatencyMs: number | null;
  contextId: string;
}): Promise<void> {
  const policy = params.policy ??
    await loadVoiceAiPolicy(params.db, params.userId);
  const audioBytes = estimateBase64Bytes(asString(params.message.data));
  await recordVoiceAiUsage(params.db, {
    userId: params.userId,
    provider: params.provider,
    feature: "cartesia_realtime_tts",
    metricType: "audio_bytes",
    quantity: audioBytes,
    policy,
    metadata: { context_id: params.contextId },
  });

  if (params.ttfaMs !== null) {
    await recordVoiceAiUsage(params.db, {
      userId: params.userId,
      provider: params.provider,
      feature: "cartesia_realtime_tts",
      metricType: "ttfa_ms",
      quantity: params.ttfaMs,
      policy,
      metadata: { context_id: params.contextId },
    });
  } else if (params.chunkLatencyMs !== null) {
    await recordVoiceAiUsage(params.db, {
      userId: params.userId,
      provider: params.provider,
      feature: "cartesia_realtime_tts",
      metricType: "chunk_latency_ms",
      quantity: params.chunkLatencyMs,
      policy,
      metadata: { context_id: params.contextId },
    });
  }
}

function voiceProxyTokenSecret(): string {
  return Deno.env.get("VOICE_PROXY_TOKEN_SECRET") ??
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
    Deno.env.get("SERVICE_ROLE_KEY") ?? "";
}

async function signVoiceProxyPayload(
  payload: string,
  secret: string,
): Promise<Uint8Array> {
  const key = await voiceProxySigningKey(secret, ["sign"]);
  return new Uint8Array(
    await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(payload)),
  );
}

function voiceProxySigningKey(
  secret: string,
  usages: KeyUsage[],
): Promise<CryptoKey> {
  return crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    usages,
  );
}

function base64UrlEncode(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replace(/=+$/, "");
}

function base64UrlDecode(value: string): Uint8Array {
  const normalized = value.replaceAll("-", "+").replaceAll("_", "/");
  const padded = normalized + "=".repeat((4 - normalized.length % 4) % 4);
  const binary = atob(padded);
  return Uint8Array.from(binary, (char) => char.charCodeAt(0));
}

function sendClient(socket: WebSocket, value: UnknownRecord): void {
  if (socket.readyState !== 1) return;
  socket.send(JSON.stringify(value));
}

function sendUpstream(socket: WebSocket | null, value: UnknownRecord): void {
  if (socket?.readyState !== 1) return;
  socket.send(JSON.stringify(value));
}

function parseMessageEvent(event: MessageEvent): UnknownRecord | null {
  if (typeof event.data !== "string") return null;
  try {
    return asRecord(JSON.parse(event.data)) ?? null;
  } catch {
    return null;
  }
}

function estimateBase64Bytes(value: string | null): number {
  if (!value) return 0;
  const padding = value.endsWith("==") ? 2 : value.endsWith("=") ? 1 : 0;
  return Math.max(0, Math.floor((value.length * 3) / 4) - padding);
}

function readLimit(
  raw: unknown,
  envKey: string,
  fallback: number,
): number {
  const configuredLimit = Math.max(0, readEnvNumber(envKey) ?? fallback);
  if (typeof raw !== "number" && typeof raw !== "string") {
    return configuredLimit;
  }
  const bodyValue = nullableNumber(raw);
  if (bodyValue === null || bodyValue <= 0) return configuredLimit;
  return Math.min(bodyValue, configuredLimit);
}

function boundedContextId(value: unknown): string {
  const requested = String(value ?? "").trim();
  if (/^[A-Za-z0-9_-]{1,80}$/.test(requested)) return requested;
  return crypto.randomUUID();
}

function clampNumber(
  value: unknown,
  minimum: number,
  maximum: number,
  fallback: number,
): number {
  const parsed = asNumber(value);
  if (!Number.isFinite(parsed) || parsed <= 0) return fallback;
  return Math.min(maximum, Math.max(minimum, parsed));
}

function readEnvNumber(key: string): number | null {
  const raw = Deno.env.get(key);
  if (!raw) return null;
  const parsed = Number(raw);
  return Number.isFinite(parsed) ? parsed : null;
}

function roundUsd(value: number): number {
  return Math.round(value * 1_000_000) / 1_000_000;
}

function asRecord(value: unknown): UnknownRecord | null {
  if (!value || typeof value !== "object" || Array.isArray(value)) return null;
  return value as UnknownRecord;
}

function asString(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  return trimmed.length === 0 ? null : trimmed;
}

function asNumber(value: unknown): number {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string") {
    const parsed = Number(value);
    if (Number.isFinite(parsed)) return parsed;
  }
  return 0;
}

function nullableNumber(value: unknown): number | null {
  if (value === null || value === undefined || value === "") return null;
  const parsed = asNumber(value);
  return Number.isFinite(parsed) ? parsed : null;
}
