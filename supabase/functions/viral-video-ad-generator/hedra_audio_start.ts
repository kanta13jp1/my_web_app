export const HEDRA_AUDIO_START_MIN_MS = -30_000;
export const HEDRA_AUDIO_START_MAX_MS = 30_000;

export function parseHedraAudioStartMs(value: unknown): number {
  if (value == null || value === "") return 0;
  if (typeof value !== "number" || !Number.isSafeInteger(value)) {
    throw new Error("audioStartMs must be an integer");
  }
  if (
    value < HEDRA_AUDIO_START_MIN_MS ||
    value > HEDRA_AUDIO_START_MAX_MS
  ) {
    throw new Error(
      `audioStartMs must be between ${HEDRA_AUDIO_START_MIN_MS} and ${HEDRA_AUDIO_START_MAX_MS}`,
    );
  }
  return value;
}

export function withHedraAudioStartMs(
  body: Record<string, unknown>,
  audioStartMs: number,
): Record<string, unknown> {
  return { ...body, audio_start_ms: audioStartMs };
}
