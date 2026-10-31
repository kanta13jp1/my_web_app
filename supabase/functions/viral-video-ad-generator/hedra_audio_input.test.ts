import {
  assertEquals,
  assertThrows,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  parseHedraAudioInput,
  withExclusiveHedraAudio,
} from "./hedra_audio_input.ts";

Deno.test("audio input defaults to backward-compatible automatic mode", () => {
  assertEquals(parseHedraAudioInput(undefined), { mode: "automatic" });
});

Deno.test("TTS input trims text and validates Hedra settings", () => {
  assertEquals(
    parseHedraAudioInput({
      mode: "tts",
      text: " こんにちは ",
      voice: "female_narrator",
      stability: 0.65,
      speed: 1.1,
    }),
    {
      mode: "tts",
      text: "こんにちは",
      voice: "female_narrator",
      stability: 0.65,
      speed: 1.1,
    },
  );
  assertThrows(() =>
    parseHedraAudioInput({
      mode: "tts",
      text: "hello",
      voice: "unknown",
      stability: 0.5,
      speed: 1,
    })
  );
  assertThrows(() =>
    parseHedraAudioInput({
      mode: "tts",
      text: "hello",
      voice: "male_narrator",
      stability: 1.1,
      speed: 1,
    })
  );
});

Deno.test("file input decodes and verifies its signature", () => {
  const mp3 = Uint8Array.from([
    0x49,
    0x44,
    0x33,
    0x04,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
  ]);
  const parsed = parseHedraAudioInput({
    mode: "file",
    fileName: "voice.mp3",
    mimeType: "audio/mpeg",
    dataBase64: uint8ToBase64(mp3),
  });
  assertEquals(parsed.mode, "file");
  if (parsed.mode === "file") assertEquals(parsed.bytes, mp3);

  assertThrows(() =>
    parseHedraAudioInput({
      mode: "file",
      fileName: "voice.mp3",
      mimeType: "audio/mpeg",
      dataBase64: uint8ToBase64(Uint8Array.from([1, 2, 3, 4])),
    })
  );
});

Deno.test("Hedra generation body contains exactly one audio input", () => {
  assertEquals(
    withExclusiveHedraAudio({ type: "video" }, {
      audioId: "asset-123",
    }),
    { type: "video", audio_id: "asset-123" },
  );
  assertEquals(
    withExclusiveHedraAudio({ type: "video", audio_id: "old" }, {
      audioGeneration: { type: "text_to_speech", text: "hello" },
    }),
    {
      type: "video",
      audio_generation: { type: "text_to_speech", text: "hello" },
    },
  );
  assertThrows(() =>
    withExclusiveHedraAudio({ type: "video" }, {
      audioId: "",
    })
  );
});

function uint8ToBase64(bytes: Uint8Array): string {
  return btoa(String.fromCharCode(...bytes));
}
