import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  buildFalTextToVideoPayload,
  extractFalVideoUrl,
  falQueueAppId,
  isFalExhaustedBalanceError,
  normalizeFalQueueStatus,
  resolveFalApiKey,
} from "./fal_video.ts";

// 2026-07-25 実障害の回帰ガード。値は 2026-04-18 から FAL_API_KEY として
// 存在したのに、コードが FAL_KEY しか読まず動画が静かに落ちていた。
Deno.test("resolveFalApiKey prefers FAL_KEY when both names are set", () => {
  const env: Record<string, string> = {
    FAL_KEY: "primary",
    FAL_API_KEY: "secondary",
  };
  assertEquals(resolveFalApiKey((name) => env[name]), "primary");
});

Deno.test("resolveFalApiKey falls back to FAL_API_KEY", () => {
  const env: Record<string, string> = { FAL_API_KEY: "secondary" };
  assertEquals(resolveFalApiKey((name) => env[name]), "secondary");
});

Deno.test("resolveFalApiKey returns empty string when neither name is set", () => {
  assertEquals(resolveFalApiKey(() => undefined), "");
});

Deno.test("resolveFalApiKey skips blank values and trims", () => {
  const env: Record<string, string> = {
    FAL_KEY: "   ",
    FAL_API_KEY: "  secondary  ",
  };
  assertEquals(resolveFalApiKey((name) => env[name]), "secondary");
});

Deno.test("falQueueAppId keeps owner/alias and drops model sub-paths", () => {
  assertEquals(falQueueAppId("fal-ai/veo3/fast"), "fal-ai/veo3");
  assertEquals(
    falQueueAppId("fal-ai/kling-video/v2.5-turbo/pro/text-to-video"),
    "fal-ai/kling-video",
  );
  assertEquals(falQueueAppId("fal-ai/veo3"), "fal-ai/veo3");
  assertEquals(falQueueAppId("fal-ai/veo3/"), "fal-ai/veo3");
});

Deno.test("buildFalTextToVideoPayload defaults to prompt + 16:9", () => {
  const payload = buildFalTextToVideoPayload({ prompt: "paper craft samurai" });
  assertEquals(payload, {
    prompt: "paper craft samurai",
    aspect_ratio: "16:9",
  });
});

Deno.test("buildFalTextToVideoPayload merges extra params but keeps prompt", () => {
  const payload = buildFalTextToVideoPayload({
    prompt: "paper craft samurai",
    extraParamsJson: '{"duration":"8s","resolution":"720p","prompt":"evil"}',
  });
  assertEquals(payload["duration"], "8s");
  assertEquals(payload["resolution"], "720p");
  assertEquals(payload["prompt"], "paper craft samurai");
  assertEquals(payload["aspect_ratio"], "16:9");
});

Deno.test("buildFalTextToVideoPayload ignores broken extra params JSON", () => {
  const payload = buildFalTextToVideoPayload({
    prompt: "paper craft samurai",
    extraParamsJson: "{broken",
  });
  assertEquals(payload, {
    prompt: "paper craft samurai",
    aspect_ratio: "16:9",
  });
});

Deno.test("normalizeFalQueueStatus maps queue states", () => {
  assertEquals(normalizeFalQueueStatus("IN_QUEUE"), "queued");
  assertEquals(normalizeFalQueueStatus("IN_PROGRESS"), "processing");
  assertEquals(normalizeFalQueueStatus("COMPLETED"), "completed");
  assertEquals(normalizeFalQueueStatus("FAILED"), "failed");
  assertEquals(normalizeFalQueueStatus("CANCELLED"), "failed");
  // 未知値は完了扱いせず polling 継続にする。
  assertEquals(normalizeFalQueueStatus("SOMETHING_NEW"), "processing");
  assertEquals(normalizeFalQueueStatus(null), "processing");
});

Deno.test("extractFalVideoUrl accepts common fal output shapes", () => {
  assertEquals(
    extractFalVideoUrl({ video: { url: "https://fal.media/v.mp4" } }),
    "https://fal.media/v.mp4",
  );
  assertEquals(
    extractFalVideoUrl({ video_url: "https://fal.media/v2.mp4" }),
    "https://fal.media/v2.mp4",
  );
  assertEquals(
    extractFalVideoUrl({ videos: [{ url: "https://fal.media/v3.mp4" }] }),
    "https://fal.media/v3.mp4",
  );
  assertEquals(
    extractFalVideoUrl({
      response: { video: { url: "https://fal.media/v4.mp4" } },
    }),
    "https://fal.media/v4.mp4",
  );
  assertEquals(extractFalVideoUrl({ video: { url: "not-a-url" } }), null);
  assertEquals(extractFalVideoUrl({}), null);
  assertEquals(extractFalVideoUrl(null), null);
});

Deno.test("isFalExhaustedBalanceError detects billing failures", () => {
  assertEquals(
    isFalExhaustedBalanceError(
      new Error('fal.ai API 403: {"detail":"Exhausted balance"}'),
    ),
    true,
  );
  assertEquals(
    isFalExhaustedBalanceError(new Error("fal.ai API 500: server error")),
    false,
  );
});
