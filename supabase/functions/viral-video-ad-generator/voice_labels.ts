// ElevenLabs voice-label resolution for the X-share presenter video pipeline.
//
// The client (universal_x_share_service.dart) rotates the on-screen presenter
// character (39 variants, both genders) and now sends a matching *voice label*
// (e.g. "male_narrator", "energetic_female") so the narration voice matches the
// presenter's face and lip movement instead of always using the single female
// AI-secretary voice.
//
// This module maps a voice label to an ElevenLabs voiceId secret. It is a pure
// function (env is injected) so it can be deno-tested without real secrets or
// network access. When the label's dedicated secret is not configured it
// returns `voiceId: null`, and the caller falls back to the existing single
// AI-secretary voice — so shares keep working before the user finishes adding
// the extra ElevenLabs voices.

export type VoiceGender = "male" | "female";

export type VoiceLabelResolution = {
  /**
   * ElevenLabs voiceId resolved from a configured secret, or null when no
   * dedicated secret is set for this label. Callers apply their own default
   * (ELEVENLABS_AI_SECRETARY_VOICE_ID) when this is null.
   */
  voiceId: string | null;
  /** Intended presenter gender, used to bias fallback voice discovery. */
  gender: VoiceGender | null;
  /** Normalized known label, or null when the incoming label is not recognized. */
  label: string | null;
};

type VoiceLabelConfig = {
  gender: VoiceGender;
  // Ordered secret names: tone-specific first, then the gender base voice.
  envCandidates: string[];
};

// Keep this list small so the number of ElevenLabs voices the user must provide
// stays manageable. Tone-specific secrets are optional and gracefully fall back
// to the gender base voice, which in turn falls back (in the caller) to the
// existing single AI-secretary voice.
const VOICE_LABELS: Record<string, VoiceLabelConfig> = {
  female_narrator: {
    gender: "female",
    envCandidates: ["ELEVENLABS_VOICE_FEMALE_ID"],
  },
  energetic_female: {
    gender: "female",
    envCandidates: [
      "ELEVENLABS_VOICE_ENERGETIC_FEMALE_ID",
      "ELEVENLABS_VOICE_FEMALE_ID",
    ],
  },
  calm_female: {
    gender: "female",
    envCandidates: [
      "ELEVENLABS_VOICE_CALM_FEMALE_ID",
      "ELEVENLABS_VOICE_FEMALE_ID",
    ],
  },
  male_narrator: {
    gender: "male",
    envCandidates: ["ELEVENLABS_VOICE_MALE_ID"],
  },
  energetic_male: {
    gender: "male",
    envCandidates: [
      "ELEVENLABS_VOICE_ENERGETIC_MALE_ID",
      "ELEVENLABS_VOICE_MALE_ID",
    ],
  },
  calm_male: {
    gender: "male",
    envCandidates: [
      "ELEVENLABS_VOICE_CALM_MALE_ID",
      "ELEVENLABS_VOICE_MALE_ID",
    ],
  },
};

/**
 * Resolve an incoming voice label to an ElevenLabs voiceId secret.
 *
 * @param label the voice label sent by the client (case-insensitive), e.g.
 *   "male_narrator". Unknown labels (including legacy "ai_secretary_female",
 *   "ja-JP", raw UUIDs, or undefined) resolve to `{ voiceId: null, gender: null }`
 *   so the caller keeps its current default behaviour.
 * @param env reads a secret by name; inject `Deno.env.get` in production.
 */
export function resolveElevenLabsVoiceForLabel(
  label: string | null | undefined,
  env: (name: string) => string | undefined,
): VoiceLabelResolution {
  const key = (label ?? "").trim().toLowerCase();
  const config = VOICE_LABELS[key];
  if (!config) {
    return { voiceId: null, gender: null, label: null };
  }
  for (const name of config.envCandidates) {
    const value = env(name);
    if (typeof value === "string" && value.trim().length > 0) {
      return { voiceId: value.trim(), gender: config.gender, label: key };
    }
  }
  // Known label but no dedicated secret yet: keep the intended gender so the
  // caller can still bias fallback voice discovery, but signal null voiceId so
  // it falls back to the existing single AI-secretary voice.
  return { voiceId: null, gender: config.gender, label: key };
}

/** The set of voice labels this module understands (for tests/tooling). */
export function knownVoiceLabels(): string[] {
  return Object.keys(VOICE_LABELS);
}
