import {
  assertEquals,
  assertExists,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  AI_EMOTION_ALERT_SOURCE,
  AI_EMOTION_LOG_SOURCE,
} from "../_shared/ai_functional_emotion.ts";
import {
  type AiEmotionDb,
  handleAiEmotionAction,
} from "./ai_emotion.ts";

function createInMemoryEmotionDb(): AiEmotionDb {
  let seq = 0;
  const rows: Array<{
    id: string;
    source: string;
    metadata: Record<string, unknown>;
    created_at: string;
  }> = [];

  return {
    insertRecord(source, userId, metadata) {
      seq += 1;
      const ts = typeof metadata.recorded_at === "string"
        ? metadata.recorded_at
        : typeof metadata.triggered_at === "string"
        ? metadata.triggered_at
        : `2026-11-25T10:00:0${seq}Z`;
      const row = {
        id: `emo-${seq}`,
        source,
        metadata: { ...metadata, user_id: userId },
        created_at: ts,
      };
      rows.unshift(row);
      return Promise.resolve(row);
    },

    listRecords(source, userId, limit) {
      const filtered = rows
        .filter((r) => r.source === source && r.metadata.user_id === userId)
        .slice(0, limit);
      return Promise.resolve(filtered);
    },
  };
}

Deno.test(
  "ai_emotion rejects missing userId and empty response_text",
  async () => {
    const db = createInMemoryEmotionDb();

    const unauth = await handleAiEmotionAction({
      action: "ai_emotion.list",
      body: {},
      userId: "",
      db,
    });
    assertEquals(unauth.status, 401);

    const emptyText = await handleAiEmotionAction({
      action: "ai_emotion.classify_and_log",
      body: { response_text: "   " },
      userId: "user-a",
      db,
    });
    assertEquals(emptyText.status, 400);
  },
);

Deno.test(
  "ai_emotion.classify_and_log creates alert, notifies webhook, isolates user",
  async () => {
    const db = createInMemoryEmotionDb();
    const webhookCalls: string[] = [];

    const created = await handleAiEmotionAction({
      action: "ai_emotion.classify_and_log",
      body: {
        response_text: "至急今すぐ対処しないと重大な危険でパニックです！!",
        model: "gemini-2.5-flash",
        source_action: "assistant_reply",
        alert_threshold: 0.65,
      },
      userId: "user-a",
      db,
      getEnv: (k) =>
        k === "AI_EMOTION_ALERT_WEBHOOK_URL"
          ? "https://hooks.example.com/admin"
          : undefined,
      fetcher: (input) => {
        webhookCalls.push(typeof input === "string" ? input : String(input));
        return Promise.resolve(new Response("ok", { status: 200 }));
      },
    });
    assertEquals(created.status, 200);
    assertEquals(created.body.needs_verification, true);
    const log = created.body.log as Record<string, unknown>;
    assertEquals(log.tone, "panic");
    assertEquals(log.needs_verification, true);
    assertEquals(log.threshold_exceeded, true);
    const alert = created.body.alert as Record<string, unknown> | null;
    assertExists(alert);
    assertEquals(alert.notified, true);
    assertEquals(webhookCalls.length, 1);

    const listA = await handleAiEmotionAction({
      action: "ai_emotion.list",
      body: {},
      userId: "user-a",
      db,
    });
    assertEquals((listA.body.logs as unknown[]).length, 1);
    assertEquals((listA.body.alerts as unknown[]).length, 1);

    const listB = await handleAiEmotionAction({
      action: "ai_emotion.list",
      body: {},
      userId: "user-b",
      db,
    });
    assertEquals((listB.body.logs as unknown[]).length, 0);
    assertEquals((listB.body.alerts as unknown[]).length, 0);
  },
);

Deno.test(
  "ai_emotion.seed_defaults is idempotent and builds time-series summary",
  async () => {
    const db = createInMemoryEmotionDb();

    const first = await handleAiEmotionAction({
      action: "ai_emotion.seed_defaults",
      body: {},
      userId: "user-seed",
      db,
    });
    assertEquals(first.status, 200);
    assertEquals(first.body.seeded, 4);
    assertEquals((first.body.logs as unknown[]).length, 4);
    assertEquals((first.body.alerts as unknown[]).length, 1);

    const second = await handleAiEmotionAction({
      action: "ai_emotion.seed_defaults",
      body: {},
      userId: "user-seed",
      db,
    });
    assertEquals(second.status, 200);
    assertEquals(second.body.seeded, 0);

    const summaryRes = await handleAiEmotionAction({
      action: "ai_emotion.summary",
      body: {},
      userId: "user-seed",
      db,
    });
    const summary = summaryRes.body.summary as Record<string, unknown>;
    assertEquals(summary.total_logs, 4);
    assertEquals(summary.alert_count, 1);
    assertEquals(summary.needs_verification, true);
    assertEquals((summary.timeline as unknown[]).length, 4);
    assertEquals(typeof AI_EMOTION_LOG_SOURCE, "string");
    assertEquals(typeof AI_EMOTION_ALERT_SOURCE, "string");
  },
);
