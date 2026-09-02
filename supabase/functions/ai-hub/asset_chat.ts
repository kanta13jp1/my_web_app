export type AssetChatMessage = {
  role: "system" | "user" | "assistant";
  content: string;
};

export type AssetChatProviderRequest = {
  provider: string;
  model?: string;
  messages: AssetChatMessage[];
};

export type AssetChatProviderResult = {
  ok: boolean;
  text?: string;
  modelUsed?: string;
  estimatedCostUsd?: number;
  error?: string;
  httpStatus?: number;
  isRetriable?: boolean;
};

export type AssetChatProviderInvoker = (
  request: AssetChatProviderRequest,
) => Promise<AssetChatProviderResult>;

type UnknownRecord = Record<string, unknown>;

export type AssetChatThread = {
  id: string;
  title: string;
  created_at: string;
  last_message_at: string;
};

export type AssetChatSnapshotRow = {
  month_key: string;
  payload: UnknownRecord;
  updated_at?: string | null;
};

export type AssetChatHistoryRow = {
  id?: string;
  role: "user" | "assistant";
  content: string;
  created_at: string;
};

export type AssetChatExchange = {
  user: {
    role: "user";
    content: string;
    tokens_in: number;
    tokens_out: number;
    model: null;
    created_at: string;
  };
  assistant: {
    role: "assistant";
    content: string;
    tokens_in: number;
    tokens_out: number;
    model: string;
    created_at: string;
  };
};

export type AssetChatStore = {
  getOwnedThread(
    userId: string,
    threadId: string,
  ): Promise<AssetChatThread | null>;
  createThread(
    userId: string,
    title: string,
    createdAt: string,
  ): Promise<AssetChatThread>;
  loadSnapshots(
    userId: string,
    limit: number,
  ): Promise<AssetChatSnapshotRow[]>;
  loadRecentMessages(
    threadId: string,
    limit: number,
  ): Promise<AssetChatHistoryRow[]>;
  appendExchange(threadId: string, exchange: AssetChatExchange): Promise<void>;
  touchThread(
    userId: string,
    threadId: string,
    lastMessageAt: string,
  ): Promise<void>;
};

export type AssetChatPiiMode = "off" | "mask";

type AssetChatSnapshotContext = {
  month_key: string;
  positive_asset_total: number | null;
  liability_total: number | null;
  net_worth: number | null;
  cash_like_total: number | null;
  monthly_received_income_total: number | null;
  monthly_scheduled_payment_total: number | null;
  monthly_paid_payment_total: number | null;
  monthly_unpaid_payment_total: number | null;
  monthly_actual_payment_total: number | null;
  monthly_payment_difference_total: number | null;
  overdue_payment_count: number | null;
  securities_total: number | null;
};

type CachedSnapshots = {
  expiresAt: number;
  rows: AssetChatSnapshotRow[];
};

export class AssetChatContextCache {
  readonly ttlMs: number;
  private readonly snapshots = new Map<string, CachedSnapshots>();

  constructor(ttlMs = 60 * 60 * 1000) {
    this.ttlMs = ttlMs;
  }

  get(
    userId: string,
    limit: number,
    nowMs: number,
  ): AssetChatSnapshotRow[] | null {
    const key = `${userId}:${limit}`;
    const cached = this.snapshots.get(key);
    if (!cached) return null;
    if (cached.expiresAt <= nowMs) {
      this.snapshots.delete(key);
      return null;
    }
    return cached.rows.map(cloneSnapshotRow);
  }

  set(
    userId: string,
    limit: number,
    rows: AssetChatSnapshotRow[],
    nowMs: number,
  ): void {
    const key = `${userId}:${limit}`;
    this.snapshots.set(key, {
      expiresAt: nowMs + this.ttlMs,
      rows: rows.map(cloneSnapshotRow),
    });
  }

  clear(): void {
    this.snapshots.clear();
  }
}

const DEFAULT_CONTEXT_CACHE = new AssetChatContextCache();

export type AssetChatResult = {
  status: "completed";
  thread_id: string;
  thread_title: string;
  thread_created: boolean;
  reply: string;
  provider: string;
  model: string;
  tokens_in: number;
  tokens_out: number;
  estimated_cost_usd: number;
  pii_mode: AssetChatPiiMode;
  context: {
    snapshot_months_requested: number;
    snapshot_rows: number;
    history_messages_requested: number;
    history_rows: number;
    snapshot_cache: "hit" | "miss";
    snapshot_cache_ttl_seconds: number;
    selected_snapshot_columns: string;
    selected_message_columns: string;
  };
};

export class AssetChatActionError extends Error {
  status: number;
  code: string;

  constructor(message: string, status = 400, code = "assetChatError") {
    super(message);
    this.name = "AssetChatActionError";
    this.status = status;
    this.code = code;
  }
}

export function isAssetChatAction(action: string): boolean {
  return action === "ai_hub.asset_chat" || action === "asset.chat";
}

export function normalizeAssetChatPiiMode(value: unknown): AssetChatPiiMode {
  const mode = typeof value === "string" ? value.trim().toLowerCase() : "";
  if (!mode || mode === "off") return "off";
  if (mode === "mask") return "mask";
  throw new AssetChatActionError(
    "pii_mode must be off or mask",
    400,
    "invalidPiiMode",
  );
}

export function assetChatMoneyRange(value: number): string {
  if (!Number.isFinite(value)) return "[masked-number]";
  const prefix = value < 0 ? "-" : "";
  const amount = Math.abs(value);
  if (amount < 10_000) return `${prefix}¥0-10k`;
  if (amount < 50_000) return `${prefix}¥10k-50k`;
  if (amount < 100_000) return `${prefix}¥50k-100k`;
  if (amount < 500_000) return `${prefix}¥100k-500k`;
  if (amount < 1_000_000) return `${prefix}¥500k-1m`;
  if (amount < 5_000_000) return `${prefix}¥1m-5m`;
  if (amount < 10_000_000) return `${prefix}¥5m-10m`;
  if (amount < 50_000_000) return `${prefix}¥10m-50m`;
  if (amount < 100_000_000) return `${prefix}¥50m-100m`;
  return `${prefix}¥100m+`;
}

export function maskAssetChatSensitiveNumbers(value: string): string {
  const moneyRanges: Array<{ token: string; range: string }> = [];
  const keepRange = (range: string): string => {
    const token = `__ASSET_CHAT_MONEY_${alphabeticToken(moneyRanges.length)}__`;
    moneyRanges.push({ token, range });
    return token;
  };
  let masked = normalizeNumericWidth(value)
    .replace(/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/gi, "[masked-email]")
    // Keep already-bucketed values stable when a structured snapshot is serialized.
    .replace(
      /-?¥\s*\d+(?:\.\d+)?(?:k|m)?(?:-\d+(?:\.\d+)?(?:k|m)?)?\+?/gi,
      (match) => keepRange(match.replace(/\s+/g, "")),
    )
    .replace(
      /¥\s*([+-]?\d+(?:,\d{3})*(?:\.\d+)?)\s*(億|万|千)?(?:円)?|([+-]?\d+(?:,\d{3})*(?:\.\d+)?)\s*(億|万|千)?\s*円/gu,
      (_match, prefixed, prefixedUnit, suffixed, suffixedUnit) => {
        const amount = parseMoneyAmount(
          prefixed ?? suffixed,
          prefixedUnit ?? suffixedUnit,
        );
        return keepRange(assetChatMoneyRange(amount));
      },
    )
    // Comma-grouped bare values are overwhelmingly monetary in this feature.
    .replace(
      /[+-]?\d{1,3}(?:,\d{3})+(?:\.\d+)?/g,
      (match) => keepRange(assetChatMoneyRange(parseMoneyAmount(match))),
    )
    // Account numbers, dates, counts, and other raw numbers remain fully masked.
    .replace(/\d+(?:[.,]\d+)*/g, "[masked-number]");

  for (const entry of moneyRanges) {
    masked = masked.replaceAll(entry.token, entry.range);
  }
  return masked;
}

export async function handleAssetChatAction(options: {
  store: AssetChatStore;
  body: UnknownRecord;
  userId: string;
  invokeProvider?: AssetChatProviderInvoker;
  cache?: AssetChatContextCache;
  now?: () => number;
}): Promise<AssetChatResult> {
  const userId = options.userId.trim();
  if (!userId) {
    throw new AssetChatActionError(
      "Authenticated user required",
      401,
      "unauthorized",
    );
  }
  const message = readString(options.body.message);
  if (!message) {
    throw new AssetChatActionError("message required", 400, "messageRequired");
  }
  if (message.length > 4000) {
    throw new AssetChatActionError(
      "message must be at most 4000 characters",
      400,
      "messageTooLong",
    );
  }

  const threadId = readString(options.body.thread_id ?? options.body.threadId);
  if (threadId && !isUuid(threadId)) {
    throw new AssetChatActionError(
      "thread_id must be a UUID",
      400,
      "invalidThreadId",
    );
  }
  const snapshotMonths = readBoundedInteger(
    options.body.snapshot_months ?? options.body.snapshotMonths,
    3,
    1,
    12,
    "snapshot_months",
  );
  const historyMessages = readBoundedInteger(
    options.body.history_messages ?? options.body.historyMessages,
    8,
    0,
    20,
    "history_messages",
  );
  const piiMode = normalizeAssetChatPiiMode(
    options.body.pii_mode ?? options.body.piiMode,
  );
  const provider = normalizeProvider(options.body.provider);
  const requestedModel = readString(options.body.model);
  if (requestedModel.length > 200) {
    throw new AssetChatActionError(
      "model must be at most 200 characters",
      400,
      "modelTooLong",
    );
  }

  const nowMs = (options.now ?? Date.now)();
  const cache = options.cache ?? DEFAULT_CONTEXT_CACHE;
  let thread: AssetChatThread | null = null;
  let history: AssetChatHistoryRow[] = [];
  if (threadId) {
    thread = await options.store.getOwnedThread(userId, threadId);
    if (!thread) {
      throw new AssetChatActionError(
        "asset chat thread not found",
        404,
        "threadNotFound",
      );
    }
    if (historyMessages > 0) {
      history = await options.store.loadRecentMessages(
        thread.id,
        historyMessages,
      );
    }
  }

  let snapshotCache: "hit" | "miss" = "hit";
  let snapshotRows = cache.get(userId, snapshotMonths, nowMs);
  if (snapshotRows === null) {
    snapshotCache = "miss";
    snapshotRows = await options.store.loadSnapshots(userId, snapshotMonths);
    cache.set(userId, snapshotMonths, snapshotRows, nowMs);
  }

  const providerMessages = buildAssetChatMessages({
    message,
    history: [...history].reverse(),
    snapshots: snapshotRows.map(toSnapshotContext),
    piiMode,
  });
  if (!options.invokeProvider) {
    throw new AssetChatActionError(
      "asset chat provider is unavailable",
      503,
      "providerUnavailable",
    );
  }
  const providerResult = await options.invokeProvider({
    provider,
    model: requestedModel || undefined,
    messages: providerMessages,
  });
  const rawReply = readString(providerResult.text);
  if (!providerResult.ok || !rawReply) {
    throw new AssetChatActionError(
      providerResult.error || "asset chat provider returned an empty response",
      providerResult.httpStatus ?? providerFailureStatus(providerResult.error),
      "providerFailed",
    );
  }

  const reply = applyPiiMode(rawReply.slice(0, 50000), piiMode);
  const inputChars = providerMessages.reduce(
    (sum, item) => sum + item.content.length,
    0,
  );
  const tokensIn = estimateTokens(inputChars);
  const tokensOut = estimateTokens(rawReply.length);
  const createdAt = new Date(nowMs).toISOString();
  const assistantCreatedAt = new Date(nowMs + 1).toISOString();
  const model =
    (readString(providerResult.modelUsed) || requestedModel || provider)
      .slice(0, 200);

  let threadCreated = false;
  if (!thread) {
    const title = normalizeThreadTitle(options.body.thread_title, message);
    thread = await options.store.createThread(userId, title, createdAt);
    threadCreated = true;
  }
  await options.store.appendExchange(thread.id, {
    user: {
      role: "user",
      content: message,
      tokens_in: 0,
      tokens_out: 0,
      model: null,
      created_at: createdAt,
    },
    assistant: {
      role: "assistant",
      content: reply,
      tokens_in: tokensIn,
      tokens_out: tokensOut,
      model,
      created_at: assistantCreatedAt,
    },
  });
  await options.store.touchThread(userId, thread.id, assistantCreatedAt);

  return {
    status: "completed",
    thread_id: thread.id,
    thread_title: thread.title,
    thread_created: threadCreated,
    reply,
    provider,
    model,
    tokens_in: tokensIn,
    tokens_out: tokensOut,
    estimated_cost_usd: providerResult.estimatedCostUsd ?? 0,
    pii_mode: piiMode,
    context: {
      snapshot_months_requested: snapshotMonths,
      snapshot_rows: snapshotRows.length,
      history_messages_requested: historyMessages,
      history_rows: history.length,
      snapshot_cache: snapshotCache,
      snapshot_cache_ttl_seconds: Math.round(cache.ttlMs / 1000),
      selected_snapshot_columns: "month_key,payload,updated_at",
      selected_message_columns: "id,role,content,created_at",
    },
  };
}

export function buildAssetChatMessages(options: {
  message: string;
  history: AssetChatHistoryRow[];
  snapshots: AssetChatSnapshotContext[];
  piiMode: AssetChatPiiMode;
}): AssetChatMessage[] {
  const snapshots = options.piiMode === "mask"
    ? options.snapshots.map(rangeSnapshotMoneyAmounts)
    : options.snapshots;
  const contextJson = applyPiiMode(
    JSON.stringify(snapshots),
    options.piiMode,
  );
  const history = options.history.map((row) => ({
    role: row.role,
    content: applyPiiMode(row.content.slice(0, 4000), options.piiMode),
  } satisfies AssetChatMessage));
  return [
    {
      role: "system",
      content: [
        "あなたは資産・負債管理を補助する慎重な日本語アシスタントです。",
        "入力された月次指標はアプリが確定した値です。再計算、推測、架空の金額補完をしないでください。",
        "不明な値は不明と明示し、説明と次に確認すべき行動だけを簡潔に示してください。",
        "投資・税務・法務の断定的助言や売買指示は行わないでください。",
        options.piiMode === "mask"
          ? "プライバシーモード中です。金額レンジ（例: ¥100k-500k）や [masked-number] を具体値へ推測しないでください。"
          : "プライバシーモードはOFFです。受け取った値を必要以上に繰り返さないでください。",
      ].join("\n"),
    },
    {
      role: "system",
      content: `直近の月次資産スナップショット（新しい順）: ${contextJson}`,
    },
    ...history,
    {
      role: "user",
      content: applyPiiMode(options.message, options.piiMode),
    },
  ];
}

function rangeSnapshotMoneyAmounts(
  snapshot: AssetChatSnapshotContext,
): Record<string, string | number | null> {
  const moneyRange = (value: number | null): string | null =>
    value === null ? null : assetChatMoneyRange(value);
  return {
    month_key: snapshot.month_key,
    positive_asset_total: moneyRange(snapshot.positive_asset_total),
    liability_total: moneyRange(snapshot.liability_total),
    net_worth: moneyRange(snapshot.net_worth),
    cash_like_total: moneyRange(snapshot.cash_like_total),
    monthly_received_income_total: moneyRange(
      snapshot.monthly_received_income_total,
    ),
    monthly_scheduled_payment_total: moneyRange(
      snapshot.monthly_scheduled_payment_total,
    ),
    monthly_paid_payment_total: moneyRange(
      snapshot.monthly_paid_payment_total,
    ),
    monthly_unpaid_payment_total: moneyRange(
      snapshot.monthly_unpaid_payment_total,
    ),
    monthly_actual_payment_total: moneyRange(
      snapshot.monthly_actual_payment_total,
    ),
    monthly_payment_difference_total: moneyRange(
      snapshot.monthly_payment_difference_total,
    ),
    overdue_payment_count: snapshot.overdue_payment_count,
    securities_total: moneyRange(snapshot.securities_total),
  };
}

function toSnapshotContext(
  row: AssetChatSnapshotRow,
): AssetChatSnapshotContext {
  const payload = row.payload;
  return {
    month_key: row.month_key,
    positive_asset_total: readNumber(payload, [
      "positive_asset_total",
      "positiveAssetTotal",
      "total_assets",
    ]),
    liability_total: readNumber(payload, [
      "liability_total",
      "liabilityTotal",
      "total_liabilities",
    ]),
    net_worth: readNumber(payload, ["net_worth", "netWorth"]),
    cash_like_total: readNumber(payload, ["cash_like_total", "cashLikeTotal"]),
    monthly_received_income_total: readNumber(payload, [
      "monthly_received_income_total",
      "monthlyReceivedIncomeTotal",
    ]),
    monthly_scheduled_payment_total: readNumber(payload, [
      "monthly_scheduled_payment_total",
      "monthlyScheduledPaymentTotal",
    ]),
    monthly_paid_payment_total: readNumber(payload, [
      "monthly_paid_payment_total",
      "monthlyPaidPaymentTotal",
    ]),
    monthly_unpaid_payment_total: readNumber(payload, [
      "monthly_unpaid_payment_total",
      "monthlyUnpaidPaymentTotal",
    ]),
    monthly_actual_payment_total: readNumber(payload, [
      "monthly_actual_payment_total",
      "monthlyActualPaymentTotal",
    ]),
    monthly_payment_difference_total: readNumber(payload, [
      "monthly_payment_difference_total",
      "monthlyPaymentDifferenceTotal",
    ]),
    overdue_payment_count: readNumber(payload, [
      "overdue_payment_count",
      "overduePaymentCount",
    ]),
    securities_total: readNumber(payload, [
      "securities_total",
      "securitiesTotal",
    ]),
  };
}

function normalizeThreadTitle(value: unknown, message: string): string {
  const explicit = readString(value).replace(/\s+/g, " ");
  if (explicit.length > 200) {
    throw new AssetChatActionError(
      "thread_title must be at most 200 characters",
      400,
      "threadTitleTooLong",
    );
  }
  if (explicit) return explicit;
  return message.replace(/\s+/g, " ").slice(0, 60);
}

function normalizeProvider(value: unknown): string {
  const provider = readString(value).toLowerCase();
  if (!provider) return "google";
  const aliases: Record<string, string> = {
    claude: "anthropic",
    gemini: "google",
    chatgpt: "openai",
    gpt: "openai",
    grok: "xai",
  };
  return aliases[provider] ?? provider;
}

function providerFailureStatus(error: unknown): number {
  const message = readString(error).toLowerCase();
  if (message.includes("apikeyrequired")) return 503;
  if (
    message.includes("paidplanrequired") ||
    message.includes("usagelimitreached") ||
    message.includes("free_limit_reached")
  ) return 402;
  if (message.includes("budgetexceeded")) return 429;
  return 502;
}

function applyPiiMode(value: string, mode: AssetChatPiiMode): string {
  return mode === "mask" ? maskAssetChatSensitiveNumbers(value) : value;
}

function normalizeNumericWidth(value: string): string {
  return value
    .replace(
      /[０-９]/g,
      (character) => String(character.charCodeAt(0) - "０".charCodeAt(0)),
    )
    .replaceAll("，", ",")
    .replaceAll("．", ".")
    .replaceAll("￥", "¥")
    .replaceAll("＋", "+")
    .replaceAll("－", "-");
}

function parseMoneyAmount(value: string, unit?: string): number {
  const parsed = Number(value.replaceAll(",", ""));
  const multiplier = unit === "億"
    ? 100_000_000
    : unit === "万"
    ? 10_000
    : unit === "千"
    ? 1_000
    : 1;
  return parsed * multiplier;
}

function alphabeticToken(index: number): string {
  let current = index;
  let result = "";
  do {
    result = String.fromCharCode(65 + (current % 26)) + result;
    current = Math.floor(current / 26) - 1;
  } while (current >= 0);
  return result;
}

function estimateTokens(characters: number): number {
  return Math.max(0, Math.ceil(characters / 4));
}

function readBoundedInteger(
  value: unknown,
  fallback: number,
  min: number,
  max: number,
  field: string,
): number {
  if (value === undefined || value === null || value === "") return fallback;
  const parsed = typeof value === "number" ? value : Number(value);
  if (!Number.isInteger(parsed) || parsed < min || parsed > max) {
    throw new AssetChatActionError(
      `${field} must be an integer between ${min} and ${max}`,
      400,
      `invalid${
        field.replace(/(^|_)([a-z])/g, (_, _prefix, letter) =>
          letter.toUpperCase())
      }`,
    );
  }
  return parsed;
}

function readNumber(record: UnknownRecord, keys: string[]): number | null {
  for (const key of keys) {
    const value = record[key];
    if (typeof value === "number" && Number.isFinite(value)) return value;
    if (typeof value === "string" && value.trim()) {
      const parsed = Number(value.replace(/,/g, ""));
      if (Number.isFinite(parsed)) return parsed;
    }
  }
  return null;
}

function cloneSnapshotRow(row: AssetChatSnapshotRow): AssetChatSnapshotRow {
  return {
    month_key: row.month_key,
    payload: structuredClone(row.payload),
    updated_at: row.updated_at ?? null,
  };
}

function readString(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function isUuid(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
    .test(value);
}
