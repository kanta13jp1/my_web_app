export type MonthlyAssetReportChatMessage = {
  role: string;
  content: string;
};

export type MonthlyAssetReportProviderRequest = {
  provider: string;
  model?: string;
  messages: MonthlyAssetReportChatMessage[];
};

export type MonthlyAssetReportProviderResult = {
  ok: boolean;
  text?: string;
  modelUsed?: string;
  error?: string;
  isRetriable?: boolean;
};

export type MonthlyAssetReportProviderInvoker = (
  request: MonthlyAssetReportProviderRequest,
) => Promise<MonthlyAssetReportProviderResult>;

type UnknownRecord = Record<string, unknown>;

type QueryResult = {
  data?: unknown[] | null;
  error?: { message?: string } | null;
};

type SingleResult = {
  data?: unknown | null;
  error?: { message?: string } | null;
};

export type MonthlyAssetReportDbQuery = {
  select(columns?: string): MonthlyAssetReportDbQuery;
  eq(column: string, value: string): MonthlyAssetReportDbQuery;
  gte(column: string, value: string): MonthlyAssetReportDbQuery;
  lt(column: string, value: string): MonthlyAssetReportDbQuery;
  order(
    column: string,
    options?: { ascending?: boolean },
  ): MonthlyAssetReportDbQuery;
  limit(count: number): Promise<QueryResult>;
  upsert(
    value: UnknownRecord,
    options?: { onConflict?: string },
  ): {
    select(columns?: string): {
      single(): Promise<SingleResult>;
    };
  };
};

export type MonthlyAssetReportDb = {
  from(table: string): MonthlyAssetReportDbQuery;
};

export type MonthlyAssetSnapshot = {
  month_key: string;
  total_assets: number;
  total_liabilities: number;
  net_worth: number;
  cash_like_total: number;
  monthly_scheduled_payment_total: number;
  monthly_paid_payment_total: number;
  monthly_unpaid_payment_total: number;
  monthly_actual_payment_total: number;
  monthly_payment_difference_total: number;
  overdue_payment_count: number;
  source: "request" | "monthly_snapshot" | "cfo_assets" | "empty";
};

export type MonthlyAssetReportResult = {
  status:
    | "feature_flag_off"
    | "ai_summary_generated"
    | "deterministic_fallback";
  year_month: string;
  month_key: string;
  snapshot: MonthlyAssetSnapshot;
  report: UnknownRecord | null;
  deterministic_summary: string;
  ai_summary: string;
  ai_model: string;
  provider: string | null;
  ai_enabled: boolean;
  warnings: string[];
};

export class MonthlyAssetReportActionError extends Error {
  status: number;

  constructor(message: string, status = 400) {
    super(message);
    this.name = "MonthlyAssetReportActionError";
    this.status = status;
  }
}

const PROVIDER_ALIASES: Record<string, string> = {
  anthropic: "anthropic",
  claude: "anthropic",
  opus: "anthropic",
  openai: "openai",
  gpt: "openai",
  chatgpt: "openai",
  google: "google",
  gemini: "google",
  deepseek: "deepseek",
  moonshot: "moonshot",
  kimi: "moonshot",
  xai: "xai",
  grok: "xai",
};

export function isMonthlyAssetReportAction(action: string): boolean {
  return action === "asset.monthly_report.generate" ||
    action === "asset_liability.monthly_report.generate";
}

export function isMonthlyAssetReportAiSummaryEnabled(
  body: UnknownRecord,
): boolean {
  return body.enable_ai_summary === true ||
    body.ai_summary_enabled === true ||
    Deno.env.get("ASSET_MONTHLY_REPORT_AI_ENABLED") === "true";
}

export function normalizeMonthlyAssetReportProvider(value: unknown): string {
  const key = typeof value === "string" ? value.trim().toLowerCase() : "";
  if (!key) return "google";
  return PROVIDER_ALIASES[key] ?? key;
}

export function normalizeMonthlyAssetReportMonth(value: unknown): {
  monthKey: string;
  yearMonth: string;
} {
  let raw = typeof value === "string" ? value.trim() : "";
  if (!raw) {
    const now = new Date();
    raw = `${now.getUTCFullYear()}-${
      String(now.getUTCMonth() + 1).padStart(2, "0")
    }`;
  }
  const match = raw.match(/^(\d{4})-(\d{2})(?:-(\d{2}))?$/);
  if (!match) {
    throw new MonthlyAssetReportActionError(
      "year_month must be YYYY-MM or YYYY-MM-DD",
      400,
    );
  }
  const year = Number(match[1]);
  const month = Number(match[2]);
  if (month < 1 || month > 12) {
    throw new MonthlyAssetReportActionError("year_month month is invalid", 400);
  }
  const monthKey = `${String(year).padStart(4, "0")}-${
    String(month).padStart(2, "0")
  }`;
  return { monthKey, yearMonth: `${monthKey}-01` };
}

export async function handleMonthlyAssetReportAction(options: {
  db: MonthlyAssetReportDb;
  body: UnknownRecord;
  userId: string;
  invokeProvider?: MonthlyAssetReportProviderInvoker;
  aiSummaryEnabled?: boolean;
  generatedAt?: Date;
}): Promise<MonthlyAssetReportResult> {
  const { monthKey, yearMonth } = normalizeMonthlyAssetReportMonth(
    options.body.year_month ?? options.body.month_key,
  );
  const warnings: string[] = [];
  const snapshot = await loadMonthlyAssetSnapshot({
    db: options.db,
    body: options.body,
    userId: options.userId,
    monthKey,
    warnings,
  });
  const deterministicSummary = buildDeterministicMonthlyAssetSummary(snapshot);
  const aiEnabled = options.aiSummaryEnabled ??
    isMonthlyAssetReportAiSummaryEnabled(options.body);
  const provider = normalizeMonthlyAssetReportProvider(
    options.body.provider_preference ?? options.body.provider,
  );
  const generatedAt = (options.generatedAt ?? new Date()).toISOString();
  let status: MonthlyAssetReportResult["status"] = aiEnabled
    ? "deterministic_fallback"
    : "feature_flag_off";
  let aiSummary = deterministicSummary;
  let aiModel = "deterministic-fallback";

  if (aiEnabled) {
    const providerResult = options.invokeProvider
      ? await options.invokeProvider({
        provider,
        model: readString(options.body.model),
        messages: buildMonthlyAssetReportMessages(snapshot),
      })
      : {
        ok: false,
        error: "providerInvokerUnavailable",
        isRetriable: false,
      };
    const providerText = readString(providerResult.text);
    if (providerResult.ok && providerText) {
      status = "ai_summary_generated";
      aiSummary = providerText.slice(0, 2400);
      aiModel = providerResult.modelUsed ?? `${provider}:default`;
    } else {
      warnings.push(
        `AI summary fallback used: ${providerResult.error ?? "empty response"}`,
      );
    }
  }

  const upsertPayload = {
    user_id: options.userId,
    year_month: yearMonth,
    total_assets: snapshot.total_assets,
    total_liabilities: snapshot.total_liabilities,
    net_worth: snapshot.net_worth,
    ai_summary: aiSummary,
    ai_model: aiModel,
    generated_at: generatedAt,
  };

  let report: UnknownRecord | null = null;
  if (options.body.dry_run !== true) {
    const { data, error } = await options.db.from("monthly_asset_reports")
      .upsert(upsertPayload, { onConflict: "user_id,year_month" })
      .select(
        "id,user_id,year_month,total_assets,total_liabilities,net_worth,ai_summary,ai_model,generated_at,updated_at",
      )
      .single();
    if (error) {
      throw new MonthlyAssetReportActionError(
        `monthly_asset_reports upsert failed: ${error.message ?? "unknown"}`,
        500,
      );
    }
    report = asRecord(data) ?? upsertPayload;
  }

  return {
    status,
    year_month: yearMonth,
    month_key: monthKey,
    snapshot,
    report,
    deterministic_summary: deterministicSummary,
    ai_summary: aiSummary,
    ai_model: aiModel,
    provider: aiEnabled ? provider : null,
    ai_enabled: aiEnabled,
    warnings,
  };
}

async function loadMonthlyAssetSnapshot(options: {
  db: MonthlyAssetReportDb;
  body: UnknownRecord;
  userId: string;
  monthKey: string;
  warnings: string[];
}): Promise<MonthlyAssetSnapshot> {
  const explicitSnapshot = asRecord(options.body.snapshot);
  if (explicitSnapshot) {
    return normalizeSnapshot(explicitSnapshot, options.monthKey, "request");
  }

  const persisted = await readMonthlySnapshotRow(options);
  if (persisted) {
    return normalizeSnapshot(persisted, options.monthKey, "monthly_snapshot");
  }

  const cfoRows = await readCfoAssetRows(options);
  if (cfoRows.length > 0) {
    return buildSnapshotFromCfoAssets(cfoRows, options.monthKey);
  }

  return emptySnapshot(options.monthKey);
}

async function readMonthlySnapshotRow(options: {
  db: MonthlyAssetReportDb;
  userId: string;
  monthKey: string;
  warnings: string[];
}): Promise<UnknownRecord | null> {
  try {
    const { data, error } = await options.db
      .from("asset_liability_monthly_snapshots")
      .select("payload,month_key,updated_at,created_at")
      .eq("user_id", options.userId)
      .eq("month_key", options.monthKey)
      .limit(1);
    if (error) {
      options.warnings.push(
        `monthly snapshot read skipped: ${error.message ?? "unknown"}`,
      );
      return null;
    }
    const row = firstRecord(data);
    const payload = asRecord(row?.payload);
    return payload ? { ...payload, month_key: row?.month_key } : row;
  } catch (error) {
    options.warnings.push(`monthly snapshot read skipped: ${String(error)}`);
    return null;
  }
}

async function readCfoAssetRows(options: {
  db: MonthlyAssetReportDb;
  userId: string;
  monthKey: string;
  warnings: string[];
}): Promise<UnknownRecord[]> {
  const { start, end } = monthRangeUtc(options.monthKey);
  try {
    const { data, error } = await options.db
      .from("cfo_assets")
      .select("title,amount,created_at")
      .eq("user_id", options.userId)
      .gte("created_at", start)
      .lt("created_at", end)
      .order("created_at", { ascending: true })
      .limit(2000);
    if (error) {
      options.warnings.push(
        `cfo_assets read skipped: ${error.message ?? "unknown"}`,
      );
      return [];
    }
    return toRecords(data);
  } catch (error) {
    options.warnings.push(`cfo_assets read skipped: ${String(error)}`);
    return [];
  }
}

export function buildDeterministicMonthlyAssetSummary(
  snapshot: MonthlyAssetSnapshot,
): string {
  const netDeltaLabel = snapshot.net_worth >= 0 ? "positive" : "negative";
  return [
    `${snapshot.month_key} monthly asset report.`,
    `Assets: ${formatYen(snapshot.total_assets)}; liabilities: ${
      formatYen(snapshot.total_liabilities)
    }; net worth: ${formatYen(snapshot.net_worth)} (${netDeltaLabel}).`,
    `Cash-like assets: ${
      formatYen(snapshot.cash_like_total)
    }; scheduled payments: ${
      formatYen(snapshot.monthly_scheduled_payment_total)
    }; actual payments: ${formatYen(snapshot.monthly_actual_payment_total)}.`,
    `Payment difference: ${
      formatYen(snapshot.monthly_payment_difference_total)
    }; overdue payments: ${snapshot.overdue_payment_count}.`,
  ].join(" ");
}

export function buildMonthlyAssetReportMessages(
  snapshot: MonthlyAssetSnapshot,
): MonthlyAssetReportChatMessage[] {
  return [
    {
      role: "system",
      content:
        "You are a cautious personal finance analyst. Do not invent account balances. Return a concise Japanese summary with risks and next actions.",
    },
    {
      role: "user",
      content: [
        "Create a monthly asset management summary from this deterministic snapshot.",
        "Keep it under 600 Japanese characters.",
        "Include: net worth, liability pressure, payment variance, overdue risk, and one next action.",
        JSON.stringify(snapshot),
      ].join("\n"),
    },
  ];
}

function normalizeSnapshot(
  input: UnknownRecord,
  monthKey: string,
  source: MonthlyAssetSnapshot["source"],
): MonthlyAssetSnapshot {
  const totalAssets = readYen(input, [
    "total_assets",
    "positive_asset_total",
    "positiveAssetTotal",
    "assets",
  ]);
  const totalLiabilities = Math.abs(readYen(input, [
    "total_liabilities",
    "liability_total",
    "liabilityTotal",
    "liabilities",
  ]));
  const netWorthValue = readOptionalNumber(input, ["net_worth", "netWorth"]);
  return {
    month_key: readString(input.month_key) || readString(input.monthKey) ||
      monthKey,
    total_assets: totalAssets,
    total_liabilities: totalLiabilities,
    net_worth: netWorthValue !== undefined && Number.isFinite(netWorthValue)
      ? roundYen(netWorthValue)
      : totalAssets - totalLiabilities,
    cash_like_total: readYen(input, ["cash_like_total", "cashLikeTotal"]),
    monthly_scheduled_payment_total: readYen(input, [
      "monthly_scheduled_payment_total",
      "monthlyScheduledPaymentTotal",
    ]),
    monthly_paid_payment_total: readYen(input, [
      "monthly_paid_payment_total",
      "monthlyPaidPaymentTotal",
    ]),
    monthly_unpaid_payment_total: readYen(input, [
      "monthly_unpaid_payment_total",
      "monthlyUnpaidPaymentTotal",
    ]),
    monthly_actual_payment_total: readYen(input, [
      "monthly_actual_payment_total",
      "monthlyActualPaymentTotal",
      "monthly_paid_payment_total",
      "monthlyPaidPaymentTotal",
    ]),
    monthly_payment_difference_total: readYen(input, [
      "monthly_payment_difference_total",
      "monthlyPaymentDifferenceTotal",
    ]),
    overdue_payment_count: Math.max(
      0,
      Math.round(
        readOptionalNumber(input, [
          "overdue_payment_count",
          "overduePaymentCount",
        ]) ?? 0,
      ),
    ),
    source,
  };
}

function buildSnapshotFromCfoAssets(
  rows: UnknownRecord[],
  monthKey: string,
): MonthlyAssetSnapshot {
  const latestByTitle = new Map<string, number>();
  for (const row of rows) {
    const title = readString(row.title);
    if (!title) continue;
    latestByTitle.set(title, readOptionalNumber(row, ["amount"]) ?? 0);
  }
  let totalAssets = 0;
  let totalLiabilities = 0;
  for (const amount of latestByTitle.values()) {
    if (amount >= 0) {
      totalAssets += amount;
    } else {
      totalLiabilities += Math.abs(amount);
    }
  }
  return {
    ...emptySnapshot(monthKey),
    total_assets: roundYen(totalAssets),
    total_liabilities: roundYen(totalLiabilities),
    net_worth: roundYen(totalAssets - totalLiabilities),
    source: "cfo_assets",
  };
}

function emptySnapshot(monthKey: string): MonthlyAssetSnapshot {
  return {
    month_key: monthKey,
    total_assets: 0,
    total_liabilities: 0,
    net_worth: 0,
    cash_like_total: 0,
    monthly_scheduled_payment_total: 0,
    monthly_paid_payment_total: 0,
    monthly_unpaid_payment_total: 0,
    monthly_actual_payment_total: 0,
    monthly_payment_difference_total: 0,
    overdue_payment_count: 0,
    source: "empty",
  };
}

function monthRangeUtc(monthKey: string): { start: string; end: string } {
  const [yearText, monthText] = monthKey.split("-");
  const year = Number(yearText);
  const month = Number(monthText);
  const start = new Date(Date.UTC(year, month - 1, 1));
  const end = new Date(Date.UTC(year, month, 1));
  return { start: start.toISOString(), end: end.toISOString() };
}

function readYen(record: UnknownRecord, keys: string[]): number {
  return roundYen(readOptionalNumber(record, keys) ?? 0);
}

function readOptionalNumber(
  record: UnknownRecord,
  keys: string[],
): number | undefined {
  for (const key of keys) {
    const value = record[key];
    if (typeof value === "number" && Number.isFinite(value)) return value;
    if (typeof value === "string" && value.trim()) {
      const parsed = Number(value.replace(/,/g, ""));
      if (Number.isFinite(parsed)) return parsed;
    }
  }
  return undefined;
}

function readString(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function roundYen(value: number): number {
  if (!Number.isFinite(value)) return 0;
  return Math.round(value);
}

function formatYen(value: number): string {
  return `${roundYen(value).toLocaleString("en-US")} JPY`;
}

function asRecord(value: unknown): UnknownRecord | null {
  return value !== null && typeof value === "object" && !Array.isArray(value)
    ? value as UnknownRecord
    : null;
}

function firstRecord(value: unknown): UnknownRecord | null {
  return toRecords(value)[0] ?? null;
}

function toRecords(value: unknown): UnknownRecord[] {
  return Array.isArray(value)
    ? value.map(asRecord).filter((row): row is UnknownRecord => row !== null)
    : [];
}
