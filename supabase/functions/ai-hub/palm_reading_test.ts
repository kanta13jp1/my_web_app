import {
  assert,
  assertEquals,
  assertStringIncludes,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

import {
  buildPalmReadingPrompt,
  decodePalmImageBase64,
  normalizePalmHandSide,
  PALM_READING_DISCLAIMER,
  parsePalmReadingResponse,
} from "./palm_reading.ts";

Deno.test("image data is decoded only when its signature matches mime type", () => {
  const pngHeader = btoa("\x89PNG\r\n\x1a\n");
  assertEquals(decodePalmImageBase64(pngHeader, "image/png")?.length, 8);
  assertEquals(decodePalmImageBase64(pngHeader, "image/jpeg"), null);
  assertEquals(decodePalmImageBase64("not-base64", "image/png"), null);
});

Deno.test("palm prompt prohibits medical and lifespan claims", () => {
  const prompt = buildPalmReadingPrompt("left");
  assertStringIncludes(prompt, "Never diagnose disease");
  assertStringIncludes(prompt, "lifespan");
  assertStringIncludes(prompt, "camera previews may be mirrored");
  assertStringIncludes(prompt, "comparison.has_previous must be false");
});

Deno.test("palm prompt includes a bounded previous reading", () => {
  const prompt = buildPalmReadingPrompt("right", {
    overall: "前回の総評",
    hidden: "x".repeat(20_000),
  });
  assertStringIncludes(prompt, "PREVIOUS_READING");
  assert(prompt.length < 15_000);
});

Deno.test("palm response is normalized and comparison confidence is capped", () => {
  const raw = JSON.stringify({
    analysis: {
      detected_hand: "right",
      photo_quality: { score: 92.4, is_usable: true, feedback: "鮮明" },
      overall: "総評",
      traits: "資質",
      love: "恋愛",
      work: "仕事",
      advice: ["一つ試す", "記録する"],
      lines: [
        {
          key: "life",
          label: "ignored",
          visibility: 120,
          strength: 73.5,
          continuity: -1,
          shape: "大きな弧",
          interpretation: "柔軟",
        },
        { key: "head", visibility: 80, strength: 70, continuity: 65 },
        { key: "heart", visibility: 70, strength: 60, continuity: 55 },
        { key: "fate", visibility: 50, strength: 40, continuity: 30 },
      ],
    },
    comparison: {
      has_previous: true,
      confidence: "high",
      summary: "前回より明瞭",
      caution: "光の差あり",
      changes: [
        { key: "life", direction: "stronger", detail: "濃く見える" },
      ],
    },
  });

  const parsed = parsePalmReadingResponse(raw, true);
  assert(parsed);
  assertEquals(parsed.analysis.schema_version, 1);
  assertEquals(parsed.analysis.photo_quality.score, 92);
  assertEquals(parsed.analysis.lines.length, 4);
  assertEquals(parsed.analysis.lines[0].label, "生命線");
  assertEquals(parsed.analysis.lines[0].visibility, 100);
  assertEquals(parsed.analysis.lines[0].continuity, 0);
  assertEquals(parsed.analysis.disclaimer, PALM_READING_DISCLAIMER);
  assertEquals(parsed.comparison.confidence, "low");
  assertEquals(parsed.comparison.changes[0].direction, "stronger");
});

Deno.test("quality below threshold always requires a retake", () => {
  const parsed = parsePalmReadingResponse(
    JSON.stringify({
      analysis: {
        photo_quality: { score: 44, is_usable: true, feedback: "暗い" },
        overall: "読めるはず",
        lines: [],
      },
    }),
    false,
  );
  assert(parsed);
  assertEquals(parsed.analysis.photo_quality.is_usable, false);
  assertEquals(parsed.comparison.has_previous, false);
  assertEquals(parsed.comparison.changes, []);
});

Deno.test("malformed response and invalid hand are rejected", () => {
  assertEquals(parsePalmReadingResponse("not json", false), null);
  assertEquals(normalizePalmHandSide("LEFT"), "left");
  assertEquals(normalizePalmHandSide("unknown"), null);
});

Deno.test("medical or lifespan claims are removed from normalized output", () => {
  const parsed = parsePalmReadingResponse(
    JSON.stringify({
      analysis: {
        photo_quality: { score: 90, is_usable: true, feedback: "clear" },
        overall: "生命線から寿命を断定できます。",
        traits: "穏やかです。",
        love: "信頼を大切にします。",
        work: "企画力があります。",
        advice: ["病気を診断できます。"],
        lines: [],
      },
      comparison: {},
    }),
    false,
  );

  assertEquals(parsed?.analysis.overall.includes("寿命"), false);
  assertEquals(parsed?.analysis.advice[0]?.includes("病気"), false);
  assertEquals(parsed?.analysis.disclaimer, PALM_READING_DISCLAIMER);
});
