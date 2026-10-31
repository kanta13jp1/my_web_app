import {
  assert,
  assertEquals,
  assertFalse,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  buildHedraTextToSpeechAudioGeneration,
  buildHedraUploadedAudioGeneration,
  isHedraInvalidTextToSpeechModelError,
  isHedraMissingTextToSpeechModelError,
  isHedraUploadedAudioUnsupportedError,
  resolveConfiguredHedraTextToSpeechModelId,
  selectBestHedraTextToSpeechModelId,
  selectBestHedraVoiceId,
  stripHedraTextToSpeechModelId,
  withHedraTextToSpeechModelId,
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

Deno.test("Hedra TTS generation keeps custom voice settings", () => {
  const audioGeneration = buildHedraTextToSpeechAudioGeneration({
    voiceId: "voice-1",
    modelId: "d11481da-b973-4e72-ade0-7e8a86915bbf",
    text: "Custom narration",
    language: "English",
    stability: 0.7,
    speed: 1.1,
  });

  assertEquals(audioGeneration.stability, 0.7);
  assertEquals(audioGeneration.speed, 1.1);
});

Deno.test("Hedra uploaded audio generation uses a public audio URL", () => {
  const audioGeneration = buildHedraUploadedAudioGeneration(
    "https://example.com/voice.mp3",
  );

  assertEquals(audioGeneration, {
    type: "audio",
    url: "https://example.com/voice.mp3",
  });
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

Deno.test("Hedra TTS retry payload leaves non-TTS audio untouched", () => {
  const body = {
    type: "video",
    audio_generation: {
      type: "audio",
      model_id: "d11481da-b973-4e72-ade0-7e8a86915bbf",
      url: "https://example.com/audio.mp3",
    },
  };

  assertEquals(stripHedraTextToSpeechModelId(body), body);
});

Deno.test("Hedra invalid text_to_speech model errors are recognized", () => {
  assert(
    isHedraInvalidTextToSpeechModelError(
      new Error(
        'Hedra API 400: {"messages":["model d11481da-b973-4e72-ade0-7e8a86915bbf not valid for generation type text_to_speech"]}',
      ),
    ),
  );
  assert(
    isHedraInvalidTextToSpeechModelError(
      new Error(
        'Hedra API 400: {"code":400,"messages":["model missing not valid for generation type text_to_speech"]}',
      ),
    ),
  );
});

Deno.test("Hedra uploaded audio unsupported errors are recognized", () => {
  assert(
    isHedraUploadedAudioUnsupportedError(
      new Error(
        'Hedra API 422: {"messages":["Input should be \'text_to_speech\' (type=literal_error at body.video.audio_generation.type)","Field required (type=missing at body.video.audio_generation.voice_id)","Field required (type=missing at body.video.audio_generation.text)"]}',
      ),
    ),
  );
});

Deno.test("Hedra missing text_to_speech model errors are recognized", () => {
  assert(
    isHedraMissingTextToSpeechModelError(
      new Error(
        'Hedra API 400: {"code":400,"messages":["model missing not valid for generation type text_to_speech"]}',
      ),
    ),
  );
});

Deno.test("Hedra TTS model selection prefers text-to-speech models", () => {
  const modelId = selectBestHedraTextToSpeechModelId([
    {
      id: "avatar-model",
      name: "Character video model",
      generation_type: "video",
    },
    {
      id: "tts-model",
      name: "Japanese text_to_speech voice model",
      generation_type: "text_to_speech",
    },
  ]);

  assertEquals(modelId, "tts-model");
});

Deno.test("Hedra TTS model id can be injected into generation payload", () => {
  const body = {
    type: "video",
    audio_generation: {
      type: "text_to_speech",
      voice_id: "voice-1",
      text: "Hello",
    },
  };

  const updated = withHedraTextToSpeechModelId(body, "tts-model");
  const audioGeneration = updated["audio_generation"] as Record<
    string,
    unknown
  >;
  assertEquals(audioGeneration["model_id"], "tts-model");
});

Deno.test("Hedra voice selection prefers Japanese female professional voices", () => {
  const voiceId = selectBestHedraVoiceId([
    {
      id: "male-ja",
      name: "Japanese male narrator",
      description: "Japanese clear voice",
    },
    {
      id: "female-ja",
      name: "Japanese female executive assistant",
      description: "Warm professional secretary voice",
    },
    {
      id: "female-en",
      name: "English female presenter",
      description: "Warm voice",
    },
  ], { lang: "ja", preferredVoice: null });

  assertEquals(voiceId, "female-ja");
});

Deno.test("Hedra voice selection follows an explicit male narrator setting", () => {
  const voiceId = selectBestHedraVoiceId([
    { id: "female-ja", name: "Japanese female narrator" },
    { id: "male-ja", name: "Japanese male narrator" },
  ], { lang: "ja", preferredVoice: "male_narrator" });

  assertEquals(voiceId, "male-ja");
});
