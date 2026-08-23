import {
  AssetChatActionError,
  AssetChatContextCache,
  type AssetChatExchange,
  type AssetChatHistoryRow,
  type AssetChatMessage,
  assetChatMoneyRange,
  type AssetChatProviderRequest,
  type AssetChatSnapshotRow,
  type AssetChatStore,
  type AssetChatThread,
  handleAssetChatAction,
  isAssetChatAction,
  maskAssetChatSensitiveNumbers,
  normalizeAssetChatPiiMode,
} from "./asset_chat.ts";

const THREAD_ID = "11111111-1111-4111-8111-111111111111";
const NEW_THREAD_ID = "22222222-2222-4222-8222-222222222222";

Deno.test("asset chat action aliases and PII defaults are stable", () => {
  assertEquals(isAssetChatAction("ai_hub.asset_chat"), true);
  assertEquals(isAssetChatAction("asset.chat"), true);
  assertEquals(isAssetChatAction("provider.chat"), false);
  assertEquals(normalizeAssetChatPiiMode(undefined), "off");
  assertEquals(normalizeAssetChatPiiMode("off"), "off");
  assertEquals(normalizeAssetChatPiiMode("mask"), "mask");
  assertThrows(
    () => normalizeAssetChatPiiMode("range"),
    "pii_mode must be off or mask",
  );

  const masked = maskAssetChatSensitiveNumbers(
    "口座123-456、残高1,234,567円、全角１２３万円、mail=user123@example.com",
  );
  assert(masked.includes("[masked-number]-[masked-number]"), masked);
  assert(masked.includes("¥1m-5m"), masked);
  assert(!masked.includes("1,234,567"), `raw amount leaked: ${masked}`);
  assert(!masked.includes("１２３"), `full-width amount leaked: ${masked}`);
  assert(!masked.includes("user123@example.com"), `email leaked: ${masked}`);

  assertEquals(assetChatMoneyRange(0), "¥0-10k");
  assertEquals(assetChatMoneyRange(123_456), "¥100k-500k");
  assertEquals(assetChatMoneyRange(1_234_567), "¥1m-5m");
  assertEquals(assetChatMoneyRange(-500_000), "-¥500k-1m");
  assertEquals(assetChatMoneyRange(100_000_000), "¥100m+");
});

Deno.test("creates a thread, calls the provider, and persists one exchange", async () => {
  const store = new FakeStore({
    snapshots: [
      snapshot("2026-08", 1_200_000, 300_000),
      snapshot("2026-07", 1_100_000, 320_000),
    ],
  });
  const providerRequests: AssetChatProviderRequest[] = [];
  const result = await handleAssetChatAction({
    store,
    userId: "user-1",
    body: {
      message: "今月の負債圧力を説明して",
      provider: "claude",
      snapshot_months: 2,
      history_messages: 4,
    },
    cache: new AssetChatContextCache(),
    now: () => Date.parse("2026-08-18T00:00:00.000Z"),
    invokeProvider: (request) => {
      providerRequests.push(request);
      return Promise.resolve({
        ok: true,
        text: "負債は確定値の範囲で確認し、支払予定を見直してください。",
        modelUsed: "claude-test",
        estimatedCostUsd: 0.001,
      });
    },
  });

  const providerRequest = providerRequests[0];
  assert(providerRequest, "provider was not invoked");
  assertEquals(providerRequest.provider, "anthropic");
  assert(
    providerRequest.messages.some((item) =>
      item.content.includes("1200000") && item.content.includes("300000")
    ),
    "bounded snapshot context was not sent",
  );
  assertEquals(result.thread_id, NEW_THREAD_ID);
  assertEquals(result.thread_created, true);
  assertEquals(result.context.snapshot_rows, 2);
  assertEquals(result.context.history_rows, 0);
  assertEquals(result.context.snapshot_cache, "miss");
  assertEquals(result.estimated_cost_usd, 0.001);
  assert(result.tokens_in > 0, "input tokens were not estimated");
  assert(result.tokens_out > 0, "output tokens were not estimated");
  assertEquals(store.createdThreads.length, 1);
  assertEquals(store.exchanges.length, 1);
  assertEquals(
    store.exchanges[0].exchange.user.content,
    "今月の負債圧力を説明して",
  );
  assertEquals(store.exchanges[0].exchange.assistant.model, "claude-test");
  assert(
    store.exchanges[0].exchange.user.created_at <
      store.exchanges[0].exchange.assistant.created_at,
    "exchange ordering timestamps must be stable",
  );
  assertEquals(store.touches.length, 1);
});

Deno.test("loads owned thread history in chronological provider order", async () => {
  const store = new FakeStore({
    threads: [thread(THREAD_ID, "既存スレッド")],
    history: {
      [THREAD_ID]: [
        history("assistant", "前回回答", "2026-08-17T00:00:01.000Z"),
        history("user", "前回質問", "2026-08-17T00:00:00.000Z"),
      ],
    },
  });
  let roles: string[] = [];
  let contents: string[] = [];
  const result = await handleAssetChatAction({
    store,
    userId: "user-1",
    body: { thread_id: THREAD_ID, message: "続けて説明して" },
    cache: new AssetChatContextCache(),
    invokeProvider: (request) => {
      roles = request.messages.map((item) => item.role);
      contents = request.messages.map((item) => item.content);
      return Promise.resolve({ ok: true, text: "続きの回答です。" });
    },
  });

  assertEquals(roles, ["system", "system", "user", "assistant", "user"]);
  assertEquals(contents.slice(-3), ["前回質問", "前回回答", "続けて説明して"]);
  assertEquals(result.thread_id, THREAD_ID);
  assertEquals(result.thread_created, false);
  assertEquals(result.context.history_rows, 2);
  assertEquals(store.createdThreads.length, 0);
});

Deno.test("rejects an unowned or missing thread before context/provider work", async () => {
  const store = new FakeStore();
  let providerCalled = false;
  const error = await captureError(() =>
    handleAssetChatAction({
      store,
      userId: "user-1",
      body: { thread_id: THREAD_ID, message: "見せて" },
      invokeProvider: () => {
        providerCalled = true;
        return Promise.resolve({ ok: true, text: "unexpected" });
      },
    })
  );

  assert(
    error instanceof AssetChatActionError,
    "expected AssetChatActionError",
  );
  assertEquals((error as AssetChatActionError).status, 404);
  assertEquals((error as AssetChatActionError).code, "threadNotFound");
  assertEquals(store.snapshotReads, 0);
  assertEquals(providerCalled, false);
});

Deno.test("reuses snapshot context for one hour but always reloads history", async () => {
  const store = new FakeStore({
    threads: [thread(THREAD_ID, "cache")],
    snapshots: [snapshot("2026-08", 10, 2)],
  });
  const cache = new AssetChatContextCache(60 * 60 * 1000);
  let nowMs = Date.parse("2026-08-18T00:00:00.000Z");
  const run = () =>
    handleAssetChatAction({
      store,
      userId: "user-1",
      body: { thread_id: THREAD_ID, message: "確認" },
      cache,
      now: () => nowMs,
      invokeProvider: () => Promise.resolve({ ok: true, text: "回答" }),
    });

  const first = await run();
  nowMs += 30 * 60 * 1000;
  const second = await run();
  assertEquals(first.context.snapshot_cache, "miss");
  assertEquals(second.context.snapshot_cache, "hit");
  assertEquals(store.snapshotReads, 1);
  assertEquals(store.historyReads, 2);

  nowMs += 31 * 60 * 1000;
  const third = await run();
  assertEquals(third.context.snapshot_cache, "miss");
  assertEquals(store.snapshotReads, 2);
});

Deno.test("mask mode sends money ranges without raw sensitive values", async () => {
  const store = new FakeStore({
    snapshots: [snapshot("2026-08", 1_234_567, 456_789)],
  });
  const rawMessage = "残高123456円、user9@example.comです";
  let providerMessages: AssetChatMessage[] = [];
  const result = await handleAssetChatAction({
    store,
    userId: "user-1",
    body: { message: rawMessage, pii_mode: "mask" },
    cache: new AssetChatContextCache(),
    invokeProvider: (request) => {
      providerMessages = request.messages;
      return Promise.resolve({ ok: true, text: "残高500000円を確認しました" });
    },
  });

  const providerInput = providerMessages.map((item) => item.content).join("\n");
  for (
    const rawValue of [
      "123456",
      "1,234,567",
      "1234567",
      "456789",
      "2026-08",
      "user9@example.com",
    ]
  ) {
    assert(
      !providerInput.includes(rawValue),
      `provider input leaked ${rawValue}: ${providerInput}`,
    );
  }
  assert(
    providerInput.includes('"positive_asset_total":"¥1m-5m"'),
    providerInput,
  );
  assert(
    providerInput.includes('"liability_total":"¥100k-500k"'),
    providerInput,
  );
  assert(providerInput.includes("残高¥100k-500k"), providerInput);
  assertEquals(result.reply, "残高¥500k-1mを確認しました");
  assertEquals(store.exchanges[0].exchange.user.content, rawMessage);
  assertEquals(
    store.exchanges[0].exchange.assistant.content,
    "残高¥500k-1mを確認しました",
  );
});

Deno.test("provider failures do not create a new thread or persist messages", async () => {
  const store = new FakeStore({ snapshots: [snapshot("2026-08", 10, 1)] });
  const error = await captureError(() =>
    handleAssetChatAction({
      store,
      userId: "user-1",
      body: { message: "質問" },
      cache: new AssetChatContextCache(),
      invokeProvider: () =>
        Promise.resolve({
          ok: false,
          error: "apiKeyRequired",
          isRetriable: false,
        }),
    })
  );

  assert(
    error instanceof AssetChatActionError,
    "expected AssetChatActionError",
  );
  assertEquals((error as AssetChatActionError).status, 503);
  assertEquals((error as AssetChatActionError).code, "providerFailed");
  assertEquals(store.createdThreads.length, 0);
  assertEquals(store.exchanges.length, 0);
  assertEquals(store.touches.length, 0);
});

Deno.test("validates bounded request fields", async () => {
  const store = new FakeStore();
  const invalidThread = await captureError(() =>
    handleAssetChatAction({
      store,
      userId: "user-1",
      body: { thread_id: "not-a-uuid", message: "質問" },
    })
  );
  assertEquals((invalidThread as AssetChatActionError).code, "invalidThreadId");

  const invalidLimit = await captureError(() =>
    handleAssetChatAction({
      store,
      userId: "user-1",
      body: { message: "質問", snapshot_months: 13 },
    })
  );
  assertEquals((invalidLimit as AssetChatActionError).status, 400);

  const longMessage = await captureError(() =>
    handleAssetChatAction({
      store,
      userId: "user-1",
      body: { message: "x".repeat(4001) },
    })
  );
  assertEquals((longMessage as AssetChatActionError).code, "messageTooLong");
});

function thread(id: string, title: string): AssetChatThread {
  return {
    id,
    title,
    created_at: "2026-08-17T00:00:00.000Z",
    last_message_at: "2026-08-17T00:00:00.000Z",
  };
}

function snapshot(
  monthKey: string,
  assets: number,
  liabilities: number,
): AssetChatSnapshotRow {
  return {
    month_key: monthKey,
    payload: {
      positive_asset_total: assets,
      liability_total: liabilities,
      net_worth: assets - liabilities,
      overdue_payment_count: 1,
    },
    updated_at: "2026-08-18T00:00:00.000Z",
  };
}

function history(
  role: "user" | "assistant",
  content: string,
  createdAt: string,
): AssetChatHistoryRow {
  return { role, content, created_at: createdAt };
}

class FakeStore implements AssetChatStore {
  readonly threads = new Map<string, AssetChatThread>();
  readonly snapshots: AssetChatSnapshotRow[];
  readonly history: Record<string, AssetChatHistoryRow[]>;
  readonly createdThreads: AssetChatThread[] = [];
  readonly exchanges: { threadId: string; exchange: AssetChatExchange }[] = [];
  readonly touches: { userId: string; threadId: string; at: string }[] = [];
  snapshotReads = 0;
  historyReads = 0;

  constructor(options: {
    threads?: AssetChatThread[];
    snapshots?: AssetChatSnapshotRow[];
    history?: Record<string, AssetChatHistoryRow[]>;
  } = {}) {
    for (const item of options.threads ?? []) this.threads.set(item.id, item);
    this.snapshots = options.snapshots ?? [];
    this.history = options.history ?? {};
  }

  getOwnedThread(
    _userId: string,
    threadId: string,
  ): Promise<AssetChatThread | null> {
    return Promise.resolve(this.threads.get(threadId) ?? null);
  }

  createThread(
    _userId: string,
    title: string,
    createdAt: string,
  ): Promise<AssetChatThread> {
    const item: AssetChatThread = {
      id: NEW_THREAD_ID,
      title,
      created_at: createdAt,
      last_message_at: createdAt,
    };
    this.createdThreads.push(item);
    this.threads.set(item.id, item);
    return Promise.resolve(item);
  }

  loadSnapshots(
    _userId: string,
    limit: number,
  ): Promise<AssetChatSnapshotRow[]> {
    this.snapshotReads += 1;
    return Promise.resolve(this.snapshots.slice(0, limit));
  }

  loadRecentMessages(
    threadId: string,
    limit: number,
  ): Promise<AssetChatHistoryRow[]> {
    this.historyReads += 1;
    return Promise.resolve((this.history[threadId] ?? []).slice(0, limit));
  }

  appendExchange(threadId: string, exchange: AssetChatExchange): Promise<void> {
    this.exchanges.push({ threadId, exchange });
    return Promise.resolve();
  }

  touchThread(userId: string, threadId: string, at: string): Promise<void> {
    this.touches.push({ userId, threadId, at });
    return Promise.resolve();
  }
}

async function captureError(run: () => Promise<unknown>): Promise<unknown> {
  try {
    await run();
  } catch (error) {
    return error;
  }
  throw new Error("Expected operation to throw");
}

function assert(
  condition: unknown,
  message = "Assertion failed",
): asserts condition {
  if (!condition) throw new Error(message);
}

function assertEquals(actual: unknown, expected: unknown): void {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(
      `Assertion failed:\nactual:   ${JSON.stringify(actual)}\nexpected: ${
        JSON.stringify(expected)
      }`,
    );
  }
}

function assertThrows(run: () => unknown, message: string): void {
  try {
    run();
  } catch (error) {
    assert(
      String(error).includes(message),
      `unexpected error: ${String(error)}`,
    );
    return;
  }
  throw new Error("Expected operation to throw");
}
