export type HedraTextToSpeechAudioGeneration = {
  type: "text_to_speech";
  voice_id: string;
  text: string;
  stability: number;
  speed: number;
  language: string;
  model_id?: string;
};

export function extractHedraTextToSpeechModelId(
  payload: unknown,
): string | null {
  const models = Array.isArray(payload)
    ? payload
    : Array.isArray(asRecord(payload)?.["data"])
    ? asRecord(payload)?.["data"] as unknown[]
    : [];
  const candidates = models
    .map((model) => asRecord(model))
    .filter((model): model is Record<string, unknown> => model != null)
    .filter((model) => isUuid(firstNonEmptyString(model["id"])))
    .map((model) => {
      const type = String(model["type"] ?? "").toLowerCase();
      const name = String(model["name"] ?? "").toLowerCase();
      const description = String(model["description"] ?? "").toLowerCase();
      const haystack = `${type} ${name} ${description}`;
      const premium = model["premium"] === true ? 1 : 0;
      let score = 0;
      if (type === "text_to_speech") score += 100;
      if (type.includes("text_to_speech")) score += 80;
      if (haystack.includes("text to speech")) score += 60;
      if (haystack.includes("tts")) score += 50;
      if (type.includes("audio") && haystack.includes("speech")) score += 30;
      if (haystack.includes("voice")) score += 10;
      return {
        id: firstNonEmptyString(model["id"]),
        score,
        premium,
      };
    })
    .filter((model) => model.id != null && model.score > 0)
    .sort((a, b) => b.score - a.score || a.premium - b.premium);
  return candidates[0]?.id ?? null;
}

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
