import {
  assert,
  assertEquals,
  assertFalse,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  buildHedraTextToSpeechAudioGeneration,
  isHedraInvalidTextToSpeechModelError,
  resolveConfiguredHedraTextToSpeechModelId,
  stripHedraTextToSpeechModelId,
} from "./hedra_tts.ts";

Deno.test("Hedra TTS generation omits model_id when no override is configured", () => {
  const audioGeneration = buildHedraTextToSpeechAudioGeneration({
    voiceId: "voice-1",
    modelId: null,
    text: "Hello",
    language: "english",
  });

  assertEquals(audioGeneration.type, "text_to_speech");
  assertEquals(audioGeneration.voice_id, "voice-1");
  assertFalse("model_id" in audioGeneration);
});

Deno.test("Hedra TTS generation includes valid configured model_id", () => {
  const modelId = "d11481da-b973-4e72-ade0-7e8a86915bbf";
  const audioGeneration = buildHedraTextToSpeechAudioGeneration({
    voiceId: "voice-1",
    modelId,
    text: "Hello",
    language: "english",
  });

  assertEquals(audioGeneration.model_id, modelId);
});

Deno.test("Hedra TTS configured model_id accepts only UUID values", () => {
  assertEquals(
    resolveConfiguredHedraTextToSpeechModelId(
      "d11481da-b973-4e72-ade0-7e8a86915bbf",
    ),
    "d11481da-b973-4e72-ade0-7e8a86915bbf",
  );
  assertEquals(resolveConfiguredHedraTextToSpeechModelId("not-a-uuid"), null);
  assertEquals(resolveConfiguredHedraTextToSpeechModelId("   "), null);
});

Deno.test("Hedra TTS retry payload strips invalid model_id only from text_to_speech audio", () => {
  const body = {
    type: "video",
    audio_generation: {
      type: "text_to_speech",
      voice_id: "voice-1",
      model_id: "d11481da-b973-4e72-ade0-7e8a86915bbf",
      text: "Hello",
    },
  };

  const stripped = stripHedraTextToSpeechModelId(body);
  assertEquals(stripped["type"], "video");
  const strippedAudio = stripped["audio_generation"] as Record<string, unknown>;
  assertEquals(strippedAudio["voice_id"], "voice-1");
  assertFalse("model_id" in strippedAudio);
});

Deno.test("Hedra invalid text_to_speech model errors are recognized", () => {
  assert(
    isHedraInvalidTextToSpeechModelError(
      new Error(
        'Hedra API 400: {"messages":["model d11481da-b973-4e72-ade0-7e8a86915bbf not valid for generation type text_to_speech"]}',
      ),
    ),
  );
});
