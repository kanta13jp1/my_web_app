export type HedraTextToSpeechAudioGeneration = {
  type: "text_to_speech";
  voice_id: string;
  text: string;
  stability: number;
  speed: number;
  language: string;
  model_id?: string;
};

export type HedraUploadedAudioGeneration = {
  type: "audio";
  url: string;
};

export type HedraAudioGeneration =
  | HedraTextToSpeechAudioGeneration
  | HedraUploadedAudioGeneration;

export type HedraVoiceSelectionOptions = {
  lang: "ja" | "en";
  preferredVoice?: string | null;
};

export function resolveConfiguredHedraTextToSpeechModelId(
  configuredValue: string | null | undefined,
): string | null {
  const configured = firstNonEmptyString(configuredValue);
  if (!configured) return null;
  return isUuid(configured) ? configured : null;
}

export function buildHedraTextToSpeechAudioGeneration(params: {
  voiceId: string;
  modelId?: string | null;
  text: string;
  language: string;
  stability?: number;
  speed?: number;
}): HedraTextToSpeechAudioGeneration {
  const audioGeneration: HedraTextToSpeechAudioGeneration = {
    type: "text_to_speech",
    voice_id: params.voiceId,
    text: params.text,
    stability: params.stability ?? 0.5,
    speed: params.speed ?? 1.0,
    language: params.language,
  };
  if (params.modelId) {
    audioGeneration.model_id = params.modelId;
  }
  return audioGeneration;
}

export function buildHedraUploadedAudioGeneration(
  url: string,
): HedraUploadedAudioGeneration {
  return { type: "audio", url };
}

export function stripHedraTextToSpeechModelId(
  body: Record<string, unknown>,
): Record<string, unknown> {
  const audioGeneration = asRecord(body["audio_generation"]);
  if (
    audioGeneration == null ||
    audioGeneration["type"] !== "text_to_speech" ||
    audioGeneration["model_id"] == null
  ) {
    return body;
  }

  const strippedAudioGeneration = { ...audioGeneration };
  delete strippedAudioGeneration["model_id"];
  return { ...body, audio_generation: strippedAudioGeneration };
}

export function isHedraInvalidTextToSpeechModelError(error: unknown): boolean {
  const message = error instanceof Error ? error.message : String(error);
  const normalized = message.toLowerCase();
  return normalized.includes("not valid for generation type text_to_speech") ||
    (normalized.includes("model") &&
      normalized.includes("not valid") &&
      normalized.includes("text_to_speech"));
}

export function isHedraMissingTextToSpeechModelError(error: unknown): boolean {
  const message = error instanceof Error ? error.message : String(error);
  const normalized = message.toLowerCase();
  return normalized.includes("model missing") &&
    normalized.includes("text_to_speech");
}

export function isHedraUploadedAudioUnsupportedError(error: unknown): boolean {
  const message = error instanceof Error ? error.message : String(error);
  const normalized = message.toLowerCase();
  return normalized.includes("input should be 'text_to_speech'") ||
    (normalized.includes("audio_generation.type") &&
      normalized.includes("text_to_speech")) ||
    (normalized.includes("field required") &&
      normalized.includes("audio_generation.voice_id") &&
      normalized.includes("audio_generation.text"));
}

export function selectBestHedraVoiceId(
  voices: unknown[],
  options: HedraVoiceSelectionOptions,
): string | null {
  const scored = voices
    .map((voice, index) => {
      const record = asRecord(voice);
      const id = firstNonEmptyString(
        record?.["id"],
        record?.["voice_id"],
        record?.["uuid"],
      );
      if (!record || !id) return null;
      return {
        id,
        index,
        score: scoreHedraVoice(record, options),
      };
    })
    .filter((voice): voice is { id: string; index: number; score: number } =>
      voice != null
    )
    .sort((a, b) => b.score - a.score || a.index - b.index);

  return scored[0]?.id ?? null;
}

export function selectBestHedraTextToSpeechModelId(
  models: unknown[],
): string | null {
  const scored = models
    .map((model, index) => {
      const record = asRecord(model);
      const id = firstNonEmptyString(
        record?.["id"],
        record?.["model_id"],
        record?.["uuid"],
      );
      if (!record || !id) return null;
      return {
        id,
        index,
        score: scoreHedraTextToSpeechModel(record),
      };
    })
    .filter((model): model is { id: string; index: number; score: number } =>
      model != null
    )
    .sort((a, b) => b.score - a.score || a.index - b.index);

  const best = scored[0];
  return best != null && best.score > 0 ? best.id : null;
}

export function withHedraTextToSpeechModelId(
  body: Record<string, unknown>,
  modelId: string,
): Record<string, unknown> {
  const audioGeneration = asRecord(body["audio_generation"]);
  if (
    audioGeneration == null ||
    audioGeneration["type"] !== "text_to_speech"
  ) {
    return body;
  }
  return {
    ...body,
    audio_generation: {
      ...audioGeneration,
      model_id: modelId,
    },
  };
}

export function scoreHedraVoice(
  voice: Record<string, unknown>,
  options: HedraVoiceSelectionOptions,
): number {
  const preferred = firstNonEmptyString(options.preferredVoice);
  const id = firstNonEmptyString(voice["id"], voice["voice_id"], voice["uuid"]);
  const haystack = flattenVoiceText(voice).toLowerCase();
  let score = 0;
  const normalizedPreferred = preferred?.toLowerCase() ?? "";
  const prefersFemale = normalizedPreferred.includes("female");
  const prefersMale = !prefersFemale && normalizedPreferred.includes("male");

  if (preferred) {
    if (id?.toLowerCase() === normalizedPreferred) score += 100;
    if (haystack.includes(normalizedPreferred)) score += 40;
  }

  const languageMarkers = options.lang === "ja"
    ? ["japanese", "japan", "ja", "日本", "日本語"]
    : ["english", "en"];
  if (languageMarkers.some((marker) => haystack.includes(marker))) {
    score += 30;
  }

  if (
    ["female", "feminine", "woman", "women", "lady", "女性", "女声", "女"]
      .some((marker) => haystack.includes(marker))
  ) {
    score += prefersMale ? -100 : 80;
  }
  if (
    ["male", "masculine", "man", "men", "男性", "男声", "男"].some((marker) =>
      haystack.includes(marker)
    )
  ) {
    score += prefersMale ? 80 : -100;
  }
  if (
    ["secretary", "assistant", "concierge", "executive", "professional", "秘書"]
      .some((marker) => haystack.includes(marker))
  ) {
    score += 18;
  }
  if (
    ["warm", "calm", "clear", "business", "polished", "上品", "落ち着"]
      .some((marker) => haystack.includes(marker))
  ) {
    score += 8;
  }
  if (
    ["child", "kid", "boy", "girl", "子供", "少年", "少女"].some((marker) =>
      haystack.includes(marker)
    )
  ) {
    score -= 35;
  }

  return score;
}

function scoreHedraTextToSpeechModel(model: Record<string, unknown>): number {
  const haystack = flattenVoiceText(model).toLowerCase();
  let score = 0;

  if (haystack.includes("text_to_speech")) score += 120;
  if (haystack.includes("text to speech")) score += 100;
  if (haystack.includes("text-to-speech")) score += 100;
  if (haystack.includes("tts")) score += 80;
  if (haystack.includes("speech")) score += 50;
  if (haystack.includes("audio")) score += 20;
  if (haystack.includes("voice")) score += 20;

  if (haystack.includes("video")) score -= 45;
  if (haystack.includes("avatar")) score -= 45;
  if (haystack.includes("image")) score -= 45;
  if (haystack.includes("character")) score -= 25;

  return score;
}

function isUuid(value: string | null): boolean {
  return value != null &&
    /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
      .test(value);
}

function asRecord(value: unknown): Record<string, unknown> | null {
  return typeof value === "object" && value !== null
    ? value as Record<string, unknown>
    : null;
}

function firstNonEmptyString(...values: unknown[]): string | null {
  for (const value of values) {
    if (typeof value === "string" && value.trim().length > 0) {
      return value.trim();
    }
  }
  return null;
}

function flattenVoiceText(value: unknown): string {
  if (value == null) return "";
  if (typeof value === "string" || typeof value === "number") {
    return String(value);
  }
  if (Array.isArray(value)) {
    return value.map(flattenVoiceText).join(" ");
  }
  if (typeof value === "object") {
    return Object.values(value as Record<string, unknown>)
      .map(flattenVoiceText)
      .join(" ");
  }
  return "";
}
