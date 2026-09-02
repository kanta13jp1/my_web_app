import {
  assertEquals,
  assertMatch,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  publicCatalog,
  quoteVideoCredits,
  validateVideoRequest,
  VIDEO_MODELS,
} from "./catalog.ts";

Deno.test("public catalog exposes only the first-party product contract", () => {
  const serialized = JSON.stringify(publicCatalog());
  assertEquals(serialized.includes("fal"), false);
  assertEquals(serialized.includes("veo"), false);
  assertEquals(serialized.includes("wan"), false);
});

Deno.test("video quote is server-owned", () => {
  assertEquals(quoteVideoCredits(VIDEO_MODELS[0], 5), 300);
});

Deno.test("valid request requires rights confirmation", () => {
  const missing = validateVideoRequest({
    prompt: "A paper craft train crosses a snowy bridge",
    duration_seconds: 5,
    aspect_ratio: "16:9",
    resolution: "720p",
  });
  assertEquals(missing.ok, false);
  if (!missing.ok) assertEquals(missing.code, "rights_confirmation_required");
});

Deno.test("valid request ignores client credit claims", () => {
  const result = validateVideoRequest({
    model_key: "studio-video-v1",
    prompt: "A paper craft train crosses a snowy bridge",
    duration_seconds: 5,
    aspect_ratio: "9:16",
    resolution: "720p",
    rights_confirmed: true,
    adult_confirmed: true,
    required_credits: 1,
  });
  assertEquals(result.ok, true);
  if (result.ok) assertEquals(result.value.requiredCredits, 300);
});

Deno.test("minor sexual content is rejected before queue admission", () => {
  const result = validateVideoRequest({
    prompt: "sexualized underage character",
    duration_seconds: 5,
    aspect_ratio: "16:9",
    resolution: "720p",
    rights_confirmed: true,
    adult_confirmed: true,
  });
  assertEquals(result.ok, false);
  if (!result.ok) assertMatch(result.code, /not_allowed/);
});
