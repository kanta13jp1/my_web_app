export const HEDRA_TTS_MAX_CHARACTERS = 450;
export const HEDRA_AUDIO_FILE_MAX_BYTES = 4 * 1024 * 1024;

const HEDRA_VOICES = new Set([
  "female_narrator",
  "male_narrator",
]);

export type HedraAutomaticAudioInput = { mode: "automatic" };

export type HedraTtsAudioInput = {
  mode: "tts";
  text: string;
  voice: string;
  stability: number;
  speed: number;
};

export type HedraFileAudioInput = {
  mode: "file";
  fileName: string;
  mimeType: "audio/mpeg" | "audio/wav" | "audio/mp4";
  bytes: Uint8Array;
};

export type HedraAudioInput =
  | HedraAutomaticAudioInput
  | HedraTtsAudioInput
  | HedraFileAudioInput;

export type HedraGenerationAudioInput =
  | { audioId: string; audioGeneration?: never }
  | { audioGeneration: Record<string, unknown>; audioId?: never };

export function parseHedraAudioInput(value: unknown): HedraAudioInput {
  if (value == null) return { mode: "automatic" };
  const input = asRecord(value);
  if (!input) throw new Error("audioInput must be an object");

  if (input.mode === "tts") {
    const text = typeof input.text === "string" ? input.text.trim() : "";
    if (!text) throw new Error("audioInput.text is required for TTS");
    if (text.length > HEDRA_TTS_MAX_CHARACTERS) {
      throw new Error(
        `audioInput.text must be at most ${HEDRA_TTS_MAX_CHARACTERS} characters`,
      );
    }
    const voice = typeof input.voice === "string" ? input.voice.trim() : "";
    if (!HEDRA_VOICES.has(voice)) {
      throw new Error("audioInput.voice is not supported");
    }
    return {
      mode: "tts",
      text,
      voice,
      stability: boundedNumber(input.stability, "stability", 0, 1, 0.5),
      speed: boundedNumber(input.speed, "speed", 0.7, 1.2, 1),
    };
  }

  if (input.mode === "file") {
    return parseAudioFile(input);
  }

  throw new Error("audioInput.mode must be either 'file' or 'tts'");
}

export function withExclusiveHedraAudio(
  body: Record<string, unknown>,
  input: HedraGenerationAudioInput,
): Record<string, unknown> {
  const audioId = "audioId" in input && typeof input.audioId === "string"
    ? input.audioId.trim()
    : "";
  const audioGeneration = "audioGeneration" in input
    ? input.audioGeneration
    : null;
  if ((audioId.length > 0) === (audioGeneration != null)) {
    throw new Error("exactly one of audioId or audioGeneration is required");
  }
  const result = { ...body };
  delete result.audio_id;
  delete result.audio_generation;
  if (audioId) result.audio_id = audioId;
  if (audioGeneration) result.audio_generation = audioGeneration;
  return result;
}

function parseAudioFile(input: Record<string, unknown>): HedraFileAudioInput {
  const fileName = typeof input.fileName === "string"
    ? input.fileName.trim()
    : "";
  if (!fileName || fileName.length > 120 || hasUnsafeFileNameChars(fileName)) {
    throw new Error("audioInput.fileName is invalid");
  }
  const mimeType = normalizedMimeType(input.mimeType);
  const extension = fileName.includes(".")
    ? fileName.split(".").pop()!.toLowerCase()
    : "";
  const expectedExtension = mimeType === "audio/mpeg"
    ? "mp3"
    : mimeType === "audio/wav"
    ? "wav"
    : "m4a";
  if (extension !== expectedExtension) {
    throw new Error("audioInput file extension does not match mimeType");
  }
  const dataBase64 = typeof input.dataBase64 === "string"
    ? input.dataBase64
    : "";
  const bytes = decodeBase64(dataBase64);
  if (!matchesAudioSignature(bytes, mimeType)) {
    throw new Error("audioInput file signature does not match mimeType");
  }
  return { mode: "file", fileName, mimeType, bytes };
}

function hasUnsafeFileNameChars(value: string): boolean {
  return [...value].some((character) => {
    const codePoint = character.codePointAt(0) ?? 0;
    return character === "/" || character === "\\" || codePoint <= 0x1f;
  });
}

function normalizedMimeType(
  value: unknown,
): HedraFileAudioInput["mimeType"] {
  if (value === "audio/mpeg") return "audio/mpeg";
  if (value === "audio/wav" || value === "audio/x-wav") return "audio/wav";
  if (value === "audio/mp4" || value === "audio/x-m4a") return "audio/mp4";
  throw new Error("audioInput.mimeType is not supported");
}

function decodeBase64(value: string): Uint8Array {
  if (
    !value || value.length % 4 !== 0 || !/^[A-Za-z0-9+/]*={0,2}$/.test(value)
  ) {
    throw new Error("audioInput.dataBase64 is invalid");
  }
  const maximumEncodedLength = Math.ceil(HEDRA_AUDIO_FILE_MAX_BYTES / 3) * 4;
  if (value.length > maximumEncodedLength) {
    throw new Error("audioInput file must be at most 4MB");
  }
  let decoded: string;
  try {
    decoded = atob(value);
  } catch {
    throw new Error("audioInput.dataBase64 is invalid");
  }
  if (!decoded.length) throw new Error("audioInput file is empty");
  if (decoded.length > HEDRA_AUDIO_FILE_MAX_BYTES) {
    throw new Error("audioInput file must be at most 4MB");
  }
  return Uint8Array.from(decoded, (character) => character.charCodeAt(0));
}

function matchesAudioSignature(
  bytes: Uint8Array,
  mimeType: HedraFileAudioInput["mimeType"],
): boolean {
  if (mimeType === "audio/mpeg") {
    return bytes.length >= 10 &&
      (ascii(bytes, 0, 3) === "ID3" ||
        (bytes[0] === 0xff && (bytes[1] & 0xe0) === 0xe0));
  }
  if (mimeType === "audio/wav") {
    return bytes.length >= 12 && ascii(bytes, 0, 4) === "RIFF" &&
      ascii(bytes, 8, 12) === "WAVE";
  }
  return bytes.length >= 12 && ascii(bytes, 4, 8) === "ftyp";
}

function ascii(bytes: Uint8Array, start: number, end: number): string {
  return String.fromCharCode(...bytes.slice(start, end));
}

function boundedNumber(
  value: unknown,
  name: string,
  min: number,
  max: number,
  fallback: number,
): number {
  const parsed = value == null ? fallback : value;
  if (typeof parsed !== "number" || !Number.isFinite(parsed)) {
    throw new Error(`audioInput.${name} must be a number`);
  }
  if (parsed < min || parsed > max) {
    throw new Error(`audioInput.${name} must be between ${min} and ${max}`);
  }
  return parsed;
}

function asRecord(value: unknown): Record<string, unknown> | null {
  return typeof value === "object" && value !== null && !Array.isArray(value)
    ? value as Record<string, unknown>
    : null;
}
