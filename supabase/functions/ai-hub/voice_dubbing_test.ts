import {
  assertEquals,
  assertThrows,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  concatenateAudio,
  normalizeVoiceLanguage,
  normalizeVoiceSettings,
  resolveVoiceDubbingModel,
  safeAudioFileName,
  splitVoiceText,
  voiceCharacterLimit,
} from "./voice_dubbing.ts";

Deno.test("eleven_v3 exposes the 70+ language acceptance surface", () => {
  const model = resolveVoiceDubbingModel("eleven_v3");
  assertEquals(model.languages.size >= 70, true);
  assertEquals(normalizeVoiceLanguage("ja", model), "ja");
  assertThrows(() => normalizeVoiceLanguage("xx", model), Error);
});

Deno.test("long text splits at natural boundaries without losing content", () => {
  const text = `${"a".repeat(80)}。${"b".repeat(80)}。${"c".repeat(80)}`;
  const chunks = splitVoiceText(text, 120);
  assertEquals(chunks.length, 3);
  assertEquals(chunks.every((chunk) => chunk.length <= 120), true);
  assertEquals(chunks.join(""), text);
});

Deno.test("voice settings are clamped to provider ranges", () => {
  assertEquals(
    normalizeVoiceSettings({
      stability: -1,
      similarity_boost: 2,
      style: 0.4,
      speed: 8,
      use_speaker_boost: false,
    }),
    {
      stability: 0,
      similarity_boost: 1,
      style: 0.4,
      speed: 1.2,
      use_speaker_boost: false,
    },
  );
});

Deno.test("audio chunks concatenate in request order", () => {
  assertEquals(
    [...concatenateAudio([new Uint8Array([1, 2]), new Uint8Array([3])])],
    [1, 2, 3],
  );
});

Deno.test("quota tiers and download names are deterministic", () => {
  assertEquals(voiceCharacterLimit("free"), 5_000);
  assertEquals(voiceCharacterLimit("pro"), 100_000);
  assertEquals(voiceCharacterLimit("unexpected"), 5_000);
  assertEquals(
    safeAudioFileName("  日本語 article / 01  "),
    "日本語-article-01.mp3",
  );
});
