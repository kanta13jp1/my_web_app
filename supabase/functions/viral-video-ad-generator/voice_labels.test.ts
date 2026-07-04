import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  knownVoiceLabels,
  resolveElevenLabsVoiceForLabel,
} from "./voice_labels.ts";

function envFrom(
  map: Record<string, string>,
): (name: string) => string | undefined {
  return (name) => map[name];
}

Deno.test("male label resolves to the configured male voice", () => {
  const result = resolveElevenLabsVoiceForLabel(
    "male_narrator",
    envFrom({ ELEVENLABS_VOICE_MALE_ID: "male-voice-1" }),
  );
  assertEquals(result.voiceId, "male-voice-1");
  assertEquals(result.gender, "male");
  assertEquals(result.label, "male_narrator");
});

Deno.test("female label resolves to the configured female voice", () => {
  const result = resolveElevenLabsVoiceForLabel(
    "female_narrator",
    envFrom({ ELEVENLABS_VOICE_FEMALE_ID: "female-voice-1" }),
  );
  assertEquals(result.voiceId, "female-voice-1");
  assertEquals(result.gender, "female");
});

Deno.test("tone-specific label falls back to the gender base voice", () => {
  const result = resolveElevenLabsVoiceForLabel(
    "energetic_male",
    envFrom({ ELEVENLABS_VOICE_MALE_ID: "male-voice-base" }),
  );
  // No ELEVENLABS_VOICE_ENERGETIC_MALE_ID configured, so it uses the base voice.
  assertEquals(result.voiceId, "male-voice-base");
  assertEquals(result.gender, "male");
});

Deno.test("tone-specific label prefers its dedicated voice when set", () => {
  const result = resolveElevenLabsVoiceForLabel(
    "energetic_male",
    envFrom({
      ELEVENLABS_VOICE_ENERGETIC_MALE_ID: "energetic-male",
      ELEVENLABS_VOICE_MALE_ID: "male-voice-base",
    }),
  );
  assertEquals(result.voiceId, "energetic-male");
});

Deno.test("case-insensitive label matching", () => {
  const result = resolveElevenLabsVoiceForLabel(
    "  Male_Narrator  ",
    envFrom({ ELEVENLABS_VOICE_MALE_ID: "male-voice-1" }),
  );
  assertEquals(result.voiceId, "male-voice-1");
  assertEquals(result.gender, "male");
});

Deno.test("known label without any configured secret keeps intended gender but null voiceId", () => {
  const result = resolveElevenLabsVoiceForLabel("male_narrator", envFrom({}));
  // Graceful fallback: caller uses its default single AI-secretary voice, but
  // the intended gender is preserved so fallback discovery can still bias male.
  assertEquals(result.voiceId, null);
  assertEquals(result.gender, "male");
  assertEquals(result.label, "male_narrator");
});

Deno.test("legacy and unknown labels resolve to caller default (null)", () => {
  for (
    const legacy of ["ai_secretary_female", "ja-JP", "en-US", "", undefined]
  ) {
    const result = resolveElevenLabsVoiceForLabel(
      legacy,
      envFrom({ ELEVENLABS_VOICE_MALE_ID: "male-voice-1" }),
    );
    assertEquals(result.voiceId, null);
    assertEquals(result.gender, null);
    assertEquals(result.label, null);
  }
});

Deno.test("blank secret values are ignored", () => {
  const result = resolveElevenLabsVoiceForLabel(
    "female_narrator",
    envFrom({ ELEVENLABS_VOICE_FEMALE_ID: "   " }),
  );
  assertEquals(result.voiceId, null);
  assertEquals(result.gender, "female");
});

Deno.test("all known labels are gender-suffixed and resolvable", () => {
  for (const label of knownVoiceLabels()) {
    const result = resolveElevenLabsVoiceForLabel(
      label,
      envFrom({
        ELEVENLABS_VOICE_MALE_ID: "m",
        ELEVENLABS_VOICE_FEMALE_ID: "f",
      }),
    );
    assertEquals(result.label, label);
    assertEquals(
      result.gender,
      label.includes("male") && !label.includes("female") ? "male" : "female",
    );
    assertEquals(result.voiceId, result.gender === "male" ? "m" : "f");
  }
});
