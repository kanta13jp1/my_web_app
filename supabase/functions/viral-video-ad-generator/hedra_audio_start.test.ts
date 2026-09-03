import {
  assertEquals,
  assertThrows,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

import {
  HEDRA_AUDIO_START_MAX_MS,
  HEDRA_AUDIO_START_MIN_MS,
  parseHedraAudioStartMs,
  withHedraAudioStartMs,
} from "./hedra_audio_start.ts";

Deno.test("defaults the Hedra audio start offset to zero", () => {
  assertEquals(parseHedraAudioStartMs(undefined), 0);
  assertEquals(parseHedraAudioStartMs(null), 0);
});

Deno.test("accepts silence and crop offsets inside the app safety range", () => {
  assertEquals(parseHedraAudioStartMs(-1000), -1000);
  assertEquals(parseHedraAudioStartMs(2000), 2000);
  assertEquals(parseHedraAudioStartMs(HEDRA_AUDIO_START_MIN_MS), -30_000);
  assertEquals(parseHedraAudioStartMs(HEDRA_AUDIO_START_MAX_MS), 30_000);
});

Deno.test("rejects fractions, strings, and offsets outside the safety range", () => {
  assertThrows(() => parseHedraAudioStartMs(1.5), Error, "integer");
  assertThrows(() => parseHedraAudioStartMs("1000"), Error, "integer");
  assertThrows(() => parseHedraAudioStartMs(-30_001), Error, "between");
  assertThrows(() => parseHedraAudioStartMs(30_001), Error, "between");
});

Deno.test("adds the documented Hedra snake-case parameter", () => {
  assertEquals(withHedraAudioStartMs({ type: "video" }, -1000), {
    type: "video",
    audio_start_ms: -1000,
  });
});
