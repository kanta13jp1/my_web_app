type UnknownRecord = Record<string, unknown>;

type QueryResult = {
  data?: unknown[] | null;
  error?: { message?: string } | null;
};

type SingleResult = {
  data?: unknown | null;
  error?: { message?: string } | null;
};

export type MarketPriceDbQuery = {
  select(columns?: string): MarketPriceDbQuery;
  eq(column: string, value: string): MarketPriceDbQuery;
  order(
    column: string,
    options?: { ascending?: boolean },
  ): MarketPriceDbQuery;
  limit(count: number): Promise<QueryResult>;
  update(value: UnknownRecord): MarketPriceDbQuery;
  upsert(
    value: UnknownRecord,
    options?: { onConflict?: string },
  ): {
    select(columns?: string): {
      single(): Promise<SingleResult>;
    };
  };
};

export type MarketPriceDb = {
  from(table: string): MarketPriceDbQuery;
};

export type MarketPriceFetchRequest = {
  assetType: MarketPriceAssetType;
  ticker: string;
  currency: string;
  provider: string;
  body: UnknownRecord;
};

export type MarketPriceFetchResult = {
  ok: boolean;
  priceJpy?: number;
  provider?: string;
  fetchedAt?: string;
  payload?: UnknownRecord;
  error?: string;
  rateLimited?: boolean;
};

export type MarketPriceFetcher = (
  request: MarketPriceFetchRequest,
) => Promise<MarketPriceFetchResult>;

export type MarketPriceAssetType = "stock" | "crypto" | "reit" | "etf";

export type MarketPriceInput = {
  assetType: MarketPriceAssetType;
  ticker: string;
  currency: string;
  provider: string;
  cacheMinutes: number;
  forceRefresh: boolean;
  dryRun: boolean;
};

type MarketPriceCacheRow = {
  asset_type: MarketPriceAssetType;
  ticker: string;
  currency: string;
  provider: string;
  price_jpy: number;
  fetched_at: string;
  expires_at: string;
  source_payload?: UnknownRecord;
};

export type MarketPriceActionResult = {
  status:
    | "cache_hit"
    | "cache_write"
    | "stale_cache_fallback"
    | "external_fetch_disabled"
    | "provider_rate_limited"
    | "provider_error";
  asset_type: MarketPriceAssetType;
  ticker: string;
  currency: string;
  provider: string;
  price_jpy: number | null;
  fetched_at: string | null;
  expires_at: string | null;
  source: "cache" | "provider" | "none";
  cache_age_minutes: number | null;
  cache_ttl_minutes: number;
  dry_run: boolean;
  updated_holding_count: number;
  warnings: string[];
};

export class MarketPriceActionError extends Error {
  status: number;

  constructor(message: string, status = 400) {
    super(message);
    this.name = "MarketPriceActionError";
    this.status = status;
  }
}

const ASSET_TYPES = new Set(["stock", "crypto", "reit", "etf"]);
const MARKET_PRICE_ACTIONS = new Set([
  "asset.market_price.fetch",
  "asset.investment.market_price.fetch",
  "ai_hub.fetch_market_price",
]);
const COMMON_COINGECKO_IDS: Record<string, string> = {
  btc: "bitcoin",
  bitcoin: "bitcoin",
  eth: "ethereum",
  ethereum: "ethereum",
  sol: "solana",
  solana: "solana",
  xrp: "ripple",
  ripple: "ripple",
  doge: "dogecoin",
  dogecoin: "dogecoin",
  ada: "cardano",
  cardano: "cardano",
};

export function isMarketPriceAction(action: string): boolean {
  return MARKET_PRICE_ACTIONS.has(action);
}

export function isMarketPriceLiveFetchEnabled(body: UnknownRecord): boolean {
  return body.live_fetch_enabled === true ||
    body.enable_live_fetch === true ||
    Deno.env.get("ASSET_MARKET_PRICE_LIVE_FETCH_ENABLED") === "true";
}

export function normalizeMarketPriceInput(
  body: UnknownRecord,
): MarketPriceInput {
  const assetType = normalizeAssetType(body.asset_type ?? body.assetType);
  const ticker = normalizeTicker(body.ticker ?? body.symbol);
  const currency = normalizeCurrency(body.currency);
  const provider = normalizeMarketPriceProvider(
    body.provider,
    assetType,
  );
  const cacheMinutes = clampNumber(
    readOptionalNumber(body, ["cache_minutes", "cacheMinutes"]) ?? 30,
    5,
    24 * 60,
  );
  return {
    assetType,
    ticker,
    currency,
    provider,
    cacheMinutes,
    forceRefresh: body.force_refresh === true ||
      body.forceRefresh === true,
    dryRun: body.dry_run === true || body.dryRun === true,
  };
}

export async function handleMarketPriceAction(options: {
  db: MarketPriceDb;
  body: UnknownRecord;
  userId: string;
  fetcher?: MarketPriceFetcher;
  liveFetchEnabled?: boolean;
  now?: Date;
}): Promise<MarketPriceActionResult> {
  const input = normalizeMarketPriceInput(options.body);
  const now = options.now ?? new Date();
  const liveFetchEnabled = options.liveFetchEnabled ??
    isMarketPriceLiveFetchEnabled(options.body);
  const warnings: string[] = [];
  const cached = await readMarketPriceCache(options.db, input, warnings);
  if (cached && !input.forceRefresh && isFresh(cached, now)) {
    return resultFromCache({
      status: "cache_hit",
      input,
      cached,
      now,
      warnings,
      updatedHoldingCount: 0,
    });
  }

  if (!liveFetchEnabled) {
    if (cached) {
      warnings.push("Live market price fetch is disabled; using stale cache.");
      return resultFromCache({
        status: "stale_cache_fallback",
        input,
        cached,
        now,
        warnings,
        updatedHoldingCount: 0,
      });
    }
    warnings.push("Live market price fetch is disabled and no cache exists.");
    return emptyResult("external_fetch_disabled", input, warnings);
  }

  const fetcher = options.fetcher ?? fetchConfiguredMarketPrice;
  const providerResult = await fetcher({
    assetType: input.assetType,
    ticker: input.ticker,
    currency: input.currency,
    provider: input.provider,
    body: options.body,
  });
  if (!providerResult.ok || !isPositivePrice(providerResult.priceJpy)) {
    const status = providerResult.rateLimited
      ? "provider_rate_limited"
      : "provider_error";
    warnings.push(
      providerResult.error ?? "Provider returned no usable JPY price.",
    );
    if (cached) {
      warnings.push("Using last cached market price as fallback.");
      return resultFromCache({
        status: "stale_cache_fallback",
        input,
        cached,
        now,
        warnings,
        updatedHoldingCount: 0,
      });
    }
    return emptyResult(status, input, warnings);
  }

  const fetchedAt = providerResult.fetchedAt ?? now.toISOString();
  const expiresAt = new Date(
    new Date(fetchedAt).getTime() + input.cacheMinutes * 60 * 1000,
  ).toISOString();
  const cachePayload: UnknownRecord = {
    asset_type: input.assetType,
    ticker: input.ticker,
    currency: input.currency,
    provider: providerResult.provider ?? input.provider,
    price_jpy: roundPrice(providerResult.priceJpy),
    fetched_at: fetchedAt,
    expires_at: expiresAt,
    source_payload: providerResult.payload ?? {},
  };

  let updatedHoldingCount = 0;
  if (!input.dryRun) {
    const { error } = await options.db.from("investment_market_price_cache")
      .upsert(cachePayload, { onConflict: "asset_type,ticker,currency" })
      .select(
        "asset_type,ticker,currency,provider,price_jpy,fetched_at,expires_at,source_payload",
      )
      .single();
    if (error) {
      throw new MarketPriceActionError(
        `investment_market_price_cache upsert failed: ${
          error.message ?? "unknown"
        }`,
        500,
      );
    }
    updatedHoldingCount = await updateInvestmentAssetPrices({
      db: options.db,
      userId: options.userId,
      input,
      priceJpy: roundPrice(providerResult.priceJpy),
      fetchedAt,
      warnings,
    });
  }

  return {
    status: "cache_write",
    asset_type: input.assetType,
    ticker: input.ticker,
    currency: input.currency,
    provider: providerResult.provider ?? input.provider,
    price_jpy: roundPrice(providerResult.priceJpy),
    fetched_at: fetchedAt,
    expires_at: expiresAt,
    source: "provider",
    cache_age_minutes: 0,
    cache_ttl_minutes: input.cacheMinutes,
    dry_run: input.dryRun,
    updated_holding_count: updatedHoldingCount,
    warnings,
  };
}

export function fetchConfiguredMarketPrice(
  request: MarketPriceFetchRequest,
): Promise<MarketPriceFetchResult> {
  if (request.assetType === "crypto") {
    return fetchCoinGeckoCryptoPrice(request);
  }
  return fetchAlphaVantageMarketPrice(request);
}

async function fetchCoinGeckoCryptoPrice(
  request: MarketPriceFetchRequest,
): Promise<MarketPriceFetchResult> {
  const id = readString(request.body.coingecko_id) ||
    COMMON_COINGECKO_IDS[request.ticker.toLowerCase()];
  if (!id) {
    return {
      ok: false,
      error: "coingecko_id required for crypto tickers not in the common map",
      rateLimited: false,
    };
  }
  const vsCurrency = request.currency.toLowerCase();
  const url = new URL("https://api.coingecko.com/api/v3/simple/price");
  url.searchParams.set("ids", id);
  url.searchParams.set("vs_currencies", vsCurrency);
  const response = await fetch(url);
  const rawText = await response.text();
  const parsed = parseJsonRecord(rawText);
  if (!response.ok) {
    return {
      ok: false,
      error: `coingecko:${response.status}:${rawText.slice(0, 240)}`,
      rateLimited: response.status === 429,
    };
  }
  const price = readOptionalNumber(asRecord(parsed[id]) ?? {}, [vsCurrency]);
  return {
    ok: isPositivePrice(price),
    priceJpy: price,
    provider: "coingecko",
    payload: parsed,
    error: isPositivePrice(price) ? undefined : "coingecko price missing",
  };
}

async function fetchAlphaVantageMarketPrice(
  request: MarketPriceFetchRequest,
): Promise<MarketPriceFetchResult> {
  const apiKey = Deno.env.get("ALPHA_VANTAGE_API_KEY") ?? "";
  if (!apiKey) {
    return {
      ok: false,
      error: "ALPHA_VANTAGE_API_KEY required for stock/ETF/REIT prices",
      rateLimited: false,
    };
  }
  const url = new URL("https://www.alphavantage.co/query");
  url.searchParams.set("function", "GLOBAL_QUOTE");
  url.searchParams.set("symbol", request.ticker);
  url.searchParams.set("apikey", apiKey);
  const response = await fetch(url);
  const rawText = await response.text();
  const parsed = parseJsonRecord(rawText);
  if (!response.ok) {
    return {
      ok: false,
      error: `alpha_vantage:${response.status}:${rawText.slice(0, 240)}`,
      rateLimited: response.status === 429,
    };
  }
  const quote = asRecord(parsed["Global Quote"]) ?? {};
  const rateLimited = readString(parsed.Note).length > 0 ||
    readString(parsed.Information).toLowerCase().includes("rate limit");
  const price = readOptionalNumber(quote, ["05. price", "price"]);
  return {
    ok: isPositivePrice(price) && !rateLimited,
    priceJpy: price,
    provider: "alpha_vantage",
    payload: parsed,
    error: rateLimited
      ? "alpha_vantage rate limit"
      : isPositivePrice(price)
      ? undefined
      : "alpha_vantage price missing",
    rateLimited,
  };
}

async function readMarketPriceCache(
  db: MarketPriceDb,
  input: MarketPriceInput,
  warnings: string[],
): Promise<MarketPriceCacheRow | null> {
  try {
    const { data, error } = await db.from("investment_market_price_cache")
      .select(
        "asset_type,ticker,currency,provider,price_jpy,fetched_at,expires_at,source_payload",
      )
      .eq("asset_type", input.assetType)
      .eq("ticker", input.ticker)
      .eq("currency", input.currency)
      .order("expires_at", { ascending: false })
      .limit(1);
    if (error) {
      warnings.push(`price cache read skipped: ${error.message ?? "unknown"}`);
      return null;
    }
    const row = firstRecord(data);
    return row ? normalizeCacheRow(row) : null;
  } catch (error) {
    warnings.push(`price cache read skipped: ${String(error)}`);
    return null;
  }
}

async function updateInvestmentAssetPrices(options: {
  db: MarketPriceDb;
  userId: string;
  input: MarketPriceInput;
  priceJpy: number;
  fetchedAt: string;
  warnings: string[];
}): Promise<number> {
  if (!options.userId) return 0;
  try {
    const { data, error } = await options.db.from("investment_assets")
      .update({
        current_price_jpy: options.priceJpy,
        last_priced_at: options.fetchedAt,
      })
      .eq("user_id", options.userId)
      .eq("asset_type", options.input.assetType)
      .eq("ticker", options.input.ticker)
      .select("id")
      .limit(1000);
    if (error) {
      options.warnings.push(
        `investment_assets update skipped: ${error.message ?? "unknown"}`,
      );
      return 0;
    }
    return toRecords(data).length;
  } catch (error) {
    options.warnings.push(`investment_assets update skipped: ${String(error)}`);
    return 0;
  }
}

function resultFromCache(options: {
  status: "cache_hit" | "stale_cache_fallback";
  input: MarketPriceInput;
  cached: MarketPriceCacheRow;
  now: Date;
  warnings: string[];
  updatedHoldingCount: number;
}): MarketPriceActionResult {
  return {
    status: options.status,
    asset_type: options.input.assetType,
    ticker: options.input.ticker,
    currency: options.input.currency,
    provider: options.cached.provider,
    price_jpy: options.cached.price_jpy,
    fetched_at: options.cached.fetched_at,
    expires_at: options.cached.expires_at,
    source: "cache",
    cache_age_minutes: cacheAgeMinutes(options.cached, options.now),
    cache_ttl_minutes: options.input.cacheMinutes,
    dry_run: options.input.dryRun,
    updated_holding_count: options.updatedHoldingCount,
    warnings: options.warnings,
  };
}

function emptyResult(
  status:
    | "external_fetch_disabled"
    | "provider_rate_limited"
    | "provider_error",
  input: MarketPriceInput,
  warnings: string[],
): MarketPriceActionResult {
  return {
    status,
    asset_type: input.assetType,
    ticker: input.ticker,
    currency: input.currency,
    provider: input.provider,
    price_jpy: null,
    fetched_at: null,
    expires_at: null,
    source: "none",
    cache_age_minutes: null,
    cache_ttl_minutes: input.cacheMinutes,
    dry_run: input.dryRun,
    updated_holding_count: 0,
    warnings,
  };
}

function normalizeCacheRow(row: UnknownRecord): MarketPriceCacheRow {
  return {
    asset_type: normalizeAssetType(row.asset_type),
    ticker: normalizeTicker(row.ticker),
    currency: normalizeCurrency(row.currency),
    provider: readString(row.provider) || "unknown",
    price_jpy: roundPrice(
      readOptionalNumber(row, ["price_jpy", "priceJpy"]) ?? 0,
    ),
    fetched_at: readString(row.fetched_at),
    expires_at: readString(row.expires_at),
    source_payload: asRecord(row.source_payload) ?? {},
  };
}

function normalizeAssetType(value: unknown): MarketPriceAssetType {
  const key = readString(value).toLowerCase();
  if (ASSET_TYPES.has(key)) return key as MarketPriceAssetType;
  throw new MarketPriceActionError(
    "asset_type must be one of stock, crypto, reit, etf",
    400,
  );
}

function normalizeTicker(value: unknown): string {
  const ticker = readString(value).toUpperCase();
  if (!ticker) {
    throw new MarketPriceActionError("ticker is required", 400);
  }
  if (!/^[A-Z0-9._:-]{1,32}$/.test(ticker)) {
    throw new MarketPriceActionError(
      "ticker must be 1-32 chars of A-Z, 0-9, dot, underscore, colon, or hyphen",
      400,
    );
  }
  return ticker;
}

function normalizeCurrency(value: unknown): string {
  const currency = readString(value).toUpperCase() || "JPY";
  if (!/^[A-Z]{3}$/.test(currency)) {
    throw new MarketPriceActionError("currency must be a 3-letter code", 400);
  }
  if (currency !== "JPY") {
    throw new MarketPriceActionError(
      "Only JPY market price cache is supported in this phase",
      400,
    );
  }
  return currency;
}

function normalizeMarketPriceProvider(
  value: unknown,
  assetType: MarketPriceAssetType,
): string {
  const provider = readString(value).toLowerCase();
  if (provider) return provider;
  return assetType === "crypto" ? "coingecko" : "alpha_vantage";
}

function isFresh(row: MarketPriceCacheRow, now: Date): boolean {
  const expiresAt = Date.parse(row.expires_at);
  return Number.isFinite(expiresAt) && expiresAt > now.getTime();
}

function cacheAgeMinutes(row: MarketPriceCacheRow, now: Date): number | null {
  const fetchedAt = Date.parse(row.fetched_at);
  if (!Number.isFinite(fetchedAt)) return null;
  return Math.max(0, Math.round((now.getTime() - fetchedAt) / 60000));
}

function isPositivePrice(value: unknown): value is number {
  return typeof value === "number" && Number.isFinite(value) && value >= 0;
}

function roundPrice(value: number): number {
  return Math.round(value * 10000) / 10000;
}

function clampNumber(value: number, min: number, max: number): number {
  if (!Number.isFinite(value)) return min;
  return Math.max(min, Math.min(max, Math.round(value)));
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

function parseJsonRecord(text: string): UnknownRecord {
  try {
    return asRecord(JSON.parse(text)) ?? {};
  } catch {
    return {};
  }
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
