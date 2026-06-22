import {
  handleMarketPriceAction,
  isMarketPriceAction,
  type MarketPriceDb,
  type MarketPriceDbQuery,
  normalizeMarketPriceInput,
} from "./market_price.ts";

Deno.test("market price actions and inputs are normalized", () => {
  assertEquals(isMarketPriceAction("asset.market_price.fetch"), true);
  assertEquals(isMarketPriceAction("ai_hub.fetch_market_price"), true);
  assertEquals(isMarketPriceAction("provider.chat"), false);

  const input = normalizeMarketPriceInput({
    asset_type: "crypto",
    ticker: "btc",
    cache_minutes: 2,
  });
  assertEquals(input.assetType, "crypto");
  assertEquals(input.ticker, "BTC");
  assertEquals(input.currency, "JPY");
  assertEquals(input.provider, "coingecko");
  assertEquals(input.cacheMinutes, 5);
});

Deno.test("handleMarketPriceAction returns fresh cache without live fetch", async () => {
  const db = new FakeDb({
    investment_market_price_cache: [
      priceCacheRow({
        ticker: "BTC",
        fetched_at: "2026-06-20T00:20:00.000Z",
        expires_at: "2026-06-20T00:50:00.000Z",
      }),
    ],
  });

  const result = await handleMarketPriceAction({
    db,
    userId: "user-1",
    body: { asset_type: "crypto", ticker: "btc" },
    liveFetchEnabled: false,
    now: new Date("2026-06-20T00:30:00.000Z"),
    fetcher: () => {
      throw new Error("fetcher should not be called for fresh cache");
    },
  });

  assertEquals(result.status, "cache_hit");
  assertEquals(result.price_jpy, 10500000);
  assertEquals(result.source, "cache");
  assertEquals(result.cache_age_minutes, 10);
  assertEquals(db.upserts.length, 0);
});

Deno.test("handleMarketPriceAction falls back to stale cache when live fetch is off", async () => {
  const db = new FakeDb({
    investment_market_price_cache: [
      priceCacheRow({
        ticker: "BTC",
        fetched_at: "2026-06-20T00:00:00.000Z",
        expires_at: "2026-06-20T00:30:00.000Z",
      }),
    ],
  });

  const result = await handleMarketPriceAction({
    db,
    userId: "user-1",
    body: { asset_type: "crypto", ticker: "btc" },
    liveFetchEnabled: false,
    now: new Date("2026-06-20T01:00:00.000Z"),
  });

  assertEquals(result.status, "stale_cache_fallback");
  assertEquals(result.price_jpy, 10500000);
  assertStringIncludes(result.warnings.join(" "), "disabled");
});

Deno.test("handleMarketPriceAction writes provider cache and updates holdings", async () => {
  const db = new FakeDb({
    investment_assets: [
      {
        id: "asset-1",
        user_id: "user-1",
        asset_type: "crypto",
        ticker: "BTC",
      },
      {
        id: "asset-2",
        user_id: "other-user",
        asset_type: "crypto",
        ticker: "BTC",
      },
    ],
  });

  const result = await handleMarketPriceAction({
    db,
    userId: "user-1",
    body: { asset_type: "crypto", ticker: "btc", live_fetch_enabled: true },
    liveFetchEnabled: true,
    now: new Date("2026-06-20T00:00:00.000Z"),
    fetcher: (request) => {
      assertEquals(request.provider, "coingecko");
      assertEquals(request.ticker, "BTC");
      return Promise.resolve({
        ok: true,
        priceJpy: 10600000.12345,
        provider: "coingecko",
        fetchedAt: "2026-06-20T00:00:00.000Z",
        payload: { bitcoin: { jpy: 10600000.12345 } },
      });
    },
  });

  assertEquals(result.status, "cache_write");
  assertEquals(result.price_jpy, 10600000.1235);
  assertEquals(result.updated_holding_count, 1);
  assertEquals(db.upserts[0].table, "investment_market_price_cache");
  assertEquals(db.upserts[0].value.expires_at, "2026-06-20T00:30:00.000Z");
  assertEquals(
    db.rows.investment_assets[0].current_price_jpy,
    10600000.1235,
  );
  assertEquals(db.rows.investment_assets[1].current_price_jpy, undefined);
});

Deno.test("handleMarketPriceAction reports provider errors without cache", async () => {
  const db = new FakeDb();

  const result = await handleMarketPriceAction({
    db,
    userId: "user-1",
    body: { asset_type: "stock", ticker: "7203.T", live_fetch_enabled: true },
    liveFetchEnabled: true,
    fetcher: () =>
      Promise.resolve({
        ok: false,
        error: "rate limit",
        rateLimited: true,
      }),
  });

  assertEquals(result.status, "provider_rate_limited");
  assertEquals(result.price_jpy, null);
  assertStringIncludes(result.warnings.join(" "), "rate limit");
});

function priceCacheRow(
  overrides: Record<string, unknown> = {},
): Record<string, unknown> {
  return {
    asset_type: "crypto",
    ticker: "BTC",
    currency: "JPY",
    provider: "coingecko",
    price_jpy: 10500000,
    fetched_at: "2026-06-20T00:00:00.000Z",
    expires_at: "2026-06-20T00:30:00.000Z",
    source_payload: {},
    ...overrides,
  };
}

function assertEquals(actual: unknown, expected: unknown) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(
      `Assertion failed:\nactual:   ${JSON.stringify(actual)}\nexpected: ${
        JSON.stringify(expected)
      }`,
    );
  }
}

function assertStringIncludes(actual: string, expected: string) {
  if (!actual.includes(expected)) {
    throw new Error(
      `Assertion failed: expected ${JSON.stringify(actual)} to include ${
        JSON.stringify(expected)
      }`,
    );
  }
}

class FakeDb implements MarketPriceDb {
  rows: Record<string, Record<string, unknown>[]>;
  upserts: { table: string; value: Record<string, unknown> }[] = [];

  constructor(rows: Record<string, Record<string, unknown>[]> = {}) {
    this.rows = rows;
  }

  from(table: string): MarketPriceDbQuery {
    this.rows[table] ??= [];
    return new FakeQuery(table, this);
  }
}

class FakeQuery implements MarketPriceDbQuery {
  private filters: { column: string; value: string }[] = [];
  private updateValue: Record<string, unknown> | null = null;

  constructor(
    private readonly table: string,
    private readonly db: FakeDb,
  ) {}

  select(): MarketPriceDbQuery {
    return this;
  }

  eq(column: string, value: string): MarketPriceDbQuery {
    this.filters.push({ column, value });
    return this;
  }

  order(): MarketPriceDbQuery {
    return this;
  }

  update(value: Record<string, unknown>): MarketPriceDbQuery {
    this.updateValue = value;
    return this;
  }

  limit(count: number): Promise<{ data: unknown[]; error: null }> {
    let rows = this.db.rows[this.table].filter((row) =>
      this.filters.every((filter) => row[filter.column] === filter.value)
    );
    if (this.updateValue) {
      rows = rows.map((row) => Object.assign(row, this.updateValue));
    }
    return Promise.resolve({ data: rows.slice(0, count), error: null });
  }

  upsert(value: Record<string, unknown>) {
    this.db.upserts.push({ table: this.table, value });
    this.db.rows[this.table].push(value);
    return {
      select: () => ({
        single: () => Promise.resolve({ data: value, error: null }),
      }),
    };
  }
}
