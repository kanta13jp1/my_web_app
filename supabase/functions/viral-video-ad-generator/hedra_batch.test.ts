import {
  assertEquals,
  assertThrows,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  normalizeHedraBatchResponse,
  parseHedraBatchSize,
  parseHedraGenerationIds,
  withHedraBatchSize,
} from "./hedra_batch.ts";

Deno.test("parseHedraBatchSize accepts the supported 1 to 8 range", () => {
  assertEquals(parseHedraBatchSize(undefined), 1);
  assertEquals(parseHedraBatchSize("1"), 1);
  assertEquals(parseHedraBatchSize(8), 8);
  assertThrows(() => parseHedraBatchSize(0));
  assertThrows(() => parseHedraBatchSize(9));
  assertThrows(() => parseHedraBatchSize(1.5));
});

Deno.test("withHedraBatchSize sends the Hedra batch_size parameter", () => {
  assertEquals(withHedraBatchSize({ type: "video" }, 8), {
    type: "video",
    batch_size: 8,
  });
});

Deno.test("normalizeHedraBatchResponse preserves every batch result", () => {
  const result = normalizeHedraBatchResponse({
    batch_generation_id: "batch-123",
    batch_size: 2,
    generation_ids: ["video-a", "video-b"],
    batch_results: [
      { id: "video-a", status: "completed", url: "https://a.test/a.mp4" },
      {
        generation_id: "video-b",
        status: "processing",
        progress: 40,
      },
    ],
  });

  assertEquals(result.batchGenerationId, "batch-123");
  assertEquals(result.batchSize, 2);
  assertEquals(result.generationIds, ["video-a", "video-b"]);
  assertEquals(result.variants.length, 2);
  assertEquals(result.variants[0].videoUrl, "https://a.test/a.mp4");
  assertEquals(result.variants[1].progress, 40);
});

Deno.test("parseHedraGenerationIds de-duplicates and caps poll IDs", () => {
  assertEquals(
    parseHedraGenerationIds([
      "a",
      "a",
      "b",
      "c",
      "d",
      "e",
      "f",
      "g",
      "h",
      "i",
    ]),
    ["a", "b", "c", "d", "e", "f", "g", "h"],
  );
});

Deno.test("generation_ids alone create one pollable variant per id", () => {
  const result = normalizeHedraBatchResponse({
    batch_generation_id: "batch-only-ids",
    generation_ids: ["video-a", "video-b", "video-c"],
  });

  assertEquals(result.batchSize, 3);
  assertEquals(
    result.variants.map((variant) => variant.id),
    ["video-a", "video-b", "video-c"],
  );
});
