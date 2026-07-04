import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  resolveElevenLabsVoiceId,
  toneVoiceLabels,
  voiceGenderForLabel,
} from "./voice_labels.ts";

const FEMALE_BASE = "female-base-voice";
const MALE_BASE = "male-base-voice";

function resolve(
  voiceLabel: string | undefined,
  env: Record<string, string> = {},
): string {
  return resolveElevenLabsVoiceId({
    voiceLabel,
    femaleBaseVoiceId: FEMALE_BASE,
    maleBaseVoiceId: MALE_BASE,
    env: (name) => env[name],
  });
}

Deno.test("gender labels resolve to the gender base voice (== #3794)", () => {
  assertEquals(resolve("female_narrator"), FEMALE_BASE);
  assertEquals(resolve("male_narrator"), MALE_BASE);
});

Deno.test("legacy and unknown labels keep #3794's female default", () => {
  for (
    const legacy of ["ai_secretary_female", "ja-JP", "en-US", "", undefined]
  ) {
    assertEquals(resolve(legacy), FEMALE_BASE);
  }
});

Deno.test("tone labels fall back to the gender base when no tone secret set", () => {
  // No regression vs #3794: without extra secrets, tone labels use the same
  // gender base voice as the plain narrator labels.
  assertEquals(resolve("energetic_male"), MALE_BASE);
  assertEquals(resolve("calm_male"), MALE_BASE);
  assertEquals(resolve("energetic_female"), FEMALE_BASE);
  assertEquals(resolve("calm_female"), FEMALE_BASE);
});

Deno.test("tone labels use their dedicated secret when configured", () => {
  assertEquals(
    resolve("energetic_male", {
      ELEVENLABS_VOICE_ENERGETIC_MALE_ID: "energetic-male-voice",
    }),
    "energetic-male-voice",
  );
  assertEquals(
    resolve("calm_female", {
      ELEVENLABS_VOICE_CALM_FEMALE_ID: "calm-female-voice",
    }),
    "calm-female-voice",
  );
});

Deno.test("a configured tone secret does not leak to other tones/genders", () => {
  const env = { ELEVENLABS_VOICE_ENERGETIC_MALE_ID: "energetic-male-voice" };
  assertEquals(resolve("energetic_male", env), "energetic-male-voice");
  // calm_male has no dedicated secret → base; energetic_female is a different
  // gender → female base; plain narrators are unaffected.
  assertEquals(resolve("calm_male", env), MALE_BASE);
  assertEquals(resolve("energetic_female", env), FEMALE_BASE);
  assertEquals(resolve("male_narrator", env), MALE_BASE);
});

Deno.test("blank tone secret values are ignored", () => {
  assertEquals(
    resolve("energetic_male", { ELEVENLABS_VOICE_ENERGETIC_MALE_ID: "   " }),
    MALE_BASE,
  );
});

Deno.test("labels are trimmed and case-insensitive", () => {
  assertEquals(
    resolve("  Energetic_Male  ", {
      ELEVENLABS_VOICE_ENERGETIC_MALE_ID: "energetic-male-voice",
    }),
    "energetic-male-voice",
  );
});

Deno.test("voiceGenderForLabel checks female before male", () => {
  assertEquals(voiceGenderForLabel("female_narrator"), "female");
  assertEquals(voiceGenderForLabel("energetic_female"), "female");
  assertEquals(voiceGenderForLabel("male_narrator"), "male");
  assertEquals(voiceGenderForLabel("calm_male"), "male");
  assertEquals(voiceGenderForLabel("ai_secretary_female"), "female");
  assertEquals(voiceGenderForLabel("ja-JP"), "female");
  assertEquals(voiceGenderForLabel(undefined), "female");
});

Deno.test("every tone label is gender-suffixed and resolvable", () => {
  for (const label of toneVoiceLabels()) {
    const gender = label.includes("male") && !label.includes("female")
      ? "male"
      : "female";
    assertEquals(voiceGenderForLabel(label), gender);
    // Falls back to the correct gender base when no secret is set.
    assertEquals(resolve(label), gender === "male" ? MALE_BASE : FEMALE_BASE);
  }
});
