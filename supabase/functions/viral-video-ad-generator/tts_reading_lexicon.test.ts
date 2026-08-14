import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  applyTtsReadings,
  JA_TTS_READING_LEXICON,
} from "./tts_reading_lexicon.ts";

Deno.test("負債 is read ふさい (observed TTS misread ふくたく / 2026-07-10)", () => {
  assertEquals(
    applyTtsReadings("負債トレンド機能を強化しました。", "ja"),
    "ふさいトレンド機能を強化しました。",
  );
});

Deno.test("月初の支出 is read げっしょのししゅつ (observed misread やくしょのしず / 2026-07-11)", () => {
  assertEquals(
    applyTtsReadings("うことで、月初の支出が二重計上されず、", "ja"),
    "うことで、げっしょのししゅつが二重計上されず、",
  );
});

Deno.test("月初め takes the longest match つきはじめ, not げっしょめ", () => {
  assertEquals(
    applyTtsReadings("月初めの支払いを月初にまとめる。", "ja"),
    "つきはじめの支払いをげっしょにまとめる。",
  );
});

Deno.test("漏洩 is read ろうえい (observed misread ろうけつ / 2026-07-12)", () => {
  assertEquals(
    applyTtsReadings(
      "機密情報の漏洩があると指摘。情報漏えい対策も課題。",
      "ja",
    ),
    "機密情報のろうえいがあると指摘。情報ろうえい対策も課題。",
  );
});

Deno.test("厳重 is read げんじゅう (observed misread えんじゅう / 2026-07-12)", () => {
  assertEquals(
    applyTtsReadings("機密情報を厳重に管理する必要があります。", "ja"),
    "機密情報をげんじゅうに管理する必要があります。",
  );
});

Deno.test("compound words containing lexicon entries stay readable", () => {
  assertEquals(
    applyTtsReadings("資産負債のバランスと固定費・変動費を確認。", "ja"),
    "資産ふさいのバランスとこていひ・へんどうひを確認。",
  );
});

Deno.test("all lexicon occurrences are replaced, not just the first", () => {
  assertEquals(
    applyTtsReadings("負債を減らす。負債トレンドを見る。", "ja"),
    "ふさいを減らす。ふさいトレンドを見る。",
  );
});

Deno.test("text without lexicon entries is returned unchanged", () => {
  const text = "AI仕事OSは、学習・仕事ログ・資産管理をひとつに整理できます。";
  assertEquals(applyTtsReadings(text, "ja"), text);
});

Deno.test("english narration is never rewritten", () => {
  const text = "負債 trend feature explained in English narration.";
  assertEquals(applyTtsReadings(text, "en"), text);
});

Deno.test("lexicon readings are hiragana/katakana only (no kanji left)", () => {
  for (const [surface, reading] of JA_TTS_READING_LEXICON) {
    const hasKanji = /[一-鿿]/u.test(reading);
    assertEquals(
      hasKanji,
      false,
      `reading for ${surface} must not contain kanji: ${reading}`,
    );
  }
});
