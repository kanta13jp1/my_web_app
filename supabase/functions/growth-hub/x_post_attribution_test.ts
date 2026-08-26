import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { resolveXPostAttribution } from "./x_post_attribution.ts";

Deno.test("resolveXPostAttribution preserves explicit variant and UTM content", () => {
  assertEquals(
    resolveXPostAttribution({
      variant: "ai_video",
      utmContent: "video_launch_a",
    }),
    { variant: "ai_video", utmContent: "video_launch_a" },
  );
});

Deno.test("resolveXPostAttribution mirrors variant when UTM content is absent", () => {
  assertEquals(resolveXPostAttribution({ variant: "ai_video" }), {
    variant: "ai_video",
    utmContent: "ai_video",
  });
});

Deno.test("resolveXPostAttribution supports snake case and empty input", () => {
  assertEquals(resolveXPostAttribution({ utm_content: "ai_image" }), {
    variant: "ai_image",
    utmContent: "ai_image",
  });
  assertEquals(resolveXPostAttribution({}), {
    variant: null,
    utmContent: null,
  });
});
