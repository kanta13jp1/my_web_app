import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  isQiitaAccessEnabled,
  resolveBlogPublishPlatforms,
} from "./blog_publish_policy.ts";

Deno.test("scheduled override narrows stored Qiita+dev.to targets to dev.to", () => {
  assertEquals(
    resolveBlogPublishPlatforms(["qiita", "devto"], ["devto"]),
    { platforms: ["devto"] },
  );
});

Deno.test("omitted override preserves the stored targets", () => {
  assertEquals(
    resolveBlogPublishPlatforms(["qiita", "devto"], undefined),
    { platforms: ["qiita", "devto"] },
  );
});

Deno.test("override cannot add a destination absent from stored targets", () => {
  assertEquals(
    resolveBlogPublishPlatforms(["devto"], ["qiita", "devto"]),
    { platforms: ["devto"] },
  );
});

Deno.test("invalid, empty, and non-matching overrides fail closed", () => {
  for (const override of [[], ["note"], "devto", null]) {
    const result = resolveBlogPublishPlatforms(["qiita", "devto"], override);
    assertEquals(result.platforms, []);
    assertEquals(typeof result.error, "string");
  }
  const nonMatching = resolveBlogPublishPlatforms(["qiita"], ["devto"]);
  assertEquals(nonMatching.platforms, []);
  assertEquals(typeof nonMatching.error, "string");
});

Deno.test("Qiita access is disabled by default and requires explicit true", () => {
  assertEquals(isQiitaAccessEnabled(undefined), false);
  assertEquals(isQiitaAccessEnabled(null), false);
  assertEquals(isQiitaAccessEnabled("false"), false);
  assertEquals(isQiitaAccessEnabled(" true "), true);
});
