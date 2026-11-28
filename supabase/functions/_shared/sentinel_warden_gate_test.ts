import {
  assertEquals,
  assertExists,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  evaluateSentinelWardenGate,
  InMemoryRevisionQueueStore,
} from "./sentinel_warden_gate.ts";

Deno.test(
  "evaluateSentinelWardenGate publishes clean output passing both stages",
  async () => {
    const store = new InMemoryRevisionQueueStore();
    const res = await evaluateSentinelWardenGate(
      {
        id: "cand-1",
        sourceAction: "ai.summary",
        content: "本日の家計サマリー: 食費は前月比で安定しています。",
        structuredData: { summary: "ok", category: "finance" },
      },
      store,
      { requiredKeys: ["summary", "category"] },
    );

    assertEquals(res.disposition, "published");
    assertEquals(res.publishable, true);
    assertEquals(res.sentinelPassed, true);
    assertEquals(res.wardenPassed, true);
    assertEquals(res.queuedItemId, null);
    assertEquals((await store.listPending()).length, 0);
  },
);

Deno.test(
  "evaluateSentinelWardenGate discards output containing PII",
  async () => {
    const store = new InMemoryRevisionQueueStore();
    const res = await evaluateSentinelWardenGate(
      {
        id: "cand-pii",
        sourceAction: "ai.reply",
        content: "連絡先は user.private@example.com です。",
      },
      store,
    );

    assertEquals(res.disposition, "discarded");
    assertEquals(res.publishable, false);
    assertEquals(res.sentinelPassed, false);
    assertEquals(res.findings[0].code, "pii_or_secret_detected");
    assertEquals((await store.listPending()).length, 0);
  },
);

Deno.test(
  "evaluateSentinelWardenGate queues missing schema or bad formatting",
  async () => {
    const store = new InMemoryRevisionQueueStore();

    const sentinelBlocked = await evaluateSentinelWardenGate(
      {
        id: "cand-schema",
        sourceAction: "ai.extract",
        content: "十分な長さのある構造化出力テキストです。",
        structuredData: { summary: "only-one-key" },
      },
      store,
      { requiredKeys: ["summary", "category"] },
    );
    assertEquals(sentinelBlocked.disposition, "revision_queue");
    assertEquals(sentinelBlocked.sentinelPassed, false);
    assertExists(sentinelBlocked.queuedItemId);

    const wardenBlocked = await evaluateSentinelWardenGate(
      {
        id: "cand-format",
        sourceAction: "ai.code",
        content: "```dart\nfinal x = 1;\n未閉じのコードブロック {{user_name}}",
      },
      store,
    );
    assertEquals(wardenBlocked.disposition, "revision_queue");
    assertEquals(wardenBlocked.sentinelPassed, true);
    assertEquals(wardenBlocked.wardenPassed, false);

    const pending = await store.listPending();
    assertEquals(pending.length, 2);
    assertEquals(await store.markResolved("rev-cand-schema"), true);
    assertEquals((await store.listPending()).length, 1);
  },
);
