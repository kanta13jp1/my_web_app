export const VOICE_DUBBING_BUCKET = "voice-dubbing";

export const VOICE_DUBBING_MONTHLY_LIMITS: Record<string, number> = {
  free: 5_000,
  pro: 100_000,
  team: 300_000,
};

const V3_LANGUAGES = new Set([
  "af",
  "ar",
  "hy",
  "as",
  "az",
  "be",
  "bn",
  "bs",
  "bg",
  "ca",
  "ceb",
  "ny",
  "zh",
  "hr",
  "cs",
  "da",
  "nl",
  "en",
  "et",
  "fil",
  "fi",
  "fr",
  "gl",
  "ka",
  "de",
  "el",
  "gu",
  "ha",
  "he",
  "hi",
  "hu",
  "is",
  "id",
  "ga",
  "it",
  "ja",
  "jv",
  "kn",
  "kk",
  "ky",
  "ko",
  "lv",
  "ln",
  "lt",
  "lb",
  "mk",
  "ms",
  "ml",
  "mr",
  "ne",
  "no",
  "ps",
  "fa",
  "pl",
  "pt",
  "pa",
  "ro",
  "ru",
  "sr",
  "sd",
  "sk",
  "sl",
  "so",
  "es",
  "sw",
  "sv",
  "ta",
  "te",
  "th",
  "tr",
  "uk",
  "ur",
  "vi",
  "cy",
]);

const MULTILINGUAL_V2_LANGUAGES = new Set([
  "ar",
  "bg",
  "zh",
  "hr",
  "cs",
  "da",
  "nl",
  "en",
  "fil",
  "fi",
  "fr",
  "de",
  "el",
  "hi",
  "id",
  "it",
  "ja",
  "ko",
  "ms",
  "pl",
  "pt",
  "ro",
  "ru",
  "sk",
  "es",
  "sv",
  "ta",
  "tr",
  "uk",
]);

const FLASH_V2_5_LANGUAGES = new Set([
  ...MULTILINGUAL_V2_LANGUAGES,
  "hu",
  "no",
  "vi",
]);

export type VoiceDubbingModelSpec = {
  id: string;
  chunkLimit: number;
  totalLimit: number;
  languages: ReadonlySet<string>;
  requestStitching: boolean;
};

export const VOICE_DUBBING_MODELS: Record<string, VoiceDubbingModelSpec> = {
  eleven_v3: {
    id: "eleven_v3",
    chunkLimit: 4_500,
    totalLimit: 15_000,
    languages: V3_LANGUAGES,
    requestStitching: false,
  },
  eleven_multilingual_v2: {
    id: "eleven_multilingual_v2",
    chunkLimit: 9_000,
    totalLimit: 30_000,
    languages: MULTILINGUAL_V2_LANGUAGES,
    requestStitching: true,
  },
  eleven_flash_v2_5: {
    id: "eleven_flash_v2_5",
    chunkLimit: 38_000,
    totalLimit: 40_000,
    languages: FLASH_V2_5_LANGUAGES,
    requestStitching: true,
  },
};

export type VoiceSettings = {
  stability: number;
  similarity_boost: number;
  style: number;
  speed: number;
  use_speaker_boost: boolean;
};

export function resolveVoiceDubbingModel(
  value: unknown,
): VoiceDubbingModelSpec {
  const id = typeof value === "string" ? value.trim() : "";
  const model = VOICE_DUBBING_MODELS[id || "eleven_v3"];
  if (!model) throw new Error("unsupported_model");
  return model;
}

export function normalizeVoiceLanguage(
  value: unknown,
  model: VoiceDubbingModelSpec,
): string {
  const language = typeof value === "string" ? value.trim().toLowerCase() : "";
  if (!model.languages.has(language)) throw new Error("unsupported_language");
  return language;
}

export function normalizeVoiceId(value: unknown): string {
  const voiceId = typeof value === "string" ? value.trim() : "";
  if (!/^[A-Za-z0-9_-]{8,80}$/.test(voiceId)) {
    throw new Error("invalid_voice_id");
  }
  return voiceId;
}

function clampNumber(
  value: unknown,
  fallback: number,
  min: number,
  max: number,
) {
  const parsed = typeof value === "number" ? value : Number(value);
  if (!Number.isFinite(parsed)) return fallback;
  return Math.min(max, Math.max(min, parsed));
}

export function normalizeVoiceSettings(value: unknown): VoiceSettings {
  const raw = typeof value === "object" && value !== null
    ? value as Record<string, unknown>
    : {};
  return {
    stability: clampNumber(raw.stability, 0.5, 0, 1),
    similarity_boost: clampNumber(raw.similarity_boost, 0.75, 0, 1),
    style: clampNumber(raw.style, 0, 0, 1),
    speed: clampNumber(raw.speed, 1, 0.7, 1.2),
    use_speaker_boost: raw.use_speaker_boost !== false,
  };
}

function preferredBreakIndex(text: string, maxChars: number): number {
  const minBreak = Math.floor(maxChars * 0.55);
  const window = text.slice(0, maxChars + 1);
  const candidates = ["\n\n", "\n", "。", "！", "？", ". ", "! ", "? ", " "];
  for (const delimiter of candidates) {
    const index = window.lastIndexOf(delimiter);
    if (index >= minBreak) return index + delimiter.length;
  }
  return maxChars;
}

export function splitVoiceText(text: string, maxChars: number): string[] {
  if (!Number.isInteger(maxChars) || maxChars < 100) {
    throw new Error("invalid_chunk_limit");
  }
  let remaining = text.replace(/\r\n/g, "\n").trim();
  const chunks: string[] = [];
  while (remaining.length > maxChars) {
    const breakIndex = preferredBreakIndex(remaining, maxChars);
    const chunk = remaining.slice(0, breakIndex).trim();
    if (chunk) chunks.push(chunk);
    remaining = remaining.slice(breakIndex).trimStart();
  }
  if (remaining) chunks.push(remaining);
  return chunks;
}

export function concatenateAudio(chunks: Uint8Array[]): Uint8Array {
  const length = chunks.reduce((total, chunk) => total + chunk.byteLength, 0);
  const combined = new Uint8Array(length);
  let offset = 0;
  for (const chunk of chunks) {
    combined.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return combined;
}

export function voiceCharacterLimit(tier: unknown): number {
  const normalized = typeof tier === "string" ? tier.toLowerCase() : "free";
  return VOICE_DUBBING_MONTHLY_LIMITS[normalized] ??
    VOICE_DUBBING_MONTHLY_LIMITS.free;
}

export function safeAudioFileName(value: unknown): string {
  const raw = typeof value === "string"
    ? value.trim().replace(/\.mp3$/i, "")
    : "";
  const safe = raw
    .normalize("NFKC")
    .replace(/[^\p{L}\p{N}._-]+/gu, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 60);
  return `${safe || "multilingual-dubbing"}.mp3`;
}
