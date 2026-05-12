export type HedraTextToSpeechAudioGeneration = {
  type: "text_to_speech";
  voice_id: string;
  text: string;
  stability: number;
  speed: number;
  language: string;
  model_id?: string;
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
}): HedraTextToSpeechAudioGeneration {
  const audioGeneration: HedraTextToSpeechAudioGeneration = {
    type: "text_to_speech",
    voice_id: params.voiceId,
    text: params.text,
    stability: 0.5,
    speed: 1.0,
    language: params.language,
  };
  if (params.modelId) {
    audioGeneration.model_id = params.modelId;
  }
  return audioGeneration;
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
