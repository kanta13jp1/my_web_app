import {
  assertEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  AI_EMOTION_ALERT_SOURCE,
  AI_EMOTION_LOG_SOURCE,
  classifyFunctionalEmotion,
  normalizeEmotionThreshold,
  recordFunctionalEmotionTelemetryFailOpen,
  type TelemetryDbWriter,
  validateAlertWebhookUrl,
} from "./ai_functional_emotion.ts";

Deno.test(
  "classifyFunctionalEmotion scores calm vs panic and pins needs_verification",
  () => {
    const calm = classifyFunctionalEmotion(
      "落ち着いて手順を段階的に確認しましょう。",
    );
    assertEquals(calm.tone, "calm");
    assertEquals(calm.threshold_exceeded, false);
    assertEquals(calm.needs_verification, true);

    const panic = classifyFunctionalEmotion(
      "今すぐ対応しないと崩壊して取り返しがつかないパニック状態です！!",
    );
    assertEquals(panic.tone, "panic");
    assertEquals(panic.threshold_exceeded, true);
    assertEquals(panic.alert_severity, "critical");
    assertEquals(panic.needs_verification, true);
  },
);

Deno.test(
  "normalizeEmotionThreshold clamps boundaries and rejects invalid input",
  () => {
    assertEquals(normalizeEmotionThreshold(undefined), 0.7);
    assertEquals(normalizeEmotionThreshold("invalid"), 0.7);
    assertEquals(normalizeEmotionThreshold(0.01), 0.1);
    assertEquals(normalizeEmotionThreshold(1.5), 0.99);
    assertEquals(normalizeEmotionThreshold(0.755), 0.76);
  },
);

Deno.test(
  "validateAlertWebhookUrl blocks insecure and private targets",
  () => {
    assertEquals(
      validateAlertWebhookUrl("https://hooks.example.com/alerts"),
      true,
    );
    assertEquals(
      validateAlertWebhookUrl("http://hooks.example.com/alerts"),
      false,
    );
    assertEquals(validateAlertWebhookUrl("https://localhost/hook"), false);
    assertEquals(validateAlertWebhookUrl("https://127.0.0.1/hook"), false);
    assertEquals(validateAlertWebhookUrl("https://10.0.0.5/hook"), false);
  },
);

Deno.test(
  "recordFunctionalEmotionTelemetryFailOpen logs, alerts, and stays fail-open",
  async () => {
    const inserted: Array<{
      source: string;
      userId: string;
      metadata: Record<string, unknown>;
    }> = [];
    const db: TelemetryDbWriter = {
      insertRecord(source, userId, metadata) {
        inserted.push({ source, userId, metadata });
        return Promise.resolve({ id: `row-${inserted.length}` });
      },
    };
    const webhooks: string[] = [];

    const okRes = await recordFunctionalEmotionTelemetryFailOpen({
      db,
      userId: "user-1",
      responseText: "至急今すぐ対処しないと重大な危険と禁止事項に抵触!",
      model: "gemini-2.5-flash",
      webhookUrl: "https://hooks.example.com/emotion",
      fetcher: (url) => {
        webhooks.push(String(url));
        return Promise.resolve(new Response("ok", { status: 200 }));
      },
    });
    assertEquals(okRes.ok, true);
    assertEquals(okRes.alertCreated, true);
    assertEquals(inserted.length, 2);
    assertEquals(inserted[0].source, AI_EMOTION_LOG_SOURCE);
    assertEquals(inserted[0].metadata.needs_verification, true);
    assertEquals(inserted[1].source, AI_EMOTION_ALERT_SOURCE);
    assertEquals(webhooks.length, 1);

    const brokenDb: TelemetryDbWriter = {
      insertRecord() {
        return Promise.reject(new Error("db down"));
      },
    };
    const failRes = await recordFunctionalEmotionTelemetryFailOpen({
      db: brokenDb,
      userId: "user-1",
      responseText: "落ち着いて確認します。",
    });
    assertEquals(failRes.ok, false);
    assertEquals(failRes.error, "db down");
  },
);
