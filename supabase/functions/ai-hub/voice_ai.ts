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
    return roundUsd((quantity / 1_000_000) * (providerRate ?? sharedRate ?? 0));
  }
  if (metricType === "stt_seconds") {
    const providerRate = readEnvNumber(
      `VOICE_AI_${provider.toUpperCase()}_STT_USD_PER_HOUR`,
    );
    const sharedRate = readEnvNumber("VOICE_AI_STT_USD_PER_HOUR");
    return roundUsd((quantity / 3600) * (providerRate ?? sharedRate ?? 0));
  }
  return 0;
}

export async function loadVoiceAiPolicy(
  db: VoiceAiDb,
  userId: string,
): Promise<VoiceAiPolicy> {
  const { data, error } = await db
    .from("user_profiles")
    .select("voice_ai_training_consent, voice_ai_consent_updated_at")
    .eq("user_id", userId)
    .maybeSingle();

  if (error?.message) {
    throw new VoiceAiError(error.message, 500);
  }

  const row = asRecord(data);
  const trainingConsent = row?.voice_ai_training_consent === true;
  return {
    trainingConsent,
    zeroDataRetentionRequested: !trainingConsent,
    consentUpdatedAt: asString(row?.voice_ai_consent_updated_at),
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

export async function handleVoiceMetricAction(
  db: VoiceAiDb,
  userId: string,
  body: UnknownRecord,
): Promise<UnknownRecord> {
  const provider = normalizeVoiceProvider(body.provider);
  const metricType = String(body.metric_type ?? body.metricType ?? "").trim();
  const quantity = asNumber(body.quantity);
  const policy = await loadVoiceAiPolicy(db, userId);
  const usage = await recordVoiceAiUsage(db, {
    userId,
    provider,
    feature: String(body.feature ?? "voice_metric"),
    metricType,
    quantity,
    estimatedCostUsd: estimateVoiceAiCostUsd(provider, metricType, quantity),
    policy,
    metadata: asRecord(body.metadata) ?? {},
  });
  return {
    success: true,
    policy: policyPayload(policy),
    usage: usagePayload(usage),
  };
}

export async function handleVoiceUsageSummaryAction(
  db: VoiceAiDb,
  userId: string,
): Promise<UnknownRecord> {
  const { data, error } = await db
    .from("voice_ai_usage_daily_summary")
    .select(
      "user_id, provider, usage_date, tts_chars, stt_seconds, audio_bytes, avg_ttfa_ms, avg_chunk_latency_ms, estimated_cost_usd, event_count, blocked_event_count, last_event_at",
    )
    .eq("user_id", userId)
    .order("usage_date", { ascending: false })
    .limit(60);

  if (error?.message) {
    throw new VoiceAiError(error.message, 500);
  }

  return {
    success: true,
    rows: Array.isArray(data) ? data : [],
  };
}

export async function handleVoiceCartesiaSessionAction(
  req: Request,
  db: VoiceAiDb,
  userId: string,
): Promise<UnknownRecord> {
  const policy = await loadVoiceAiPolicy(db, userId);
  const url = new URL(req.url);
  url.protocol = url.protocol === "https:" ? "wss:" : "ws:";
  url.search = "";
  url.searchParams.set("action", "voice.cartesia.websocket");

  return {
    success: true,
    provider: "cartesia",
    websocket_url: url.toString(),
    cartesia_version: CARTESIA_VERSION,
    policy: policyPayload(policy),
    client_message: {
      type: "generate",
      transcript: "Text to speak",
      voice_id: "a0e99841-438c-4a64-b679-ae501e7d6091",
      language: "ja",
    },
  };
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

  socket.onopen = async () => {
    try {
      policy = await loadVoiceAiPolicy(db, userId);
      const token = await createCartesiaAccessToken(apiKey);
      const upstreamUrl = new URL(CARTESIA_WS_URL);
      upstreamUrl.searchParams.set("cartesia_version", CARTESIA_VERSION);
      upstreamUrl.searchParams.set("access_token", token);
      upstream = new WebSocket(upstreamUrl.toString());

      upstream.onopen = () => {
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
      };
      upstream.onclose = () => {
        sendClient(socket, { type: "upstream_closed" });
      };
      upstream.onmessage = (event: MessageEvent) => {
        const parsed = parseMessageEvent(event);
        if (parsed) {
          recordCartesiaRealtimeMetrics({
            db,
            userId,
            provider: "cartesia",
            policy,
            message: parsed,
            generationStartedAt,
            lastChunkAt,
            firstChunkSeen,
            contextId,
          }).then((state) => {
            firstChunkSeen = state.firstChunkSeen;
            lastChunkAt = state.lastChunkAt;
          }).catch((error) => {
            console.warn("voice cartesia metric write failed", error);
          });
          sendClient(socket, parsed);
        }
      };
    } catch (error) {
      sendClient(socket, {
        type: "error",
        message: error instanceof Error ? error.message : String(error),
      });
      socket.close(1011, "Cartesia setup failed");
    }
  };

  socket.onmessage = async (event: MessageEvent) => {
    const message = parseMessageEvent(event);
    if (!message) return;
    if (message.type === "generate") {
      const transcript = String(message.transcript ?? "").slice(0, 5000);
      if (transcript.trim().length === 0) {
        sendClient(socket, { type: "error", message: "transcript required" });
        return;
      }

      const activePolicy = policy ?? await loadVoiceAiPolicy(db, userId);
      const usage = await recordVoiceAiUsage(db, {
        userId,
        provider: "cartesia",
        feature: String(message.feature ?? "cartesia_realtime_tts"),
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
        return;
      }

      contextId = String(message.context_id ?? crypto.randomUUID());
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
        context_id: String(message.context_id ?? contextId),
        cancel: true,
      });
      return;
    }

    sendUpstream(upstream, message);
  };

  socket.onclose = () => {
    if (upstream?.readyState === 1) upstream.close();
  };

  return response;
}

export function policyPayload(policy: VoiceAiPolicy | null): UnknownRecord {
  return {
    training_consent: policy?.trainingConsent ?? false,
    zero_data_retention_requested: policy?.zeroDataRetentionRequested ?? true,
    consent_updated_at: policy?.consentUpdatedAt ?? null,
  };
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
  return {
    model_id: String(message.model_id ?? "sonic-latest"),
    transcript: String(message.transcript ?? ""),
    voice: {
      mode: "id",
      id: String(
        message.voice_id ?? "a0e99841-438c-4a64-b679-ae501e7d6091",
      ),
    },
    language: String(message.language ?? "ja"),
    context_id: String(message.context_id ?? crypto.randomUUID()),
    output_format: asRecord(message.output_format) ?? {
      container: "raw",
      encoding: "pcm_s16le",
      sample_rate: 16000,
    },
    continue: message.continue === true,
  };
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
  generationStartedAt: number;
  lastChunkAt: number;
  firstChunkSeen: boolean;
  contextId: string;
}): Promise<{ firstChunkSeen: boolean; lastChunkAt: number }> {
  if (params.message.type !== "chunk") {
    return {
      firstChunkSeen: params.firstChunkSeen,
      lastChunkAt: params.lastChunkAt,
    };
  }

  const policy = params.policy ??
    await loadVoiceAiPolicy(params.db, params.userId);
  const now = Date.now();
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

  if (!params.firstChunkSeen && params.generationStartedAt > 0) {
    await recordVoiceAiUsage(params.db, {
      userId: params.userId,
      provider: params.provider,
      feature: "cartesia_realtime_tts",
      metricType: "ttfa_ms",
      quantity: now - params.generationStartedAt,
      policy,
      metadata: { context_id: params.contextId },
    });
  } else if (params.lastChunkAt > 0) {
    await recordVoiceAiUsage(params.db, {
      userId: params.userId,
      provider: params.provider,
      feature: "cartesia_realtime_tts",
      metricType: "chunk_latency_ms",
      quantity: now - params.lastChunkAt,
      policy,
      metadata: { context_id: params.contextId },
    });
  }

  return { firstChunkSeen: true, lastChunkAt: now };
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
): number | null {
  if (raw === null || raw === false) return null;
  const bodyValue = nullableNumber(raw);
  if (bodyValue !== null) return bodyValue;
  return readEnvNumber(envKey) ?? fallback;
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
