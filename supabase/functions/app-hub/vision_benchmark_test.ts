import {
  assertEquals,
  assertExists,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  DEFAULT_VISION_THRESHOLD,
  handleVisionBenchmarkAction,
  normalizeVisionThreshold,
  VISION_BENCHMARK_SOURCE,
  type VisionBenchmarkDb,
} from "./vision_benchmark.ts";

function createInMemoryVisionDb(): VisionBenchmarkDb {
  let seq = 0;
  const rows: Array<{
    id: string;
    source: string;
    metadata: Record<string, unknown>;
    created_at: string;
  }> = [];

  return {
    insertRun(userId, metadata) {
      seq += 1;
      const recordedAt = typeof metadata.recorded_at === "string"
        ? metadata.recorded_at
        : `2026-11-25T10:00:0${seq}Z`;
      const row = {
        id: `vb-${seq}`,
        source: VISION_BENCHMARK_SOURCE,
        metadata: { ...metadata, user_id: userId },
        created_at: recordedAt,
      };
      rows.unshift(row);
      return Promise.resolve(row);
    },

    listRuns(userId, limit) {
      const matched = rows
        .filter((r) => r.metadata.user_id === userId)
        .slice(0, limit);
      return Promise.resolve(matched);
    },
  };
}

Deno.test("normalizeVisionThreshold clamps invalid or extreme inputs", () => {
  assertEquals(normalizeVisionThreshold(undefined), DEFAULT_VISION_THRESHOLD);
  assertEquals(normalizeVisionThreshold("bad"), DEFAULT_VISION_THRESHOLD);
  assertEquals(normalizeVisionThreshold(0), 1);
  assertEquals(normalizeVisionThreshold(140), 100);
  assertEquals(normalizeVisionThreshold(82.4), 82);
});

Deno.test(
  "vision_benchmark.record validates model and numeric score",
  async () => {
    const db = createInMemoryVisionDb();

    const missingModel = await handleVisionBenchmarkAction({
      action: "vision_benchmark.record",
      body: { score: 88 },
      userId: "user-1",
      db,
    });
    assertEquals(missingModel.status, 400);

    const badScore = await handleVisionBenchmarkAction({
      action: "vision_benchmark.record",
      body: { model: "claude-sonnet-4-6", score: "nan" },
      userId: "user-1",
      db,
    });
    assertEquals(badScore.status, 400);
  },
);

Deno.test(
  "vision_benchmark isolates users and evaluates threshold alerts",
  async () => {
    const db = createInMemoryVisionDb();

    const first = await handleVisionBenchmarkAction({
      action: "vision_benchmark.record",
      body: {
        model: "gemini-2.5-flash",
        provider: "gemini",
        score: 92,
        latency_ms: 420,
        threshold: 70,
        detail: "6-stage Vision suite passed",
        levels: [
          {
            level: "level1",
            description: "Connectivity smoke test",
            passed: true,
            score: 92,
            maxPoints: 100,
            latency: 420,
            response: "ping-ok",
          },
        ],
        recorded_at: "2026-11-25T10:00:00Z",
      },
      userId: "user-1",
      db,
    });
    assertEquals(first.status, 200);

    const second = await handleVisionBenchmarkAction({
      action: "vision_benchmark.record",
      body: {
        model: "gpt-4o-mini",
        provider: "gpt",
        score: 74,
        latency_ms: 810,
        threshold: 70,
        recorded_at: "2026-11-25T11:00:00Z",
      },
      userId: "user-1",
      db,
    });
    assertEquals(second.status, 200);

    const listAt70 = await handleVisionBenchmarkAction({
      action: "vision_benchmark.list",
      body: { threshold: 70 },
      userId: "user-1",
      db,
    });
    assertEquals(listAt70.status, 200);
    const summary70 = listAt70.body.summary as Record<string, unknown>;
    assertEquals(summary70.total_runs, 2);
    assertEquals(summary70.alert_count, 0);

    const listAt80 = await handleVisionBenchmarkAction({
      action: "vision_benchmark.list",
      body: { threshold: 80 },
      userId: "user-1",
      db,
    });
    assertEquals(listAt80.status, 200);
    const summary80 = listAt80.body.summary as Record<string, unknown>;
    assertEquals(summary80.alert_count, 1);
    assertEquals(summary80.below_threshold_models, ["gpt-4o-mini"]);

    const otherUser = await handleVisionBenchmarkAction({
      action: "vision_benchmark.list",
      body: {},
      userId: "user-2",
      db,
    });
    assertEquals(otherUser.status, 200);
    const otherRuns = otherUser.body.runs as unknown[];
    assertEquals(otherRuns.length, 0);

    const filtered = await handleVisionBenchmarkAction({
      action: "vision_benchmark.list",
      body: { model: "gemini-2.5-flash" },
      userId: "user-1",
      db,
    });
    const filteredRuns = filtered.body.runs as Array<Record<string, unknown>>;
    assertEquals(filteredRuns.length, 1);
    assertExists((filteredRuns[0].levels as unknown[])[0]);
  },
);
