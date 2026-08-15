// Tone-aware ElevenLabs voice resolution for the X-share presenter video.
//
// #3794 matched the narration voice to the presenter's *gender* (male /
// female) with a no-config default male voice ("Daniel"). This module layers
// *tone* on top: the client can additionally send "energetic_*" / "calm_*"
// labels, and when a tone-specific ElevenLabs voice secret is configured we use
// it. When it is not, we fall back to the exact same gender base voice #3794
// already uses, so behaviour is unchanged until the user opts in by adding the
// extra secrets.
//
// Pure functions (env is injected) so they are deno-testable without real
// secrets or network access.

export type VoiceGender = "male" | "female";

// Tone-specific labels → the ElevenLabs voice secret to prefer. Labels not
// listed here (e.g. "male_narrator", "female_narrator", legacy
// "ai_secretary_female", "ja-JP") have no tone secret and resolve straight to
// the gender base voice, matching #3794 exactly.
const TONE_VOICE_ENV: Record<string, string> = {
  energetic_female: "ELEVENLABS_VOICE_ENERGETIC_FEMALE_ID",
  calm_female: "ELEVENLABS_VOICE_CALM_FEMALE_ID",
  energetic_male: "ELEVENLABS_VOICE_ENERGETIC_MALE_ID",
  calm_male: "ELEVENLABS_VOICE_CALM_MALE_ID",
};

/**
 * The presenter gender a voice label maps to. "female" is checked before
 * "male" because the string "female" contains "male" as a substring. Unknown
 * labels default to "female", preserving #3794's female-default behaviour.
 */
export function voiceGenderForLabel(
  voiceLabel: string | null | undefined,
): VoiceGender {
  const label = (voiceLabel ?? "").toLowerCase();
  if (label.includes("female")) return "female";
  if (label.includes("male")) return "male";
  return "female";
}

/**
 * Resolve a voice label to an ElevenLabs voiceId.
 *
 * Resolution order:
 *   1. If the label is tone-specific and its dedicated secret is set → that voiceId.
 *   2. Otherwise → the gender base voiceId (the same voice #3794 uses).
 *
 * @param voiceLabel label from the client, e.g. "energetic_male". Legacy /
 *   unknown labels resolve to the female base voice (== #3794's default).
 * @param femaleBaseVoiceId gender base for female presenters (ELEVENLABS_AI_SECRETARY_VOICE_ID).
 * @param maleBaseVoiceId gender base for male presenters (ELEVENLABS_MALE_VOICE_ID / "Daniel").
 * @param env reads a secret by name; inject `Deno.env.get` in production.
 */
export function resolveElevenLabsVoiceId(params: {
  voiceLabel: string | null | undefined;
  femaleBaseVoiceId: string;
  maleBaseVoiceId: string;
  env: (name: string) => string | undefined;
}): string {
  const label = (params.voiceLabel ?? "").trim().toLowerCase();
  const gender = voiceGenderForLabel(label);
  const baseVoiceId = gender === "male"
    ? params.maleBaseVoiceId
    : params.femaleBaseVoiceId;

  const toneEnvName = TONE_VOICE_ENV[label];
  if (toneEnvName) {
    const toneVoiceId = params.env(toneEnvName);
    if (typeof toneVoiceId === "string" && toneVoiceId.trim().length > 0) {
      return toneVoiceId.trim();
    }
  }
  return baseVoiceId;
}

/** Tone labels this module can resolve to a dedicated voice (for tests/tooling). */
export function toneVoiceLabels(): string[] {
  return Object.keys(TONE_VOICE_ENV);
}
